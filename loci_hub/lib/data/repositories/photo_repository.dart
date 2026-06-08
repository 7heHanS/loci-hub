import 'package:photo_manager/photo_manager.dart';
import '../../core/di/service_locator.dart';
import '../../core/utils/timezone_utils.dart';
import '../../services/photo/photo_scanner_service.dart';
import '../../services/photo/exif_parser_service.dart';
import '../../services/photo/binary_search_matcher.dart';
import '../../data/database/dao/photo_metadata_dao.dart';
import '../../data/models/photo_metadata.dart';
import '../../data/models/match_status.dart';
import '../../data/models/location_log.dart';
import 'journal_repository.dart';
import 'location_repository.dart';

class PhotoRepository {
  final PhotoMetadataDao _photoMetadataDao;
  final JournalRepository _journalRepository;

  PhotoRepository(this._photoMetadataDao, this._journalRepository);

  /// Saves photo metadata. Ensures that the parent DailyJournal row exists 
  /// and updates the DailyJournal updated_at timestamp.
  Future<void> savePhotoMetadata(PhotoMetadata photo) async {
    // 1. Ensure foreign key constraint is satisfied
    await _journalRepository.ensureJournalExists(photo.journalDate);

    // 2. Insert or replace photo metadata
    await _photoMetadataDao.insertOrReplace(photo);

    // 3. Update parent journal modified timestamp
    final journal = await _journalRepository.getJournal(photo.journalDate);
    if (journal != null) {
      await _journalRepository.updateJournal(journal);
    }
  }

  Future<List<PhotoMetadata>> getPhotosForDate(String journalDate) async {
    return _photoMetadataDao.getByDate(journalDate);
  }

  Future<List<PhotoMetadata>> getUnmatchedPhotos() async {
    return _photoMetadataDao.getUnmatched();
  }

  Future<List<PhotoMetadata>> getPendingPhotos() async {
    return _photoMetadataDao.getPending();
  }

  Future<bool> isPhotoRegistered(String assetId) async {
    return _photoMetadataDao.existsByAssetId(assetId);
  }

  Future<void> updatePhotoMatch({
    required String assetId,
    required MatchStatus matchStatus,
    double? matchedLat,
    double? matchedLng,
    double? matchedConfidence,
    int? matchTimeDiffSeconds,
  }) async {
    await _photoMetadataDao.updateMatchResult(
      assetId: assetId,
      matchStatus: matchStatus,
      matchedLat: matchedLat,
      matchedLng: matchedLng,
      matchedConfidence: matchedConfidence,
      matchTimeDiffSeconds: matchTimeDiffSeconds,
    );
  }

  /// Synchronizes new photos from the local gallery, parses their EXIF timestamps,
  /// and performs binary search matching against location logs.
  Future<void> syncAndMatchPhotos({
    required DateTime from,
    required DateTime to,
    int toleranceMinutes = 5,
  }) async {
    final scanner = getIt<PhotoScannerService>();
    final parser = getIt<ExifParserService>();
    final matcher = getIt<BinarySearchMatcher>();
    final locationRepo = getIt<LocationRepository>();

    // 1. Scan new photo assets from the local gallery
    final List<AssetEntity> galleryPhotos = await scanner.scanNewPhotos(
      from: from,
      to: to,
    );

    // 2. Parse EXIF data and save initial pending photo records to local database
    for (final asset in galleryPhotos) {
      final exists = await isPhotoRegistered(asset.id);
      if (exists) continue;

      final parsed = await parser.extractTakenTime(asset);
      final journalDate = TimezoneUtils.epochToJournalDate(parsed.timestamp);
      final relativePath = asset.relativePath ?? '';

      final photo = PhotoMetadata(
        assetId: asset.id,
        journalDate: journalDate,
        assetTitle: asset.title ?? 'unnamed',
        relativePath: relativePath,
        photoPath: null,
        takenAt: parsed.timestamp,
        takenTimeSource: parsed.source,
        matchStatus: MatchStatus.pending,
      );

      await savePhotoMetadata(photo);
    }

    // 3. Batch match all pending photo records against available GPS logs
    final pendingPhotos = await getPendingPhotos();
    if (pendingPhotos.isEmpty) return;

    // Group pending photos by journalDate to batch query LocationLogs efficiently
    final Map<String, List<PhotoMetadata>> groupedByDate = {};
    for (final photo in pendingPhotos) {
      groupedByDate.putIfAbsent(photo.journalDate, () => []).add(photo);
    }

    for (final entry in groupedByDate.entries) {
      final date = entry.key;
      final photosForDate = entry.value;

      final List<LocationLog> sortedLogs = await locationRepo.getLocationsForDate(date);

      if (sortedLogs.isEmpty) {
        // No location logs exist for this date
        for (final photo in photosForDate) {
          await updatePhotoMatch(
            assetId: photo.assetId,
            matchStatus: MatchStatus.unmatchedNoLocation,
          );
        }
        continue;
      }

      // Run binary search matcher for each photo record
      for (final photo in photosForDate) {
        final matchResult = matcher.findClosestLocation(
          photoTimestamp: photo.takenAt,
          sortedLogs: sortedLogs,
          timeSource: photo.takenTimeSource,
          toleranceMinutes: toleranceMinutes,
        );

        if (matchResult != null) {
          await updatePhotoMatch(
            assetId: photo.assetId,
            matchStatus: MatchStatus.matched,
            matchedLat: matchResult.location.latitude,
            matchedLng: matchResult.location.longitude,
            matchedConfidence: matchResult.confidence,
            matchTimeDiffSeconds: matchResult.timeDiffSeconds,
          );
        } else {
          await updatePhotoMatch(
            assetId: photo.assetId,
            matchStatus: MatchStatus.unmatchedOutOfTolerance,
          );
        }
      }
    }
  }
}
