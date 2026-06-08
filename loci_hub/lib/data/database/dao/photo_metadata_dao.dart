import 'package:sqflite/sqflite.dart';
import '../../models/photo_metadata.dart';
import '../../models/match_status.dart';
import '../app_database.dart';

class PhotoMetadataDao {
  final AppDatabase _appDatabase;

  PhotoMetadataDao(this._appDatabase);

  Database get _db => _appDatabase.db;

  Future<void> insertOrReplace(PhotoMetadata photo) async {
    await _db.insert(
      'PhotoMetadata',
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PhotoMetadata>> getByDate(String journalDate) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'PhotoMetadata',
      where: 'journal_date = ?',
      whereArgs: [journalDate],
      orderBy: 'taken_at ASC',
    );
    return maps.map((map) => PhotoMetadata.fromMap(map)).toList();
  }

  Future<List<PhotoMetadata>> getUnmatched() async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'PhotoMetadata',
      where: 'match_status != ?',
      whereArgs: [MatchStatus.matched.toDbValue()],
      orderBy: 'taken_at ASC',
    );
    return maps.map((map) => PhotoMetadata.fromMap(map)).toList();
  }

  Future<List<PhotoMetadata>> getPending() async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'PhotoMetadata',
      where: 'match_status = ?',
      whereArgs: [MatchStatus.pending.toDbValue()],
      orderBy: 'taken_at ASC',
    );
    return maps.map((map) => PhotoMetadata.fromMap(map)).toList();
  }

  Future<void> updateMatchResult({
    required String assetId,
    required MatchStatus matchStatus,
    double? matchedLat,
    double? matchedLng,
    double? matchedConfidence,
    int? matchTimeDiffSeconds,
  }) async {
    await _db.update(
      'PhotoMetadata',
      {
        'match_status': matchStatus.toDbValue(),
        'matched_lat': matchedLat,
        'matched_lng': matchedLng,
        'matched_confidence': matchedConfidence,
        'match_time_diff_seconds': matchTimeDiffSeconds,
      },
      where: 'asset_id = ?',
      whereArgs: [assetId],
    );
  }

  Future<bool> existsByAssetId(String assetId) async {
    final result = await _db.rawQuery(
      'SELECT 1 FROM PhotoMetadata WHERE asset_id = ? LIMIT 1',
      [assetId],
    );
    return result.isNotEmpty;
  }

  Future<List<PhotoMetadata>> getByMatchStatus(MatchStatus status) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'PhotoMetadata',
      where: 'match_status = ?',
      whereArgs: [status.toDbValue()],
      orderBy: 'taken_at ASC',
    );
    return maps.map((map) => PhotoMetadata.fromMap(map)).toList();
  }
}
