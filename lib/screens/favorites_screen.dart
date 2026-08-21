import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'now_playing_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(title: const Text('Favorites')),
      body: Consumer<MusicProvider>(
        builder: (context, provider, _) {
          final favorites = provider.favorites;

          if (favorites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppTheme.accentSecondary,
                          AppTheme.accent,
                        ]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('No Favorites Yet',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap the ♡ icon on any song to add it here',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Header bar
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppTheme.accentSecondary.withValues(alpha: 0.15),
                    AppTheme.cardDark,
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          AppTheme.accentSecondary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite_rounded,
                        color: AppTheme.accentSecondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${favorites.length} song${favorites.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        provider.audioService
                            .setQueue(favorites);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const NowPlayingScreen()),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: AppTheme.accentSecondary,
                          size: 18),
                      label: const Text('Play All',
                          style: TextStyle(
                              color: AppTheme.accentSecondary,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        final shuffled = List.of(favorites)
                          ..shuffle();
                        provider.audioService.setQueue(shuffled);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const NowPlayingScreen()),
                        );
                      },
                      icon: const Icon(Icons.shuffle_rounded,
                          color: AppTheme.textSecondary, size: 18),
                      label: const Text('Shuffle',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final song = favorites[index];
                    final isPlaying =
                        provider.audioService.currentSong?.id ==
                            song.id;
                    return SongTile(
                      song: song,
                      isPlaying: isPlaying,
                      onTap: () {
                        provider.playSong(song,
                            queue: favorites);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const NowPlayingScreen()),
                        );
                      },
                      onFavorite: () =>
                          provider.toggleFavorite(song),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
