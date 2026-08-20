import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/song.dart';
import '../models/video.dart';
import '../models/playlist.dart';
import '../models/user_stats.dart';

/// SQLite data layer for Mosaic Player.
///
/// Schema v2 adds: extended `songs` metadata (genre, privacy, lyrics, last
/// played), a `videos` table, `playlist_videos`, and `playback_progress` for
/// resume / "continue watching" behaviour. Migration from v1 is handled in
/// [_upgradeTables].
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mosaic_player_v2.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
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
        genre TEXT,
        last_played_at TEXT,
        is_private INTEGER NOT NULL DEFAULT 0,
        lyrics TEXT,
        year INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        artist TEXT NOT NULL DEFAULT 'Local Video',
        file_path TEXT UNIQUE NOT NULL,
        duration INTEGER NOT NULL DEFAULT 0,
        date_added TEXT NOT NULL,
        play_count INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        thumbnail_path TEXT,
        last_position INTEGER NOT NULL DEFAULT 0,
        is_private INTEGER NOT NULL DEFAULT 0,
        is_demo INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        description TEXT,
        is_auto_generated INTEGER NOT NULL DEFAULT 0,
        media_type TEXT NOT NULL DEFAULT 'music'
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        song_id INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE,
        UNIQUE(playlist_id, song_id)
      )
    ''');
// __CONTINUE__
    await db.execute('''
      CREATE TABLE playlist_videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        video_id INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE,
        UNIQUE(playlist_id, video_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE listening_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER NOT NULL,
        played_at TEXT NOT NULL,
        duration_played INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE user_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_play_time INTEGER NOT NULL DEFAULT 0,
        total_songs_played INTEGER NOT NULL DEFAULT 0,
        streak_days INTEGER NOT NULL DEFAULT 0,
        last_played_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE badges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        badge_type TEXT UNIQUE NOT NULL,
        is_unlocked INTEGER NOT NULL DEFAULT 0,
        unlocked_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE playback_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        media_type TEXT NOT NULL,
        media_id INTEGER NOT NULL,
        position_seconds INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        UNIQUE(media_type, media_id)
      )
    ''');

    await _createIndexes(db);
    await db.insert('user_stats', {
      'total_play_time': 0,
      'total_songs_played': 0,
      'streak_days': 0,
    });
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_songs_artist ON songs(artist)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_songs_album ON songs(album)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_songs_play_count ON songs(play_count DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_videos_play_count ON videos(play_count DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_history_played_at ON listening_history(played_at)');
  }

  /// Migrate a v1 database (original music-only schema) to v2.
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final songCols = await _columnNames(db, 'songs');
      if (!songCols.contains('genre')) {
        await db.execute('ALTER TABLE songs ADD COLUMN genre TEXT');
      }
      if (!songCols.contains('last_played_at')) {
        await db.execute('ALTER TABLE songs ADD COLUMN last_played_at TEXT');
      }
      if (!songCols.contains('is_private')) {
        await db.execute('ALTER TABLE songs ADD COLUMN is_private INTEGER NOT NULL DEFAULT 0');
      }
      if (!songCols.contains('lyrics')) {
        await db.execute('ALTER TABLE songs ADD COLUMN lyrics TEXT');
      }
      if (!songCols.contains('year')) {
        await db.execute('ALTER TABLE songs ADD COLUMN year INTEGER');
      }
      final plCols = await _columnNames(db, 'playlists');
      if (!plCols.contains('media_type')) {
        await db.execute("ALTER TABLE playlists ADD COLUMN media_type TEXT NOT NULL DEFAULT 'music'");
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS videos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          artist TEXT NOT NULL DEFAULT 'Local Video',
          file_path TEXT UNIQUE NOT NULL,
          duration INTEGER NOT NULL DEFAULT 0,
          date_added TEXT NOT NULL,
          play_count INTEGER NOT NULL DEFAULT 0,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          thumbnail_path TEXT,
          last_position INTEGER NOT NULL DEFAULT 0,
          is_private INTEGER NOT NULL DEFAULT 0,
          is_demo INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS playlist_videos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          playlist_id INTEGER NOT NULL,
          video_id INTEGER NOT NULL,
          position INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
          FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE,
          UNIQUE(playlist_id, video_id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS playback_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          media_type TEXT NOT NULL,
          media_id INTEGER NOT NULL,
          position_seconds INTEGER NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL,
          UNIQUE(media_type, media_id)
        )
      ''');
      await _createIndexes(db);
    }
  }

  Future<List<String>> _columnNames(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((r) => r['name'] as String).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SONGS
  // ═══════════════════════════════════════════════════════════════════════

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

  /// All songs; hide the user's private music unless explicitly requested.
  Future<List<Song>> getAllSongs({bool includePrivate = false}) async {
    final db = await database;
    final rows = await db.query(
      'songs',
      where: includePrivate ? null : 'is_private = 0',
      orderBy: 'date_added DESC',
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<Song?> getSongById(int id) async {
    final db = await database;
    final rows = await db.query('songs', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Song.fromMap(rows.first);
  }

  Future<List<Song>> searchSongs(String query,
      {bool includePrivate = false}) async {
    final db = await database;
    final q = '%$query%';
    final where = includePrivate
        ? 'title LIKE ? OR artist LIKE ? OR album LIKE ? OR genre LIKE ?'
        : '(title LIKE ? OR artist LIKE ? OR album LIKE ? OR genre LIKE ?) '
            'AND is_private = 0';
    final rows = await db.query(
      'songs',
      where: where,
      whereArgs: [q, q, q, q],
      orderBy: 'title ASC',
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getFavoriteSongs({bool includePrivate = false}) async {
    final db = await database;
    final rows = await db.query(
      'songs',
      where: includePrivate ? 'is_favorite = 1' : 'is_favorite = 1 AND is_private = 0',
      orderBy: 'title ASC',
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getMostPlayedSongs({int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'songs',
      where: 'play_count > 0 AND is_private = 0',
      orderBy: 'play_count DESC',
      limit: limit,
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getRecentlyPlayedSongs({int limit = 10}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.* FROM songs s
      WHERE s.last_played_at IS NOT NULL AND s.is_private = 0
      ORDER BY s.last_played_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getRecentlyAddedSongs({int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'songs',
      where: 'is_private = 0',
      orderBy: 'date_added DESC',
      limit: limit,
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getSongsByGenre(String genre,
      {bool includePrivate = false}) async {
    final db = await database;
    final rows = await db.query(
      'songs',
      where: includePrivate ? 'genre = ?' : 'genre = ? AND is_private = 0',
      whereArgs: [genre],
    );
    return rows.map(Song.fromMap).toList();
  }

  /// Distinct genres ordered by song count (descending).
  Future<List<Map<String, dynamic>>> getGenres() async {
    final db = await database;
    return db.rawQuery('''
      SELECT genre, COUNT(*) as count FROM songs
      WHERE genre IS NOT NULL AND genre != '' AND is_private = 0
      GROUP BY LOWER(genre) ORDER BY count DESC
    ''');
  }

  Future<Map<String, List<Song>>> getSongsByArtist() async {
    final songs = await getAllSongs();
    final map = <String, List<Song>>{};
    for (final s in songs) {
      map.putIfAbsent(s.artist, () => []).add(s);
    }
    return map;
  }

  Future<Map<String, List<Song>>> getSongsByAlbum() async {
    final songs = await getAllSongs();
    final map = <String, List<Song>>{};
    for (final s in songs) {
      map.putIfAbsent(s.album, () => []).add(s);
    }
    return map;
  }

  /// Folders derived from the audio files' directory paths.
  Future<Map<String, List<Song>>> getSongsByFolder() async {
    final songs = await getAllSongs();
    final map = <String, List<Song>>{};
    for (final s in songs) {
      final dir = _parentDir(s.filePath);
      map.putIfAbsent(dir, () => []).add(s);
    }
    return map;
  }

  String _parentDir(String path) {
    final index = path.lastIndexOf(RegExp(r'[/\\]'));
    if (index <= 0) return 'Device storage';
    return path.substring(0, index);
  }

  Future<void> updateSong(Song song) async {
    final db = await database;
    await db.update('songs', song.toMap(),
        where: 'id = ?', whereArgs: [song.id]);
  }

  Future<void> updateSongFilePath(int id, String newPath) async {
    final db = await database;
    await db.update('songs', {'file_path': newPath},
        where: 'id = ?', whereArgs: [id]);
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

  Future<void> updateLastPlayedAt(int songId, DateTime time) async {
    final db = await database;
    await db.update('songs', {'last_played_at': time.toIso8601String()},
        where: 'id = ?', whereArgs: [songId]);
  }

  Future<void> updateMoodTag(int songId, String? mood) async {
    final db = await database;
    await db.update('songs', {'mood_tag': mood},
        where: 'id = ?', whereArgs: [songId]);
  }

  Future<void> updateLyrics(int songId, String lyrics) async {
    final db = await database;
    await db.update('songs', {'lyrics': lyrics},
        where: 'id = ?', whereArgs: [songId]);
  }

  Future<void> setPrivateStatus(int songId, bool isPrivate) async {
    final db = await database;
    await db.update('songs', {'is_private': isPrivate ? 1 : 0},
        where: 'id = ?', whereArgs: [songId]);
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
    final res = await db.rawQuery(
        'SELECT COUNT(*) as c FROM songs WHERE is_private = 0');
    return (res.first['c'] as int?) ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // VIDEOS
  // ═══════════════════════════════════════════════════════════════════════

  Future<int> insertVideo(Video video) async {
    final db = await database;
    try {
      return await db.insert('videos', video.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (_) {
      return -1;
    }
  }

  Future<void> insertVideoBatch(List<Video> videos) async {
    if (videos.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final v in videos) {
      batch.insert('videos', v.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Video>> getAllVideos({bool includePrivate = false}) async {
    final db = await database;
    final rows = await db.query(
      'videos',
      where: includePrivate ? null : 'is_private = 0',
      orderBy: 'date_added DESC',
    );
    return rows.map(Video.fromMap).toList();
  }

  Future<Video?> getVideoById(int id) async {
    final db = await database;
    final rows = await db.query('videos', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Video.fromMap(rows.first);
  }

  Future<List<Video>> searchVideos(String query) async {
    final db = await database;
    final q = '%$query%';
    final rows = await db.query(
      'videos',
      where: '(title LIKE ? OR artist LIKE ?) AND is_private = 0',
      whereArgs: [q, q],
      orderBy: 'title ASC',
    );
    return rows.map(Video.fromMap).toList();
  }

  Future<List<Video>> getFavoriteVideos() async {
    final db = await database;
    final rows = await db.query(
      'videos',
      where: 'is_favorite = 1 AND is_private = 0',
      orderBy: 'title ASC',
    );
    return rows.map(Video.fromMap).toList();
  }

  Future<List<Video>> getMostPlayedVideos({int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'videos',
      where: 'play_count > 0 AND is_private = 0',
      orderBy: 'play_count DESC',
      limit: limit,
    );
    return rows.map(Video.fromMap).toList();
  }

  /// Videos with a saved resume point — "Continue watching".
  Future<List<Video>> getContinueWatching({int limit = 12}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT v.*, pp.updated_at as progress_at FROM videos v
      INNER JOIN playback_progress pp
        ON pp.media_type = 'video' AND pp.media_id = v.id
      WHERE v.last_position > 15 AND v.duration > 0
        AND v.last_position < v.duration - 5
        AND v.is_private = 0
      ORDER BY pp.updated_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(Video.fromMap).toList();
  }

  /// Recently played videos (ordered by their last progress update).
  Future<List<Video>> getRecentlyPlayedVideos({int limit = 10}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT v.* FROM videos v
      INNER JOIN playback_progress pp
        ON pp.media_type = 'video' AND pp.media_id = v.id
      WHERE v.is_private = 0
      ORDER BY pp.updated_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(Video.fromMap).toList();
  }

  Future<List<Video>> getRecentlyAddedVideos({int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'videos',
      where: 'is_private = 0',
      orderBy: 'date_added DESC',
      limit: limit,
    );
    return rows.map(Video.fromMap).toList();
  }

  Future<Map<String, List<Video>>> getVideosByFolder() async {
    final videos = await getAllVideos();
    final map = <String, List<Video>>{};
    for (final v in videos) {
      final dir = _parentDir(v.filePath);
      map.putIfAbsent(dir, () => []).add(v);
    }
    return map;
  }

  Future<void> updateVideo(Video video) async {
    final db = await database;
    await db.update('videos', video.toMap(),
        where: 'id = ?', whereArgs: [video.id]);
  }

  Future<void> toggleVideoFavorite(int videoId, bool isFavorite) async {
    final db = await database;
    await db.update('videos', {'is_favorite': isFavorite ? 1 : 0},
        where: 'id = ?', whereArgs: [videoId]);
  }

  Future<void> incrementVideoPlayCount(int videoId) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE videos SET play_count = play_count + 1 WHERE id = ?',
        [videoId]);
  }

  Future<void> setVideoPrivateStatus(int videoId, bool isPrivate) async {
    final db = await database;
    await db.update('videos', {'is_private': isPrivate ? 1 : 0},
        where: 'id = ?', whereArgs: [videoId]);
  }

  Future<void> updateVideoFilePath(int id, String newPath) async {
    final db = await database;
    await db.update('videos', {'file_path': newPath},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteVideo(int videoId) async {
    final db = await database;
    await db.delete('videos', where: 'id = ?', whereArgs: [videoId]);
  }

  Future<int> getVideoCount() async {
    final db = await database;
    final res = await db.rawQuery(
        'SELECT COUNT(*) as c FROM videos WHERE is_private = 0');
    return (res.first['c'] as int?) ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PLAYBACK PROGRESS (resume points for songs & videos)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> savePlaybackProgress(
      String mediaType, int mediaId, int positionSeconds) async {
    final db = await database;
    if (positionSeconds <= 0) return;
    await db.insert(
      'playback_progress',
      {
        'media_type': mediaType,
        'media_id': mediaId,
        'position_seconds': positionSeconds,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (mediaType == 'video') {
      await db.update('videos', {'last_position': positionSeconds},
          where: 'id = ?', whereArgs: [mediaId]);
    }
  }

  Future<int> getPlaybackProgress(String mediaType, int mediaId) async {
    final db = await database;
    final rows = await db.query(
      'playback_progress',
      where: 'media_type = ? AND media_id = ?',
      whereArgs: [mediaType, mediaId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['position_seconds'] as int?) ?? 0;
  }

  Future<void> clearPlaybackProgress(String mediaType, int mediaId) async {
    final db = await database;
    await db.delete('playback_progress',
        where: 'media_type = ? AND media_id = ?',
        whereArgs: [mediaType, mediaId]);
    if (mediaType == 'video') {
      await db.update('videos', {'last_position': 0},
          where: 'id = ?', whereArgs: [mediaId]);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PLAYLISTS
  // ═══════════════════════════════════════════════════════════════════════

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
      p.videos = await getPlaylistVideos(p.id!);
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
    await db.update('playlists', {'media_type': 'music'},
        where: 'id = ? AND media_type = "music"', whereArgs: [playlistId]);
  }

  Future<void> addVideoToPlaylist(int playlistId, int videoId) async {
    final db = await database;
    final countRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM playlist_videos WHERE playlist_id = ?',
        [playlistId]);
    final pos = (countRes.first['c'] as int?) ?? 0;
    await db.insert(
      'playlist_videos',
      {'playlist_id': playlistId, 'video_id': videoId, 'position': pos},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.update('playlists', {'media_type': 'video'},
        where: 'id = ? AND media_type = "video"', whereArgs: [playlistId]);
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    final db = await database;
    await db.delete('playlist_songs',
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, songId]);
  }

  Future<void> removeVideoFromPlaylist(int playlistId, int videoId) async {
    final db = await database;
    await db.delete('playlist_videos',
        where: 'playlist_id = ? AND video_id = ?',
        whereArgs: [playlistId, videoId]);
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

  Future<List<Video>> getPlaylistVideos(int playlistId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT v.* FROM videos v
      INNER JOIN playlist_videos pv ON v.id = pv.video_id
      WHERE pv.playlist_id = ?
      ORDER BY pv.position ASC
    ''', [playlistId]);
    return rows.map(Video.fromMap).toList();
  }

  /// Persist a full song order for a playlist (queue-save support).
  Future<void> reorderPlaylistSongs(int playlistId, List<int> songIds) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('playlist_songs', where: 'playlist_id = ?', whereArgs: [playlistId]);
    for (var i = 0; i < songIds.length; i++) {
      batch.insert('playlist_songs',
          {'playlist_id': playlistId, 'song_id': songIds[i], 'position': i});
    }
    await batch.commit(noResult: true);
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

  // ═══════════════════════════════════════════════════════════════════════
  // LISTENING HISTORY & STATS & BADGES
  // ═══════════════════════════════════════════════════════════════════════

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

  Future<List<Song>> getHistorySongs({int limit = 20}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT s.* FROM songs s
      INNER JOIN listening_history lh ON s.id = lh.song_id
      WHERE s.is_private = 0
      ORDER BY lh.played_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(Song.fromMap).toList();
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

  /// Total seconds listened across all history.
  Future<int> getTotalListeningTime() async {
    final db = await database;
    final res = await db.rawQuery(
        'SELECT COALESCE(SUM(duration_played), 0) as t FROM listening_history');
    return (res.first['t'] as int?) ?? 0;
  }

  Future<UserStats> getUserStats() async {
    final db = await database;
    final rows = await db.query('user_stats', limit: 1);
    if (rows.isEmpty) {
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

  Future<String> getFavoriteArtist() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT artist, SUM(play_count) as total
      FROM songs
      WHERE play_count > 0 AND is_private = 0
      GROUP BY artist
      ORDER BY total DESC
      LIMIT 1
    ''');
    if (rows.isEmpty) return 'None yet';
    return (rows.first['artist'] as String?) ?? 'None yet';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BACKUP / RESTORE
  // ═══════════════════════════════════════════════════════════════════════

  /// Path of the live SQLite database file (for backup copies).
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'mosaic_player_v2.db');
  }

  /// Restore media metadata by re-inserting songs; existing paths are kept
  /// (conflict on unique file_path is ignored).
  Future<void> restoreSongs(List<Song> songs) async {
    await insertSongBatch(songs);
  }
}

