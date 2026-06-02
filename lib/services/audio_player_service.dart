import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song.dart';
import '../database/database_helper.dart';
import '../models/user_stats.dart';
import '../models/repeat_mode.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  final DatabaseHelper _db = DatabaseHelper();

  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _isShuffle = false;
  RepeatMode _repeatMode = RepeatMode.none;
  List<int> _shuffleIndices = [];

  // BUG FIX: track skip attempts to prevent infinite recursion when all files are broken
  int _skipAttempts = 0;

  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;

  Song? _currentSong;
  DateTime? _playStartTime;

  StreamController<Song?> _currentSongController =
      StreamController<Song?>.broadcast();

  AudioPlayer get player => _player;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isShuffle => _isShuffle;
  RepeatMode get repeatMode => _repeatMode;
  Song? get currentSong => _currentSong;
  bool get isPlaying => _player.playing;
  Duration? get sleepTimerRemaining =>
      _sleepTimerEnd != null && _sleepTimerEnd!.isAfter(DateTime.now())
          ? _sleepTimerEnd!.difference(DateTime.now())
          : null;

  Stream<Song?> get currentSongStream => _currentSongController.stream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<double> get volumeStream => _player.volumeStream;

  Future<void> init() async {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onSongCompleted();
      }
    });
  }

  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    _queue = List.from(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    _skipAttempts = 0;

    if (_isShuffle) {
      _generateShuffleIndices();
    }
    await _playCurrentSong();
  }

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
      await _player.play();
      // BUG FIX: reset skip counter on successful play
      _skipAttempts = 0;
      await _db.incrementPlayCount(song.id!);
    } catch (e) {
      // BUG FIX: cap skip attempts to prevent infinite loop when all files broken
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
    await _saveListeningHistory();
  }

  Future<void> resume() async => await _player.play();

  // BUG FIX: internal skip used during error recovery (doesn't save history)
  Future<void> _skipToNext() async {
    if (_isShuffle) {
      final shuffleIdx = _shuffleIndices.indexOf(_currentIndex);
      if (shuffleIdx < _shuffleIndices.length - 1) {
        _currentIndex = _shuffleIndices[shuffleIdx + 1];
      } else if (_repeatMode == RepeatMode.all) {
        _generateShuffleIndices();
        _currentIndex = _shuffleIndices.first;
      } else {
        return;
      }
    } else {
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
      } else if (_repeatMode == RepeatMode.all) {
        _currentIndex = 0;
      } else {
        return;
      }
    }
    await _playCurrentSong();
  }

  Future<void> next() async {
    await _saveListeningHistory();
    _skipAttempts = 0;
    await _skipToNext();
  }

  Future<void> previous() async {
    await _saveListeningHistory();

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
    _currentIndex = index;
    _skipAttempts = 0;
    await _playCurrentSong();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) {
      _generateShuffleIndices();
    }
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.none:
        _repeatMode = RepeatMode.all;
        _player.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        _player.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.none;
        _player.setLoopMode(LoopMode.off);
        break;
    }
  }

  void _generateShuffleIndices() {
    _shuffleIndices = List.generate(_queue.length, (i) => i)..shuffle();
    _shuffleIndices.remove(_currentIndex);
    _shuffleIndices.insert(0, _currentIndex);
  }

  void _onSongCompleted() {
    _saveListeningHistory();
    if (_repeatMode == RepeatMode.one) {
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
      // diff == 0 means same day, don't change streak
    }
    stats.lastPlayedDate = today;
    await _db.updateUserStats(stats);
    _playStartTime = DateTime.now();
  }

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimerEnd = DateTime.now().add(Duration(minutes: minutes));

    // BUG FIX: fade starts 30s before end, not during entire timer
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
    _player.setVolume(1.0);
  }

  Future<void> disposeService() async {
    await _saveListeningHistory();
    _sleepTimer?.cancel();
    await _currentSongController.close();
    await _player.dispose();
  }
}
