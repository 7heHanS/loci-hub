import 'dart:math';
import '../../data/models/location_log.dart';
import '../../data/models/match_status.dart';
import '../../data/models/taken_time_source.dart';

class MatchResult {
  final LocationLog location;
  final int timeDiffSeconds;
  final double confidence;
  final MatchStatus matchStatus;

  MatchResult({
    required this.location,
    required this.timeDiffSeconds,
    required this.confidence,
    required this.matchStatus,
  });
}

class BinarySearchMatcher {
  static const int defaultToleranceMinutes = 5;

  /// Source-specific reliability weight
  static const Map<TakenTimeSource, double> sourceWeights = {
    TakenTimeSource.exifOriginal: 1.0,
    TakenTimeSource.exifDigitized: 0.9,
    TakenTimeSource.imageDateTime: 0.8,
    TakenTimeSource.assetCreateTime: 0.5,
  };

  /// Finds the closest LocationLog for a photo's timestamp using binary search.
  /// If the closest log is within [toleranceMinutes], it calculates the confidence
  /// score and returns a [MatchResult]. Otherwise returns null.
  MatchResult? findClosestLocation({
    required int photoTimestamp,
    required List<LocationLog> sortedLogs,
    required TakenTimeSource timeSource,
    int toleranceMinutes = defaultToleranceMinutes,
  }) {
    if (sortedLogs.isEmpty) return null;

    final toleranceSec = toleranceMinutes * 60;

    // Binary search to find the insert point or exact match
    int lo = 0;
    int hi = sortedLogs.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (sortedLogs[mid].timestamp < photoTimestamp) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    // Check surrounding elements (lo - 1, lo) to find the absolute minimum difference
    LocationLog? closest;
    int minDiff = toleranceSec + 1;

    final startIdx = max(0, lo - 1);
    final endIdx = lo;

    for (int i = startIdx; i <= min(endIdx, sortedLogs.length - 1); i++) {
      final diff = (sortedLogs[i].timestamp - photoTimestamp).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = sortedLogs[i];
      }
    }

    if (closest != null && minDiff <= toleranceSec) {
      // Calculate time-based confidence (linear decay from 1.0 down to 0.0 at the threshold boundary)
      final timeConfidence = 1.0 - (minDiff / toleranceSec);
      
      // Calculate final confidence based on EXIF quality source weights
      final sourceWeight = sourceWeights[timeSource] ?? 0.5;
      final finalConfidence = timeConfidence * sourceWeight;

      return MatchResult(
        location: closest,
        timeDiffSeconds: minDiff,
        confidence: finalConfidence,
        matchStatus: MatchStatus.matched,
      );
    }

    return null;
  }
}
