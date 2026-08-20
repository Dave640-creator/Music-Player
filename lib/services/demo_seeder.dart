import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/song.dart';
import '../models/video.dart';
import '../database/database_helper.dart';

/// Seeder that populates the app with a rich demo library so the redesigned
/// experience is fully demonstrable without requiring the user to first copy
/// media onto the device.
///
/// Demo *songs* are backed by real, generated 16-bit WAV tone files written
/// to the application support directory — so playback genuinely works on any
/// platform. Demo *videos* are flagged `isDemo` and render the video-player UI
/// in a simulated mode when no real video content exists.
class DemoSeeder {
  DemoSeeder._();
  static final DemoSeeder instance = DemoSeeder._();
  factory DemoSeeder() => instance;

  final DatabaseHelper _db = DatabaseHelper();

  /// Returns true when a demo library was seeded into an empty database.
  Future<bool> seedIfEmpty() async {
    final songCount = await _db.getSongCount();
    final videoCount = await _db.getVideoCount();
    if (songCount > 0 || videoCount > 0) return false;

    final dir = await _demoDir();
    final wavFiles = await _generateToneFiles(dir);

    final now = DateTime.now();
    final songs = <Song>[];
    final configs = _songConfigs();
    for (var i = 0; i < configs.length; i++) {
      final cfg = configs[i];
      songs.add(Song(
        title: cfg['title'],
        artist: cfg['artist'],
        album: cfg['album'],
        genre: cfg['genre'],
        moodTag: cfg['mood'],
        filePath: wavFiles[i % wavFiles.length].path,
        duration: _wavDurationSeconds(wavFiles[i % wavFiles.length]),
        dateAdded: now.subtract(Duration(days: cfg['addedDays'] as int)),
        playCount: cfg['plays'] as int,
        isFavorite: cfg['fav'] as bool,
        lastPlayedAt: now.subtract(Duration(hours: cfg['hoursAgo'] as int)),
        year: cfg['year'] as int,
        lyrics: cfg['lyrics'] as String?,
        artworkPath: null,
      ));
    }
    await _db.insertSongBatch(songs);

    final seeded = await _db.getAllSongs(includePrivate: true);
    for (final s in seeded.take(5)) {
      if (s.id != null) {
        await _db.savePlaybackProgress('audio', s.id!, s.duration ~/ 3);
      }
    }

    final videos = [
      Video(
        title: 'Coastal Drive — 4K',
        artist: 'Mosaic Originals',
        duration: 218,
        isDemo: true,
        lastPosition: 62,
        dateAdded: now.subtract(const Duration(days: 2)),
        playCount: 7,
        isFavorite: true,
        filePath: '',
      ),
      Video(
        title: 'City Lights Timelapse',
        artist: 'Mosaic Originals',
        duration: 96,
        isDemo: true,
        lastPosition: 80,
        dateAdded: now.subtract(const Duration(days: 4)),
        playCount: 3,
        filePath: '',
      ),
      Video(
        title: 'Studio Sessions — Live',
        artist: 'Mosaic Originals',
        duration: 342,
        isDemo: true,
        dateAdded: now.subtract(const Duration(days: 6)),
        playCount: 5,
        isFavorite: true,
        filePath: '',
      ),
      Video(
        title: 'Night City Loop',
        artist: 'Ambient Reel',
        duration: 158,
        isDemo: true,
        dateAdded: now.subtract(const Duration(days: 1)),
        filePath: '',
      ),
    ];
    await _db.insertVideoBatch(videos);

    final seededVideos = await _db.getAllVideos(includePrivate: true);
    for (final v in seededVideos.take(2)) {
      if (v.id != null) {
        await _db.savePlaybackProgress('video', v.id!, v.lastPosition);
      }
    }

    return true;
  }

  Future<Directory> _demoDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}demo_audio');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

    static const int _sampleRate = 22050;

  Future<List<File>> _generateToneFiles(Directory dir) async {
    final roots = [57, 60, 62, 64, 55, 59]; // midi roots
    final files = <File>[];
    for (var i = 0; i < roots.length; i++) {
      final file =
          File('${dir.path}${Platform.pathSeparator}demo_$i.wav');
      if (await file.exists()) {
        files.add(file);
        continue;
      }
      final ok = await _writeTone(file, seconds: 46, rootMidi: roots[i], seed: i);
      if (ok) files.add(file);
    }
    return files;
  }

  int _wavDurationSeconds(File f) {
    try {
      return (f.lengthSync() / (_sampleRate * 2)).floor();
    } catch (_) {
      return 0;
    }
  }

  // ── WAV tone generation ───────────────────────────────────────────────

  /// Writes a 16-bit PCM mono WAV containing a soft, evolving arpeggio so the
  /// demo tracks sound distinct from one another.
  Future<bool> _writeTone(File file,
      {required int seconds, required int rootMidi, required int seed}) async {
    try {
      final numSamples = seconds * _sampleRate;
      final dataSize = numSamples * 2;
      final bytes = ByteData(44 + dataSize);

      _writeAscii(bytes, 0, 'RIFF');
      bytes.setUint32(4, 36 + dataSize, Endian.little);
      _writeAscii(bytes, 8, 'WAVE');
      _writeAscii(bytes, 12, 'fmt ');
      bytes.setUint32(16, 16, Endian.little);
      bytes.setUint16(20, 1, Endian.little); // PCM
      bytes.setUint16(22, 1, Endian.little); // mono
      bytes.setUint32(24, _sampleRate, Endian.little);
      bytes.setUint32(28, _sampleRate * 2, Endian.little);
      bytes.setUint16(32, 2, Endian.little); // block align
      bytes.setUint16(34, 16, Endian.little); // bits per sample
      _writeAscii(bytes, 36, 'data');
      bytes.setUint32(40, dataSize, Endian.little);

            final scale = [0, 2, 4, 7, 9, 11, 12, 14]; // pentatonic-ish
      final rootFreq = 440.0 * math.pow(2, (rootMidi - 69) / 12.0);
      const noteLen = 0.52; // seconds per note

      for (var i = 0; i < numSamples; i++) {
        final t = i / _sampleRate;
        final noteIdx = (t / noteLen).floor();
        final interval = scale[noteIdx % scale.length];
        final noteFreq = rootFreq * math.pow(2, interval / 12.0);

        final phaseInNote = (t % noteLen) / noteLen;
        final env = math.sin(phaseInNote * math.pi);

        var sample = math.sin(2 * math.pi * noteFreq * t) * 0.5;
        sample += math.sin(2 * math.pi * noteFreq * 2 * t) * 0.12;

                final bassFreq = rootFreq / 4;
        final bass = math.sin(2 * math.pi * bassFreq * t) *
            (0.08 * (1 - env));

        final shimmer =
            1.0 + 0.06 * math.sin(2 * math.pi * 0.17 * t + seed);

        var value =
            ((sample * env + bass * env) * 0.62 * shimmer).clamp(-1.0, 1.0);

        final fadeIn = (t / 1.5).clamp(0.0, 1.0);
        final fadeOut = ((seconds - t) / 2.5).clamp(0.0, 1.0);
        value *= math.min(fadeIn, fadeOut);

        bytes.setInt16(44 + i * 2, (value * 32767).round(), Endian.little);
      }

      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _writeAscii(ByteData data, int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  // ── Demo metadata ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> _songConfigs() {
        final baseLyrics = [
      '[00:00.00] Drifting through the quiet hours',
      '[00:08.00] Colors melting on the sky',
      '[00:16.00] Every second feels like power',
      '[00:24.00] When the moment passes by',
      '[00:32.00] Let the melody surround you',
      '[00:40.00] Nothing else could hold you near',
    ].join('\n');

    return [
      {
        'title': 'Aurora Drift',
        'artist': 'Amber Vale',
        'album': 'Night Canvas',
        'genre': 'Ambient',
        'mood': 'chill',
        'addedDays': 12,
        'plays': 42,
        'fav': true,
        'hoursAgo': 3,
        'year': 2024,
        'lyrics': baseLyrics,
      },
      {
        'title': 'Midnight Frequency',
        'artist': 'Nova Reyes',
        'album': 'Neon Bloom',
        'genre': 'Electronic',
        'mood': 'workout',
        'addedDays': 10,
        'plays': 38,
        'fav': true,
        'hoursAgo': 6,
        'year': 2025,
        'lyrics': null,
      },
      {
        'title': 'Paper Planes',
        'artist': 'Juno Park',
        'album': 'Little Letters',
        'genre': 'Indie Pop',
        'mood': 'happy',
        'addedDays': 8,
        'plays': 21,
        'fav': false,
        'hoursAgo': 26,
        'year': 2023,
        'lyrics': baseLyrics,
      },
      {
        'title': 'Silent Current',
        'artist': 'Mara Sol',
        'album': 'Still Waters',
        'genre': 'Ambient',
        'mood': 'focus',
        'addedDays': 5,
        'plays': 19,
        'fav': false,
        'hoursAgo': 12,
        'year': 2024,
        'lyrics': null,
      },
      {
        'title': 'Ember Lights',
        'artist': 'The Signal',
        'album': 'Cold War',
        'genre': 'Rock',
        'mood': 'sad',
        'addedDays': 4,
        'plays': 14,
        'fav': true,
        'hoursAgo': 49,
        'year': 2022,
        'lyrics': null,
      },
      {
        'title': 'Gravity Dance',
        'artist': 'Nova Reyes',
        'album': 'Neon Bloom',
        'genre': 'Electronic',
        'mood': 'workout',
        'addedDays': 3,
        'plays': 27,
        'fav': false,
        'hoursAgo': 1,
        'year': 2025,
        'lyrics': null,
      },
    ];
  }
}

