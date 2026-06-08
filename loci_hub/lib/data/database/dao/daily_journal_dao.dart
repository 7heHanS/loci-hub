import 'package:sqflite/sqflite.dart';
import '../../models/daily_journal.dart';
import '../app_database.dart';

class DailyJournalDao {
  final AppDatabase _appDatabase;

  DailyJournalDao(this._appDatabase);

  Database get _db => _appDatabase.db;

  Future<void> insertOrReplace(DailyJournal journal) async {
    await _db.insert(
      'DailyJournal',
      journal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DailyJournal?> getByDate(String journalDate) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'DailyJournal',
      where: 'journal_date = ?',
      whereArgs: [journalDate],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DailyJournal.fromMap(maps.first);
  }

  Future<List<DailyJournal>> getDateRange(String startDate, String endDate) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'DailyJournal',
      where: 'journal_date BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: 'journal_date ASC',
    );
    return maps.map((map) => DailyJournal.fromMap(map)).toList();
  }

  Future<List<String>> getDatesWithData() async {
    final List<Map<String, dynamic>> maps = await _db.rawQuery(
      'SELECT DISTINCT journal_date FROM DailyJournal ORDER BY journal_date DESC'
    );
    return maps.map((map) => map['journal_date'] as String).toList();
  }

  Future<void> updateTimestamp(String journalDate) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.update(
      'DailyJournal',
      {'updated_at': nowSeconds},
      where: 'journal_date = ?',
      whereArgs: [journalDate],
    );
  }
}
