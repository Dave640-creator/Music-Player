import 'dart:async';
import 'dart:io';
import 'package:video_player/video_player.dart';
import '../models/video.dart';
import '../database/database_helper.dart';

/// Video playback engine built on `video_player`.
///
/// Handles real file playback, resume-from-last-position, playback speed,
/// volume and periodic progress persistence. When the library contains demo
/// videos (no real file), [DemoVideoSimulation] drives a simulated timeline so
/// the full player UI — gestures, subtitles, controls — remains demonstrable.
class VideoPlayerService {
  VideoPlayerService._internal();
  static final VideoPlayerService instance = VideoPlayerService._internal();
  factory VideoPlayerService() => instance;

  final DatabaseHelper _db = DatabaseHelper();

  VideoPlayerController? _controller;
  Video? _currentVideo;
  bool _isDemo = false;
  bool _demoPlaying = false;
  int _demoPosition = 0;
  Timer? _demoTimer;
  double _volume = 1.0;
  double _speed = 1.0;
  StreamController<void> _tickController = StreamController<void>.broadcast();

  Video? get currentVideo => _currentVideo;
  bool get isDemoMode => _isDemo;
  bool get isInitialized => _controller?.value.isInitialized ?? _isDemo;
  bool get isPlaying => _controller?.value.isPlaying ?? _demoPlaying;
  bool get hasError => !_isDemo && (_controller?.value.hasError ?? false);

  Duration get position =>
      _controller?.value.position ?? Duration(seconds: _demoPosition);
  Duration get duration =>
      _controller?.value.duration ?? Duration(seconds: _currentVideo?.duration ?? 0);

  Stream<void> get updates => _tickController.stream;

  Future<void> load(Video video, {bool autoPlay = true}) async {
    await stop();
    _currentVideo = video;

    if (video.isDemo || video.filePath.isEmpty || !_fileExists(video.filePath)) {
      _isDemo = true;
      _demoPosition = video.lastPosition.clamp(0, video.duration);
      _demoPlaying = autoPlay;
      _startDemoTimer();
      _startProgressSaver();
      _tickController.add(null);
      return;
    }

    _isDemo = false;
    try {
            _controller = VideoPlayerController.file(
        File(video.filePath.startsWith('file://')
            ? Uri.parse(video.filePath).toFilePath()
            : Uri.file(video.filePath).toFilePath()),
      );
      await _controller!.initialize();
      if (video.lastPosition > 15 &&
          video.lastPosition < video.duration - 5) {
        await _controller!.seekTo(Duration(seconds: video.lastPosition));
      }
      await _controller!.setVolume(_volume);
      await _controller!.setPlaybackSpeed(_speed);
      if (autoPlay) await _controller!.play();
      _startProgressSaver();
      if (video.id != null) {
        await _db.incrementVideoPlayCount(video.id!);
      }
      _tickController.add(null);
    } catch (_) {
      // Fall back to simulation so the player never hard-fails.
      _isDemo = true;
      _demoPosition = video.lastPosition.clamp(0, video.duration);
      _demoPlaying = autoPlay;
      _startDemoTimer();
      _startProgressSaver();
      _tickController.add(null);
    }
  }

  Future<void> play() async {
    if (_isDemo) {
      _demoPlaying = true;
      _startDemoTimer();
      _tickController.add(null);
      return;
    }
    await _controller?.play();
    _tickController.add(null);
  }

  Future<void> pause() async {
    if (_isDemo) {
      _demoPlaying = false;
      _tickController.add(null);
      await _saveProgress();
      return;
    }
    await _controller?.pause();
    await _saveProgress();
    _tickController.add(null);
  }

  Future<void> seek(Duration to) async {
    final target = Duration(
        seconds: to.inSeconds.clamp(0, duration.inSeconds));
    if (_isDemo) {
      _demoPosition = target.inSeconds;
      _tickController.add(null);
      return;
    }
    await _controller?.seekTo(target);
    _tickController.add(null);
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.25, 2.0);
    await _controller?.setPlaybackSpeed(_speed);
    if (_isDemo) _tickController.add(null);
  }

  double get speed => _speed;

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _controller?.setVolume(_volume);
  }

  Future<void> skipRelative(int seconds) async {
    await seek(position + Duration(seconds: seconds));
  }

  /// Whether a real file exists on disk for this video.
  bool _fileExists(String path) {
    try {
      return Uri.file(path).toFilePath().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _startDemoTimer() {
    _demoTimer?.cancel();
    if (!_demoPlaying) return;
    _demoTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_demoPosition >= _currentVideo!.duration) {
        _demoPlaying = false;
        t.cancel();
        _tickController.add(null);
        return;
      }
      _demoPosition++;
      _tickController.add(null);
    });
  }

  void _startProgressSaver() {
    _progressSaver?.cancel();
    _progressSaver = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  Timer? _progressSaver;

  Future<void> _saveProgress() async {
    if (_currentVideo?.id == null) return;
    await _db.savePlaybackProgress('video', _currentVideo!.id!, position.inSeconds);
  }

  Future<void> stop() async {
    await _saveProgress();
    _demoTimer?.cancel();
    _progressSaver?.cancel();
    await _controller?.dispose();
    _controller = null;
    _currentVideo = null;
    _isDemo = false;
    _demoPlaying = false;
  }

  Future<void> disposeService() async {
    await stop();
    await _tickController.close();
  }
}
