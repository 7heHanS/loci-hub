import '../../data/database/dao/daily_journal_dao.dart';
import '../../data/models/daily_journal.dart';

class JournalRepository {
  final DailyJournalDao _dailyJournalDao;

  JournalRepository(this._dailyJournalDao);

  /// Checks if a journal exists for [journalDate]. If not, creates and inserts a new one.
  Future<DailyJournal> ensureJournalExists(String journalDate) async {
    final existing = await _dailyJournalDao.getByDate(journalDate);
    if (existing != null) {
      return existing;
    }

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final newJournal = DailyJournal(
      journalDate: journalDate,
      aiTitle: null,
      aiSummary: null,
      createdAt: nowSeconds,
      updatedAt: nowSeconds,
    );
    await _dailyJournalDao.insertOrReplace(newJournal);
    return newJournal;
  }

  Future<DailyJournal?> getJournal(String journalDate) async {
    return _dailyJournalDao.getByDate(journalDate);
  }

  Future<List<DailyJournal>> getJournalRange(String startDate, String endDate) async {
    return _dailyJournalDao.getDateRange(startDate, endDate);
  }

  Future<List<String>> getJournalDates() async {
    return _dailyJournalDao.getDatesWithData();
  }

  Future<void> updateJournal(DailyJournal journal) async {
    final updated = journal.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    await _dailyJournalDao.insertOrReplace(updated);
  }
}
