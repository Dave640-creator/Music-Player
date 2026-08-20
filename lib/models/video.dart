/// A single video file stored on the device.
///
/// Supports resume playback via [lastPosition], favorites, privacy flags and
/// a lightweight "demo" mode that renders the player UI without a real file
/// (used by the seeded demo library on devices without video content).
class Video {
  final int? id;
  final String title;
  final String artist; // uploader / channel / folder name
  final String filePath;
  final int duration; // in seconds
  DateTime dateAdded;
  int playCount;
  bool isFavorite;
  String? thumbnailPath;
  int lastPosition; // resume point in seconds
  bool isPrivate;
  bool isDemo;

  Video({
    this.id,
    required this.title,
    required this.filePath,
    this.artist = 'Local Video',
    this.duration = 0,
    DateTime? dateAdded,
    this.playCount = 0,
    this.isFavorite = false,
    this.thumbnailPath,
    this.lastPosition = 0,
    this.isPrivate = false,
    this.isDemo = false,
  }) : dateAdded = dateAdded ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'file_path': filePath,
      'duration': duration,
      'date_added': dateAdded.toIso8601String(),
      'play_count': playCount,
      'is_favorite': isFavorite ? 1 : 0,
      'thumbnail_path': thumbnailPath,
      'last_position': lastPosition,
      'is_private': isPrivate ? 1 : 0,
      'is_demo': isDemo ? 1 : 0,
    };
  }

  factory Video.fromMap(Map<String, dynamic> map) {
    return Video(
      id: map['id'],
      title: map['title'] ?? 'Untitled',
      artist: map['artist'] ?? 'Local Video',
      filePath: map['file_path'] ?? '',
      duration: map['duration'] ?? 0,
      dateAdded: map['date_added'] != null
          ? DateTime.tryParse(map['date_added']) ?? DateTime.now()
          : DateTime.now(),
      playCount: map['play_count'] ?? 0,
      isFavorite: map['is_favorite'] == 1,
      thumbnailPath: map['thumbnail_path'],
      lastPosition: map['last_position'] ?? 0,
      isPrivate: map['is_private'] == 1,
      isDemo: map['is_demo'] == 1,
    );
  }

  Video copyWith({
    int? id,
    String? title,
    String? artist,
    String? filePath,
    int? duration,
    DateTime? dateAdded,
    int? playCount,
    bool? isFavorite,
    String? thumbnailPath,
    int? lastPosition,
    bool? isPrivate,
    bool? isDemo,
  }) {
    return Video(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      dateAdded: dateAdded ?? this.dateAdded,
      playCount: playCount ?? this.playCount,
      isFavorite: isFavorite ?? this.isFavorite,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      lastPosition: lastPosition ?? this.lastPosition,
      isPrivate: isPrivate ?? this.isPrivate,
      isDemo: isDemo ?? this.isDemo,
    );
  }

  String get formattedDuration {
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    final s = duration % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get progress => duration > 0
      ? (lastPosition / duration).clamp(0.0, 1.0).toDouble()
      : 0.0;

  bool get hasResumePoint => lastPosition > 10 && lastPosition < duration - 5;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Video && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// The media kind used across the unified library / progress tracking.
enum MediaKind { audio, video }
