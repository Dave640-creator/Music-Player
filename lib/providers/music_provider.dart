import 'package:flutter/material.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/user_stats.dart';
import '../database/database_helper.dart';
import '../services/audio_player_service.dart';
import '../services/music_scanner_service.dart';
import '../models/library_scan_result.dart';

enum SortBy { recentlyAdded, title, artist, mostPlayed }

class MusicProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final AudioPlayerService _audioService = AudioPlayerService();
  final MusicScannerService _scanner = MusicScannerService();

  List<Song> _allSongs = [];
  List<Song> _displaySongs = [];
  List<Playlist> _playlists = [];
  List<Song> _favorites = [];
  UserStats _userStats = UserStats();
  Set<BadgeType> _unlockedBadges = {};

  bool _isLoading = false;
  bool _isScanning = false;
  int _scanProgress = 0;
  int _scanTotal = 0;
  LibraryScanResult _scanResult = const LibraryScanResult();
  String _searchQuery = '';
  SortBy _sortBy = SortBy.recentlyAdded;

  // BUG FIX: allSongs now always returns _displaySongs which is correctly computed
  List<Song> get allSongs => _displaySongs;
  List<Song> get rawSongs => _allSongs;
  List<Playlist> get playlists => _playlists;
  List<Song> get favorites => _favorites;
  UserStats get userStats => _userStats;
  Set<BadgeType> get unlockedBadges => _unlockedBadges;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  int get scanProgress => _scanProgress;
  int get scanTotal => _scanTotal;
  LibraryScanResult get scanResult => _scanResult;
  SortBy get sortBy => _sortBy;
  String get searchQuery => _searchQuery;
  AudioPlayerService get audioService => _audioService;

  List<Song> getRecommendedSongs({int limit = 8}) {
    final now = DateTime.now();
    final recommendations = List<Song>.from(_allSongs)
      ..sort((a, b) {
        int score(Song song) {
          final recentDays = now.difference(song.dateAdded).inDays;
          final recency = (30 - recentDays).clamp(0, 30);
          return (song.isFavorite ? 100 : 0) +
              (song.playCount * 6) +
              (song.moodTag == null ? 0 : 4) +
              recency;
        }

        return score(b).compareTo(score(a));
      });
    return recommendations.take(limit).toList();
  }

  Future<void> init() async {
    await _audioService.init();
    await loadAll();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    _allSongs = await _db.getAllSongs();
    _playlists = await _db.getAllPlaylists();
    _favorites = await _db.getFavoriteSongs();
    _userStats = await _db.getUserStats();
    _unlockedBadges = await _db.getUnlockedBadges();
    _applyFilters();

    _isLoading = false;
    notifyListeners();
  }

  void _applyFilters() {
    List<Song> source = List.from(_allSongs);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      source = source
          .where((s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q))
          .toList();
    }

    switch (_sortBy) {
      case SortBy.title:
        source.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortBy.artist:
        source.sort((a, b) => a.artist.compareTo(b.artist));
        break;
      case SortBy.mostPlayed:
        source.sort((a, b) => b.playCount.compareTo(a.playCount));
        break;
      case SortBy.recentlyAdded:
        source.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
    }

    // BUG FIX: always assign _displaySongs regardless of source length
    _displaySongs = source;
  }

  void setSearch(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setSortBy(SortBy sort) {
    _sortBy = sort;
    _applyFilters();
    notifyListeners();
  }

  // === SCANNING ===

  Future<void> scanDevice() async {
    final hasPerms = await _scanner.hasPermission();
    if (!hasPerms) {
      final granted = await _scanner.requestPermissions();
      if (!granted) return;
    }

    _isScanning = true;
    _scanProgress = 0;
    _scanTotal = 0;
    _scanResult = const LibraryScanResult();
    notifyListeners();

    await _scanner.scanDeviceStorage(
      onProgress: (found, total) {
        _scanProgress = found;
        _scanTotal = total;
        notifyListeners();
      },
      onResult: (result) {
        _scanResult = result;
        notifyListeners();
      },
    );

    _isScanning = false;
    await loadAll();
  }

  Future<List<Song>> importFromPicker() async {
    final songs = await _scanner.importFromFilePicker();
    if (songs.isNotEmpty) {
      await loadAll();
    }
    return songs;
  }

  // === PLAYBACK ===

  void playSong(Song song, {List<Song>? queue}) {
    final playQueue = queue ?? _displaySongs;
    final index = playQueue.indexWhere((s) => s.id == song.id);
    _audioService.setQueue(playQueue, startIndex: index < 0 ? 0 : index);
    notifyListeners();
  }

  void playPlaylist(Playlist playlist) {
    if (playlist.songs.isEmpty) return;
    _audioService.setQueue(playlist.songs);
    notifyListeners();
  }

  // === FAVORITES ===

  Future<void> toggleFavorite(Song song) async {
    song.isFavorite = !song.isFavorite;
    await _db.toggleFavorite(song.id!, song.isFavorite);
    _favorites = await _db.getFavoriteSongs();
    // Update in _allSongs list too for UI consistency
    final idx = _allSongs.indexWhere((s) => s.id == song.id);
    if (idx >= 0) _allSongs[idx].isFavorite = song.isFavorite;
    _applyFilters();
    await _checkBadges();
    notifyListeners();
  }

  // === PLAYLISTS ===

  Future<Playlist?> createPlaylist(String name, {String? description}) async {
    final playlist = Playlist(name: name, description: description);
    final id = await _db.createPlaylist(playlist);
    await loadAll();
    await _checkBadges();
    // BUG FIX: use orElse to avoid StateError if not found
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return _playlists.isNotEmpty ? _playlists.first : null;
    }
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

  // === AUTO PLAYLISTS ===

  Future<void> generateAutoPlaylists() async {
    final songs = await _db.getAllSongs();
    if (songs.isEmpty) return;

    final configs = [
      {
        'name': '🎓 Study Mix',
        'mood': 'focus',
        'desc': 'Perfect for deep work'
      },
      {
        'name': '💪 Workout Mix',
        'mood': 'workout',
        'desc': 'High energy tracks'
      },
      {'name': '😌 Chill Mix', 'mood': 'chill', 'desc': 'Relax and unwind'},
      {'name': '😊 Happy Vibes', 'mood': 'happy', 'desc': 'Feel-good songs'},
      {'name': '😔 Rainy Day', 'mood': 'sad', 'desc': 'For reflective moments'},
      {'name': '🔥 Top 10', 'mood': null, 'desc': 'Your most played songs'},
      {
        'name': 'Daily Mix',
        'mood': 'daily',
        'desc': 'A fresh mix from your listening habits'
      },
    ];

    for (final cfg in configs) {
      Playlist? playlist;
      for (final candidate in _playlists) {
        if (candidate.name == cfg['name'] && candidate.isAutoGenerated) {
          playlist = candidate;
          break;
        }
      }
      final id = playlist?.id ??
          await _db.createPlaylist(Playlist(
            name: cfg['name']!,
            description: cfg['desc'],
            isAutoGenerated: true,
          ));
      await _db.clearPlaylistSongs(id);

      List<Song> pSongs;
      if (cfg['mood'] == 'daily') {
        final ranked = List<Song>.from(songs)
          ..sort((a, b) {
            final aScore = (a.isFavorite ? 100 : 0) + a.playCount * 6;
            final bScore = (b.isFavorite ? 100 : 0) + b.playCount * 6;
            return bScore.compareTo(aScore);
          });
        pSongs = ranked.take(45).toList();
      } else if (cfg['mood'] != null) {
        pSongs = songs.where((s) => s.moodTag == cfg['mood']).toList();
      } else {
        final sorted = List<Song>.from(songs)
          ..sort((a, b) => b.playCount.compareTo(a.playCount));
        pSongs = sorted.take(10).toList();
      }

      for (final s in pSongs) {
        if (s.id != null) await _db.addSongToPlaylist(id, s.id!);
      }
    }

    await loadAll();
  }

  // === MOOD ===

  Future<void> tagSongMood(Song song, String? mood) async {
    await _db.updateMoodTag(song.id!, mood);
    song.moodTag = mood;
    final idx = _allSongs.indexWhere((s) => s.id == song.id);
    if (idx >= 0) _allSongs[idx] = song.copyWith(moodTag: mood);
    _applyFilters();
    notifyListeners();
  }

  Future<List<Song>> getSongsByMood(String mood) async {
    return await _db.getSongsByMood(mood);
  }

  // === ANALYTICS ===

  Future<List<Song>> getMostPlayedSongs({int limit = 10}) async {
    return await _db.getMostPlayedSongs(limit: limit);
  }

  Future<Map<String, int>> getDailyStats(int days) async {
    return await _db.getDailyListeningStats(days);
  }

  Future<int> getListeningSecondsSince(DateTime since) async {
    return await _db.getListeningSecondsSince(since);
  }

  Future<String> getFavoriteArtist() async {
    return await _db.getFavoriteArtist();
  }

  Future<Map<String, List<Song>>> getSongsByArtist() async {
    return await _db.getSongsByArtist();
  }

  Future<Map<String, List<Song>>> getSongsByAlbum() async {
    return await _db.getSongsByAlbum();
  }

  Future<List<Song>> findDuplicates() async {
    return await _db.findDuplicates();
  }

  // === BADGES ===

  Future<void> _checkBadges() async {
    final stats = await _db.getUserStats();
    final favCount = _favorites.length;
    final playlistCount = await _db.getPlaylistCount();

    Future<void> unlock(BadgeType t) async {
      if (!_unlockedBadges.contains(t)) await _db.unlockBadge(t);
    }

    if (stats.streakDays >= 7) await unlock(BadgeType.sevenDayListener);
    if (stats.totalSongsPlayed >= 100) {
      await unlock(BadgeType.hundredSongsPlayed);
    }
    if (playlistCount >= 1) await unlock(BadgeType.playlistCreator);
    if (favCount >= 20) await unlock(BadgeType.favoritesCollector);
    if (stats.totalPlayTime >= 36000) await unlock(BadgeType.marathonListener);

    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 4) await unlock(BadgeType.nightOwl);
    if (hour >= 5 && hour < 7) await unlock(BadgeType.morningPerson);

    _unlockedBadges = await _db.getUnlockedBadges();
  }

  Future<void> deleteSong(Song song) async {
    if (song.id == null) return;
    await _db.deleteSong(song.id!);
    await loadAll();
  }

  Future<void> updateSong(Song song) async {
    await _db.updateSong(song);
    await loadAll();
  }
}
