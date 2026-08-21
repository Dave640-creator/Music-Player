import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'now_playing_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<MusicProvider>(
        builder: (context, provider, _) {
          final songCount = provider.rawSongs.length;
          final playlistCount = provider.playlists.length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section('Library', [
                _tile(
                  icon: Icons.search_rounded,
                  color: AppTheme.accent,
                  title: 'Scan Device',
                  subtitle: '$songCount song${songCount != 1 ? 's' : ''} in library',
                  onTap: () => provider.scanDevice(),
                ),
                _tile(
                  icon: Icons.folder_open_rounded,
                  color: AppTheme.accentSecondary,
                  title: 'Import Files',
                  subtitle: 'Pick audio files manually',
                  onTap: () async {
                    final songs = await provider.importFromPicker();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(songs.isEmpty
                            ? 'No files imported'
                            : '${songs.length} songs added'),
                        backgroundColor: songs.isEmpty
                            ? AppTheme.cardDark
                            : AppTheme.accent,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                ),
              ]),

              const SizedBox(height: 16),

              _section('Smart Playlists', [
                _tile(
                  icon: Icons.auto_fix_high_rounded,
                  color: AppTheme.accentTertiary,
                  title: 'Generate Auto Playlists',
                  subtitle: 'Study, Workout, Chill, Happy, Sad, Top 10',
                  onTap: () async {
                    await provider.generateAutoPlaylists();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Smart playlists generated!'),
                          backgroundColor: AppTheme.accentTertiary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ]),

              const SizedBox(height: 16),

              _section('Organization', [
                _tile(
                  icon: Icons.people_alt_rounded,
                  color: AppTheme.accentSecondary,
                  title: 'Browse by Artist',
                  subtitle: 'All songs grouped by artist',
                  onTap: () => _showByArtist(context, provider),
                ),
                _tile(
                  icon: Icons.album_rounded,
                  color: AppTheme.accentTertiary,
                  title: 'Browse by Album',
                  subtitle: 'All songs grouped by album',
                  // BUG FIX: now correctly calls getSongsByAlbum not getSongsByArtist
                  onTap: () => _showByAlbum(context, provider),
                ),
                _tile(
                  icon: Icons.content_copy_rounded,
                  color: Colors.orangeAccent,
                  title: 'Find Duplicates',
                  subtitle: 'Detect songs with same title',
                  onTap: () => _showDuplicates(context, provider),
                ),
              ]),

              const SizedBox(height: 16),

              _section('Mood Player', [
                _tile(
                  icon: Icons.mood_rounded,
                  color: AppTheme.moodColors['happy']!,
                  title: 'Play by Mood',
                  subtitle: 'Happy · Sad · Focus · Chill · Workout',
                  onTap: () => _showMoodPlayer(context, provider),
                ),
              ]),

              const SizedBox(height: 16),

              _section('About', [
                _tile(
                  icon: Icons.info_outline_rounded,
                  color: AppTheme.textSecondary,
                  title: 'Smart Music Player',
                  subtitle: 'v1.0.0 — Offline music with analytics',
                  onTap: null,
                ),
                _tile(
                  icon: Icons.storage_rounded,
                  color: AppTheme.textSecondary,
                  title: 'Library Stats',
                  subtitle:
                      '$songCount songs  •  $playlistCount playlists',
                  onTap: null,
                ),
              ]),

              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12)),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded,
              color: AppTheme.textSecondary)
          : null,
      onTap: onTap,
    );
  }

  // BUG FIX: _showByAlbum now uses getSongsByAlbum()
  void _showByAlbum(BuildContext context, MusicProvider provider) async {
    final byAlbum = await provider.getSongsByAlbum();
    if (!context.mounted) return;
    _showGroupedBrowser(
      context: context,
      provider: provider,
      title: 'Browse by Album',
      icon: Icons.album_rounded,
      grouped: byAlbum,
      gradient: [AppTheme.accentTertiary, AppTheme.accent],
    );
  }

  void _showByArtist(BuildContext context, MusicProvider provider) async {
    final byArtist = await provider.getSongsByArtist();
    if (!context.mounted) return;
    _showGroupedBrowser(
      context: context,
      provider: provider,
      title: 'Browse by Artist',
      icon: Icons.people_alt_rounded,
      grouped: byArtist,
      gradient: [AppTheme.accentSecondary, AppTheme.accent],
    );
  }

  void _showGroupedBrowser({
    required BuildContext context,
    required MusicProvider provider,
    required String title,
    required IconData icon,
    required Map<String, List<Song>> grouped,
    required List<Color> gradient,
  }) {
    final sortedKeys = grouped.keys.toList()..sort();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${sortedKeys.length} groups',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            grouped.isEmpty
                ? const Expanded(
                    child: Center(
                      child: Text('No songs in library yet',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: sortedKeys.length,
                      itemBuilder: (_, i) {
                        final key = sortedKeys[i];
                        final songs = grouped[key]!;
                        return ListTile(
                          leading: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: gradient),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                key.isNotEmpty
                                    ? key[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18),
                              ),
                            ),
                          ),
                          title: Text(key,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500)),
                          trailing: Text(
                            '${songs.length} song${songs.length != 1 ? 's' : ''}',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            provider.audioService.setQueue(songs);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const NowPlayingScreen()),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showDuplicates(
      BuildContext context, MusicProvider provider) async {
    final dups = await provider.findDuplicates();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                dups.isEmpty
                    ? 'No Duplicates Found'
                    : '${dups.length} Duplicate${dups.length != 1 ? 's' : ''} Found',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            dups.isEmpty
                ? const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🎉', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('Your library is clean!',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: dups.length,
                      itemBuilder: (_, i) => SongTile(
                        song: dups[i],
                        onTap: () {},
                        onMore: () {
                          provider.deleteSong(dups[i]);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('"${dups[i].title}" removed'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showMoodPlayer(BuildContext context, MusicProvider provider) {
    final moods = [
      {'key': 'happy', 'label': '😊 Happy', 'desc': 'Feel-good bangers'},
      {'key': 'sad', 'label': '😔 Sad', 'desc': 'Rainy day melodies'},
      {'key': 'focus', 'label': '📚 Focus', 'desc': 'Deep work music'},
      {'key': 'chill', 'label': '😌 Chill', 'desc': 'Relax and unwind'},
      {'key': 'workout', 'label': '💪 Workout', 'desc': 'High energy tracks'},
    ];

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
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("How are you feeling?",
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ),
          ...moods.map((m) {
            final color = AppTheme.moodColors[m['key']]!;
            return ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(m['label']!.split(' ').first,
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              title: Text(m['label']!.split(' ').last,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600)),
              subtitle: Text(m['desc']!,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              onTap: () async {
                final songs =
                    await provider.getSongsByMood(m['key']!);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (songs.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'No ${m['key']} songs tagged yet. Tag songs from the library first!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppTheme.cardDark,
                      ),
                    );
                  }
                } else {
                  provider.audioService.setQueue(songs);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NowPlayingScreen()),
                    );
                  }
                }
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
