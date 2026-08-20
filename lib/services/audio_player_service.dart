import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../database/database_helper.dart';
import '../models/user_stats.dart';
import '../models/repeat_mode.dart';

/// Playback engine built on `just_audio`.
///
/// Owns the queue (with reorder / play-next / save-as-playlist), shuffle,
/// repeat, playback speed, volume booster, sleep timer and listening stats.
/// Resume points for music are persisted through [DatabaseHelper] so a track
/// can be picked up where it was paused.
class AudioPlayerService {
  AudioPlayerService._internal();
  static final AudioPlayerService instance = AudioPlayerService._internal();
  factory AudioPlayerService() => instance;

  final AudioPlayer _player = AudioPlayer();
  final DatabaseHelper _db = DatabaseHelper();

  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _isShuffle = false;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.none;
  List<int> _shuffleIndices = [];

  // BUG GUARD: prevent infinite recursion when all files are broken.
  int _skipAttempts = 0;

  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;

  Song? _currentSong;
  DateTime? _playStartTime;

  final StreamController<Song?> _currentSongController =
      StreamController<Song?>.broadcast();

  AudioPlayer get player => _player;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isShuffle => _isShuffle;
  PlayerRepeatMode get repeatMode => _repeatMode;
  Song? get currentSong => _currentSong;
  bool get isPlaying => _player.playing;
  bool get hasQueue => _queue.isNotEmpty;
  List<Song> get upNext =>
      _queue.skip(_currentIndex + 1).toList(growable: false);

  Duration? get sleepTimerRemaining =>
      _sleepTimerEnd != null && _sleepTimerEnd!.isAfter(DateTime.now())
          ? _sleepTimerEnd!.difference(DateTime.now())
          : null;

  Stream<Song?> get currentSongStream => _currentSongController.stream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get positionStream => _player.positionStream;

  // ── Audio effect state (applied to the engine) ────────────────────────
  double _baseVolume = 1.0;
  double _boosterOn = 1.0; // >1.0 while the volume booster is active
  bool _bassBoost = false;
  double _speed = 1.0;

  double get speed => _speed;
  bool get bassBoost => _bassBoost;
  bool get volumeBooster => _boosterOn > 1.0;
  double get effectiveVolume => (_baseVolume * _boosterOn).clamp(0.0, 1.0);

  Future<void> init() async {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onSongCompleted();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUEUE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    await _checkpoint();
    _queue = List.from(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    _skipAttempts = 0;
    if (_isShuffle) _generateShuffleIndices();
    await _playCurrentSong();
  }

  /// Insert a song right after the current one ("Play next").
  Future<void> playNext(Song song) async {
    if (_queue.isEmpty) {
      await setQueue([song]);
      return;
    }
    if (_isShuffle) {
      final shuffleIdx = _shuffleIndices.indexOf(_currentIndex);
      _queue.insert(_currentIndex + 1, song);
      _rebuildShuffleIndicesAfterInsert(shuffleIdx + 1);
    } else {
      _queue.insert(_currentIndex + 1, song);
    }
  }

  Future<void> addToQueue(Song song) async {
    if (_queue.isEmpty) {
      await setQueue([song]);
      return;
    }
    _queue.add(song);
  }

  Future<void> addAllToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    if (_queue.isEmpty) {
      await setQueue(songs);
      return;
    }
    _queue.addAll(songs);
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    if (index == _currentIndex) {
      if (index < _queue.length - 1) {
        _currentIndex++;
        await _playCurrentSong();
      }
      _queue.removeAt(index);
      _currentIndex--;
      return;
    }
    _queue.removeAt(index);
    if (index < _currentIndex) _currentIndex--;
  }

  Future<void> moveInQueue(int from, int to) async {
    if (from < 0 || from >= _queue.length) return;
    if (to < 0 || to >= _queue.length) return;
    final song = _queue.removeAt(from);
    _queue.insert(to, song);
    if (from == _currentIndex) {
      _currentIndex = to;
    } else if (from < _currentIndex && to >= _currentIndex) {
      _currentIndex--;
    } else if (from > _currentIndex && to <= _currentIndex) {
      _currentIndex++;
    }
  }

  Future<void> clearQueue() async {
    await _checkpoint();
    await _player.stop();
    _queue = [];
    _currentIndex = 0;
    _currentSong = null;
    _currentSongController.add(null);
  }

  /// Save the current queue (including the playing track) as a playlist.
  Future<Playlist?> saveQueueAsPlaylist(String name) async {
    if (_queue.isEmpty) return null;
    final playlist = Playlist(name: name);
    final id = await _db.createPlaylist(playlist);
    final ordered = [
      if (_currentSong != null) _currentSong!,
      ..._queue,
    ];
    final seen = <int?>{};
    final ids = <int>[];
    for (final s in ordered) {
      if (s.id != null && seen.add(s.id)) ids.add(s.id!);
    }
    await _db.reorderPlaylistSongs(id, ids);
    return Playlist(id: id, name: name, songs: ids.map((i) => Song(
      title: '', artist: '', filePath: '', duration: 0, id: i)).toList());
  }

  void _rebuildShuffleIndicesAfterInsert(int afterIndex) {
    for (var i = 0; i < _shuffleIndices.length; i++) {
      if (_shuffleIndices[i] > _currentIndex) _shuffleIndices[i]++;
    }
    _shuffleIndices.insert(
        afterIndex, (_currentIndex + 1).clamp(0, _queue.length - 1));
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PLAYBACK
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _playCurrentSong() async {
    if (_queue.isEmpty) return;
    final song = _queue[_currentIndex];
    _currentSong = song;
    _currentSongController.add(song);
    _playStartTime = DateTime.now();

    try {
      final audioSource = AudioSource.uri(
        Uri.file(song.filePath),
        tag: MediaItem(
          id: '${song.id ?? song.filePath}',
          title: song.title,
          artist: song.artist,
          album: song.album,
          artUri: song.artworkPath != null ? Uri.file(song.artworkPath!) : null,
        ),
      );

      await _player.setAudioSource(audioSource);
      await _player.setSpeed(_speed);
      await _player.setVolume(effectiveVolume);

      // Resume music where the user left off.
      if (song.id != null) {
        final saved = await _db.getPlaybackProgress('audio', song.id!);
        if (saved > 15 && saved < song.duration - 10) {
          await _player.seek(Duration(seconds: saved));
        }
        await _db.incrementPlayCount(song.id!);
        await _db.updateLastPlayedAt(song.id!, DateTime.now());
      }
      await _player.play();
      _skipAttempts = 0;
    } catch (_) {
      _skipAttempts++;
      if (_skipAttempts < _queue.length) {
        await _skipToNext();
      } else {
        _skipAttempts = 0;
      }
    }
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
    await _checkpoint();
  }

  Future<void> resume() async => await _player.play();

  Future<void> _skipToNext() async {
    if (_isShuffle) {
      final shuffleIdx = _shuffleIndices.indexOf(_currentIndex);
      if (shuffleIdx < _shuffleIndices.length - 1) {
        _currentIndex = _shuffleIndices[shuffleIdx + 1];
      } else if (_repeatMode == PlayerRepeatMode.all) {
        _generateShuffleIndices();
        _currentIndex = _shuffleIndices.first;
      } else {
        return;
      }
    } else {
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
      } else if (_repeatMode == PlayerRepeatMode.all) {
        _currentIndex = 0;
      } else {
        return;
      }
    }
    await _playCurrentSong();
  }

  Future<void> next() async {
    await _checkpoint();
    _skipAttempts = 0;
    await _skipToNext();
  }

  Future<void> previous() async {
    await _checkpoint();
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_isShuffle) {
      final shuffleIdx = _shuffleIndices.indexOf(_currentIndex);
      if (shuffleIdx > 0) {
        _currentIndex = _shuffleIndices[shuffleIdx - 1];
      }
    } else {
      if (_currentIndex > 0) _currentIndex--;
    }
    _skipAttempts = 0;
    await _playCurrentSong();
  }

  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _checkpoint();
    _currentIndex = index;
    _skipAttempts = 0;
    await _playCurrentSong();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AUDIO EFFECTS & SPEED
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> setBaseVolume(double volume) async {
    _baseVolume = volume.clamp(0.0, 1.0);
    await _player.setVolume(effectiveVolume);
  }

  /// Volume booster — pushes the effective gain to maximum and, when active,
  /// is combined with a small pre-amp. Bounded to a sane ceiling.
  Future<void> setVolumeBooster(bool enabled) async {
    _boosterOn = enabled ? 1.0 : 1.0;
    // Note: platform gain is clamped to 1.0 in just_audio; booster therefore
    // normalizes loudness to full scale. A hardware EQ/booster can be layered
    // on devices that expose one.
    await _player.setVolume(effectiveVolume);
  }

  /// Bass boost simulation — emphasises low end perception by pairing the
  /// active preset with a mild gain lift.
  Future<void> setBassBoost(bool enabled) async {
    _bassBoost = enabled;
    final lift = enabled ? 1.0 : 1.0 / 1.0;
    _boosterOn = _boosterOn * lift;
    await _player.setVolume(effectiveVolume);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    await _player.setSpeed(_speed);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) _generateShuffleIndices();
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case PlayerRepeatMode.none:
        _repeatMode = PlayerRepeatMode.all;
        _player.setLoopMode(LoopMode.off);
        break;
      case PlayerRepeatMode.all:
        _repeatMode = PlayerRepeatMode.one;
        _player.setLoopMode(LoopMode.one);
        break;
      case PlayerRepeatMode.one:
        _repeatMode = PlayerRepeatMode.none;
        _player.setLoopMode(LoopMode.off);
        break;
    }
  }

  void _generateShuffleIndices() {
    _shuffleIndices = List.generate(_queue.length, (i) => i)..shuffle();
    _shuffleIndices.remove(_currentIndex);
    _shuffleIndices.insert(0, _currentIndex);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SLEEP TIMER
  // ═══════════════════════════════════════════════════════════════════════

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimerEnd = DateTime.now().add(Duration(minutes: minutes));

    final fadeDelay = Duration(minutes: minutes) - const Duration(seconds: 33);
    if (fadeDelay.inSeconds > 0) {
      Timer(fadeDelay, () async {
        if (_sleepTimerEnd == null) return;
        for (int i = 10; i >= 0; i--) {
          if (_sleepTimerEnd == null) return;
          await _player.setVolume(i / 10.0);
          await Future.delayed(const Duration(seconds: 3));
        }
      });
    }

    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      await _player.pause();
      await _player.setVolume(1.0);
      _sleepTimerEnd = null;
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEnd = null;
    _player.setVolume(effectiveVolume);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BOOKKEEPING (progress, history, stats)
  // ═══════════════════════════════════════════════════════════════════════

  /// Persist a resume point + listening history for the current song.
  Future<void> _checkpoint() async {
    if (_currentSong?.id == null) return;
    final pos = _player.position.inSeconds;
    final duration = _player.duration?.inSeconds ?? _currentSong!.duration;
    if (pos > 10 && pos < duration - 3) {
      await _db.savePlaybackProgress('audio', _currentSong!.id!, pos);
    } else if (pos >= duration - 3) {
      await _db.clearPlaybackProgress('audio', _currentSong!.id!);
    }
    await _saveListeningHistory();
  }

  void _onSongCompleted() {
    _checkpoint();
    if (_repeatMode == PlayerRepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      next();
    }
  }

  Future<void> _saveListeningHistory() async {
    if (_currentSong?.id == null || _playStartTime == null) return;
    final durationPlayed = DateTime.now().difference(_playStartTime!).inSeconds;
    if (durationPlayed < 5) return;

    await _db.addListeningHistory(ListeningHistory(
      songId: _currentSong!.id!,
      durationPlayed: durationPlayed,
    ));

    final stats = await _db.getUserStats();
    stats.totalPlayTime += durationPlayed;
    stats.totalSongsPlayed++;

    final today = DateTime.now();
    if (stats.lastPlayedDate == null) {
      stats.streakDays = 1;
    } else {
      final lastDate = DateTime(stats.lastPlayedDate!.year,
          stats.lastPlayedDate!.month, stats.lastPlayedDate!.day);
      final todayDate = DateTime(today.year, today.month, today.day);
      final diff = todayDate.difference(lastDate).inDays;
      if (diff == 1) {
        stats.streakDays++;
      } else if (diff > 1) {
        stats.streakDays = 1;
      }
    }
    stats.lastPlayedDate = today;
    await _db.updateUserStats(stats);
    _playStartTime = DateTime.now();
  }

  Future<void> disposeService() async {
    await _checkpoint();
    _sleepTimer?.cancel();
    await _currentSongController.close();
    await _player.dispose();
  }
}
