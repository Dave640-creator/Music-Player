import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../database/database_helper.dart';

class MusicScannerService {
  final DatabaseHelper _db = DatabaseHelper();

  static const List<String> supportedFormats = [
    'mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'opus', 'wma'
  ];

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Try READ_MEDIA_AUDIO first (Android 13+)
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) return true;
      if (audioStatus.isDenied) {
        final result = await Permission.audio.request();
        if (result.isGranted) return true;
      }
      // Fallback to storage permission (Android < 13)
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;
      if (storageStatus.isDenied) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return false;
    } else if (Platform.isIOS) {
      return true;
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

  Future<List<Song>> scanDeviceStorage({
    Function(int found, int total)? onProgress,
  }) async {
    final hasPerms = await requestPermissions();
    if (!hasPerms) return [];

    final List<File> audioFiles = [];
    final List<Directory> scanDirs = await _getScanDirectories();

    for (final dir in scanDirs) {
      if (await dir.exists()) {
        await _findAudioFiles(dir, audioFiles, maxDepth: 6);
      }
    }

    // Deduplicate by path
    final seen = <String>{};
    final uniqueFiles = audioFiles.where((f) => seen.add(f.path)).toList();

    final List<Song> songs = [];
    for (int i = 0; i < uniqueFiles.length; i++) {
      onProgress?.call(i + 1, uniqueFiles.length);
      try {
        final song = await _extractMetadata(uniqueFiles[i]);
        if (song != null) songs.add(song);
      } catch (_) {}
    }

    if (songs.isNotEmpty) {
      await _db.insertSongBatch(songs);
    }
    return songs;
  }

  Future<List<Directory>> _getScanDirectories() async {
    final dirs = <Directory>[];
    try {
      if (Platform.isAndroid) {
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null) {
          for (final d in extDirs) {
            // Walk up to storage root
            Directory root = d;
            for (int i = 0; i < 4; i++) {
              root = root.parent;
            }
            if (!dirs.any((x) => x.path == root.path)) dirs.add(root);
          }
        }
        for (final p in [
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Downloads',
          '/storage/emulated/0/Ringtones',
          '/sdcard/Music',
          '/sdcard/Downloads',
        ]) {
          final d = Directory(p);
          if (!dirs.any((x) => x.path == d.path)) dirs.add(d);
        }
      } else if (Platform.isIOS) {
        final docs = await getApplicationDocumentsDirectory();
        dirs.add(docs);
        final lib = await getLibraryDirectory();
        dirs.add(lib);
      }
    } catch (_) {}
    return dirs;
  }

  Future<void> _findAudioFiles(
    Directory dir,
    List<File> files, {
    int maxDepth = 5,
    int depth = 0,
  }) async {
    if (depth > maxDepth) return;
    try {
      final entities = await dir.list(followLinks: false).toList();
      for (final entity in entities) {
        if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (supportedFormats.contains(ext)) {
            files.add(entity);
          }
        } else if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name.startsWith('.') &&
              name != 'Android' &&
              name != 'data' &&
              name != 'obb') {
            await _findAudioFiles(entity, files,
                maxDepth: maxDepth, depth: depth + 1);
          }
        }
      }
    } catch (_) {}
  }

  Future<Song?> _extractMetadata(File file) async {
    try {
      final stat = await file.stat();
      final fileName = file.path.split(Platform.pathSeparator).last;
      final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

      String title = nameWithoutExt;
      String artist = 'Unknown Artist';
      String album = 'Unknown Album';

      // Parse "Artist - Title" filename convention
      if (nameWithoutExt.contains(' - ')) {
        final parts = nameWithoutExt.split(' - ');
        if (parts.length >= 2) {
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }
      }

      // Use parent folder as album if not generic
      final parentName =
          file.parent.path.split(Platform.pathSeparator).last;
      const genericFolders = {
        'music', 'downloads', 'mp3', 'audio', 'ringtones',
        '0', 'emulated', 'storage'
      };
      if (!genericFolders.contains(parentName.toLowerCase())) {
        album = parentName;
      }

      final size = await file.length();
      final duration = _estimateDuration(size);

      return Song(
        title: title.isEmpty ? 'Unknown' : title,
        artist: artist,
        album: album,
        filePath: file.path,
        duration: duration,
        dateAdded: stat.modified,
      );
    } catch (_) {
      return null;
    }
  }

  int _estimateDuration(int fileSizeBytes) {
    // 128kbps MP3 = 16000 bytes/sec
    if (fileSizeBytes <= 0) return 0;
    return (fileSizeBytes / 16000).round().clamp(1, 3600);
  }

  /// Manual file picker — BUG FIX: allowedExtensions must not be passed when type is audio
  Future<List<Song>> importFromFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return [];

      final songs = <Song>[];
      for (final pf in result.files) {
        if (pf.path != null && pf.path!.isNotEmpty) {
          final song = await _extractMetadata(File(pf.path!));
          if (song != null) songs.add(song);
        }
      }

      if (songs.isNotEmpty) {
        await _db.insertSongBatch(songs);
      }
      return songs;
    } catch (_) {
      return [];
    }
  }
}
