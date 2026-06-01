import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/user_stats.dart';

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
      version: 1,
      onCreate: _createTables,
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
        artwork_path TEXT
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
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_songs_album ON songs(album)');
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

  Future<void> insertSongBatch(List<Song> songs) async {
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
    final rows = await db.query('songs',
        where: 'is_favorite = 1', orderBy: 'title ASC');
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getMostPlayedSongs({int limit = 10}) async {
    final db = await database;
    final rows = await db.query('songs',
        where: 'play_count > 0',
        orderBy: 'play_count DESC',
        limit: limit);
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getSongsByMood(String mood) async {
    final db = await database;
    final rows = await db
        .query('songs', where: 'mood_tag = ?', whereArgs: [mood]);
    return rows.map(Song.fromMap).toList();
  }

  Future<void> updateSong(Song song) async {
    final db = await database;
    await db.update('songs', song.toMap(),
        where: 'id = ?', whereArgs: [song.id]);
  }

  Future<void> toggleFavorite(int songId, bool isFavorite) async {
    final db = await database;
    await db.update('songs', {'is_favorite': isFavorite ? 1 : 0},
        where: 'id = ?', whereArgs: [songId]);
  }

  Future<void> incrementPlayCount(int songId) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE songs SET play_count = play_count + 1 WHERE id = ?',
        [songId]);
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
      SELECT * FROM songs
      WHERE title IN (
        SELECT title FROM songs GROUP BY LOWER(title) HAVING COUNT(*) > 1
      )
      ORDER BY LOWER(title), date_added ASC
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
    final rows =
        await db.query('playlists', orderBy: 'created_at DESC');
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
    await db.delete('playlists',
        where: 'id = ?', whereArgs: [playlistId]);
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

  Future<List<ListeningHistory>> getListeningHistory(
      {int limit = 100}) async {
    final db = await database;
    final rows = await db.query('listening_history',
        orderBy: 'played_at DESC', limit: limit);
    return rows.map(ListeningHistory.fromMap).toList();
  }

  Future<Map<String, int>> getDailyListeningStats(int days) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();
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
    final rows =
        await db.query('badges', where: 'is_unlocked = 1');
    final result = <BadgeType>{};
    for (final r in rows) {
      try {
        result.add(BadgeType.values
            .firstWhere((e) => e.name == r['badge_type']));
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
