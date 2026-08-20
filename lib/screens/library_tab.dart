import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/media_cards.dart';
import '../widgets/media_action_sheet.dart';

class LibraryTab extends StatelessWidget {
  const LibraryTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaProvider>(builder: (context, p, _) {
      if (p.isLoading) return const Center(child: CircularProgressIndicator());
      final isMusic = p.mediaFilter == LibraryMediaFilter.music;
      final curId = p.audio.currentSong?.id;
      final playing = p.audio.isPlaying;
      return ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          _filters(p),
          _sortRow(p),
          _header(context, isMusic ? 'Songs' : 'Videos', p),
          ..._mediaList(context, p, isMusic, curId, playing),
          _playlistSection(context, p),
          const SizedBox(height: 24),
        ],
      );
    });
  }
}

Widget _filters(MediaProvider p) => FilterChipRow(items: [
      ('Music', p.mediaFilter == LibraryMediaFilter.music,
          () => p.setMediaFilter(LibraryMediaFilter.music)),
      ('Videos', p.mediaFilter != LibraryMediaFilter.music,
          () => p.setMediaFilter(LibraryMediaFilter.video)),
    ]);

Widget _sortRow(MediaProvider p) => FilterChipRow(items: [
      ('Added', p.sortBy == SortBy.recentlyAdded, () => p.setSortBy(SortBy.recentlyAdded)),
      ('Title', p.sortBy == SortBy.title, () => p.setSortBy(SortBy.title)),
      ('Artist', p.sortBy == SortBy.artist, () => p.setSortBy(SortBy.artist)),
      ('Played', p.sortBy == SortBy.mostPlayed, () => p.setSortBy(SortBy.mostPlayed)),
      ('Recent', p.sortBy == SortBy.recentlyPlayed, () => p.setSortBy(SortBy.recentlyPlayed)),
    ]);

Widget _header(BuildContext context, String title, MediaProvider p) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        IconButton(icon: Icon(p.gridView ? Icons.view_list_rounded : Icons.grid_view_rounded, color: AppTheme.textSecondary), onPressed: () => p.toggleGridView()),
      ]),
    );

List<Widget> _mediaList(BuildContext context, MediaProvider p, bool isMusic, Object? curId, bool playing) {
  final pad = const EdgeInsets.symmetric(horizontal: 20);
  if (isMusic) {
    final songs = p.sortedSongs;
    if (songs.isEmpty) return [Padding(padding: pad, child: EmptyState(icon: Icons.music_note_rounded, title: 'No songs', message: 'Add music to get started.'))];
    if (p.gridView) {
      return [Padding(padding: pad, child: Wrap(spacing: 14, runSpacing: 12, children: songs.map((s) => SizedBox(width: 150, child: MusicCard(song: s, isCurrent: s.id == curId, isPlaying: playing && s.id == curId, onTap: () => p.playSong(s, queue: p.songs), onMenu: () => showSongActions(context, s, queue: p.songs)))).toList()))];
    }
    return songs.map((s) => SongRow(song: s, isCurrent: s.id == curId, isPlaying: playing && s.id == curId, onTap: () => p.playSong(s, queue: p.songs), onMenu: () => showSongActions(context, s, queue: p.songs), onFavorite: () => p.toggleFavorite(s))).toList();
  }
  final videos = p.sortedVideos;
  if (videos.isEmpty) return [Padding(padding: pad, child: EmptyState(icon: Icons.videocam_rounded, title: 'No videos', message: 'Import videos to get started.'))];
  if (p.gridView) {
    return [Padding(padding: pad, child: Wrap(spacing: 14, runSpacing: 12, children: videos.map((v) => SizedBox(width: 160, child: VideoCard(video: v, onTap: () => p.playVideo(v), onMenu: () => showVideoActions(context, v)))).toList()))];
  }
  return videos.map((v) => VideoRow(video: v, onTap: () => p.playVideo(v), onMenu: () => showVideoActions(context, v))).toList();
}

Widget _playlistSection(BuildContext context, MediaProvider p) {
  final playlists = p.playlists;
  if (playlists.isEmpty) return const SizedBox.shrink();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SectionHeader(title: 'Playlists'),
    SizedBox(height: 136, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: playlists.map((pl) => Padding(padding: const EdgeInsets.only(right: 8), child: PlaylistCard(playlist: pl, onTap: () { final songs = pl.songs; if (songs.isNotEmpty) p.playSong(songs.first, queue: songs); }))).toList())),
  ]);
}
