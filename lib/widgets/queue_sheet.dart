import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/media_provider.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';
import 'action_sheet_base.dart';
import 'components.dart';

/// Smart queue bottom sheet: NOW PLAYING + UP NEXT with drag-to-reorder,
/// remove, save-as-playlist and clear actions.
Future<void> showQueueSheet(BuildContext context) {
  final provider = context.read<MediaProvider>();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.modalBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _QueueSheet(provider: provider),
  );
}

class _QueueSheet extends StatefulWidget {
  final MediaProvider provider;
  const _QueueSheet({required this.provider});

  @override
  State<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<_QueueSheet> {
  AudioPlayerService get audio => widget.provider.audio;

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final queue = List<Song>.from(audio.queue);
    final current = audio.currentSong;
    final upNext = audio.upNext;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
                if (queue.isEmpty) {
                    return const Column(
            children: [
              SheetHandle(),
              Expanded(
                child: EmptyState(
                  icon: Icons.queue_music_rounded,
                  title: 'Queue is empty',
                  message:
                      'Play something from your library and it will appear here.',
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Queue',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final name = await promptText(context, 'Save queue',
                          hint: 'Playlist name', initial: 'My queue');
                      if (name != null && name.trim().isNotEmpty) {
                        await widget.provider.saveQueueAsPlaylist(name.trim());
                        if (mounted) _toast('Saved as "$name"');
                      }
                    },
                    icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                    label: const Text('Save'),
                  ),
                  TextButton(
                                                            onPressed: () async {
                      final navigator = Navigator.of(context);
                      await audio.clearQueue();
                      if (!mounted) return;
                      navigator.pop();
                    },
                    child: const Text('Clear',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (current != null)
              _currentRow(current)
            else
              const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: upNext.length + 1,
                                onReorderItem: _onReorder,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      key: const ValueKey('upnext-header'),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                      child: Text(
                        'UP NEXT · ${upNext.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    );
                  }
                  final listIndex = index - 1;
                  final song = upNext[listIndex];
                  final queueIndex = audio.currentIndex + 1 + listIndex;
                  return _upNextRow(song, queueIndex, listIndex);
                },
              ),
            ),
                    ],
        );
      },
    );
  }

  Widget _currentRow(Song current) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.accent.withValues(alpha: 0.16),
          AppTheme.accent.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Artwork(
              imagePath: current.artworkPath,
              seed: current.title,
              size: 44,
              radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(current.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text(current.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              audio.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: AppTheme.accent,
            ),
            onPressed: () => audio.isPlaying ? audio.pause() : audio.play(),
          ),
        ],
      ),
    );
  }

  Widget _upNextRow(Song song, int queueIndex, int listIndex) {
    return Container(
      key: ValueKey('upnext-$listIndex-${song.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => audio.playAtIndex(queueIndex),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Artwork(
                        imagePath: song.artworkPath,
                        seed: song.title,
                        size: 40,
                        radius: 10),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          Text(song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Text(song.formattedDuration,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded,
                size: 18, color: AppTheme.textSecondary),
            onPressed: () async {
              await audio.removeFromQueue(queueIndex);
              setState(() {});
            },
          ),
          ReorderableDragStartListener(
            index: listIndex + 1,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle_rounded,
                  size: 18, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

    void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final base = audio.currentIndex + 1;
      audio.moveInQueue(base + oldIndex - 1, base + newIndex - 1);
    });
  }
}
