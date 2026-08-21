import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';
import 'playlist_screen.dart';
import 'favorites_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'now_playing_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    PlaylistScreen(),
    FavoritesScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  void _openNowPlaying() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Consumer<MusicProvider>(
        builder: (context, provider, _) {
          final audioService = provider.audioService;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini player — shown only when something is loaded
              StreamBuilder<PlayerState>(
                stream: audioService.playerStateStream,
                builder: (context, snapshot) {
                  final song = audioService.currentSong;
                  if (song == null) return const SizedBox.shrink();

                  final isPlaying = snapshot.data?.playing ?? false;
                  return MiniPlayer(
                    song: song,
                    isPlaying: isPlaying,
                    onTap: _openNowPlaying,
                    onPlayPause: () {
                      if (isPlaying) {
                        audioService.pause();
                      } else {
                        audioService.play();
                      }
                    },
                    onNext: () => audioService.next(),
                  );
                },
              ),
              // Bottom navigation
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _currentIndex = i),
                  indicatorColor: AppTheme.accent.withValues(alpha: 0.18),
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.library_music_outlined),
                      selectedIcon: Icon(Icons.library_music_rounded,
                          color: AppTheme.accent),
                      label: 'Library',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.queue_music_outlined),
                      selectedIcon: Icon(Icons.queue_music_rounded,
                          color: AppTheme.accent),
                      label: 'Playlists',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.favorite_outline_rounded),
                      selectedIcon: Icon(Icons.favorite_rounded,
                          color: AppTheme.accent),
                      label: 'Favorites',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart_rounded,
                          color: AppTheme.accent),
                      label: 'Analytics',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded,
                          color: AppTheme.accent),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
