import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../models/video.dart';
import '../providers/media_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/media_cards.dart';
import '../widgets/media_action_sheet.dart';

/// DISCOVER: a scrolling feed of auto-curated sections sourced from the
/// library's listening history and most-played tracks.
class DiscoverTab extends StatelessWidget {
  const DiscoverTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaProvider>(builder: (context, p, _) {
      if (p.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          _hero(p),
          if (p.recentSongs.isNotEmpty)
            _songStrip(context, 'Continue listening', p.recentSongs, p),
          if (p.recentlyAddedSongs.isNotEmpty)
            _songStrip(context, 'Recently added', p.recentlyAddedSongs, p),
          if (p.rotation.isNotEmpty)
            _songStrip(context, 'On rotation', p.rotation, p),
          if (p.favorites.isNotEmpty)
            _songStrip(context, 'Liked songs', p.favorites, p),
          if (p.playlists.isNotEmpty)
            _playlistStrip(context, 'Playlists', p.playlists, p),
          if (p.continueWatching.isNotEmpty)
            _videoStrip(context, 'Continue watching', p.continueWatching, p),
          if (p.recentlyAddedVideos.isNotEmpty)
            _videoStrip(context, 'New videos', p.recentlyAddedVideos, p),
          const SizedBox(height: 12),
        ],
      );
    });
  }
}

Widget _hero(MediaProvider p) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.heroCard(radius: 20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mosaic',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const Text('Your music, reimagined.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              GradientButton(
                icon: Icons.play_arrow_rounded,
                label: 'Start listening',
                onTap: () {
                  if (p.recentSongs.isNotEmpty) {
                    p.playSong(p.recentSongs.first, queue: p.recentSongs);
                  }
                },
              ),
            ]),
      ),
    );

Widget _songStrip(
    BuildContext context, String label, List<Song> songs, MediaProvider p) {
  final audio = p.audio;
  final currentId = audio.currentSong?.id;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(title: label),
      SizedBox(
        height: 136,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: songs
              .map((s) => SizedBox(
                  width: 150,
                  child: MusicCard(
                    song: s,
                    isCurrent: s.id == currentId,
                    isPlaying: audio.isPlaying && s.id == currentId,
                    onTap: () => p.playSong(s, queue: songs),
                    onPlay: () => p.playSong(s, queue: songs),
                    onMenu: () =>
                        showSongActions(context, s, queue: songs),
                  )))
              .toList(),
        ),
      ),
    ],
  );
}

Widget _videoStrip(
    BuildContext context, String label, List<Video> videos, MediaProvider p) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(title: label),
      SizedBox(
        height: 136,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: videos
              .map((v) => SizedBox(
                  width: 160,
                  child: VideoCard(
                    video: v,
                    onTap: () => p.playVideo(v),
                    onMenu: () => showVideoActions(context, v),
                  )))
              .toList(),
        ),
      ),
    ],
  );
}

Widget _playlistStrip(BuildContext context, String label,
    List<Playlist> playlists, MediaProvider p) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(title: label),
      SizedBox(
        height: 136,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: playlists
              .map((pl) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PlaylistCard(
                    playlist: pl,
                    onTap: () {
                      final songs = pl.songs;
                      if (songs.isNotEmpty) {
                        p.playSong(songs.first, queue: songs);
                      }
                    },
                  )))
              .toList(),
        ),
      ),
    ],
  );
}
