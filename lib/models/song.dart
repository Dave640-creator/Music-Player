/// A single audio track stored on the device.
///
/// Extended from the original model with fields that power the Mosaic
/// experience: genre grouping, last-played tracking, privacy flags and
/// embedded / sidecar lyrics.
class Song {
  final int? id;
  final String title;
  final String artist;
  final String filePath;
  final int duration; // in seconds
  final String album;
  bool isFavorite;
  DateTime dateAdded;
  int playCount;
  String? moodTag; // happy, sad, focus, chill, workout
  String? artworkPath;
  String? genre;
  DateTime? lastPlayedAt;
  bool isPrivate;
  String? lyrics; // plain text or LRC synchronized lyrics
  int? year;

  Song({
    this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    required this.duration,
    this.album = 'Unknown Album',
    this.isFavorite = false,
    DateTime? dateAdded,
    this.playCount = 0,
    this.moodTag,
    this.artworkPath,
    this.genre,
    this.lastPlayedAt,
    this.isPrivate = false,
    this.lyrics,
    this.year,
  }) : dateAdded = dateAdded ?? DateTime.now();

  /// File size in bytes (computed lazily from the file system where possible).
  int? fileSizeBytes;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'file_path': filePath,
      'duration': duration,
      'album': album,
      'is_favorite': isFavorite ? 1 : 0,
      'date_added': dateAdded.toIso8601String(),
      'play_count': playCount,
      'mood_tag': moodTag,
      'artwork_path': artworkPath,
      'genre': genre,
      'last_played_at': lastPlayedAt?.toIso8601String(),
      'is_private': isPrivate ? 1 : 0,
      'lyrics': lyrics,
      'year': year,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'],
      title: map['title'] ?? 'Unknown Title',
      artist: map['artist'] ?? 'Unknown Artist',
      filePath: map['file_path'] ?? '',
      duration: map['duration'] ?? 0,
      album: map['album'] ?? 'Unknown Album',
      isFavorite: map['is_favorite'] == 1,
      dateAdded: map['date_added'] != null
          ? DateTime.tryParse(map['date_added']) ?? DateTime.now()
          : DateTime.now(),
      playCount: map['play_count'] ?? 0,
      moodTag: map['mood_tag'],
      artworkPath: map['artwork_path'],
      genre: map['genre'],
      lastPlayedAt: map['last_played_at'] != null
          ? DateTime.tryParse(map['last_played_at'])
          : null,
      isPrivate: map['is_private'] == 1,
      lyrics: map['lyrics'],
      year: map['year'],
    );
  }

  Song copyWith({
    int? id,
    String? title,
    String? artist,
    String? filePath,
    int? duration,
    String? album,
    bool? isFavorite,
    DateTime? dateAdded,
    int? playCount,
    String? moodTag,
    String? artworkPath,
    String? genre,
    DateTime? lastPlayedAt,
    bool? isPrivate,
    String? lyrics,
    int? year,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      album: album ?? this.album,
      isFavorite: isFavorite ?? this.isFavorite,
      dateAdded: dateAdded ?? this.dateAdded,
      playCount: playCount ?? this.playCount,
      moodTag: moodTag ?? this.moodTag,
      artworkPath: artworkPath ?? this.artworkPath,
      genre: genre ?? this.genre,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isPrivate: isPrivate ?? this.isPrivate,
      lyrics: lyrics ?? this.lyrics,
      year: year ?? this.year,
    );
  }

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Whether synchronized (LRC) or plain lyrics are available.
  bool get hasLyrics => lyrics != null && lyrics!.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
