import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onMore;

  const SongTile({
    super.key,
    required this.song,
    this.isPlaying = false,
    required this.onTap,
    this.onFavorite,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: isPlaying
              ? AppTheme.accent.withValues(alpha: 0.12)
              : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: isPlaying
              ? Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.35), width: 1)
              : null,
        ),
        child: Row(
          children: [
            _buildArtwork(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      color: isPlaying
                          ? AppTheme.accent
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Mood tag
            if (song.moodTag != null && song.moodTag!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(_moodEmoji(song.moodTag!),
                    style: const TextStyle(fontSize: 13)),
              ),
            // Duration
            Text(
              song.formattedDuration,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
            // Favorite
            if (onFavorite != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onFavorite,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
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
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
            // More
            if (onMore != null) ...[
              GestureDetector(
                onTap: onMore,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.more_vert_rounded,
                      color: AppTheme.textSecondary, size: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArtwork() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            _artworkColor().withValues(alpha: 0.9),
            _artworkColor().withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            song.title.isNotEmpty
                ? song.title[0].toUpperCase()
                : '♪',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isPlaying)
            Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.equalizer_rounded,
                  color: Colors.white, size: 22),
            ),
        ],
      ),
    );
  }

  Color _artworkColor() {
    const colors = [
      AppTheme.accent,
      AppTheme.accentSecondary,
      AppTheme.accentTertiary,
      Color(0xFFFF9500),
      Color(0xFF34C759),
      Color(0xFFAF52DE),
    ];
    return colors[song.title.hashCode.abs() % colors.length];
  }

  String _moodEmoji(String mood) {
    const m = {
      'happy': '😊', 'sad': '😔', 'focus': '📚',
      'chill': '😌', 'workout': '💪',
    };
    return m[mood] ?? '';
  }
}

class MiniPlayer extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  const MiniPlayer({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C1C35), Color(0xFF251830)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Artwork
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: AppTheme.accentGradient,
              ),
              child: Center(
                child: Text(
                  song.title.isNotEmpty
                      ? song.title[0].toUpperCase()
                      : '♪',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Play/Pause
            _iconBtn(
              isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onPlayPause,
              size: 28,
            ),
            // Next
            _iconBtn(Icons.skip_next_rounded, onNext, size: 26),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap,
      {double size = 24}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
