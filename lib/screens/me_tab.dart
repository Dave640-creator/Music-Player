import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_stats.dart';
import '../providers/media_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/media_cards.dart';
import '../widgets/action_sheet_base.dart';

class MeTab extends StatelessWidget {
  const MeTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaProvider>(builder: (context, p, _) {
      if (p.isLoading) return const Center(child: CircularProgressIndicator());
      final stats = p.userStats;
      final unlocked = AchievementBadge.allBadges()
          .where((b) => p.unlockedBadges.contains(b.type));
      return ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          SectionHeader(title: 'Stats'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatPill(icon: Icons.timer_rounded, label: 'Listened ${stats.formattedTotalTime}'),
                StatPill(icon: Icons.music_note_rounded, label: '${stats.totalSongsPlayed} tracks'),
                StatPill(icon: Icons.local_fire_department_rounded, label: '${stats.streakDays} day streak'),
              ],
            ),
          ),
          SectionHeader(title: 'Badges'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: unlocked.isEmpty
                  ? [Text('No badges yet — keep listening!', style: TextStyle(color: AppTheme.textSecondary))]
                  : unlocked.map((b) => Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: CircleAvatar(
                          backgroundColor: AppTheme.accentSoft,
                          child: Text(b.emoji)),
                      label: Text(b.title,
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)))).toList(),
            ),
          ),
          SectionHeader(title: 'Recent'),
          ...p.recentSongs.isEmpty
              ? [Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: EmptyState(icon: Icons.history_rounded, title: 'No history yet', message: 'Play tracks to build a listening history.'))]
              : p.recentSongs.take(8).map((s) => SongRow(
                  song: s,
                  isCurrent: s.id == p.audio.currentSong?.id,
                  onTap: () => p.playSong(s, queue: p.recentSongs))).toList(),
          SectionHeader(title: 'Appearance'),
          FilterChipRow(items: [
            ('Dark', p.themeMode == ThemeMode.dark, () => p.setThemeMode(ThemeMode.dark)),
            ('Light', p.themeMode == ThemeMode.light, () => p.setThemeMode(ThemeMode.light)),
            ('System', p.themeMode == ThemeMode.system, () => p.setThemeMode(ThemeMode.system)),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(spacing: 8, runSpacing: 8, children: List.generate(AppTheme.accentPresets.length, (i) => GestureDetector(onTap: () => p.setAccentIndex(i), child: CircleAvatar(radius: 14, backgroundColor: AppTheme.accentPresets[i], child: i == p.accentIndex ? Icon(Icons.check_rounded, size: 18, color: Colors.white70) : null)))),
          ),
          SectionHeader(title: 'Privacy'),
          SwitchListTile(title: Text('App lock', style: TextStyle(color: AppTheme.textPrimary)), value: p.appLockEnabled, activeThumbColor: AppTheme.accent, onChanged: (v) => p.setAppLock(v)),
          SectionHeader(title: 'Utilities'),
          ActionTile(icon: Icons.scanner_rounded, label: 'Scan library', onTap: () => p.scanLibrary()),
          ActionTile(icon: Icons.file_open_rounded, label: 'Import music', onTap: () async { final s = await p.importAudioFromPicker(); if (s.isNotEmpty && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.length} songs imported'), behavior: SnackBarBehavior.floating)); }),
          ActionTile(icon: Icons.videocam_rounded, label: 'Import video', onTap: () async { final v = await p.importVideoFromPicker(); if (v.isNotEmpty && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${v.length} videos imported'), behavior: SnackBarBehavior.floating)); }),
          const SizedBox(height: 32),
        ],
      );
    });
  }
}
