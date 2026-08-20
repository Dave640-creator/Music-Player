import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/video.dart';
import '../models/playlist.dart';
import '../models/user_stats.dart';
import '../database/database_helper.dart';
import '../services/audio_player_service.dart';
import '../services/video_player_service.dart';
import '../services/media_scanner_service.dart';
import '../services/demo_seeder.dart';
import '../theme/app_theme.dart';

/// Unified media state for Mosaic Player.
///
/// One source of truth for songs, videos, playlists, discovery sections,
/// library browsing, universal search, appearance settings and privacy.
class MediaProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final AudioPlayerService audio = AudioPlayerService.instance;
  final VideoPlayerService video = VideoPlayerService.instance;
  final MediaScannerService scanner = MediaScannerService.instance;

  // ── Library data ──────────────────────────────────────────────────────
  List<Song> _songs = [];
  List<Video> _videos = [];
  List<Playlist> _playlists = [];
  List<Song> _favorites = [];
  List<Video> _favoriteVideos = [];
  UserStats _userStats = UserStats();
  Set<BadgeType> _unlockedBadges = {};

  // ── Library UI state ──────────────────────────────────────────────────
  LibraryMediaFilter _mediaFilter = LibraryMediaFilter.all;
  LibraryCategory _category = LibraryCategory.songs;
  SortBy _sortBy = SortBy.recentlyAdded;
  bool _gridView = true;
  bool _showPrivate = false;

  // ── Discovery sections ────────────────────────────────────────────────
  List<Song> _recentSongs = [];
  List<Song> _rotation = [];
  List<Song> _recentlyAddedSongs = [];
  List<Video> _continueWatching = [];
  List<Video> _recentVideos = [];
  List<Video> _recentlyAddedVideos = [];

  // ── Scan state ────────────────────────────────────────────────────────
  bool _isScanning = false;
  int _scanProgress = 0;
  int _scanTotal = 0;
  bool _isLoading = true;

  // ── Appearance & behaviour settings ───────────────────────────────────
  ThemeMode _themeMode = ThemeMode.dark;
  int _accentIndex = 0;
  bool _dynamicBackground = true;
  bool _animationsEnabled = true;
  bool _autoResume = true;

  // ── Privacy ───────────────────────────────────────────────────────────
  String? _pinCode;
  bool _appLockEnabled = false;
  bool _privateModeUnlocked = false;

  // ── Audio effects ─────────────────────────────────────────────────────
  String _eqPreset = 'Flat';
  double _speed = 1.0;
  bool _bassBoost = false;
  bool _volumeBooster = false;

  // ── Getters ───────────────────────────────────────────────────────────
  List<Song> get songs => _songs;
  List<Video> get videos => _videos;
  List<Playlist> get playlists => _playlists;
  List<Song> get favorites => _favorites;
  List<Video> get favoriteVideos => _favoriteVideos;
  UserStats get userStats => _userStats;
  Set<BadgeType> get unlockedBadges => _unlockedBadges;

  LibraryMediaFilter get mediaFilter => _mediaFilter;
  LibraryCategory get category => _category;
  SortBy get sortBy => _sortBy;
  bool get gridView => _gridView;
  bool get showPrivate => _showPrivate;

  List<Song> get recentSongs => _recentSongs;
  List<Song> get rotation => _rotation;
  List<Song> get recentlyAddedSongs => _recentlyAddedSongs;
  List<Video> get continueWatching => _continueWatching;
  List<Video> get recentVideos => _recentVideos;
  List<Video> get recentlyAddedVideos => _recentlyAddedVideos;

  bool get isScanning => _isScanning;
  int get scanProgress => _scanProgress;
  int get scanTotal => _scanTotal;
  bool get isLoading => _isLoading;

  ThemeMode get themeMode => _themeMode;
  int get accentIndex => _accentIndex;
  bool get dynamicBackground => _dynamicBackground;
  bool get animationsEnabled => _animationsEnabled;
  bool get autoResume => _autoResume;
  bool get isDark => _themeMode != ThemeMode.light;

  String? get pinCode => _pinCode;
  bool get appLockEnabled => _appLockEnabled;
  bool get privateModeUnlocked => _privateModeUnlocked;
  bool get hasPrivateMedia =>
      _songs.any((s) => s.isPrivate) || _videos.any((v) => v.isPrivate);

  String get eqPreset => _eqPreset;
  double get speed => _speed;
  bool get bassBoost => _bassBoost;
  bool get volumeBooster => _volumeBooster;
  bool get hasQueue => audio.hasQueue;
  bool get isVideoActive => video.currentVideo != null;

  // ═══════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    await audio.init();
    await _loadSettings();
    await DemoSeeder.instance.seedIfEmpty();
    await loadAll();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    _songs = await _db.getAllSongs(includePrivate: _showPrivate);
    _videos = await _db.getAllVideos(includePrivate: _showPrivate);
    _playlists = await _db.getAllPlaylists();
    _favorites = await _db.getFavoriteSongs();
    _favoriteVideos = await _db.getFavoriteVideos();
    _userStats = await _db.getUserStats();
    _unlockedBadges = await _db.getUnlockedBadges();

    await _computeDiscover();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _computeDiscover() async {
    _recentSongs = await _db.getRecentlyPlayedSongs(limit: 10);
    _rotation = await _db.getMostPlayedSongs(limit: 10);
    _recentlyAddedSongs = await _db.getRecentlyAddedSongs(limit: 10);
    _continueWatching = await _db.getContinueWatching(limit: 8);
    _recentVideos = await _db.getRecentlyPlayedVideos(limit: 8);
    _recentlyAddedVideos = await _db.getRecentlyAddedVideos(limit: 8);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SETTINGS PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 2];
    _accentIndex = prefs.getInt('accentIndex') ?? 0;
    _dynamicBackground = prefs.getBool('dynamicBackground') ?? true;
    _animationsEnabled = prefs.getBool('animationsEnabled') ?? true;
    _autoResume = prefs.getBool('autoResume') ?? true;
    _pinCode = prefs.getString('pinCode');
    _appLockEnabled = prefs.getBool('appLockEnabled') ?? false;
    _eqPreset = prefs.getString('eqPreset') ?? 'Flat';
    _bassBoost = prefs.getBool('bassBoost') ?? false;
    _volumeBooster = prefs.getBool('volumeBooster') ?? false;
    AppTheme.accent = AppTheme.accentPresets[_accentIndex];
    await audio.setBassBoost(_bassBoost);
    await audio.setVolumeBooster(_volumeBooster);
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _themeMode.index);
    await prefs.setInt('accentIndex', _accentIndex);
    await prefs.setBool('dynamicBackground', _dynamicBackground);
    await prefs.setBool('animationsEnabled', _animationsEnabled);
    await prefs.setBool('autoResume', _autoResume);
    await prefs.setBool('bassBoost', _bassBoost);
    await prefs.setBool('volumeBooster', _volumeBooster);
    await prefs.setString('eqPreset', _eqPreset);
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _savePrefs();
    notifyListeners();
  }

  void setAccentIndex(int index) {
    _accentIndex = index.clamp(0, AppTheme.accentPresets.length - 1);
    AppTheme.accent = AppTheme.accentPresets[_accentIndex];
    _savePrefs();
    notifyListeners();
  }

  void setDynamicBackground(bool value) {
    _dynamicBackground = value;
    _savePrefs();
    notifyListeners();
  }

  void setAnimationsEnabled(bool value) {
    _animationsEnabled = value;
    _savePrefs();
    notifyListeners();
  }

  void setAutoResume(bool value) {
    _autoResume = value;
    _savePrefs();
    notifyListeners();
  }

  Future<void> setEqPreset(String preset) async {
    _eqPreset = preset;
    _savePrefs();
    notifyListeners();
  }

  Future<void> setSpeed(double value) async {
    _speed = value.clamp(0.5, 2.0);
    await audio.setPlaybackSpeed(_speed);
    notifyListeners();
  }

  Future<void> setBassBoost(bool value) async {
    _bassBoost = value;
    await audio.setBassBoost(value);
    _savePrefs();
    notifyListeners();
  }

  Future<void> setVolumeBooster(bool value) async {
    _volumeBooster = value;
    await audio.setVolumeBooster(value);
    _savePrefs();
    notifyListeners();
  }

  // ── Privacy ───────────────────────────────────────────────────────────

  Future<void> setPin(String? pin) async {
    _pinCode = pin;
    final prefs = await SharedPreferences.getInstance();
    if (pin == null) {
      await prefs.remove('pinCode');
    } else {
      await prefs.setString('pinCode', pin);
    }
    notifyListeners();
  }

  Future<void> setAppLock(bool enabled) async {
    _appLockEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appLockEnabled', enabled);
    notifyListeners();
  }

  void setPrivateModeUnlocked(bool value) {
    _privateModeUnlocked = value;
    notifyListeners();
  }

  Future<void> setSongPrivate(Song song, bool isPrivate) async {
    if (song.id == null) return;
    await _db.setPrivateStatus(song.id!, isPrivate);
    await loadAll();
  }

  Future<void> setVideoPrivate(Video v, bool isPrivate) async {
    if (v.id == null) return;
    await _db.setVideoPrivateStatus(v.id!, isPrivate);
    await loadAll();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LIBRARY BROWSING
  // ═══════════════════════════════════════════════════════════════════════

  void setMediaFilter(LibraryMediaFilter filter) {
    _mediaFilter = filter;
    notifyListeners();
  }

  void setCategory(LibraryCategory category) {
    _category = category;
    notifyListeners();
  }

  void setSortBy(SortBy sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void toggleGridView() {
    _gridView = !_gridView;
    notifyListeners();
  }

  void toggleShowPrivate() {
    _showPrivate = !_showPrivate;
    if (_showPrivate) setPrivateModeUnlocked(true);
    loadAll();
  }

  /// All songs honouring the active sort.
  List<Song> get sortedSongs {
    final list = List<Song>.from(_songs);
    switch (_sortBy) {
      case SortBy.title:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortBy.artist:
        list.sort(
            (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case SortBy.mostPlayed:
        list.sort((a, b) => b.playCount.compareTo(a.playCount));
        break;
      case SortBy.recentlyPlayed:
        list.sort((a, b) {
          final ta = a.lastPlayedAt ?? DateTime(1970);
          final tb = b.lastPlayedAt ?? DateTime(1970);
          return tb.compareTo(ta);
        });
        break;
      case SortBy.recentlyAdded:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
    }
    return list;
  }

  List<Video> get sortedVideos {
    final list = List<Video>.from(_videos);
    switch (_sortBy) {
      case SortBy.title:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortBy.mostPlayed:
        list.sort((a, b) => b.playCount.compareTo(a.playCount));
        break;
      case SortBy.recentlyAdded:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case SortBy.artist:
      case SortBy.recentlyPlayed:
        break;
    }
    return list;
  }

  // ── Grouped library views ─────────────────────────────────────────────

  Map<String, List<Song>> get songsByAlbum {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      map.putIfAbsent(s.album, () => []).add(s);
    }
    for (final v in map.values) {
      v.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return map;
  }

  Map<String, List<Song>> get songsByArtist {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      map.putIfAbsent(s.artist, () => []).add(s);
    }
    return map;
  }

  Map<String, List<Song>> get songsByGenre {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      final genre =
          (s.genre == null || s.genre!.isEmpty) ? 'Other' : s.genre!;
      map.putIfAbsent(genre, () => []).add(s);
    }
    return map;
  }

  Map<String, List<Song>> get songsByFolder {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      final dir = _parentDir(s.filePath);
      map.putIfAbsent(dir, () => []).add(s);
    }
    return map;
  }

  Map<String, List<Video>> get videosByFolder {
    final map = <String, List<Video>>{};
    for (final v in _videos) {
      final dir = v.filePath.isEmpty ? 'Demo videos' : _parentDir(v.filePath);
      map.putIfAbsent(dir, () => []).add(v);
    }
    return map;
  }

  List<Map<String, dynamic>> get genresWithCounts {
    final counts = <String, int>{};
    for (final s in _songs) {
      final genre =
          (s.genre == null || s.genre!.isEmpty) ? 'Other' : s.genre!;
      counts[genre] = (counts[genre] ?? 0) + 1;
    }
    final list = counts.entries
        .map((e) => {'name': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return list;
  }

  String _parentDir(String path) {
    final norm = path.replaceAll('\\', '/');
    final index = norm.lastIndexOf('/');
    if (index <= 1) return 'Device storage';
    final dir = norm.substring(0, index);
    final parts = dir.split('/');
    if (parts.length <= 2) return dir;
    return '…/${parts.sublist(parts.length - 2).join('/')}';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PLAYBACK ACTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    final playQueue = queue ?? sortedSongs;
    final index = playQueue.indexWhere((s) => s.id == song.id);
    await audio.setQueue(playQueue, startIndex: index < 0 ? 0 : index);
    notifyListeners();
  }

  Future<void> playSongs(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    await audio.setQueue(songs, startIndex: startIndex);
    notifyListeners();
  }

  Future<void> playNext(Song song) async {
    await audio.playNext(song);
    notifyListeners();
  }

  Future<void> addToQueue(Song song) async {
    await audio.addToQueue(song);
    notifyListeners();
  }

  Future<void> addSongsToQueue(List<Song> songs) async {
    await audio.addAllToQueue(songs);
    notifyListeners();
  }

  Future<void> playPlaylist(Playlist playlist) async {
    if (playlist.songs.isEmpty) return;
    await audio.setQueue(playlist.songs);
  }

  List<Video> _videoPlaylist = [];
  int _videoPlaylistIndex = 0;
  List<Video> get videoPlaylist => _videoPlaylist;
  int get videoPlaylistIndex => _videoPlaylistIndex;

  Future<void> playVideo(Video v, {List<Video>? queue}) async {
    final q = queue ?? _videos;
    _videoPlaylist = List.from(q);
    _videoPlaylistIndex =
        q.indexWhere((x) => x.id == v.id) < 0 ? 0 : q.indexWhere((x) => x.id == v.id);
    await video.load(v);
    notifyListeners();
  }

  Future<void> playNextVideoInPlaylist() async {
    if (_videoPlaylist.isEmpty) return;
    final next = _videoPlaylistIndex + 1;
    if (next < _videoPlaylist.length) {
      _videoPlaylistIndex = next;
      await playVideo(_videoPlaylist[next], queue: _videoPlaylist);
    }
  }

  Future<void> playPreviousVideoInPlaylist() async {
    if (_videoPlaylist.isEmpty) return;
    final prev = _videoPlaylistIndex - 1;
    if (prev >= 0) {
      _videoPlaylistIndex = prev;
      await playVideo(_videoPlaylist[prev], queue: _videoPlaylist);
    }
  }

  // ── Favorites ─────────────────────────────────────────────────────────

  Future<void> toggleFavorite(Song song) async {
    if (song.id == null) return;
    song.isFavorite = !song.isFavorite;
    await _db.toggleFavorite(song.id!, song.isFavorite);
    _favorites = await _db.getFavoriteSongs();
    final idx = _songs.indexWhere((s) => s.id == song.id);
    if (idx >= 0) _songs[idx].isFavorite = song.isFavorite;
    await _checkBadges();
    notifyListeners();
  }

  Future<void> toggleVideoFavorite(Video v) async {
    if (v.id == null) return;
    v.isFavorite = !v.isFavorite;
    await _db.toggleVideoFavorite(v.id!, v.isFavorite);
    _favoriteVideos = await _db.getFavoriteVideos();
    final idx = _videos.indexWhere((x) => x.id == v.id);
    if (idx >= 0) _videos[idx].isFavorite = v.isFavorite;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PLAYLISTS
  // ═══════════════════════════════════════════════════════════════════════

  Future<Playlist?> createPlaylist(String name,
      {String? description,
      PlaylistMedia mediaType = PlaylistMedia.music}) async {
    final playlist =
        Playlist(name: name, description: description, mediaType: mediaType);
    final id = await _db.createPlaylist(playlist);
    await loadAll();
    await _checkBadges();
    return _playlists.where((p) => p.id == id).firstOrNull;
  }

  Future<void> deletePlaylist(int id) async {
    await _db.deletePlaylist(id);
    await loadAll();
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    await _db.addSongToPlaylist(playlistId, songId);
    await loadAll();
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await _db.removeSongFromPlaylist(playlistId, songId);
    await loadAll();
  }

  Future<void> addVideoToPlaylist(int playlistId, int videoId) async {
    await _db.addVideoToPlaylist(playlistId, videoId);
    await loadAll();
  }

  Future<void> saveQueueAsPlaylist(String name) async {
    final pl = await audio.saveQueueAsPlaylist(name);
    if (pl != null) await loadAll();
  }

  Future<void> deleteSongFromLibrary(Song song) async {
    if (song.id == null) return;
    await _db.deleteSong(song.id!);
    if (song.id == audio.currentSong?.id && audio.hasQueue) {
      final idx = audio.queue.indexWhere((s) => s.id == song.id);
      if (idx >= 0) await audio.removeFromQueue(idx);
    }
    await loadAll();
  }

  Future<void> deleteVideoFromLibrary(Video v) async {
    if (v.id == null) return;
    await _db.deleteVideo(v.id!);
    if (video.currentVideo?.id == v.id) await video.stop();
    await loadAll();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SCANNING
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> scanLibrary(
      {bool videosOnly = false, bool musicOnly = false}) async {
    final hasPerms = await scanner.hasPermission();
    if (!hasPerms) {
      final granted = await scanner.requestPermissions();
      if (!granted) return;
    }
    _isScanning = true;
    _scanProgress = 0;
    _scanTotal = 0;
    notifyListeners();

    if (!videosOnly) {
      await scanner.scanAudio(onProgress: (found, total) {
        _scanProgress = found;
        _scanTotal = total;
        notifyListeners();
      });
    }
    if (!musicOnly) {
      await scanner.scanVideo(onProgress: (found, total) {
        _scanProgress = found;
        _scanTotal = total;
        notifyListeners();
      });
    }

    _isScanning = false;
    await loadAll();
  }

  Future<List<Song>> importAudioFromPicker() async {
    final songs = await scanner.importAudioFromPicker();
    if (songs.isNotEmpty) await loadAll();
    return songs;
  }

  Future<List<Video>> importVideoFromPicker() async {
    final videos = await scanner.importVideoFromPicker();
    if (videos.isNotEmpty) await loadAll();
    return videos;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UNIVERSAL SEARCH
  // ═══════════════════════════════════════════════════════════════════════

  SearchResults searchAll(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return SearchResults.empty();

    final songs = <Song>[];
    final artists = <String>{};
    final albums = <Map<String, dynamic>>[];
    final genres = <Map<String, dynamic>>[];
    final videos = <Video>[];
    final playlists = <Playlist>[];
    final folders = <String>{};

    for (final s in _songs) {
      if (s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q) ||
          (s.genre ?? '').toLowerCase().contains(q)) {
        songs.add(s);
        if (s.artist.toLowerCase().contains(q)) artists.add(s.artist);
        if (s.album.toLowerCase().contains(q) &&
            !albums.any((a) => a['name'] == s.album)) {
          albums.add({'name': s.album, 'artist': s.artist});
        }
        if ((s.genre ?? '').toLowerCase().contains(q) &&
            !genres.any((g) => g['name'] == s.genre)) {
          genres.add({
            'name': s.genre,
            'count': _songs.where((x) => x.genre == s.genre).length,
          });
        }
      }
      if (s.artist == query) artists.add(s.artist);
    }

    for (final v in _videos) {
      if (v.title.toLowerCase().contains(q) ||
          v.artist.toLowerCase().contains(q)) {
        videos.add(v);
      }
    }

    for (final p in _playlists) {
      if (p.name.toLowerCase().contains(q)) playlists.add(p);
    }

    final songFolders = _songs.map((s) => _parentDir(s.filePath)).toSet();
    final videoFolders = _videos
        .map((v) => v.filePath.isEmpty ? 'Demo videos' : _parentDir(v.filePath))
        .toSet();
    for (final f in {...songFolders, ...videoFolders}) {
      if (f.toLowerCase().contains(q)) folders.add(f);
    }

    return SearchResults(
      query: query,
      songs: songs.take(8).toList(),
      artists: artists.take(6).toList(),
      albums: albums.take(6).toList(),
      genres: genres.take(6).toList(),
      videos: videos.take(8).toList(),
      playlists: playlists.take(6).toList(),
      folders: folders.take(6).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FILE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  /// Rename a song's on-disk file and update the database.
  Future<bool> renameSongFile(Song song, String newTitle) async {
    try {
      final file = File(song.filePath);
      if (!await file.exists()) return false;
      final dir = file.parent.path;
      final ext = song.filePath.split('.').last;
      final safe = newTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final newPath = '$dir${Platform.pathSeparator}$safe.$ext';
      if (newPath == song.filePath) return false;
      await file.rename(newPath);
      await _db.updateSongFilePath(song.id!, newPath);
      await loadAll();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkBadges() async {
    final stats = await _db.getUserStats();
    final favCount = _favorites.length;
    final playlistCount = await _db.getPlaylistCount();

    Future<void> unlock(BadgeType t) async {
      if (!_unlockedBadges.contains(t)) await _db.unlockBadge(t);
    }

    if (stats.streakDays >= 7) await unlock(BadgeType.sevenDayListener);
    if (stats.totalSongsPlayed >= 50) await unlock(BadgeType.hundredSongsPlayed);
    if (playlistCount >= 1) await unlock(BadgeType.playlistCreator);
    if (favCount >= 10) await unlock(BadgeType.favoritesCollector);
    if (stats.totalPlayTime >= 36000) await unlock(BadgeType.marathonListener);
    _unlockedBadges = await _db.getUnlockedBadges();
  }

    Future<void> disposeProvider() async {
    await audio.disposeService();
    await video.disposeService();
  }

  @override
  void dispose() {
    disposeProvider();
    super.dispose();
  }
}

/// Media-type filter for the unified library.
enum LibraryMediaFilter { all, music, video }

/// Library categories switchable in place.
enum LibraryCategory { songs, albums, artists, genres, folders, playlists }

/// Library sort orders.
enum SortBy { recentlyAdded, title, artist, mostPlayed, recentlyPlayed }

/// Grouped results for universal search.
class SearchResults {
  final String query;
  final List<Song> songs;
  final List<String> artists;
  final List<Map<String, dynamic>> albums;
  final List<Map<String, dynamic>> genres;
  final List<Video> videos;
  final List<Playlist> playlists;
  final List<String> folders;

  SearchResults({
    required this.query,
    this.songs = const [],
    this.artists = const [],
    this.albums = const [],
    this.genres = const [],
    this.videos = const [],
    this.playlists = const [],
    this.folders = const [],
  });

  factory SearchResults.empty() {
    return SearchResults(query: '');
  }

  bool get isEmpty =>
      songs.isEmpty &&
      artists.isEmpty &&
      albums.isEmpty &&
      genres.isEmpty &&
      videos.isEmpty &&
      playlists.isEmpty &&
      folders.isEmpty;
}
