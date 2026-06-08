import 'package:flutter_test/flutter_test.dart';
import 'package:loci_hub/data/models/location_log.dart';
import 'package:loci_hub/data/models/taken_time_source.dart';
import 'package:loci_hub/data/models/match_status.dart';
import 'package:loci_hub/services/photo/binary_search_matcher.dart';

void main() {
  group('BinarySearchMatcher Tests', () {
    final matcher = BinarySearchMatcher();

    // Utility to build dummy location log
    LocationLog buildLog(int timestamp, {double accuracy = 10.0}) {
      return LocationLog(
        journalDate: '2026-06-08',
        timestamp: timestamp,
        latitude: 37.5665,
        longitude: 126.9780,
        accuracy: accuracy,
        altitude: 50.0,
        speed: 1.5,
        heading: 90.0,
        provider: 'gps',
        activityType: 'walking',
        createdAt: timestamp,
      );
    }

    test('Empty logs list returns null', () {
      final result = matcher.findClosestLocation(
        photoTimestamp: 1717800000,
        sortedLogs: [],
        timeSource: TakenTimeSource.exifOriginal,
      );
      expect(result, isNull);
    });

    test('Exact match returns correct confidence and status', () {
      final logs = [
        buildLog(1717800000),
      ];

      final result = matcher.findClosestLocation(
        photoTimestamp: 1717800000,
        sortedLogs: logs,
        timeSource: TakenTimeSource.exifOriginal,
      );

      expect(result, isNotNull);
      expect(result!.location.timestamp, 1717800000);
      expect(result.timeDiffSeconds, 0);
      expect(result.matchStatus, MatchStatus.matched);
      // confidence = (1.0 - 0/300) * 1.0 (exifOriginal weight) = 1.0
      expect(result.confidence, closeTo(1.0, 0.001));
    });

    test('Tolerance bounds tests (5 minutes default)', () {
      final logs = [
        buildLog(1717800000),
      ];

      // 1. Within tolerance (e.g. 2 minutes difference)
      final resultWithin = matcher.findClosestLocation(
        photoTimestamp: 1717800120, // +2 mins (120s)
        sortedLogs: logs,
        timeSource: TakenTimeSource.exifOriginal,
      );
      expect(resultWithin, isNotNull);
      expect(resultWithin!.timeDiffSeconds, 120);
      // timeConfidence = 1.0 - 120/300 = 0.6
      // finalConfidence = 0.6 * 1.0 = 0.6
      expect(resultWithin.confidence, closeTo(0.6, 0.001));

      // 2. Exactly at the tolerance boundary (5 minutes / 300s)
      final resultBoundary = matcher.findClosestLocation(
        photoTimestamp: 1717800300, // +5 mins (300s)
        sortedLogs: logs,
        timeSource: TakenTimeSource.exifOriginal,
      );
      expect(resultBoundary, isNotNull);
      expect(resultBoundary!.timeDiffSeconds, 300);
      expect(resultBoundary.confidence, closeTo(0.0, 0.001));

      // 3. Just outside tolerance boundary (301s)
      final resultOutside = matcher.findClosestLocation(
        photoTimestamp: 1717800301, // +5 mins 1s
        sortedLogs: logs,
        timeSource: TakenTimeSource.exifOriginal,
      );
      expect(resultOutside, isNull);
    });

    test('Source reliability weights impact confidence score', () {
      final logs = [
        buildLog(1717800000),
      ];

      // EXIF Original source (weight = 1.0)
      final resOriginal = matcher.findClosestLocation(
        photoTimestamp: 1717800060, // 60s diff (timeConfidence = 0.8)
        sortedLogs: logs,
        timeSource: TakenTimeSource.exifOriginal,
      );
      // confidence = 0.8 * 1.0 = 0.8
      expect(resOriginal!.confidence, closeTo(0.8, 0.001));

      // Asset Create Time source (weight = 0.5)
      final resAssetCreate = matcher.findClosestLocation(
        photoTimestamp: 1717800060, // 60s diff (timeConfidence = 0.8)
        sortedLogs: logs,
        timeSource: TakenTimeSource.assetCreateTime,
      );
      // confidence = 0.8 * 0.5 = 0.4
      expect(resAssetCreate!.confidence, closeTo(0.4, 0.001));
    });

    test('Correct closest log selection in multi-item sorted list', () {
      final logs = [
        buildLog(1717800000), // Log A
        buildLog(1717800600), // Log B (+10 mins)
        buildLog(1717801200), // Log C (+20 mins)
      ];

      // Photo taken at 1717800200 (200s from A, 400s from B) -> should match A
      final resultA = matcher.findClosestLocation(
        photoTimestamp: 1717800200,
        sortedLogs: logs,
        timeSource: TakenTimeSource.exifOriginal,
      );
      expect(resultA, isNotNull);
      expect(resultA!.location.timestamp, 1717800000);
      expect(resultA.timeDiffSeconds, 200);

      // Photo taken at 1717800500 (100s from B, 500s from A) -> should match B
      final resultB = matcher.findClosestLocation(
        photoTimestamp: 1717800500,
        sortedLogs: logs,
        timeSource: TakenTimeSource.exifOriginal,
      );
      expect(resultB, isNotNull);
      expect(resultB!.location.timestamp, 1717800600);
      expect(resultB.timeDiffSeconds, 100);
    });
  });
}
