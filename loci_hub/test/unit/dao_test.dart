import 'package:flutter_test/flutter_test.dart';
import 'package:loci_hub/data/database/app_database.dart';
import 'package:loci_hub/data/database/dao/daily_journal_dao.dart';
import 'package:loci_hub/data/database/dao/location_log_dao.dart';
import 'package:loci_hub/data/database/dao/photo_metadata_dao.dart';
import 'package:loci_hub/data/models/daily_journal.dart';
import 'package:loci_hub/data/models/location_log.dart';
import 'package:loci_hub/data/models/photo_metadata.dart';
import 'package:loci_hub/data/models/match_status.dart';
import 'package:loci_hub/data/models/taken_time_source.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  late AppDatabase database;
  late DailyJournalDao journalDao;
  late LocationLogDao locationDao;
  late PhotoMetadataDao photoDao;

  setUp(() async {
    database = AppDatabase();
    await database.initialize(isInMemory: true);
    journalDao = DailyJournalDao(database);
    locationDao = LocationLogDao(database);
    photoDao = PhotoMetadataDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('DAO Unit Tests', () {
    test('DailyJournalDao CRUD operations', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final journal = DailyJournal(
        journalDate: '2026-06-08',
        aiTitle: 'Test Title',
        aiSummary: 'Test Summary',
        createdAt: now,
        updatedAt: now,
      );

      // Insert
      await journalDao.insertOrReplace(journal);

      // Read
      final fetched = await journalDao.getByDate('2026-06-08');
      expect(fetched, isNotNull);
      expect(fetched!.journalDate, '2026-06-08');
      expect(fetched.aiTitle, 'Test Title');
      expect(fetched.aiSummary, 'Test Summary');

      // Update timestamp
      await Future.delayed(const Duration(seconds: 1));
      await journalDao.updateTimestamp('2026-06-08');
      
      final updated = await journalDao.getByDate('2026-06-08');
      expect(updated!.updatedAt, greaterThan(journal.updatedAt));

      // Range check
      final range = await journalDao.getDateRange('2026-06-07', '2026-06-09');
      expect(range.length, 1);
      expect(range.first.journalDate, '2026-06-08');

      // Dates with data
      final dates = await journalDao.getDatesWithData();
      expect(dates, ['2026-06-08']);
    });

    test('LocationLogDao Foreign Key constraint test', () async {
      final log = LocationLog(
        journalDate: '2026-06-08',
        timestamp: 1717800000,
        latitude: 37.5665,
        longitude: 126.9780,
        accuracy: 10.0,
        altitude: 50.0,
        speed: 1.5,
        heading: 90.0,
        provider: 'gps',
        activityType: 'walking',
        createdAt: 1717800000,
      );

      // Attempt to insert without parent DailyJournal. This should throw DatabaseException due to Foreign Key Constraint.
      expect(
        () async => await locationDao.insertBatch([log]),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('LocationLogDao insertion and queries', () async {
      // First insert parent journal
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final journal = DailyJournal(
        journalDate: '2026-06-08',
        createdAt: now,
        updatedAt: now,
      );
      await journalDao.insertOrReplace(journal);

      final logs = [
        LocationLog(
          journalDate: '2026-06-08',
          timestamp: 1717800000,
          latitude: 37.5665,
          longitude: 126.9780,
          accuracy: 10.0,
          altitude: 50.0,
          speed: 1.5,
          heading: 90.0,
          provider: 'gps',
          activityType: 'walking',
          createdAt: now,
        ),
        LocationLog(
          journalDate: '2026-06-08',
          timestamp: 1717800600, // +10 minutes
          latitude: 37.5675,
          longitude: 126.9790,
          accuracy: 5.0,
          altitude: 55.0,
          speed: 2.0,
          heading: 100.0,
          provider: 'gps',
          activityType: 'walking',
          createdAt: now,
        ),
      ];

      // Batch insert
      await locationDao.insertBatch(logs);

      // Get count
      final count = await locationDao.getCountByDate('2026-06-08');
      expect(count, 2);

      // Get sorted
      final sorted = await locationDao.getByDateSorted('2026-06-08');
      expect(sorted.length, 2);
      expect(sorted[0].timestamp, 1717800000);
      expect(sorted[1].timestamp, 1717800600);

      // Get high accuracy
      final highAcc = await locationDao.getHighAccuracyByDate('2026-06-08', 8.0);
      expect(highAcc.length, 1);
      expect(highAcc.first.accuracy, 5.0);

      // Closest to timestamp (Exact match)
      final closestExact = await locationDao.getClosestToTimestamp(1717800600);
      expect(closestExact, isNotNull);
      expect(closestExact!.timestamp, 1717800600);

      // Closest to timestamp (Midpoint test)
      // 1717800200 is closer to 1717800000 (diff 200) than 1717800600 (diff 400)
      final closestBefore = await locationDao.getClosestToTimestamp(1717800200);
      expect(closestBefore, isNotNull);
      expect(closestBefore!.timestamp, 1717800000);
      
      // 1717800500 is closer to 1717800600 (diff 100) than 1717800000 (diff 500)
      final closestAfter = await locationDao.getClosestToTimestamp(1717800500);
      expect(closestAfter, isNotNull);
      expect(closestAfter!.timestamp, 1717800600);
    });

    test('PhotoMetadataDao CRUD and status updates', () async {
      // First insert parent journal
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final journal = DailyJournal(
        journalDate: '2026-06-08',
        createdAt: now,
        updatedAt: now,
      );
      await journalDao.insertOrReplace(journal);

      final photo = PhotoMetadata(
        assetId: 'asset_123',
        journalDate: '2026-06-08',
        assetTitle: 'IMG_20260608.jpg',
        relativePath: '/DCIM/Camera',
        photoPath: null,
        takenAt: 1717800300,
        takenTimeSource: TakenTimeSource.exifOriginal,
        matchStatus: MatchStatus.pending,
      );

      // Insert
      await photoDao.insertOrReplace(photo);

      // Exist check
      expect(await photoDao.existsByAssetId('asset_123'), isTrue);
      expect(await photoDao.existsByAssetId('non_existent'), isFalse);

      // Get pending
      final pendingList = await photoDao.getPending();
      expect(pendingList.length, 1);
      expect(pendingList.first.assetId, 'asset_123');

      // Update match result
      await photoDao.updateMatchResult(
        assetId: 'asset_123',
        matchStatus: MatchStatus.matched,
        matchedLat: 37.5665,
        matchedLng: 126.9780,
        matchedConfidence: 0.95,
        matchTimeDiffSeconds: 30,
      );

      final updatedPhotos = await photoDao.getByDate('2026-06-08');
      expect(updatedPhotos.length, 1);
      expect(updatedPhotos.first.matchStatus, MatchStatus.matched);
      expect(updatedPhotos.first.matchedLat, 37.5665);
      expect(updatedPhotos.first.matchedConfidence, 0.95);
      expect(updatedPhotos.first.matchTimeDiffSeconds, 30);

      // Unmatched query check
      final unmatched = await photoDao.getUnmatched();
      expect(unmatched.isEmpty, isTrue);
    });
  });
}
