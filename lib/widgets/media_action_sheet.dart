import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/song.dart';
import '../models/video.dart';
import '../models/playlist.dart';
import '../providers/media_provider.dart';
import '../theme/app_theme.dart';
import '../database/database_helper.dart';
import 'action_sheet_base.dart';

/// Contextual action sheet for a song.
Future<void> showSongActions(BuildContext context, Song song,
    {List<Song>? queue}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.modalBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _SongActionsSheet(song: song, queue: queue),
  );
}

class _SongActionsSheet extends StatelessWidget {
  final Song song;
  final List<Song>? queue;
  const _SongActionsSheet({required this.song, this.queue});

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MediaProvider>();
    final isCurrent = provider.audio.currentSong?.id == song.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Row(
                  children: [
                    ActionArtwork(seed: song.title, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                          Text(song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ActionTile(
                icon: Icons.play_arrow_rounded,
                label: 'Play',
                onTap: () {
                  Navigator.pop(context);
                  provider.playSong(song, queue: queue);
                },
              ),
              ActionTile(
                icon: Icons.playlist_play_rounded,
                label: 'Play next',
                onTap: () async {
                  Navigator.pop(context);
                  await provider.playNext(song);
                  _toast(context, 'Will play next');
                },
              ),
              ActionTile(
                icon: Icons.queue_music_rounded,
                label: 'Add to queue',
                onTap: () async {
                  Navigator.pop(context);
                  await provider.addToQueue(song);
                  _toast(context, 'Added to queue');
                },
              ),
              ActionTile(
                icon: Icons.playlist_add_rounded,
                label: 'Add to playlist',
                onTap: () async {
                  Navigator.pop(context);
                  await _pickPlaylist(context, mediaId: song.id, isSong: true);
                },
              ),
              // __CONTINUE__
              ActionTile(
                icon: song.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                label: song.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                color: song.isFavorite ? Colors.redAccent : null,
                onTap: () {
                  Navigator.pop(context);
                  provider.toggleFavorite(song);
                },
              ),
              ActionTile(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () async {
                  Navigator.pop(context);
                  await Share.share(
                      '🎵 ${song.title} — ${song.artist}\n${song.filePath}');
                },
              ),
              ActionTile(
                icon: Icons.edit_rounded,
                label: 'Edit metadata',
                onTap: () {
                  Navigator.pop(context);
                  _editSongSheet(context, song);
                },
              ),
              ActionTile(
                icon: Icons.lock_outline_rounded,
                label: song.isPrivate ? 'Unhide' : 'Hide as private',
                color: song.isPrivate ? AppTheme.accent : null,
                onTap: () {
                  Navigator.pop(context);
                  provider.setSongPrivate(song, !song.isPrivate);
                },
              ),
              if (!isCurrent)
                ActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: Colors.redAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    final ok = await confirmDelete(context, song.title);
                    if (ok && context.mounted) {
                      await provider.deleteSongFromLibrary(song);
                      _toast(context, 'Removed from library');
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
// __CONTINUE__

/// Bottom sheet that lists playlists to add the media item to (or create a
/// new one).
Future<void> _pickPlaylist(BuildContext context,
    {int? mediaId, required bool isSong}) async {
  final provider = context.read<MediaProvider>();
  final chosen = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).bottomSheetTheme.modalBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Add to playlist',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ),
          ActionTile(
            icon: Icons.add_rounded,
            label: 'New playlist',
            color: AppTheme.accent,
            onTap: () => Navigator.pop(ctx, 'new'),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final pl in provider.playlists)
                  ActionTile(
                    icon: pl.mediaType == PlaylistMedia.video
                        ? Icons.video_library_rounded
                        : Icons.queue_music_rounded,
                    label: pl.name,
                    trailing: pl.itemCountLabel,
                    onTap: () async {
                      if (isSong && mediaId != null) {
                        await provider.addSongToPlaylist(pl.id!, mediaId);
                      } else if (!isSong && mediaId != null) {
                        await provider.addVideoToPlaylist(pl.id!, mediaId);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Added to "${pl.name}"'),
                            behavior: SnackBarBehavior.floating));
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (chosen == 'new' && context.mounted) {
    final name =
        await promptText(context, 'New playlist', hint: 'Playlist name');
    if (name != null && name.trim().isNotEmpty) {
      final pl = await provider.createPlaylist(name.trim());
      if (pl?.id != null && mediaId != null) {
        if (isSong) {
          await provider.addSongToPlaylist(pl!.id!, mediaId);
        } else {
          await provider.addVideoToPlaylist(pl!.id!, mediaId);
        }
      }
    }
  }
}

/// Metadata editor for songs.
void _editSongSheet(BuildContext context, Song song) {
  final title = TextEditingController(text: song.title);
  final artist = TextEditingController(text: song.artist);
  final album = TextEditingController(text: song.album);
  final genre = TextEditingController(text: song.genre ?? '');

  Future<void> save(MediaProvider provider) async {
    final updated = song.copyWith(
      title: title.text.trim().isEmpty ? song.title : title.text.trim(),
      artist: artist.text.trim().isEmpty ? song.artist : artist.text.trim(),
      album: album.text.trim().isEmpty ? song.album : album.text.trim(),
      genre: genre.text.trim().isEmpty ? null : genre.text.trim(),
    );
    await DatabaseHelper().updateSong(updated);
    await provider.loadAll();
    if (context.mounted) Navigator.pop(context);
  }

  showDialog(
    context: context,
    builder: (ctx) => Consumer<MediaProvider>(
      builder: (ctx, provider, _) => AlertDialog(
        title: const Text('Edit metadata'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              TextField(
                  controller: artist,
                  decoration: const InputDecoration(labelText: 'Artist')),
              const SizedBox(height: 8),
              TextField(
                  controller: album,
                  decoration: const InputDecoration(labelText: 'Album')),
              const SizedBox(height: 8),
              TextField(
                  controller: genre,
                  decoration: const InputDecoration(labelText: 'Genre')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () => save(provider),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

/// Contextual action sheet for a video.
Future<void> showVideoActions(BuildContext context, Video video) {
  final provider = context.read<MediaProvider>();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.modalBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                children: [
                  ActionArtwork(seed: video.title, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                        Text(video.formattedDuration,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ActionTile(
              icon: Icons.play_arrow_rounded,
              label: 'Play',
              onTap: () {
                Navigator.pop(context);
                provider.playVideo(video);
              },
            ),
            ActionTile(
              icon: Icons.playlist_add_rounded,
              label: 'Add to playlist',
              onTap: () async {
                Navigator.pop(context);
                await _pickPlaylist(context, mediaId: video.id, isSong: false);
              },
            ),
            ActionTile(
              icon: video.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              label: video.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              color: video.isFavorite ? Colors.redAccent : null,
              onTap: () {
                Navigator.pop(context);
                provider.toggleVideoFavorite(video);
              },
            ),
            ActionTile(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: () async {
                Navigator.pop(context);
                await Share.share('🎬 ${video.title}\n${video.filePath}');
              },
            ),
            ActionTile(
              icon: Icons.lock_outline_rounded,
              label: video.isPrivate ? 'Unhide' : 'Hide as private',
              color: video.isPrivate ? AppTheme.accent : null,
              onTap: () {
                Navigator.pop(context);
                provider.setVideoPrivate(video, !video.isPrivate);
              },
            ),
            ActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: Colors.redAccent,
              onTap: () async {
                Navigator.pop(context);
                final ok = await confirmDelete(context, video.title);
                if (ok && context.mounted) {
                  await provider.deleteVideoFromLibrary(video);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Removed from library'),
                        behavior: SnackBarBehavior.floating));
                  }
                }
              },
            ),
                        const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}