import '../../data/database/dao/location_log_dao.dart';
import '../../data/models/location_log.dart';
import 'journal_repository.dart';

class LocationRepository {
  final LocationLogDao _locationLogDao;
  final JournalRepository _journalRepository;

  LocationRepository(this._locationLogDao, this._journalRepository);

  /// Saves a list of location logs. Ensures that the parent DailyJournal exists 
  /// for each unique date, and updates the DailyJournal updated_at timestamp.
  Future<void> saveLocationLogs(List<LocationLog> logs) async {
    if (logs.isEmpty) return;

    // 1. Group unique journal dates
    final uniqueDates = logs.map((log) => log.journalDate).toSet();

    // 2. Ensure each date exists in the DailyJournal table to avoid Foreign Key violations
    for (final date in uniqueDates) {
      await _journalRepository.ensureJournalExists(date);
    }

    // 3. Batch insert the location logs
    await _locationLogDao.insertBatch(logs);

    // 4. Update the parent journal modified timestamps
    for (final date in uniqueDates) {
      final journal = await _journalRepository.getJournal(date);
      if (journal != null) {
        await _journalRepository.updateJournal(journal);
      }
    }
  }

  Future<List<LocationLog>> getLocationsForDate(String journalDate) async {
    return _locationLogDao.getByDateSorted(journalDate);
  }

  Future<LocationLog?> getClosestLocation(int timestamp) async {
    return _locationLogDao.getClosestToTimestamp(timestamp);
  }

  Future<int> getLocationCount(String journalDate) async {
    return _locationLogDao.getCountByDate(journalDate);
  }
}
