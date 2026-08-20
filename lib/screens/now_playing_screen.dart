import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/control_center_sheet.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaProvider>(builder: (context, provider, _) {
      final audio = provider.audio;
      final song = audio.currentSong;
      if (song == null) {
        return Scaffold(
          backgroundColor: AppTheme.deep,
          body: Center(child: Text('No song playing',
              style: TextStyle(color: AppTheme.textSecondary))),
        );
      }
      return StreamBuilder<PlayerState>(
        stream: audio.player.playerStateStream,
        initialData: audio.player.playerState,
        builder: (context, snapshot) {
          final playing = snapshot.data?.playing ?? false;
          void seekTo(Duration d) => audio.seek(d);
          return Scaffold(
            backgroundColor: AppTheme.deep,
            body: SafeArea(
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                                            icon: Icon(Icons.arrow_back_rounded,
                          color: AppTheme.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Artwork(seed: song.title, size: 260, radius: 24,
                          subtitle: song.artist),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(song.title, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text(song.artist, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 16),
                        _SeekBar(player: audio.player),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                    IconButton(icon: Icon(Icons.replay_10_rounded, size: 26, color: AppTheme.textPrimary),
                              onPressed: () {
                                final target = audio.player.position - const Duration(seconds: 10);
                                seekTo(target >= Duration.zero ? target : Duration.zero);
                              }),
                          const SizedBox(width: 24),
                          IconButton(icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30, color: AppTheme.textPrimary),
                              onPressed: () => playing ? audio.pause() : audio.play()),
                          const SizedBox(width: 24),
                                                    IconButton(icon: Icon(Icons.forward_10_rounded, size: 26, color: AppTheme.textPrimary),
                              onPressed: () {
                                final max = audio.player.duration ?? Duration.zero;
                                final target = audio.player.position + const Duration(seconds: 10);
                                seekTo(target <= max ? target : max);
                              }),
                        ]),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _quick('Queue', Icons.queue_music_rounded, () => showQueueSheet(context)),
                          _quick('Controls', Icons.speed_rounded, () => showControlCenter(context)),
                          _quick('Favorite', Icons.favorite_rounded, () => provider.toggleFavorite(song)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _quick(String label, IconData icon, VoidCallback onTap) => Expanded(
        child: TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: AppTheme.textSecondary, size: 20),
          label: Text(label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ),
            );
}

/// A reactive seek bar driven by the just_audio position/duration streams.
class _SeekBar extends StatelessWidget {
  final AudioPlayer player;
  const _SeekBar({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      initialData: player.position,
      builder: (context, posSnap) {
        return StreamBuilder<Duration?>(
          stream: player.durationStream,
          initialData: player.duration,
          builder: (context, durSnap) {
            final duration = (durSnap.data?.inSeconds ?? 0).toDouble();
            final position =
                (posSnap.data ?? Duration.zero).inSeconds.toDouble();
            final max = duration > 0 ? duration : 1.0;
            final value = position >= max ? max - 0.0001 : position;
                        return Slider(
              value: value,
              max: max,
              activeColor: AppTheme.accent,
              inactiveColor: AppTheme.textSecondary.withValues(alpha: 0.25),
              thumbColor: AppTheme.accent,
              onChanged: (_) {},
              onChangeEnd: (v) => player.seek(Duration(seconds: v.round())),
            );
                    },
        );
      },
    );
  }
}
