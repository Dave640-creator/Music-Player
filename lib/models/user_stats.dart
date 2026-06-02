class UserStats {
  final int? id;
  int totalPlayTime; // in seconds
  int totalSongsPlayed;
  int streakDays;
  DateTime? lastPlayedDate;

  UserStats({
    this.id,
    this.totalPlayTime = 0,
    this.totalSongsPlayed = 0,
    this.streakDays = 0,
    this.lastPlayedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total_play_time': totalPlayTime,
      'total_songs_played': totalSongsPlayed,
      'streak_days': streakDays,
      'last_played_date': lastPlayedDate?.toIso8601String(),
    };
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      id: map['id'],
      totalPlayTime: map['total_play_time'] ?? 0,
      totalSongsPlayed: map['total_songs_played'] ?? 0,
      streakDays: map['streak_days'] ?? 0,
      lastPlayedDate: map['last_played_date'] != null
          ? DateTime.parse(map['last_played_date'])
          : null,
    );
  }

  String get formattedTotalTime {
    final hours = totalPlayTime ~/ 3600;
    final minutes = (totalPlayTime % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class ListeningHistory {
  final int? id;
  final int songId;
  final DateTime playedAt;
  final int durationPlayed;

  ListeningHistory({
    this.id,
    required this.songId,
    DateTime? playedAt,
    required this.durationPlayed,
  }) : playedAt = playedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'song_id': songId,
      'played_at': playedAt.toIso8601String(),
      'duration_played': durationPlayed,
    };
  }

  factory ListeningHistory.fromMap(Map<String, dynamic> map) {
    return ListeningHistory(
      id: map['id'],
      songId: map['song_id'],
      playedAt: map['played_at'] != null
          ? DateTime.parse(map['played_at'])
          : DateTime.now(),
      durationPlayed: map['duration_played'] ?? 0,
    );
  }
}

enum BadgeType {
  sevenDayListener,
  hundredSongsPlayed,
  playlistCreator,
  nightOwl,
  morningPerson,
  marathonListener,
  shuffleKing,
  favoritesCollector,
}

// Renamed from Badge to AchievementBadge to avoid conflict with
// Flutter Material 3's built-in Badge widget
class AchievementBadge {
  final BadgeType type;
  final String title;
  final String description;
  final String emoji;
  bool isUnlocked;
  DateTime? unlockedAt;

  AchievementBadge({
    required this.type,
    required this.title,
    required this.description,
    required this.emoji,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  static List<AchievementBadge> allBadges() {
    return [
      AchievementBadge(
        type: BadgeType.sevenDayListener,
        title: '7-Day Listener',
        description: 'Listen to music 7 days in a row',
        emoji: '🔥',
      ),
      AchievementBadge(
        type: BadgeType.hundredSongsPlayed,
        title: '100 Songs Played',
        description: 'Play 100 songs total',
        emoji: '💯',
      ),
      AchievementBadge(
        type: BadgeType.playlistCreator,
        title: 'Playlist Creator',
        description: 'Create your first playlist',
        emoji: '🎵',
      ),
      AchievementBadge(
        type: BadgeType.nightOwl,
        title: 'Night Owl',
        description: 'Listen after midnight',
        emoji: '🦉',
      ),
      AchievementBadge(
        type: BadgeType.morningPerson,
        title: 'Early Bird',
        description: 'Listen to music before 6 AM',
        emoji: '🌅',
      ),
      AchievementBadge(
        type: BadgeType.marathonListener,
        title: 'Marathon Listener',
        description: 'Listen for 10+ hours total',
        emoji: '🏆',
      ),
      AchievementBadge(
        type: BadgeType.shuffleKing,
        title: 'Shuffle King',
        description: 'Use shuffle mode 50 times',
        emoji: '🎲',
      ),
      AchievementBadge(
        type: BadgeType.favoritesCollector,
        title: 'Favorites Collector',
        description: 'Add 20 songs to favorites',
        emoji: '❤️',
      ),
    ];
  }
}
