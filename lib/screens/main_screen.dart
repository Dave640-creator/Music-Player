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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _didRescan = false;
  MusicProvider? _provider;
  bool _isInitializing = true;

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
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = Provider.of<MusicProvider>(context, listen: false);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _provider?.init();
    } catch (e) {
      debugPrint('MainScreen initialization failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_didRescan) {
      _didRescan = true;
      Future.microtask(() {
        if (!mounted) return;
        _provider?.scanDevice();
      });
    }
    if (state == AppLifecycleState.paused) {
      _didRescan = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

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
                  return StreamBuilder<Duration?>(
                    stream: audioService.durationStream,
                    builder: (context, durationSnapshot) {
                      return StreamBuilder<Duration>(
                        stream: audioService.positionStream,
                        builder: (context, positionSnapshot) {
                          final duration = durationSnapshot.data;
                          final position =
                              positionSnapshot.data ?? Duration.zero;
                          final progress =
                              duration == null || duration.inMilliseconds == 0
                                  ? 0.0
                                  : position.inMilliseconds /
                                      duration.inMilliseconds;
                          return MiniPlayer(
                            song: song,
                            isPlaying: isPlaying,
                            progress: progress,
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
                      );
                    },
                  );
                },
              ),
              // Bottom navigation
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  border: Border(
                    top:
                        BorderSide(color: Colors.white.withValues(alpha: 0.06)),
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
                      selectedIcon:
                          Icon(Icons.favorite_rounded, color: AppTheme.accent),
                      label: 'Favorites',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon:
                          Icon(Icons.bar_chart_rounded, color: AppTheme.accent),
                      label: 'Analytics',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon:
                          Icon(Icons.settings_rounded, color: AppTheme.accent),
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
