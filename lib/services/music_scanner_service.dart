import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../database/database_helper.dart';
import '../models/library_scan_result.dart';

class MusicScannerService {
  final DatabaseHelper _db = DatabaseHelper();
  static const _mediaStoreChannel =
      MethodChannel('smart_music_player/media_store');

  static const List<String> supportedFormats = [
    'mp3',
    'wav',
    'm4a',
    'aac',
    'flac',
    'ogg',
    'opus',
    'wma'
  ];

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) return true;
      if (audioStatus.isPermanentlyDenied) {
        return false;
      }
      if (audioStatus.isDenied) {
        final result = await Permission.audio.request();
        if (result.isGranted) return true;
        if (result.isPermanentlyDenied) return false;
      }

      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;
      if (storageStatus.isPermanentlyDenied) {
        return false;
      }
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
      if (audio.isPermanentlyDenied) return false;
      final storage = await Permission.storage.status;
      if (storage.isGranted) return true;
      return storage.isPermanentlyDenied ? false : false;
    }
    return true;
  }

  Future<LibraryScanResult> scanDeviceStorage({
    Function(int found, int total)? onProgress,
    Function(LibraryScanResult result)? onResult,
  }) async {
    final hasPerms = await requestPermissions();
    if (!hasPerms) return const LibraryScanResult();

    if (Platform.isAndroid) {
      final mediaStoreResult = await _scanMediaStore(
        onProgress: onProgress,
        onResult: onResult,
      );
      if (mediaStoreResult != null) return mediaStoreResult;
    }

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
    var errors = 0;
    for (int i = 0; i < uniqueFiles.length; i++) {
      onProgress?.call(i + 1, uniqueFiles.length);
      try {
        final song = await _extractMetadata(uniqueFiles[i]);
        if (song != null) songs.add(song);
      } catch (_) {
        debugPrint('Metadata scan failed for ${uniqueFiles[i].path}');
        errors++;
      }
    }

    final paths = uniqueFiles.map((file) => file.path).toSet();
    final sync = await _db.insertSongBatch(songs);
    final removed = await _db.removeMissingSongs(paths);
    final result = sync.copyWith(
      detected: uniqueFiles.length,
      duplicates: audioFiles.length - uniqueFiles.length,
      errors: errors,
      removed: removed,
    );
    onResult?.call(result);
    return result;
  }

  Future<LibraryScanResult?> _scanMediaStore({
    Function(int found, int total)? onProgress,
    Function(LibraryScanResult result)? onResult,
  }) async {
    try {
      final rows = await _mediaStoreChannel.invokeMethod<List<dynamic>>(
        'queryDeviceMusic',
      );
      if (rows == null) return null;

      final songs = <Song>[];
      final paths = <String>{};
      var errors = 0;
      final total = rows.length;

      for (var i = 0; i < total; i++) {
        final row = Map<String, dynamic>.from(rows[i] as Map);
        final path = row['path'] as String?;
        if (path == null || !paths.add(path)) continue;
        onProgress?.call(i + 1, total);
        try {
          final title = (row['title'] as String?)?.trim();
          final artist = (row['artist'] as String?)?.trim();
          final album = (row['album'] as String?)?.trim();
          songs.add(Song(
            title: title?.isNotEmpty == true ? title! : 'Unknown',
            artist: artist?.isNotEmpty == true ? artist! : 'Unknown Artist',
            album: album?.isNotEmpty == true ? album! : 'Unknown Album',
            albumArtist: (row['albumArtist'] as String?)?.trim(),
            year: (row['year'] as num?)?.toInt(),
            trackNumber: (row['trackNumber'] as num?)?.toInt(),
            bitrate: (row['bitrate'] as num?)?.toInt(),
            artworkPath: (row['artwork'] as String?)?.trim(),
            filePath: path,
            duration: ((row['duration'] as num?)?.round() ?? 0) ~/ 1000,
            dateAdded: DateTime.fromMillisecondsSinceEpoch(
              ((row['modified'] as num?)?.toInt() ?? 0) * 1000,
            ),
          ));
        } catch (_) {
          errors++;
        }
      }

      final sync = await _db.insertSongBatch(songs);
      final removed = await _db.removeMissingSongs(paths);
      final result = sync.copyWith(
        detected: paths.length,
        errors: errors,
        removed: removed,
      );
      onResult?.call(result);
      return result;
    } on PlatformException catch (error) {
      debugPrint('MediaStore query failed: ${error.code}');
      return null;
    } catch (error) {
      debugPrint('MediaStore scan error: $error');
      return null;
    }
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
    } catch (error) {
      debugPrint('Unable to locate music directories: $error');
    }
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
    } catch (error) {
      debugPrint('Unable to scan directory ${dir.path}: $error');
    }
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
      final parentName = file.parent.path.split(Platform.pathSeparator).last;
      const genericFolders = {
        'music',
        'downloads',
        'mp3',
        'audio',
        'ringtones',
        '0',
        'emulated',
        'storage'
      };
      if (!genericFolders.contains(parentName.toLowerCase())) {
        album = parentName;
      }

      final duration = await _readDuration(file);

      return Song(
        title: title.isEmpty ? 'Unknown' : title,
        artist: artist,
        album: album,
        filePath: file.path,
        duration: duration,
        dateAdded: stat.modified,
      );
    } catch (error) {
      debugPrint('Unable to read metadata for ${file.path}: $error');
      return null;
    }
  }

  Future<int> _readDuration(File file) async {
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(file.path);
      return duration?.inSeconds ?? 0;
    } catch (error) {
      debugPrint('Duration metadata unavailable for ${file.path}: $error');
      return 0;
    } finally {
      await player.dispose();
    }
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
    } catch (error) {
      debugPrint('File picker import failed: $error');
      return [];
    }
  }
}
