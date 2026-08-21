import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/song.dart';
import 'now_playing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openNowPlaying() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => context.read<MusicProvider>().loadAll(),
          ),
        ],
      ),
      body: Consumer<MusicProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildSearchBar(provider),
              _buildSortRow(provider),
              if (provider.searchQuery.isEmpty && provider.rawSongs.isNotEmpty)
                _buildForYou(provider),
              if (provider.isScanning) _buildScanProgress(provider),
              if (provider.isLoading && !provider.isScanning)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                )
              else if (provider.allSongs.isEmpty && !provider.isScanning)
                Expanded(child: _buildEmptyState(context, provider))
              else
                Expanded(child: _buildSongList(provider)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        onPressed: () => _showImportOptions(context),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Import', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildSearchBar(MusicProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: provider.setSearch,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search songs, artists, albums...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    provider.setSearch('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSortRow(MusicProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: SortBy.values.map((sort) {
          final isSelected = provider.sortBy == sort;
          final label = {
            SortBy.recentlyAdded: 'Recent',
            SortBy.title: 'Title',
            SortBy.artist: 'Artist',
            SortBy.mostPlayed: 'Most Played',
          }[sort]!;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => provider.setSortBy(sort),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.accentGradient : null,
                  color: isSelected ? null : AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScanProgress(MusicProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  provider.scanTotal > 0
                      ? 'Scanning... ${provider.scanProgress}/${provider.scanTotal} files'
                      : 'Scanning device for music...',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
          if (provider.scanTotal > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: provider.scanProgress / provider.scanTotal,
                backgroundColor: AppTheme.surfaceDark,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                minHeight: 4,
              ),
            ),
          ],
          if (provider.scanResult.detected > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${provider.scanResult.detected} detected  |  '
              '${provider.scanResult.imported} new  |  '
              '${provider.scanResult.updated} updated  |  '
              '${provider.scanResult.alreadyImported} unchanged',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForYou(MusicProvider provider) {
    final songs = provider.getRecommendedSongs();
    if (songs.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 126,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'For You',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: songs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final song = songs[index];
                return SizedBox(
                  width: 150,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      provider.playSong(song, queue: songs);
                      _openNowPlaying();
                    },
                    child: Ink(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            song.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.auto_awesome_rounded,
                            color: song.isFavorite
                                ? AppTheme.accentSecondary
                                : AppTheme.accent,
                            size: 18,
                          ),
                          const Spacer(),
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, MusicProvider provider) {
    final hasQuery = provider.searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasQuery ? Icons.search_off_rounded : Icons.music_off_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery ? 'No Results' : 'No Music Yet',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term'
                  : 'Tap Import to scan your device\nor pick music files manually',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: provider.scanDevice,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Scan Device'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      side: const BorderSide(color: AppTheme.accent),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final songs = await provider.importFromPicker();
                      if (songs.isEmpty && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No files selected'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Pick Files'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSongList(MusicProvider provider) {
    final songs = provider.allSongs;
    final currentSong = provider.audioService.currentSong;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isPlaying = currentSong?.id == song.id;
        return SongTile(
          song: song,
          isPlaying: isPlaying,
          onTap: () {
            provider.playSong(song);
            _openNowPlaying();
          },
          onFavorite: () => provider.toggleFavorite(song),
          onMore: () => _showSongOptions(context, song, provider),
        );
      },
    );
  }

  void _showSongOptions(
      BuildContext context, Song song, MusicProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      song.title.isNotEmpty ? song.title[0] : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(song.artist,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading:
                const Icon(Icons.playlist_add_rounded, color: AppTheme.accent),
            title: const Text('Add to Playlist'),
            onTap: () {
              Navigator.pop(ctx);
              _showAddToPlaylist(context, song, provider);
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.mood_rounded, color: AppTheme.accentTertiary),
            title: const Text('Tag Mood'),
            trailing: song.moodTag != null
                ? Text(_moodEmoji(song.moodTag!),
                    style: const TextStyle(fontSize: 20))
                : null,
            onTap: () {
              Navigator.pop(ctx);
              _showMoodPicker(context, song, provider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
            title: const Text('Remove from Library',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDelete(context, song, provider);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Song song, MusicProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Remove Song'),
        content: Text(
            'Remove "${song.title}" from your library? The file on disk will NOT be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteSong(song);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylist(
      BuildContext context, Song song, MusicProvider provider) {
    final manualPlaylists =
        provider.playlists.where((p) => !p.isAutoGenerated).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
                color: Colors.white12, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Add to Playlist',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ),
          if (manualPlaylists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No playlists yet. Create one first!',
                  style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ...manualPlaylists.map((p) => ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.queue_music_rounded,
                        color: AppTheme.accent, size: 20),
                  ),
                  title: Text(p.name),
                  subtitle: Text(p.songCount,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                  onTap: () async {
                    await provider.addSongToPlaylist(p.id!, song.id!);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Added to ${p.name}'),
                        backgroundColor: AppTheme.accent,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showMoodPicker(
      BuildContext context, Song song, MusicProvider provider) {
    final moods = ['happy', 'sad', 'focus', 'chill', 'workout'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
                color: Colors.white12, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Tag Mood',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...moods.map((mood) {
                  final isSelected = song.moodTag == mood;
                  final color = AppTheme.moodColors[mood]!;
                  return GestureDetector(
                    onTap: () async {
                      await provider.tagSongMood(
                          song, isSelected ? null : mood);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.25)
                            : AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(30),
                        border: isSelected
                            ? Border.all(color: color, width: 1.5)
                            : Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '${_moodEmoji(mood)} ${mood[0].toUpperCase()}${mood.substring(1)}',
                        style: TextStyle(
                          color: isSelected ? color : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }),
                if (song.moodTag != null)
                  GestureDetector(
                    onTap: () async {
                      await provider.tagSongMood(song, null);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 11),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text('✕ Clear',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImportOptions(BuildContext context) {
    final provider = context.read<MusicProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
                color: Colors.white12, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Import Music',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ),
          _importTile(
            ctx,
            icon: Icons.search_rounded,
            color: AppTheme.accent,
            title: 'Auto-scan Device',
            subtitle: 'Find all MP3, WAV, M4A, FLAC, OGG files',
            onTap: () {
              Navigator.pop(ctx);
              provider.scanDevice();
            },
          ),
          _importTile(
            ctx,
            icon: Icons.folder_open_rounded,
            color: AppTheme.accentSecondary,
            title: 'Pick Files',
            subtitle: 'Manually select audio files',
            onTap: () async {
              Navigator.pop(ctx);
              final songs = await provider.importFromPicker();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(songs.isEmpty
                      ? 'No files imported'
                      : '${songs.length} songs imported'),
                  backgroundColor:
                      songs.isEmpty ? AppTheme.cardDark : AppTheme.accent,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _importTile(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      onTap: onTap,
    );
  }

  String _moodEmoji(String mood) {
    const m = {
      'happy': '😊',
      'sad': '😔',
      'focus': '📚',
      'chill': '😌',
      'workout': '💪',
    };
    return m[mood] ?? '🎵';
  }
}
