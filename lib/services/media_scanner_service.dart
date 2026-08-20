import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../models/video.dart';
import '../database/database_helper.dart';

/// Scans the device for local audio and video files, infers metadata from
/// file names and folder structure, and picks up sidecar `.lrc` lyric files.
class MediaScannerService {
  MediaScannerService._internal();
  static final MediaScannerService instance = MediaScannerService._internal();
  factory MediaScannerService() => instance;

  final DatabaseHelper _db = DatabaseHelper();

  static const List<String> audioFormats = [
    'mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'opus', 'wma', 'mid',
  ];

  static const List<String> videoFormats = [
    'mp4', 'mkv', 'webm', 'avi', 'mov', 'wmv', 'flv', '3gp', 'm4v', 'ts',
  ];

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) return true;
      if (audioStatus.isDenied) {
        final result = await Permission.audio.request();
        if (result.isGranted) return true;
      }
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;
      if (storageStatus.isDenied) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return false;
    }
    return true;
  }

  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      final audio = await Permission.audio.status;
      if (audio.isGranted) return true;
      final storage = await Permission.storage.status;
      return storage.isGranted;
    }
    return true;
  }

  // ── Audio scan ────────────────────────────────────────────────────────

  Future<List<Song>> scanAudio(
      {Function(int found, int total)? onProgress}) async {
    final hasPerms = await requestPermissions();
    if (!hasPerms) return [];

    final audioFiles = <File>[];
    for (final dir in await _getScanDirectories()) {
      if (await dir.exists()) {
        await _findFiles(dir, audioFiles, audioFormats, maxDepth: 6);
      }
    }
    final seen = <String>{};
    final unique = audioFiles.where((f) => seen.add(f.path)).toList();

    final songs = <Song>[];
    for (var i = 0; i < unique.length; i++) {
      onProgress?.call(i + 1, unique.length);
      try {
        final song = await _extractSong(unique[i]);
        if (song != null) songs.add(song);
      } catch (_) {}
    }
    if (songs.isNotEmpty) await _db.insertSongBatch(songs);
    return songs;
  }

  // ── Video scan ────────────────────────────────────────────────────────

  Future<List<Video>> scanVideo(
      {Function(int found, int total)? onProgress}) async {
    final hasPerms = await requestPermissions();
    if (!hasPerms) return [];

    final videoFiles = <File>[];
    for (final dir in await _getScanDirectories()) {
      if (await dir.exists()) {
        await _findFiles(dir, videoFiles, videoFormats, maxDepth: 6);
      }
    }
    final seen = <String>{};
    final unique = videoFiles.where((f) => seen.add(f.path)).toList();

    final videos = <Video>[];
    for (var i = 0; i < unique.length; i++) {
      onProgress?.call(i + 1, unique.length);
      try {
        final video = await _extractVideo(unique[i]);
        if (video != null) videos.add(video);
      } catch (_) {}
    }
    if (videos.isNotEmpty) await _db.insertVideoBatch(videos);
    return videos;
  }

  Future<List<Directory>> _getScanDirectories() async {
    final dirs = <Directory>[];
    try {
      if (Platform.isAndroid) {
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null) {
          for (final d in extDirs) {
            Directory root = d;
            for (int i = 0; i < 4; i++) {
              root = root.parent;
            }
            if (!dirs.any((x) => x.path == root.path)) dirs.add(root);
          }
        }
        for (final p in [
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Movies',
          '/storage/emulated/0/DCIM',
          '/storage/emulated/0/Ringtones',
          '/sdcard/Music',
          '/sdcard/Download',
        ]) {
          final d = Directory(p);
          if (!dirs.any((x) => x.path == d.path)) dirs.add(d);
        }
      } else if (Platform.isIOS) {
        final docs = await getApplicationDocumentsDirectory();
        dirs.add(docs);
      }
    } catch (_) {}
    return dirs;
  }

  Future<void> _findFiles(Directory dir, List<File> files, List<String> formats,
      {int maxDepth = 5, int depth = 0}) async {
    if (depth > maxDepth) return;
    try {
      final entities = await dir.list(followLinks: false).toList();
      for (final entity in entities) {
        if (entity is File) {
          final ext = _ext(entity.path);
          if (formats.contains(ext)) files.add(entity);
        } else if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name.startsWith('.') &&
              name != 'Android' &&
              name != 'data' &&
              name != 'obb') {
            await _findFiles(entity, files, formats,
                maxDepth: maxDepth, depth: depth + 1);
          }
        }
      }
    } catch (_) {}
  }

  // ── Metadata extraction ───────────────────────────────────────────────

  Future<Song?> _extractSong(File file) async {
    try {
      final stat = await file.stat();
      final name = _baseName(file.path);
      var title = name;
      var artist = 'Unknown Artist';
      var album = 'Unknown Album';

      if (name.contains(' - ')) {
        final parts = name.split(' - ');
        if (parts.length >= 2) {
          artist = parts.first.trim();
          title = parts.sublist(1).join(' - ').trim();
        }
      }

      final parentName = file.parent.path.split(Platform.pathSeparator).last;
      const generic = {
        'music', 'download', 'downloads', 'mp3', 'audio', 'ringtones',
        'movies', 'video', 'videos', '0', 'emulated', 'storage', 'dcim',
      };
      if (!generic.contains(parentName.toLowerCase())) {
        album = parentName;
      }

      final duration = _estimateDuration(await file.length());
      final genre = _inferGenre(name, artist);
      final lyrics = _readSidecarLyrics(file.path);

      return Song(
        title: title.isEmpty ? 'Unknown' : title,
        artist: artist,
        album: album,
        filePath: file.path,
        duration: duration,
        dateAdded: stat.modified,
        genre: genre,
        lyrics: lyrics,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Video?> _extractVideo(File file) async {
    try {
      final stat = await file.stat();
      final name = _baseName(file.path);
      final parentName = file.parent.path.split(Platform.pathSeparator).last;

      return Video(
        title: name.isEmpty ? 'Untitled' : name,
        artist: parentName,
        filePath: file.path,
        duration: _estimateDuration(await file.length(), bitrate: 240000),
        dateAdded: stat.modified,
      );
    } catch (_) {
      return null;
    }
  }

  String? _inferGenre(String name, String artist) {
    const hints = {
      'rock': 'Rock', 'metal': 'Rock', 'pop': 'Pop', 'indie': 'Indie',
      'jazz': 'Jazz', 'blues': 'Blues', 'classical': 'Classical',
      'electronic': 'Electronic', 'edm': 'Electronic', 'techno': 'Electronic',
      'house': 'Electronic', 'ambient': 'Ambient', 'lofi': 'Lo-Fi',
      'lo-fi': 'Lo-Fi', 'hip': 'Hip-Hop', 'rap': 'Hip-Hop',
      'rnb': 'R&B', 'soul': 'Soul', 'country': 'Country', 'folk': 'Folk',
      'reggae': 'Reggae', 'acoustic': 'Acoustic', 'piano': 'Piano',
      'chill': 'Chill', 'workout': 'Workout', 'focus': 'Focus',
      'happy': 'Happy', 'sad': 'Sad',
    };
    final key = '$name $artist'.toLowerCase();
    for (final entry in hints.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Looks for a `.lrc` file next to the audio file for synchronized lyrics.
    String? _readSidecarLyrics(String audioPath) {
    try {
      final withoutExt = audioPath.substring(0, audioPath.lastIndexOf('.'));
      final lrc = File('$withoutExt.lrc');
      if (lrc.existsSync()) return lrc.readAsStringSync();
      final txt = File('$withoutExt.txt');
      if (txt.existsSync()) return txt.readAsStringSync();
    } catch (_) {}
    return null;
  }

  String _baseName(String path) {
    final name = path.split(Platform.pathSeparator).last;
    return name.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  String _ext(String path) {
    return path.split('.').last.toLowerCase();
  }

  int _estimateDuration(int fileSizeBytes, {int bitrate = 16000}) {
    if (fileSizeBytes <= 0) return 0;
    return (fileSizeBytes / bitrate).round().clamp(1, 6 * 3600);
  }

  // ── Manual import ─────────────────────────────────────────────────────

  Future<List<Song>> importAudioFromPicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return [];
      final songs = <Song>[];
      for (final pf in result.files) {
        if (pf.path != null && pf.path!.isNotEmpty) {
          final song = await _extractSong(File(pf.path!));
          if (song != null) songs.add(song);
        }
      }
      if (songs.isNotEmpty) await _db.insertSongBatch(songs);
      return songs;
    } catch (_) {
      return [];
    }
  }

  Future<List<Video>> importVideoFromPicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return [];
      final videos = <Video>[];
      for (final pf in result.files) {
        if (pf.path != null && pf.path!.isNotEmpty) {
          final video = await _extractVideo(File(pf.path!));
          if (video != null) videos.add(video);
        }
      }
      if (videos.isNotEmpty) await _db.insertVideoBatch(videos);
      return videos;
    } catch (_) {
      return [];
    }
  }
}

