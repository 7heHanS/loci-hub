import 'match_status.dart';
import 'taken_time_source.dart';

class PhotoMetadata {
  final String assetId;
  final String journalDate;
  final String assetTitle;
  final String relativePath;
  final String? photoPath;
  final int takenAt; // UTC Epoch seconds
  final TakenTimeSource takenTimeSource;
  final double? matchedLat;
  final double? matchedLng;
  final double? matchedConfidence; // 0.0 to 1.0
  final int? matchTimeDiffSeconds;
  final MatchStatus matchStatus;

  PhotoMetadata({
    required this.assetId,
    required this.journalDate,
    required this.assetTitle,
    required this.relativePath,
    this.photoPath,
    required this.takenAt,
    required this.takenTimeSource,
    this.matchedLat,
    this.matchedLng,
    this.matchedConfidence,
    this.matchTimeDiffSeconds,
    required this.matchStatus,
  });

  PhotoMetadata copyWith({
    String? assetId,
    String? journalDate,
    String? assetTitle,
    String? relativePath,
    String? photoPath,
    int? takenAt,
    TakenTimeSource? takenTimeSource,
    double? matchedLat,
    double? matchedLng,
    double? matchedConfidence,
    int? matchTimeDiffSeconds,
    MatchStatus? matchStatus,
  }) {
    return PhotoMetadata(
      assetId: assetId ?? this.assetId,
      journalDate: journalDate ?? this.journalDate,
      assetTitle: assetTitle ?? this.assetTitle,
      relativePath: relativePath ?? this.relativePath,
      photoPath: photoPath ?? this.photoPath,
      takenAt: takenAt ?? this.takenAt,
      takenTimeSource: takenTimeSource ?? this.takenTimeSource,
      matchedLat: matchedLat ?? this.matchedLat,
      matchedLng: matchedLng ?? this.matchedLng,
      matchedConfidence: matchedConfidence ?? this.matchedConfidence,
      matchTimeDiffSeconds: matchTimeDiffSeconds ?? this.matchTimeDiffSeconds,
      matchStatus: matchStatus ?? this.matchStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'asset_id': assetId,
      'journal_date': journalDate,
      'asset_title': assetTitle,
      'relative_path': relativePath,
      'photo_path': photoPath,
      'taken_at': takenAt,
      'taken_time_source': takenTimeSource.toDbValue(),
      'matched_lat': matchedLat,
      'matched_lng': matchedLng,
      'matched_confidence': matchedConfidence,
      'match_time_diff_seconds': matchTimeDiffSeconds,
      'match_status': matchStatus.toDbValue(),
    };
  }

  factory PhotoMetadata.fromMap(Map<String, dynamic> map) {
    return PhotoMetadata(
      assetId: map['asset_id'] as String,
      journalDate: map['journal_date'] as String,
      assetTitle: map['asset_title'] as String,
      relativePath: map['relative_path'] as String,
      photoPath: map['photo_path'] as String?,
      takenAt: map['taken_at'] as int,
      takenTimeSource: TakenTimeSource.fromDb(map['taken_time_source'] as String?),
      matchedLat: map['matched_lat'] != null ? (map['matched_lat'] as num).toDouble() : null,
      matchedLng: map['matched_lng'] != null ? (map['matched_lng'] as num).toDouble() : null,
      matchedConfidence: map['matched_confidence'] != null ? (map['matched_confidence'] as num).toDouble() : null,
      matchTimeDiffSeconds: map['match_time_diff_seconds'] as int?,
      matchStatus: MatchStatus.fromDb(map['match_status'] as String?),
    );
  }

  @override
  String toString() {
    return 'PhotoMetadata(assetId: $assetId, journalDate: $journalDate, title: $assetTitle, takenAt: $takenAt, status: $matchStatus, lat: $matchedLat, lng: $matchedLng)';
  }
}
