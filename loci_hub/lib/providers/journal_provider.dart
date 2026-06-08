import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/daily_journal.dart';
import '../../data/models/location_log.dart';
import '../../data/models/photo_metadata.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/photo_repository.dart';
import 'date_provider.dart';

class JournalData {
  final DailyJournal? journal;
  final List<LocationLog> locationLogs;
  final List<PhotoMetadata> photos;

  JournalData({
    this.journal,
    required this.locationLogs,
    required this.photos,
  });
}

final journalDataProvider = FutureProvider.autoDispose<JournalData>((ref) async {
  final date = ref.watch(selectedDateProvider);
  
  final journalRepo = getIt<JournalRepository>();
  final locationRepo = getIt<LocationRepository>();
  final photoRepo = getIt<PhotoRepository>();

  final journal = await journalRepo.getJournal(date);
  final logs = await locationRepo.getLocationsForDate(date);
  final photos = await photoRepo.getPhotosForDate(date);

  return JournalData(
    journal: journal,
    locationLogs: logs,
    photos: photos,
  );
});

// A provider to fetch all dates that contain data, to display dots or highlight on the calendar picker.
final datesWithDataProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final journalRepo = getIt<JournalRepository>();
  return await journalRepo.getJournalDates();
});
