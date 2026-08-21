enum PlaybackEventType { started, paused, resumed, completed, skipped }

class PlaybackEvent {
  final int? id;
  final int songId;
  final PlaybackEventType type;
  final DateTime occurredAt;
  final int positionSeconds;

  const PlaybackEvent({
    this.id,
    required this.songId,
    required this.type,
    required this.occurredAt,
    this.positionSeconds = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'song_id': songId,
      'event_type': type.name,
      'occurred_at': occurredAt.toIso8601String(),
      'position_seconds': positionSeconds,
    };
  }
}
