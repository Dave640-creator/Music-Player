import 'package:flutter/material.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/user_stats.dart';
import '../database/database_helper.dart';
import '../services/audio_player_service.dart';
import '../services/music_scanner_service.dart';
import '../models/library_scan_result.dart';

enum SortBy { recentlyAdded, title, artist, album, duration, mostPlayed }

class MusicProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final AudioPlayerService _audioService = AudioPlayerService();
  final MusicScannerService _scanner = MusicScannerService();
  MusicScannerService get scanner => _scanner;

  List<Song> _allSongs = [];
  List<Song> _displaySongs = [];
  List<Playlist> _playlists = [];
  List<Song> _favorites = [];
  UserStats _userStats = UserStats();
  Set<BadgeType> _unlockedBadges = {};
  Map<String, List<Song>>? _forYouCache;
  int _forYouVersion = 0;
  bool _isInitialized = false;

  bool _isLoading = false;
  bool _isScanning = false;
  int _scanProgress = 0;
  int _scanTotal = 0;
  LibraryScanResult _scanResult = const LibraryScanResult();
  String? _scanError;
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
  String? get scanError => _scanError;
  SortBy get sortBy => _sortBy;
  String get searchQuery => _searchQuery;
  AudioPlayerService get audioService => _audioService;
  int get forYouVersion => _forYouVersion;

  List<Song> getRecommendedSongs({int limit = 8}) {
    final now = DateTime.now();
    final recommendations = List<Song>.from(_allSongs)
      ..sort((a, b) {
        int score(Song song) {
          final recentDays = now.difference(song.dateAdded).inDays;
          final recency = (30 - recentDays).clamp(0, 30);
          return (song.isFavorite ? 120 : 0) +
              (song.playCount * 8) +
              (song.moodTag == null ? 0 : 6) +
              recency;
        }

        return score(b).compareTo(score(a));
      });
    return recommendations.take(limit).toList();
  }

  Future<Map<String, List<Song>>> getForYouSections() async {
    _forYouCache ??= await _loadForYouSections();
    return _forYouCache!;
  }

  Future<Map<String, List<Song>>> _loadForYouSections() async {
    final sections = <String, List<Song>>{};
    sections['For You'] = getRecommendedSongs(limit: 12);
    sections['Recently Loved'] = await getRecentlyLovedSongs(limit: 8);
    sections['You Haven\'t Heard Recently'] = await getForgottenSongs(limit: 8);
    sections['Discoveries'] = await getDiscoveries(limit: 8);
    sections['Your Favorites'] = _favorites.take(8).toList();
    sections.removeWhere((key, value) => value.isEmpty);
    return sections;
  }

  void _invalidateForYouCache() {
    _forYouCache = null;
    _forYouVersion++;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

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
    _invalidateForYouCache();
    _applyFilters();

    _isLoading = false;
    notifyListeners();
  }

  void _applyFilters() {
    List<Song> source = List.from(_allSongs);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final playlistSongIds = _playlists
          .where((playlist) => playlist.name.toLowerCase().contains(q))
          .expand((playlist) => playlist.songs)
          .map((song) => song.id)
          .toSet();
      source = source
          .where((s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q) ||
              (s.genre?.toLowerCase().contains(q) ?? false) ||
              playlistSongIds.contains(s.id))
          .toList();
    }

    switch (_sortBy) {
      case SortBy.title:
        source.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortBy.artist:
        source.sort((a, b) => a.artist.compareTo(b.artist));
        break;
      case SortBy.album:
        source.sort((a, b) => a.album.compareTo(b.album));
        break;
      case SortBy.duration:
        source.sort((a, b) => b.duration.compareTo(a.duration));
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

  Future<LibraryScanResult?> scanDevice({
    Function(int found, int total)? onProgress,
    Function(LibraryScanResult result)? onResult,
  }) async {
    _isScanning = true;
    _scanProgress = 0;
    _scanTotal = 0;
    _scanResult = const LibraryScanResult();
    _scanError = null;
    _invalidateForYouCache();
    notifyListeners();

    try {
      final hasPerms = await _scanner.hasPermission();
      if (!hasPerms && !await _scanner.requestPermissions()) {
        throw StateError('Music access permission was not granted.');
      }

      await _scanner.scanDeviceStorage(
        onProgress: onProgress ?? (found, total) {
          _scanProgress = found;
          _scanTotal = total;
          notifyListeners();
        },
        onResult: onResult ?? (result) {
          _scanResult = result;
          notifyListeners();
        },
      );
      await loadAll();
      return _scanResult;
    } catch (error) {
      _scanError = error.toString().replaceFirst('Bad state: ', '');
      return null;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<List<Song>> importFromPicker() async {
    final songs = await _scanner.importFromFilePicker();
    if (songs.isNotEmpty) {
      _invalidateForYouCache();
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

  Future<void> addToQueue(Song song) async {
    await _audioService.addToQueue(song);
    notifyListeners();
  }

  Future<void> playNext(Song song) async {
    await _audioService.playNext(song);
    notifyListeners();
  }

  Future<void> startRadio(Song seed) async {
    final history = await _db.getListeningHistory(limit: 40);
    final recentlyPlayed = history.map((entry) => entry.songId).toSet();
    final candidates = _allSongs.where((song) => song.id != seed.id).toList()
      ..sort((a, b) {
        int score(Song song) {
          var value = song.playCount * 3;
          if (song.artist.toLowerCase() == seed.artist.toLowerCase()) {
            value += 100;
          }
          if (song.genre != null && song.genre == seed.genre) value += 45;
          if (song.moodTag != null && song.moodTag == seed.moodTag) value += 25;
          if (song.isFavorite) value += 10;
          if (recentlyPlayed.contains(song.id)) value -= 35;
          return value;
        }

        return score(b).compareTo(score(a));
      });
    final queue = [seed, ...candidates.take(30)];
    await _audioService.setQueue(queue);
    notifyListeners();
  }

  // === FAVORITES ===

  Future<void> toggleFavorite(Song song) async {
    song.isFavorite = !song.isFavorite;
    await _db.toggleFavorite(song.id!, song.isFavorite);
    _favorites = await _db.getFavoriteSongs();
    final idx = _allSongs.indexWhere((s) => s.id == song.id);
    if (idx >= 0) _allSongs[idx].isFavorite = song.isFavorite;
    _applyFilters();
    _invalidateForYouCache();
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
    } catch (error) {
      debugPrint('Playlist not found after creation: $error');
      return _playlists.isNotEmpty ? _playlists.first : null;
    }
  }

  Future<void> deletePlaylist(int id) async {
    await _db.deletePlaylist(id);
    await loadAll();
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    await _db.addSongToPlaylist(playlistId, songId);
    _invalidateForYouCache();
    await loadAll();
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await _db.removeSongFromPlaylist(playlistId, songId);
    _invalidateForYouCache();
    await loadAll();
  }

  Future<Playlist?> saveQueueAsPlaylist(String name) async {
    final songs = List<Song>.from(_audioService.queue);
    if (songs.isEmpty || name.trim().isEmpty) return null;
    final playlist = await createPlaylist(name.trim());
    final playlistId = playlist?.id;
    if (playlistId == null) return null;
    for (final song in songs) {
      if (song.id != null) {
        await _db.addSongToPlaylist(playlistId, song.id!);
      }
    }
    await loadAll();
    return _playlists.firstWhere((item) => item.id == playlistId);
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
      {
        'name': 'Morning Mix',
        'mood': 'time',
        'hourStart': 6,
        'hourEnd': 12,
        'desc': 'A bright start to your day'
      },
      {
        'name': 'Focus Mix',
        'mood': 'time',
        'hourStart': 9,
        'hourEnd': 17,
        'desc': 'Music for deep concentration'
      },
      {
        'name': 'Evening Vibes',
        'mood': 'time',
        'hourStart': 18,
        'hourEnd': 23,
        'desc': 'Music for winding down'
      },
      {
        'name': 'Late Night',
        'mood': 'time',
        'hourStart': 23,
        'hourEnd': 6,
        'desc': 'A quiet late-night mix'
      },
      {
        'name': 'Workout',
        'mood': 'time_workout',
        'desc': 'High energy for your workout'
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
            name: cfg['name'] as String,
            description: cfg['desc'] as String?,
            isAutoGenerated: true,
          ));
      await _db.clearPlaylistSongs(id);

      List<Song> pSongs;
      if (cfg['mood'] == 'daily') {
        final ranked = List<Song>.from(songs)
          ..sort((a, b) {
            final aScore = (a.isFavorite ? 100 : 0) + a.playCount * 8;
            final bScore = (b.isFavorite ? 100 : 0) + b.playCount * 8;
            return bScore.compareTo(aScore);
          });
        pSongs = ranked.take(45).toList();
      } else if (cfg['mood'] == 'time_workout') {
        final ranked = List<Song>.from(songs)
          ..sort((a, b) {
            final aScore = (a.moodTag == 'workout' ? 50 : 0) +
                (a.isFavorite ? 30 : 0) +
                a.playCount * 4;
            final bScore = (b.moodTag == 'workout' ? 50 : 0) +
                (b.isFavorite ? 30 : 0) +
                b.playCount * 4;
            return bScore.compareTo(aScore);
          });
        pSongs = ranked.take(30).toList();
      } else if (cfg['mood'] == 'time') {
        final hour = DateTime.now().hour;
        final start = cfg['hourStart'] as int? ?? 0;
        final end = cfg['hourEnd'] as int? ?? 23;
        final inRange = start < end
            ? hour >= start && hour < end
            : hour >= start || hour < end;
        final preferredMoods = hour < 12
            ? {'happy', 'focus'}
            : hour < 18
                ? {'focus', 'workout'}
                : {'chill', 'sad'};
        final candidates = songs.where((song) =>
            song.moodTag != null && preferredMoods.contains(song.moodTag));
        pSongs = inRange ? candidates.toList() : songs.toList();
        pSongs = List.from(pSongs)..shuffle();
      } else if (cfg['mood'] != null) {
        pSongs = songs.where((s) => s.moodTag == cfg['mood']).toList();
        pSongs = List.from(pSongs)..shuffle();
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
    _invalidateForYouCache();
    notifyListeners();
  }

  Future<List<Song>> getSongsByMood(String mood) async {
    return await _db.getSongsByMood(mood);
  }

  // === ANALYTICS ===

  Future<List<Song>> getMostPlayedSongs({int limit = 10}) async {
    return await _db.getMostPlayedSongs(limit: limit);
  }

  Future<List<Song>> getRecentlyLovedSongs({int limit = 10}) async {
    return await _db.getRecentlyLovedSongs(limit: limit);
  }

  Future<List<Song>> getForgottenSongs({int limit = 20}) async {
    return await _db.getForgottenSongs(limit: limit);
  }

  Future<List<Song>> getDiscoveries({int limit = 15}) async {
    return await _db.getDiscoveries(limit: limit);
  }

  Future<Map<String, int>> getDailyStats(int days) async {
    return await _db.getDailyListeningStats(days);
  }

  Future<int> getListeningSecondsSince(DateTime since) async {
    return await _db.getListeningSecondsSince(since);
  }

  Future<Map<String, int>> getPlaybackEventCounts({DateTime? since}) async {
    return await _db.getPlaybackEventCounts(since: since);
  }

  Future<int?> getMostActiveListeningHour({DateTime? since}) async {
    return await _db.getMostActiveListeningHour(since: since);
  }

  Future<void> refreshBadges() async {
    await _checkBadges();
    notifyListeners();
  }

  Future<String> getFavoriteArtist() async {
    return await _db.getFavoriteArtist();
  }

  Future<List<Song>> getTopArtistsSongs({int limit = 5}) async {
    return await _db.getTopArtistsSongs(limit: limit);
  }

  Future<Map<String, int>> getGenreStats() async {
    return await _db.getGenreStats();
  }

  Future<int> getAverageSessionSeconds() async {
    return await _db.getAverageSessionSeconds();
  }

  Future<int> getTotalUniqueArtists() async {
    return await _db.getTotalUniqueArtists();
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
    final eventCounts = await _db.getPlaybackEventCounts();
    if ((eventCounts['completed'] ?? 0) >= 50) {
      await unlock(BadgeType.fiftySongsCompleted);
    }
    if (await _db.getDiscoveredArtistCount() >= 10) {
      await unlock(BadgeType.artistsDiscovered);
    }

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
