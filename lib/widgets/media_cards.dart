import 'package:flutter/material.dart';
import '../models/song.dart';
import '../models/video.dart';
import '../models/playlist.dart';
import '../theme/app_theme.dart';
import 'components.dart';

/// A tall music card: artwork, title, artist and a quick-play button.
class MusicCard extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onMenu;
  final double width;

  const MusicCard({
    super.key,
    required this.song,
    this.isCurrent = false,
    this.isPlaying = false,
    required this.onTap,
    this.onPlay,
    this.onMenu,
    this.width = 150,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              children: [
                Artwork(
                  imagePath: song.artworkPath,
                  seed: song.title,
                  subtitle: song.artist,
                  size: width,
                  radius: 16,
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent ? AppTheme.accent : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                        color: isCurrent ? Colors.white : AppTheme.deep,
                      ),
                    ),
                  ),
                ),
                if (song.isFavorite)
                  const Positioned(
                    left: 8,
                    top: 8,
                    child: Icon(Icons.favorite_rounded,
                        size: 16, color: Colors.white),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? AppTheme.accent
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onMenu != null)
                GestureDetector(
                  onTap: onMenu,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.more_vert_rounded,
                        size: 16, color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A video card: thumbnail (or gradient), duration badge, progress bar and
/// resume button when the user left off mid-way.
class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  final VoidCallback? onMenu;
  final double width;

  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.onMenu,
    this.width = 160,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              children: [
                Artwork(
                  imagePath: video.thumbnailPath,
                  seed: video.title,
                  size: width,
                  radius: 16,
                  subtitle: 'video',
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      video.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (video.hasResumePoint)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 4,
                      color: Colors.white.withValues(alpha: 0.25),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: video.progress,
                        child: Container(color: AppTheme.accent),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        video.hasResumePoint
                            ? 'Resume · ${AppThemeHelpers.formatDuration(Duration(seconds: video.lastPosition))}'
                            : video.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: video.hasResumePoint
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                          fontWeight: video.hasResumePoint
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onMenu != null)
                GestureDetector(
                  onTap: onMenu,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.more_vert_rounded,
                        size: 16, color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An album card with a large artwork and track count.
class AlbumCard extends StatelessWidget {
  final String title;
  final String artist;
  final int trackCount;
  final int songCount;
  final VoidCallback onTap;

  const AlbumCard({
    super.key,
    required this.title,
    required this.artist,
    required this.songCount,
    required this.trackCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Artwork(seed: title, size: 140, radius: 18, subtitle: 'album'),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$trackCount · $artist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A playlist card with an artwork collage generated from its songs.
class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback? onMenu;

  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final width = 140.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Collage(width: width, playlist: playlist),
          const SizedBox(height: 8),
          Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${playlist.itemCountLabel} · ${playlist.formattedDuration}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Collage extends StatelessWidget {
  final double width;
  final Playlist playlist;

  const _Collage({required this.width, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final songs = playlist.songs;
    if (songs.isEmpty) {
      return Artwork(seed: playlist.name, size: width, radius: 18);
    }
    if (songs.length == 1) {
      return Artwork(
          imagePath: songs.first.artworkPath,
          seed: songs.first.title,
          size: width,
          radius: 18);
    }
    final size = width / 2;
    return Container(
      width: width,
      height: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.surfaceRaised,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final col in [0, 1])
            Expanded(
              child: Column(
                children: [
                  for (var row = 0; row < 2; row++) ...[
                    Expanded(
                      child: _collageArtwork(songs, row * 2 + col, size),
                    ),
                    if (row == 0) const SizedBox(height: 2),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _collageArtwork(List<Song> songs, int index, double size) {
    if (index >= songs.length) {
      return Artwork(seed: 'empty', size: size, radius: 0);
    }
    final s = songs[index];
    return Artwork(
        imagePath: s.artworkPath, seed: s.title, size: size, radius: 0);
  }
}

/// A genre card — a large rounded chip with its colour identity.
class GenreCard extends StatelessWidget {
  final String name;
  final int count;
  final VoidCallback onTap;

  const GenreCard({
    super.key,
    required this.name,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        height: 96,
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.heroCard(radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count track${count == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A folder card.
class FolderCard extends StatelessWidget {
  final String name;
  final String detail;
  final VoidCallback onTap;
  final IconData icon;

  const FolderCard({
    super.key,
    required this.name,
    required this.detail,
    required this.onTap,
    this.icon = Icons.folder_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glass(radius: 18),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// A horizontal song row used in list mode.
class SongRow extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onMenu;
  final VoidCallback? onFavorite;
  final bool showDuration;

  const SongRow({
    super.key,
    required this.song,
    this.isCurrent = false,
    this.isPlaying = false,
    required this.onTap,
    this.onMenu,
    this.onFavorite,
    this.showDuration = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppTheme.accent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Artwork(
              imagePath: song.artworkPath,
              seed: song.title,
              size: 46,
              radius: 10,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCurrent
                          ? AppTheme.accent
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isPlaying)
              Icon(Icons.graphic_eq_rounded, size: 18, color: AppTheme.accent)
            else if (showDuration)
              Text(
                song.formattedDuration,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            if (onFavorite != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onFavorite,
                child: Icon(
                  song.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  size: 18,
                  color: song.isFavorite
                      ? Colors.redAccent
                      : AppTheme.textSecondary,
                ),
              ),
            ],
            if (onMenu != null)
              GestureDetector(
                onTap: onMenu,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.more_vert_rounded,
                      size: 18, color: AppTheme.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal video row used in list mode.
class VideoRow extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  final VoidCallback? onMenu;

  const VideoRow({
    super.key,
    required this.video,
    required this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                Artwork(
                  imagePath: video.thumbnailPath,
                  seed: video.title,
                  size: 64,
                  radius: 10,
                  subtitle: 'video',
                ),
                if (video.hasResumePoint)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 3,
                      color: Colors.white.withValues(alpha: 0.3),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: video.progress,
                        child: Container(color: AppTheme.accent),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    video.hasResumePoint
                        ? '${video.formattedDuration} · resume at ${AppThemeHelpers.formatDuration(Duration(seconds: video.lastPosition))}'
                        : video.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: video.hasResumePoint
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onMenu != null)
              GestureDetector(
                onTap: onMenu,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.more_vert_rounded,
                      size: 18, color: AppTheme.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}




