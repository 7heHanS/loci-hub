import 'package:get_it/get_it.dart';
import '../../data/database/app_database.dart';
import '../../data/database/dao/daily_journal_dao.dart';
import '../../data/database/dao/location_log_dao.dart';
import '../../data/database/dao/photo_metadata_dao.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../services/location/location_background_service.dart';
import '../../services/photo/photo_scanner_service.dart';
import '../../services/photo/exif_parser_service.dart';
import '../../services/photo/binary_search_matcher.dart';
import '../../services/llm/llm_service.dart';
import '../utils/db_export_util.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Database instance
  final db = AppDatabase();
  getIt.registerSingleton<AppDatabase>(db);

  // DAOs
  getIt.registerLazySingleton<DailyJournalDao>(
    () => DailyJournalDao(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<LocationLogDao>(
    () => LocationLogDao(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<PhotoMetadataDao>(
    () => PhotoMetadataDao(getIt<AppDatabase>()),
  );

  // Repositories
  getIt.registerLazySingleton<JournalRepository>(
    () => JournalRepository(getIt<DailyJournalDao>()),
  );
  getIt.registerLazySingleton<LocationRepository>(
    () => LocationRepository(getIt<LocationLogDao>(), getIt<JournalRepository>()),
  );
  getIt.registerLazySingleton<PhotoRepository>(
    () => PhotoRepository(getIt<PhotoMetadataDao>(), getIt<JournalRepository>()),
  );

  // Background Services
  getIt.registerSingleton<LocationBackgroundService>(
    LocationBackgroundService(),
  );

  // Photo Services
  getIt.registerLazySingleton<PhotoScannerService>(
    () => PhotoScannerService(),
  );
  getIt.registerLazySingleton<ExifParserService>(
    () => ExifParserService(),
  );
  getIt.registerLazySingleton<BinarySearchMatcher>(
    () => BinarySearchMatcher(),
  );

  // LLM Services
  getIt.registerLazySingleton<LlmService>(
    () => LlmService(),
  );

  // Utilities
  getIt.registerLazySingleton<DbExportUtil>(
    () => DbExportUtil(getIt<AppDatabase>()),
  );
}
