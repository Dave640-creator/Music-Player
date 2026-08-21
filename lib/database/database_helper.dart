import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/user_stats.dart';
import '../models/library_scan_result.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_music_player_v2.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Enable FK support
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        artist TEXT NOT NULL DEFAULT 'Unknown Artist',
        file_path TEXT UNIQUE NOT NULL,
        duration INTEGER NOT NULL DEFAULT 0,
        album TEXT NOT NULL DEFAULT 'Unknown Album',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        date_added TEXT NOT NULL,
        play_count INTEGER NOT NULL DEFAULT 0,
        mood_tag TEXT,
        artwork_path TEXT,
        album_artist TEXT,
        genre TEXT,
        year INTEGER,
        track_number INTEGER,
        bitrate INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        description TEXT,
        is_auto_generated INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlist_songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        song_id INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE,
        UNIQUE(playlist_id, song_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS listening_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER NOT NULL,
        played_at TEXT NOT NULL,
        duration_played INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_play_time INTEGER NOT NULL DEFAULT 0,
        total_songs_played INTEGER NOT NULL DEFAULT 0,
        streak_days INTEGER NOT NULL DEFAULT 0,
        last_played_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS badges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        badge_type TEXT UNIQUE NOT NULL,
        is_unlocked INTEGER NOT NULL DEFAULT 0,
        unlocked_at TEXT
      )
    ''');

    // Create indexes for common queries
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_songs_artist ON songs(artist)');
    await db
        .execute('CREATE INDEX IF NOT EXISTS idx_songs_album ON songs(album)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_songs_play_count ON songs(play_count DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_history_played_at ON listening_history(played_at)');

    // Seed user stats row
    await db.insert('user_stats', {
      'total_play_time': 0,
      'total_songs_played': 0,
      'streak_days': 0,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE songs ADD COLUMN album_artist TEXT');
      await db.execute('ALTER TABLE songs ADD COLUMN genre TEXT');
      await db.execute('ALTER TABLE songs ADD COLUMN year INTEGER');
      await db.execute('ALTER TABLE songs ADD COLUMN track_number INTEGER');
      await db.execute('ALTER TABLE songs ADD COLUMN bitrate INTEGER');
    }
  }

  // ─────────────── SONGS ───────────────

  Future<int> insertSong(Song song) async {
    final db = await database;
    try {
      return await db.insert('songs', song.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (_) {
      return -1;
    }
  }

  Future<LibraryScanResult> insertSongBatch(List<Song> songs) async {
    if (songs.isEmpty) return const LibraryScanResult();
    final db = await database;
    var imported = 0;
    var updated = 0;
    var alreadyImported = 0;
    final seenPaths = <String>{};

    await db.transaction((txn) async {
      for (final song in songs) {
        if (!seenPaths.add(song.filePath)) continue;
        final existing = await txn.query(
          'songs',
          columns: [
            'id',
            'title',
            'artist',
            'album',
            'duration',
            'album_artist',
            'genre',
            'year',
            'track_number',
            'bitrate',
            'date_added',
          ],
          where: 'file_path = ?',
          whereArgs: [song.filePath],
          limit: 1,
        );

        if (existing.isEmpty) {
          await txn.insert('songs', song.toMap());
          imported++;
          continue;
        }

        final row = existing.first;
        final changed = row['title'] != song.title ||
            row['artist'] != song.artist ||
            row['album'] != song.album ||
            row['duration'] != song.duration ||
            row['album_artist'] != song.albumArtist ||
            row['genre'] != song.genre ||
            row['year'] != song.year ||
            row['track_number'] != song.trackNumber ||
            row['bitrate'] != song.bitrate;
        if (changed) {
          await txn.update(
            'songs',
            {
              'title': song.title,
              'artist': song.artist,
              'album': song.album,
              'duration': song.duration,
              'album_artist': song.albumArtist,
              'genre': song.genre,
              'year': song.year,
              'track_number': song.trackNumber,
              'bitrate': song.bitrate,
            },
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          updated++;
        } else {
          alreadyImported++;
        }
      }
    });

    return LibraryScanResult(
      detected: seenPaths.length,
      imported: imported,
      updated: updated,
      alreadyImported: alreadyImported,
    );
  }

  Future<int> removeMissingSongs(Set<String> existingPaths) async {
    if (existingPaths.isEmpty) return 0;
    final db = await database;
    final rows = await db.query('songs', columns: ['id', 'file_path']);
    final missingIds = rows
        .where((row) => !existingPaths.contains(row['file_path'] as String))
        .map((row) => row['id'] as int)
        .toList();
    if (missingIds.isEmpty) return 0;

    await db.transaction((txn) async {
      for (final id in missingIds) {
        await txn.delete('songs', where: 'id = ?', whereArgs: [id]);
      }
    });
    return missingIds.length;
  }

  Future<void> insertSongsLegacy(List<Song> songs) async {
    if (songs.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final song in songs) {
      batch.insert('songs', song.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Song>> getAllSongs() async {
    final db = await database;
    final rows = await db.query('songs', orderBy: 'date_added DESC');
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> searchSongs(String query) async {
    final db = await database;
    final q = '%$query%';
    final rows = await db.query(
      'songs',
      where: 'title LIKE ? OR artist LIKE ? OR album LIKE ?',
      whereArgs: [q, q, q],
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getFavoriteSongs() async {
    final db = await database;
    final rows =
        await db.query('songs', where: 'is_favorite = 1', orderBy: 'title ASC');
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getMostPlayedSongs({int limit = 10}) async {
    final db = await database;
    final rows = await db.query('songs',
        where: 'play_count > 0', orderBy: 'play_count DESC', limit: limit);
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getSongsByMood(String mood) async {
    final db = await database;
    final rows =
        await db.query('songs', where: 'mood_tag = ?', whereArgs: [mood]);
    return rows.map(Song.fromMap).toList();
  }

  Future<void> updateSong(Song song) async {
    final db = await database;
    await db
        .update('songs', song.toMap(), where: 'id = ?', whereArgs: [song.id]);
  }

  Future<void> toggleFavorite(int songId, bool isFavorite) async {
    final db = await database;
    await db.update('songs', {'is_favorite': isFavorite ? 1 : 0},
        where: 'id = ?', whereArgs: [songId]);
  }

  Future<void> incrementPlayCount(int songId) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE songs SET play_count = play_count + 1 WHERE id = ?', [songId]);
  }

  Future<void> updateMoodTag(int songId, String? mood) async {
    final db = await database;
    await db.update('songs', {'mood_tag': mood},
        where: 'id = ?', whereArgs: [songId]);
  }

  // BUG FIX: getSongsByArtist groups by artist key
  Future<Map<String, List<Song>>> getSongsByArtist() async {
    final songs = await getAllSongs();
    final map = <String, List<Song>>{};
    for (final s in songs) {
      map.putIfAbsent(s.artist, () => []).add(s);
    }
    return map;
  }

  // BUG FIX: getSongsByAlbum correctly groups by album key
  Future<Map<String, List<Song>>> getSongsByAlbum() async {
    final songs = await getAllSongs();
    final map = <String, List<Song>>{};
    for (final s in songs) {
      map.putIfAbsent(s.album, () => []).add(s);
    }
    return map;
  }

  Future<List<Song>> findDuplicates() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.*
      FROM songs s
      INNER JOIN (
        SELECT LOWER(TRIM(title)) AS title_key,
               LOWER(TRIM(artist)) AS artist_key,
               LOWER(TRIM(album)) AS album_key
        FROM songs
        GROUP BY title_key, artist_key, album_key
        HAVING COUNT(*) > 1
      ) d ON LOWER(TRIM(s.title)) = d.title_key
         AND LOWER(TRIM(s.artist)) = d.artist_key
         AND LOWER(TRIM(s.album)) = d.album_key
      ORDER BY LOWER(s.title), LOWER(s.artist), s.date_added ASC
    ''');
    return rows.map(Song.fromMap).toList();
  }

  Future<void> deleteSong(int songId) async {
    final db = await database;
    await db.delete('songs', where: 'id = ?', whereArgs: [songId]);
  }

  Future<int> getSongCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM songs');
    return (res.first['c'] as int?) ?? 0;
  }

  // ─────────────── PLAYLISTS ───────────────

  Future<int> createPlaylist(Playlist playlist) async {
    final db = await database;
    return await db.insert('playlists', playlist.toMap());
  }

  Future<List<Playlist>> getAllPlaylists() async {
    final db = await database;
    final rows = await db.query('playlists', orderBy: 'created_at DESC');
    final playlists = rows.map(Playlist.fromMap).toList();
    for (final p in playlists) {
      p.songs = await getPlaylistSongs(p.id!);
    }
    return playlists;
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    final db = await database;
    final countRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM playlist_songs WHERE playlist_id = ?',
        [playlistId]);
    final pos = (countRes.first['c'] as int?) ?? 0;
    await db.insert(
      'playlist_songs',
      {'playlist_id': playlistId, 'song_id': songId, 'position': pos},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> clearPlaylistSongs(int playlistId) async {
    final db = await database;
    await db.delete('playlist_songs',
        where: 'playlist_id = ?', whereArgs: [playlistId]);
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    final db = await database;
    await db.delete('playlist_songs',
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, songId]);
  }

  Future<List<Song>> getPlaylistSongs(int playlistId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.* FROM songs s
      INNER JOIN playlist_songs ps ON s.id = ps.song_id
      WHERE ps.playlist_id = ?
      ORDER BY ps.position ASC
    ''', [playlistId]);
    return rows.map(Song.fromMap).toList();
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    final db = await database;
    await db.update('playlists', playlist.toMap(),
        where: 'id = ?', whereArgs: [playlist.id]);
  }

  Future<void> deletePlaylist(int playlistId) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
  }

  Future<int> getPlaylistCount() async {
    final db = await database;
    final res = await db.rawQuery(
        'SELECT COUNT(*) as c FROM playlists WHERE is_auto_generated = 0');
    return (res.first['c'] as int?) ?? 0;
  }

  // ─────────────── LISTENING HISTORY ───────────────

  Future<void> addListeningHistory(ListeningHistory h) async {
    final db = await database;
    await db.insert('listening_history', h.toMap());
  }

  Future<List<ListeningHistory>> getListeningHistory({int limit = 100}) async {
    final db = await database;
    final rows = await db.query('listening_history',
        orderBy: 'played_at DESC', limit: limit);
    return rows.map(ListeningHistory.fromMap).toList();
  }

  Future<Map<String, int>> getDailyListeningStats(int days) async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final rows = await db.rawQuery('''
      SELECT DATE(played_at) as day, SUM(duration_played) as total
      FROM listening_history
      WHERE played_at >= ?
      GROUP BY DATE(played_at)
      ORDER BY day ASC
    ''', [cutoff]);

    final result = <String, int>{};
    for (final r in rows) {
      result[r['day'] as String] = (r['total'] as int?) ?? 0;
    }
    return result;
  }

  Future<int> getListeningSecondsSince(DateTime since) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(duration_played), 0) AS total
      FROM listening_history
      WHERE played_at >= ?
    ''', [since.toIso8601String()]);
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  // ─────────────── USER STATS ───────────────

  Future<UserStats> getUserStats() async {
    final db = await database;
    final rows = await db.query('user_stats', limit: 1);
    if (rows.isEmpty) {
      // Safety: insert if missing
      await db.insert('user_stats', {
        'total_play_time': 0,
        'total_songs_played': 0,
        'streak_days': 0,
      });
      return UserStats();
    }
    return UserStats.fromMap(rows.first);
  }

  Future<void> updateUserStats(UserStats stats) async {
    final db = await database;
    if (stats.id == null) {
      await db.insert('user_stats', stats.toMap());
    } else {
      await db.update('user_stats', stats.toMap(),
          where: 'id = ?', whereArgs: [stats.id]);
    }
  }

  // ─────────────── BADGES ───────────────

  Future<void> unlockBadge(BadgeType type) async {
    final db = await database;
    await db.insert(
      'badges',
      {
        'badge_type': type.name,
        'is_unlocked': 1,
        'unlocked_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Set<BadgeType>> getUnlockedBadges() async {
    final db = await database;
    final rows = await db.query('badges', where: 'is_unlocked = 1');
    final result = <BadgeType>{};
    for (final r in rows) {
      try {
        result
            .add(BadgeType.values.firstWhere((e) => e.name == r['badge_type']));
      } catch (_) {}
    }
    return result;
  }

  // ─────────────── ANALYTICS ───────────────

  Future<String> getFavoriteArtist() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT artist, SUM(play_count) as total
      FROM songs
      WHERE play_count > 0
      GROUP BY artist
      ORDER BY total DESC
      LIMIT 1
    ''');
    if (rows.isEmpty) return 'None yet';
    return (rows.first['artist'] as String?) ?? 'None yet';
  }
}
