import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';
import '../models/user_stats.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<Song> _topSongs = [];
  Map<String, int> _dailyStats = {};
  String _favoriteArtist = 'None yet';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final provider = context.read<MusicProvider>();
    final results = await Future.wait([
      provider.getMostPlayedSongs(limit: 10),
      provider.getDailyStats(7),
      provider.getFavoriteArtist(),
    ]);

    if (mounted) {
      setState(() {
        _topSongs = results[0] as List<Song>;
        _dailyStats = results[1] as Map<String, int>;
        _favoriteArtist = results[2] as String;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : Consumer<MusicProvider>(
              builder: (context, provider, _) {
                return RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.accent,
                  backgroundColor: AppTheme.cardDark,
                  child: ListView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatsCards(provider.userStats),
                      const SizedBox(height: 16),
                      _buildFavoriteArtistCard(),
                      const SizedBox(height: 16),
                      _buildDailyChart(),
                      const SizedBox(height: 16),
                      _buildTopSongs(),
                      const SizedBox(height: 16),
                      _buildMoodChart(provider),
                      const SizedBox(height: 16),
                      _buildBadgesSection(provider),
                      const SizedBox(height: 80),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatsCards(UserStats stats) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.access_time_rounded,
          label: 'Listen Time',
          value: stats.formattedTotalTime,
          color: AppTheme.accent,
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.music_note_rounded,
          label: 'Songs Played',
          value: '${stats.totalSongsPlayed}',
          color: AppTheme.accentSecondary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.local_fire_department_rounded,
          label: 'Day Streak',
          value: '${stats.streakDays}d',
          color: AppTheme.accentTertiary,
        ),
      ],
    );
  }

  Widget _buildFavoriteArtistCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentSecondary.withValues(alpha: 0.2),
            AppTheme.cardDark,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentSecondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accentSecondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.favorite_rounded,
                color: AppTheme.accentSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Favorite Artist',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  _favoriteArtist,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.star_rounded,
              color: AppTheme.accentSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _buildDailyChart() {
    return _card(
      title: '📈 This Week',
      child: _dailyStats.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No listening history yet.\nStart playing music!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            )
          : SizedBox(
              height: 160,
              child: _buildBarChart(),
            ),
    );
  }

  Widget _buildBarChart() {
    final entries = _dailyStats.entries.toList();
    final maxVal = _dailyStats.values.fold(0, (a, b) => a > b ? a : b);
    final maxMinutes = (maxVal / 60).ceil() + 5;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxMinutes.toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= entries.length) {
                  return const SizedBox.shrink();
                }
                try {
                  final date = DateTime.parse(entries[idx].key);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('EEE').format(date),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 10),
                    ),
                  );
                } catch (_) {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        ),
        barGroups: entries.asMap().entries.map((e) {
          final minutes = e.value.value / 60;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: minutes,
                gradient: const LinearGradient(
                  colors: [AppTheme.accent, AppTheme.accentSecondary],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 18,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopSongs() {
    return _card(
      title: '🔥 Most Played',
      child: _topSongs.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No plays recorded yet',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          : Column(
              children: _topSongs.asMap().entries.map((e) {
                final rank = e.key;
                final song = e.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: rank == 0 ? AppTheme.accentGradient : null,
                          color: rank > 0 ? AppTheme.surfaceDark : null,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${rank + 1}',
                            style: TextStyle(
                              color: rank == 0
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(song.artist,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${song.playCount} play${song.playCount != 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMoodChart(MusicProvider provider) {
    final moodCounts = <String, int>{};
    for (final song in provider.rawSongs) {
      if (song.moodTag != null && song.moodTag!.isNotEmpty) {
        moodCounts[song.moodTag!] = (moodCounts[song.moodTag!] ?? 0) + 1;
      }
    }

    if (moodCounts.isEmpty) {
      return _card(
        title: '🎭 Mood Distribution',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'No mood tags yet.\nTag songs from the library!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ),
      );
    }

    final total = moodCounts.values.fold(0, (a, b) => a + b);
    const moodEmojis = {
      'happy': '😊',
      'sad': '😔',
      'focus': '📚',
      'chill': '😌',
      'workout': '💪',
    };

    return _card(
      title: '🎭 Mood Distribution',
      child: Column(
        children: moodCounts.entries.map((e) {
          final pct = e.value / total;
          final color = AppTheme.moodColors[e.key] ?? AppTheme.accent;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(moodEmojis[e.key] ?? '🎵',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${e.key[0].toUpperCase()}${e.key.substring(1)}',
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${e.value} song${e.value != 1 ? 's' : ''}  (${(pct * 100).round()}%)',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBadgesSection(MusicProvider provider) {
    // FIX: use AchievementBadge instead of Badge (Badge conflicts with Flutter Material 3)
    final all = AchievementBadge.allBadges();
    for (final b in all) {
      b.isUnlocked = provider.unlockedBadges.contains(b.type);
    }
    final unlocked = all.where((b) => b.isUnlocked).length;

    return _card(
      title: '🏆 Achievements  ($unlocked/${all.length})',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: all.length,
        itemBuilder: (_, i) {
          final badge = all[i];
          return Tooltip(
            message: badge.description,
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: badge.isUnlocked ? AppTheme.accentGradient : null,
                    color: badge.isUnlocked ? null : AppTheme.surfaceDark,
                    shape: BoxShape.circle,
                    border: badge.isUnlocked
                        ? null
                        : Border.all(color: Colors.white12),
                  ),
                  child: Center(
                    child: Text(
                      badge.emoji,
                      style: TextStyle(
                        fontSize: 22,
                        color: badge.isUnlocked ? null : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  badge.title,
                  style: TextStyle(
                    color: badge.isUnlocked
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
