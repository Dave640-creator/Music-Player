import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../services/audio_player_service.dart';
import '../models/repeat_mode.dart';
import '../theme/app_theme.dart';
import '../models/song.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final audioService = context.read<MusicProvider>().audioService;

    audioService.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing;
      if (playing && !_wasPlaying) {
        _rotateController.repeat();
        _wasPlaying = true;
      } else if (!playing && _wasPlaying) {
        _rotateController.stop();
        _wasPlaying = false;
      }
    });

    if (audioService.isPlaying) {
      _rotateController.repeat();
      _wasPlaying = true;
    }
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, _) {
        final audioService = provider.audioService;

        return StreamBuilder<PlayerState>(
          stream: audioService.playerStateStream,
          builder: (context, playerSnapshot) {
            final song = audioService.currentSong;
            if (song == null) {
              return Scaffold(
                backgroundColor: AppTheme.primaryDark,
                appBar: AppBar(
                  backgroundColor: AppTheme.primaryDark,
                  leading: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 32, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                body: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off_rounded,
                          color: AppTheme.textSecondary, size: 64),
                      SizedBox(height: 16),
                      Text('Nothing playing',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 16)),
                    ],
                  ),
                ),
              );
            }

            final isPlaying = playerSnapshot.data?.playing ?? false;

            return Scaffold(
              backgroundColor: AppTheme.primaryDark,
              body: Stack(
                children: [
                  _buildBackground(song),
                  SafeArea(
                    child: Column(
                      children: [
                        _buildTopBar(context, audioService),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                const SizedBox(height: 24),
                                _buildAlbumArt(song, isPlaying),
                                const SizedBox(height: 36),
                                _buildSongInfo(context, song, provider),
                                const SizedBox(height: 28),
                                _buildProgressBar(audioService),
                                const SizedBox(height: 20),
                                _buildControls(audioService, isPlaying),
                                const SizedBox(height: 20),
                                _buildVolumeBar(audioService),
                                const SizedBox(height: 16),
                                _buildQueuePreview(audioService),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBackground(Song song) {
    final colors = [
      AppTheme.accent,
      AppTheme.accentSecondary,
      AppTheme.accentTertiary,
      const Color(0xFFFF9500),
      const Color(0xFF34C759),
      const Color(0xFFAF52DE),
    ];
    final color = colors[song.title.hashCode.abs() % colors.length];
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.1,
            colors: [color.withValues(alpha: 0.25), AppTheme.primaryDark],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AudioPlayerService audioService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 32, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'NOW PLAYING',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.timer_outlined, color: Colors.white, size: 22),
            onPressed: () => _showSleepTimer(context, audioService),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(Song song, bool isPlaying) {
    final gradient = _getSongGradient(song);
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) => Transform.scale(
          scale: isPlaying ? _pulseAnim.value : 1.0,
          child: child,
        ),
        child: RotationTransition(
          turns: _rotateController,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.4),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                child: song.artworkPath != null && song.artworkPath!.isNotEmpty
                    ? ClipOval(
                        child: Image.file(
                          File(song.artworkPath!),
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _artworkFallback(song),
                        ),
                      )
                    : _artworkFallback(song),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _artworkFallback(Song song) {
    return Center(
      child: Text(
        song.title.isNotEmpty ? song.title[0].toUpperCase() : '♪',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  LinearGradient _getSongGradient(Song song) {
    const gradients = [
      LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFFF6B9D)]),
      LinearGradient(colors: [Color(0xFFFF6B9D), Color(0xFFFF9500)]),
      LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF6C63FF)]),
      LinearGradient(colors: [Color(0xFFFF9500), Color(0xFFFF6B9D)]),
      LinearGradient(colors: [Color(0xFFAF52DE), Color(0xFF00D4AA)]),
      LinearGradient(colors: [Color(0xFF34C759), Color(0xFF6C63FF)]),
    ];
    return gradients[song.title.hashCode.abs() % gradients.length];
  }

  Widget _buildSongInfo(
      BuildContext context, Song song, MusicProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  song.album != 'Unknown Album'
                      ? '${song.artist} • ${song.album}'
                      : song.artist,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => provider.toggleFavorite(song),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                song.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                key: ValueKey(song.isFavorite),
                color: song.isFavorite
                    ? AppTheme.accentSecondary
                    : AppTheme.textSecondary,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(AudioPlayerService audioService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<Duration?>(
        stream: audioService.durationStream,
        builder: (context, durationSnap) {
          final duration = durationSnap.data ?? Duration.zero;
          return StreamBuilder<Duration>(
            stream: audioService.positionStream,
            builder: (context, posSnap) {
              final position = posSnap.data ?? Duration.zero;
              final progress = duration.inMilliseconds > 0
                  ? (position.inMilliseconds / duration.inMilliseconds)
                      .clamp(0.0, 1.0)
                  : 0.0;

              return Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: AppTheme.accent,
                      inactiveTrackColor: Colors.white10,
                      thumbColor: Colors.white,
                      overlayColor: AppTheme.accent.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: progress.toDouble(),
                      onChanged: (value) {
                        final newPos = Duration(
                          milliseconds:
                              (value * duration.inMilliseconds).round(),
                        );
                        audioService.seek(newPos);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmtDuration(position),
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                        Text(_fmtDuration(duration),
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildControls(AudioPlayerService audioService, bool isPlaying) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.shuffle_rounded,
            isActive: audioService.isShuffle,
            size: 22,
            onTap: () {
              audioService.toggleShuffle();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded,
                color: Colors.white, size: 38),
            onPressed: audioService.previous,
          ),
          GestureDetector(
            onTap: () {
              if (isPlaying) {
                audioService.pause();
              } else {
                audioService.play();
              }
            },
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded,
                color: Colors.white, size: 38),
            onPressed: audioService.next,
          ),
          // PlayerRepeatMode is now imported from models/repeat_mode.dart — no ambiguity
          _ControlButton(
            icon: audioService.repeatMode == PlayerRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            isActive: audioService.repeatMode != PlayerRepeatMode.none,
            size: 22,
            onTap: () {
              audioService.cycleRepeatMode();
              setState(() {});
            },
          ),
          _ControlButton(
            icon: Icons.radio_rounded,
            isActive: false,
            size: 22,
            onTap: () async {
              final song = audioService.currentSong;
              if (song == null || !context.mounted) return;
              await context.read<MusicProvider>().startRadio(song);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeBar(AudioPlayerService audioService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          const Icon(Icons.volume_down_rounded,
              color: AppTheme.textSecondary, size: 18),
          Expanded(
            child: StreamBuilder<double>(
              stream: audioService.volumeStream,
              builder: (context, snap) {
                final vol = snap.data ?? 1.0;
                return SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    activeTrackColor: AppTheme.textSecondary,
                    inactiveTrackColor: Colors.white10,
                    thumbColor: AppTheme.textSecondary,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: vol.clamp(0.0, 1.0),
                    onChanged: audioService.setVolume,
                  ),
                );
              },
            ),
          ),
          const Icon(Icons.volume_up_rounded,
              color: AppTheme.textSecondary, size: 18),
        ],
      ),
    );
  }

  Widget _buildQueuePreview(AudioPlayerService audioService) {
    if (audioService.queue.isEmpty) return const SizedBox.shrink();
    final queue = audioService.queue;
    final currentIdx = audioService.currentIndex;
    final nextIdx = (currentIdx + 1) % queue.length;
    if (nextIdx == currentIdx) return const SizedBox.shrink();
    final next = queue[nextIdx];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: GestureDetector(
        onTap: () => _showQueueSheet(context, audioService),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.queue_music_rounded,
                  color: AppTheme.textSecondary, size: 16),
              const SizedBox(width: 10),
              const Text('Next: ',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Expanded(
                child: Text(
                  '${next.title} - ${next.artist}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueueSheet(BuildContext context, AudioPlayerService audioService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final queue = audioService.queue;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Queue',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: queue.length < 2
                            ? null
                            : () async {
                                await audioService.clearQueue();
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              },
                        child: const Text('Clear'),
                      ),
                      IconButton(
                        tooltip: 'Save queue as playlist',
                        icon: const Icon(Icons.playlist_add_rounded),
                        onPressed: queue.isEmpty
                            ? null
                            : () => _showSaveQueueDialog(
                                sheetContext, audioService),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: queue.length,
                    onReorderItem: (oldIndex, newIndex) {
                      audioService.reorderQueue(oldIndex, newIndex);
                      setSheetState(() {});
                    },
                    itemBuilder: (_, index) {
                      final song = queue[index];
                      final isCurrent = index == audioService.currentIndex;
                      return ListTile(
                        key: ValueKey('${song.id}-${song.filePath}'),
                        leading: Icon(
                          isCurrent
                              ? Icons.equalizer_rounded
                              : Icons.music_note_rounded,
                          color: isCurrent
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                        ),
                        title: Text(song.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(song.artist,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: isCurrent
                            ? const SizedBox(width: 48)
                            : IconButton(
                                tooltip: 'Remove from queue',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () async {
                                  await audioService.removeFromQueue(index);
                                  setSheetState(() {});
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showSaveQueueDialog(
      BuildContext context, AudioPlayerService audioService) {
    final controller = TextEditingController(text: 'My Queue');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Save Queue as Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await context.read<MusicProvider>().saveQueueAsPlaylist(name);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Saved "$name" as a playlist')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() {
      controller.dispose();
    });
  }

  void _showSleepTimer(BuildContext context, AudioPlayerService audioService) {
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
            child: Text(
              'Sleep Timer',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (audioService.sleepTimerRemaining != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Stops in ${audioService.sleepTimerRemaining!.inMinutes}m '
                '${audioService.sleepTimerRemaining!.inSeconds % 60}s',
                style: const TextStyle(
                    color: AppTheme.accentTertiary, fontSize: 13),
              ),
            ),
          ...[15, 30, 60].map((min) => ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timer_outlined,
                      color: AppTheme.accent, size: 20),
                ),
                title: Text('$min minutes'),
                onTap: () {
                  audioService.setSleepTimer(min);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Sleep timer: $min minutes'),
                    backgroundColor: AppTheme.accent,
                    behavior: SnackBarBehavior.floating,
                  ));
                },
              )),
          if (audioService.sleepTimerRemaining != null)
            ListTile(
              leading:
                  const Icon(Icons.timer_off_outlined, color: Colors.redAccent),
              title: const Text('Cancel Timer',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                audioService.cancelSleepTimer();
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.isActive,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? AppTheme.accent : AppTheme.textSecondary,
              size: size),
          if (isActive)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 3),
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
