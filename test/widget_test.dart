// Tests for the Smart Music Player app.
//
// These are self-contained unit + widget tests that do not need platform
// plugins (sqflite, just_audio, path_provider), so they run reliably on the
// host machine.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_music_player/models/song.dart';
import 'package:smart_music_player/models/user_stats.dart';

void main() {
  group('Song model', () {
    test('formats duration as mm:ss', () {
      final song = Song(
        title: 'Test',
        artist: 'Artist',
        filePath: '/tmp/a.mp3',
        duration: 125,
      );
      expect(song.formattedDuration, '02:05');

      final longSong = Song(
        title: 'Long',
        artist: 'Artist',
        filePath: '/tmp/b.mp3',
        duration: 3671,
      );
      expect(longSong.formattedDuration, '61:11');
    });

    test('toMap / fromMap round-trips every field', () {
      final song = Song(
        id: 1,
        title: 'Title',
        artist: 'Artist',
        filePath: '/tmp/t.mp3',
        duration: 200,
        album: 'Album',
        isFavorite: true,
        playCount: 3,
        moodTag: 'focus',
      );
      final restored = Song.fromMap(song.toMap());
      expect(restored.id, 1);
      expect(restored.title, 'Title');
      expect(restored.artist, 'Artist');
      expect(restored.filePath, '/tmp/t.mp3');
      expect(restored.duration, 200);
      expect(restored.album, 'Album');
      expect(restored.isFavorite, true);
      expect(restored.playCount, 3);
      expect(restored.moodTag, 'focus');
    });

    test('songs with the same id are equal; copyWith toggles favorite', () {
      final a = Song(
        id: 7,
        title: 'A',
        artist: 'x',
        filePath: '/a',
        duration: 1,
      );
      final b = Song(
        id: 7,
        title: 'B',
        artist: 'y',
        filePath: '/b',
        duration: 2,
      );
      expect(a == b, true);

      final fav = a.copyWith(isFavorite: true);
      expect(fav.isFavorite, true);
      expect(fav.id, 7);
      expect(fav.title, 'A');
    });
  });

  group('UserStats', () {
    test('formatTotalTime renders minutes and hours', () {
      expect(UserStats(totalPlayTime: 90).formattedTotalTime, '1m');
      expect(UserStats(totalPlayTime: 3661).formattedTotalTime, '1h 1m');
    });

    test('toMap / fromMap round-trips', () {
      final stats = UserStats(
        id: 1,
        totalPlayTime: 500,
        totalSongsPlayed: 10,
        streakDays: 3,
        lastPlayedDate: DateTime.utc(2026, 1, 1),
      );
      final restored = UserStats.fromMap(stats.toMap());
      expect(restored.totalPlayTime, 500);
      expect(restored.totalSongsPlayed, 10);
      expect(restored.streakDays, 3);
      expect(restored.lastPlayedDate, DateTime.utc(2026, 1, 1));
    });
  });

  testWidgets('a basic MaterialApp renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('ok'))),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}
