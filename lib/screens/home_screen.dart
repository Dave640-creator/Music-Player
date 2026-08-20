import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/control_center_sheet.dart';
import 'now_playing_screen.dart';
import 'discover_tab.dart';
import 'library_tab.dart';
import 'me_tab.dart';

/// Root screen for the Mosaic Player experience (DISCOVER → LIBRARY → ME).
///
/// The bottom navigation switches between the three persistent sections; the
/// PLAYER surface is reached from the mini-player bar (→ [NowPlayingScreen])
/// and from contextual action sheets. The mini-player bar itself docks over
/// the tab content so playback is always one tap away.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
    static const List<BottomNavigationBarItem> _destinations = [
    BottomNavigationBarItem(
        icon: Icon(Icons.explore_rounded), label: 'Discover'),
    BottomNavigationBarItem(
        icon: Icon(Icons.library_music_rounded), label: 'Library'),
    BottomNavigationBarItem(
        icon: Icon(Icons.person_rounded), label: 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [const DiscoverTab(), const LibraryTab(), const MeTab()];
    return Scaffold(
      body: Stack(children: [
        pages[_tab],
        const Align(
            alignment: Alignment.bottomCenter, child: _MiniPlayer()),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: AppTheme.textSecondary,
        items: _destinations,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

/// Persistent mini-player bar docked above the navigation bar.
class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MediaProvider>();
    final audio = p.audio;
    final song = audio.currentSong;
    if (song == null || !audio.hasQueue) return const SizedBox.shrink();

    return StreamBuilder<PlayerState>(
      stream: audio.player.playerStateStream,
      builder: (context, snap) {
        final playing = snap.hasData && snap.data!.playing;
        final durationSec = audio.player.duration?.inSeconds ?? 0;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
                bottom: 72 + MediaQuery.of(context).viewInsets.bottom),
            child: Material(
              elevation: 16,
              color: AppTheme.surfaceRaised,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              child: Row(children: [
                const SizedBox(width: 12),
                Artwork(seed: song.title, size: 44, radius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      Text(song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                StreamBuilder<Duration>(
                  stream: audio.player.positionStream,
                  initialData: audio.player.position,
                  builder: (context, s) {
                    final pos = s.data?.inSeconds ?? 0;
                    final fraction = durationSec > 0 ? pos / durationSec : 0.0;
                    return SizedBox(
                      width: 40,
                      child: LinearProgressIndicator(
                          value: fraction.clamp(0.0, 1.0),
                          backgroundColor: Colors.white10,
                          color: AppTheme.accent),
                    );
                  },
                ),
                IconButton(
                    icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppTheme.accent),
                    onPressed: () =>
                        playing ? audio.pause() : audio.play()),
                IconButton(
                    icon: Icon(Icons.queue_music_rounded,
                        color: AppTheme.textSecondary),
                    onPressed: () => showQueueSheet(context)),
                IconButton(
                    icon: Icon(Icons.speed_rounded,
                        color: AppTheme.textSecondary),
                    onPressed: () => showControlCenter(context)),
                IconButton(
                                        icon: Icon(Icons.keyboard_arrow_up_rounded,
                        color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NowPlayingScreen()))),
                const SizedBox(width: 8),
              ]),
            ),
          ),
        );
      },
    );
  }
}
