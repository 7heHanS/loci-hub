import 'package:geolocator/geolocator.dart';
import '../../core/constants/tracking_constants.dart';
import '../../data/models/location_log.dart';

enum MotionState {
  stationary,
  walking,
  vehicle,
}

class MotionDetector {
  /// Detects the motion state based on recent location logs.
  MotionState detectMotion(List<LocationLog> recentLogs) {
    // 1. Filter out coordinates with accuracy lower than threshold (accuracy > 50m)
    final filteredLogs = recentLogs
        .where((log) => log.accuracy <= TrackingConstants.accuracyThresholdMeters)
        .toList();

    if (filteredLogs.isEmpty) {
      return MotionState.walking; // Default fallback
    }

    // 2. Calculate average speed (m/s)
    double speedSum = 0;
    for (final log in filteredLogs) {
      speedSum += log.speed;
    }
    final avgSpeed = speedSum / filteredLogs.length;

    // 3. Calculate distance sum of adjacent coordinates
    double distanceSum = 0;
    for (int i = 0; i < filteredLogs.length - 1; i++) {
      distanceSum += Geolocator.distanceBetween(
        filteredLogs[i].latitude,
        filteredLogs[i].longitude,
        filteredLogs[i + 1].latitude,
        filteredLogs[i + 1].longitude,
      );
    }

    // 4. Branching decision logic
    // Stationary requires a minimum number of samples to avoid premature triggers
    if (filteredLogs.length >= TrackingConstants.recentSampleCount) {
      if (distanceSum < TrackingConstants.stationaryDistanceThresholdMeters &&
          avgSpeed < TrackingConstants.stationarySpeedThresholdMs) {
        return MotionState.stationary;
      }
    }

    // Otherwise, decide between walking and vehicle based on average speed
    if (avgSpeed < TrackingConstants.walkingSpeedThresholdMs) {
      return MotionState.walking;
    } else {
      return MotionState.vehicle;
    }
  }
}
