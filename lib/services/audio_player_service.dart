import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';
import '../database/database_helper.dart';
import '../models/user_stats.dart';
import '../models/repeat_mode.dart';
import '../models/playback_event.dart' as app_events;

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  final DatabaseHelper _db = DatabaseHelper();

  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _isShuffle = false;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.none;
  List<int> _shuffleIndices = [];

  // BUG FIX: track skip attempts to prevent infinite recursion when all files are broken
  int _skipAttempts = 0;

  Timer? _sleepTimer;
  Timer? _sleepFadeTimer;
  DateTime? _sleepTimerEnd;

  Song? _currentSong;
  DateTime? _playStartTime;
  int _sessionListenedSeconds = 0;

  final StreamController<Song?> _currentSongController =
      StreamController<Song?>.broadcast();

  bool _isInitialized = false;

  AudioPlayer get player => _player;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isShuffle => _isShuffle;
  PlayerRepeatMode get repeatMode => _repeatMode;
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
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('Audio session configuration skipped: $e');
    }

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

  Future<void> addToQueue(Song song) async {
    if (_queue.any((queuedSong) => queuedSong.id == song.id)) return;
    _queue = [..._queue, song];
  }

  Future<void> playNext(Song song) async {
    if (_queue.any((queuedSong) => queuedSong.id == song.id)) return;
    if (_queue.isEmpty) {
      await setQueue([song]);
      return;
    }
    final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertAt, song);
    if (_isShuffle) _generateShuffleIndices();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length || index == _currentIndex) {
      return;
    }
    _queue.removeAt(index);
    if (index < _currentIndex) _currentIndex--;
    if (_currentIndex >= _queue.length) _currentIndex = _queue.length - 1;
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex > oldIndex) newIndex--;
    if (newIndex < 0 || newIndex >= _queue.length) return;

    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    if (_isShuffle) {
      _generateShuffleIndices();
    }
  }

  Future<void> clearQueue() async {
    await _finishListeningSession();
    await _player.stop();
    _queue = [];
    _currentIndex = 0;
    _currentSong = null;
    _currentSongController.add(null);
  }

  Future<void> _playCurrentSong() async {
    if (_queue.isEmpty) return;

    await _finishListeningSession();
    final song = _queue[_currentIndex];
    _currentSong = song;
    _currentSongController.add(song);
    _playStartTime = null;
    _sessionListenedSeconds = 0;

    try {
      if (song.filePath.isEmpty) {
        debugPrint('Empty file path for song: ${song.title}');
        _skipAttempts++;
        if (_skipAttempts < _queue.length) {
          await _skipToNext();
        } else {
          _skipAttempts = 0;
        }
        return;
      }

      final file = File(song.filePath);
      if (!await file.exists()) {
        debugPrint('File missing: ${song.filePath}');
        _skipAttempts++;
        if (_skipAttempts < _queue.length) {
          await _skipToNext();
        } else {
          _skipAttempts = 0;
        }
        return;
      }

      Uri? artUri;
      if (song.artworkPath != null) {
        if (song.artworkPath!.startsWith('content://')) {
          artUri = Uri.parse(song.artworkPath!);
        } else if (File(song.artworkPath!).existsSync()) {
          artUri = Uri.file(song.artworkPath!);
        }
      }

      final audioSource = AudioSource.uri(
        Uri.file(song.filePath),
        tag: MediaItem(
          id: '${song.id ?? song.filePath}',
          title: song.title,
          artist: song.artist,
          album: song.album,
          artUri: artUri,
        ),
      );

      await _player.setAudioSource(audioSource);
      await _player.setVolume(1.0);
      debugPrint('Audio source set, starting playback: ${song.title}');
      await _player.play();
      debugPrint('Playback started for: ${song.title}');
      _beginListeningSession();
      await _recordEvent(app_events.PlaybackEventType.started);
      _skipAttempts = 0;
      if (song.id != null) await _db.incrementPlayCount(song.id!);
    } catch (e) {
      debugPrint('Playback failed for ${song.filePath}: $e');
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
    _beginListeningSession();
  }

  Future<void> pause() async {
    await _player.pause();
    await _recordEvent(app_events.PlaybackEventType.paused);
    await _finishListeningSession();
  }

  Future<void> resume() async {
    await _player.play();
    _beginListeningSession();
    await _recordEvent(app_events.PlaybackEventType.resumed);
  }

  void _beginListeningSession() {
    if (_currentSong != null && _playStartTime == null) {
      _playStartTime = DateTime.now();
    }
  }

  // BUG FIX: internal skip used during error recovery (doesn't save history)
  Future<void> _skipToNext() async {
    if (_isShuffle) {
      final shuffleIdx = _shuffleIndices.indexOf(_currentIndex);
      if (shuffleIdx < _shuffleIndices.length - 1) {
        _currentIndex = _shuffleIndices[shuffleIdx + 1];
      } else if (_repeatMode == PlayerRepeatMode.all) {
        _generateShuffleIndices();
        if (_shuffleIndices.length > 1) {
          _currentIndex = _shuffleIndices[1];
        }
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
    await _recordEvent(app_events.PlaybackEventType.skipped);
    await _finishListeningSession();
    _skipAttempts = 0;
    await _skipToNext();
  }

  Future<void> previous() async {
    await _finishListeningSession();

    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      _beginListeningSession();
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
      case PlayerRepeatMode.none:
        _repeatMode = PlayerRepeatMode.all;
        _player.setLoopMode(LoopMode.all);
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
    if (_shuffleIndices.contains(_currentIndex)) {
      _shuffleIndices.remove(_currentIndex);
    }
    _shuffleIndices.insert(0, _currentIndex);
  }

  void _onSongCompleted() {
    _handleSongCompleted();
  }

  Future<void> _handleSongCompleted() async {
    await _recordEvent(app_events.PlaybackEventType.completed);
    await _finishListeningSession();
    if (_repeatMode == PlayerRepeatMode.one) {
      await _player.seek(Duration.zero);
      await _player.play();
      _beginListeningSession();
    } else {
      await _skipToNext();
    }
  }

  Future<void> _recordEvent(app_events.PlaybackEventType type) async {
    final songId = _currentSong?.id;
    if (songId == null) return;
    try {
      await _db.addPlaybackEvent(app_events.PlaybackEvent(
        songId: songId,
        type: type,
        occurredAt: DateTime.now(),
        positionSeconds: _player.position.inSeconds,
      ));
    } catch (error) {
      debugPrint('Playback event failed for $songId: $error');
    }
  }

  Future<void> _finishListeningSession() async {
    if (_currentSong?.id == null) return;
    if (_playStartTime != null) {
      _sessionListenedSeconds +=
          DateTime.now().difference(_playStartTime!).inSeconds;
    }
    _playStartTime = null;

    final durationPlayed = _sessionListenedSeconds;
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
    _sessionListenedSeconds = 0;
  }

  void setSleepTimer(int minutes) {
    _cancelSleepTimers();
    _sleepTimerEnd = DateTime.now().add(Duration(minutes: minutes));

    final totalSeconds = minutes * 60;
    final fadeStart = totalSeconds - 33;

    if (fadeStart > 0) {
      _sleepFadeTimer = Timer(Duration(seconds: fadeStart), () async {
        if (_sleepTimerEnd == null) return;
        const steps = 10;
        const stepDuration = 3;
        for (int i = steps; i >= 0; i--) {
          if (_sleepTimerEnd == null) return;
          final targetVolume = i / steps.toDouble();
          await _player.setVolume(targetVolume);
          await Future.delayed(const Duration(seconds: stepDuration));
        }
      });
    }

    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      await pause();
      await _player.setVolume(1.0);
      _sleepTimerEnd = null;
      _sleepFadeTimer = null;
    });
  }

  void cancelSleepTimer() {
    _cancelSleepTimers();
    _sleepTimerEnd = null;
    _player.setVolume(1.0);
  }

  void _cancelSleepTimers() {
    _sleepTimer?.cancel();
    _sleepFadeTimer?.cancel();
    _sleepTimer = null;
    _sleepFadeTimer = null;
  }

  Future<void> disposeService() async {
    await _finishListeningSession();
    _cancelSleepTimers();
    await _currentSongController.close();
    await _player.dispose();
  }
}
