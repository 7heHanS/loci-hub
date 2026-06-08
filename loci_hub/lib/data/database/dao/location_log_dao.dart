import 'package:sqflite/sqflite.dart';
import '../../models/location_log.dart';
import '../app_database.dart';

class LocationLogDao {
  final AppDatabase _appDatabase;

  LocationLogDao(this._appDatabase);

  Database get _db => _appDatabase.db;

  Future<void> insertBatch(List<LocationLog> logs) async {
    if (logs.isEmpty) return;
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final log in logs) {
        batch.insert('LocationLogs', log.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<LocationLog>> getByDateSorted(String journalDate) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'LocationLogs',
      where: 'journal_date = ?',
      whereArgs: [journalDate],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => LocationLog.fromMap(map)).toList();
  }

  Future<List<LocationLog>> getByTimestampRange(int startTimestamp, int endTimestamp) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'LocationLogs',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [startTimestamp, endTimestamp],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => LocationLog.fromMap(map)).toList();
  }

  Future<LocationLog?> getClosestToTimestamp(int timestamp) async {
    // Query for the closest record before or at the given timestamp (uses idx_location_timestamp)
    final List<Map<String, dynamic>> mapsBefore = await _db.query(
      'LocationLogs',
      where: 'timestamp <= ?',
      whereArgs: [timestamp],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    
    // Query for the closest record after or at the given timestamp (uses idx_location_timestamp)
    final List<Map<String, dynamic>> mapsAfter = await _db.query(
      'LocationLogs',
      where: 'timestamp >= ?',
      whereArgs: [timestamp],
      orderBy: 'timestamp ASC',
      limit: 1,
    );

    if (mapsBefore.isEmpty && mapsAfter.isEmpty) return null;
    if (mapsBefore.isEmpty) return LocationLog.fromMap(mapsAfter.first);
    if (mapsAfter.isEmpty) return LocationLog.fromMap(mapsBefore.first);

    final logBefore = LocationLog.fromMap(mapsBefore.first);
    final logAfter = LocationLog.fromMap(mapsAfter.first);

    if ((logBefore.timestamp - timestamp).abs() <= (logAfter.timestamp - timestamp).abs()) {
      return logBefore;
    } else {
      return logAfter;
    }
  }

  Future<int> getCountByDate(String journalDate) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM LocationLogs WHERE journal_date = ?',
      [journalDate],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<LocationLog>> getHighAccuracyByDate(String journalDate, double maxAccuracyMeters) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'LocationLogs',
      where: 'journal_date = ? AND accuracy <= ?',
      whereArgs: [journalDate, maxAccuracyMeters],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => LocationLog.fromMap(map)).toList();
  }
}
