class LibraryScanResult {
  final int detected;
  final int imported;
  final int updated;
  final int alreadyImported;
  final int duplicates;
  final int errors;
  final int removed;

  const LibraryScanResult({
    this.detected = 0,
    this.imported = 0,
    this.updated = 0,
    this.alreadyImported = 0,
    this.duplicates = 0,
    this.errors = 0,
    this.removed = 0,
  });

  LibraryScanResult copyWith({
    int? detected,
    int? imported,
    int? updated,
    int? alreadyImported,
    int? duplicates,
    int? errors,
    int? removed,
  }) {
    return LibraryScanResult(
      detected: detected ?? this.detected,
      imported: imported ?? this.imported,
      updated: updated ?? this.updated,
      alreadyImported: alreadyImported ?? this.alreadyImported,
      duplicates: duplicates ?? this.duplicates,
      errors: errors ?? this.errors,
      removed: removed ?? this.removed,
    );
  }
}
