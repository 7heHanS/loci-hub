import 'package:flutter_test/flutter_test.dart';
import 'package:loci_hub/data/models/location_log.dart';
import 'package:loci_hub/services/location/motion_detector.dart';

void main() {
  group('MotionDetector Tests', () {
    final detector = MotionDetector();

    LocationLog buildLog({
      required double latitude,
      required double longitude,
      required double accuracy,
      required double speed,
    }) {
      return LocationLog(
        journalDate: '2026-06-08',
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        altitude: 0.0,
        speed: speed,
        heading: 0.0,
        provider: 'gps',
        activityType: 'walking',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    }

    test('Empty logs list returns walking (default fallback)', () {
      expect(detector.detectMotion([]), MotionState.walking);
    });

    test('High accuracy-filtered logs are ignored, returns walking fallback', () {
      final logs = [
        buildLog(latitude: 37.5, longitude: 126.9, accuracy: 100.0, speed: 0.0),
        buildLog(latitude: 37.5, longitude: 126.9, accuracy: 60.0, speed: 0.0),
      ];
      expect(detector.detectMotion(logs), MotionState.walking);
    });

    test('Stationary state triggers when distance < 30m and avg speed < 0.5m/s with >=5 samples', () {
      // 5 logs very close to each other with zero speed
      final logs = List.generate(
        5,
        (index) => buildLog(
          latitude: 37.5665,
          longitude: 126.9780,
          accuracy: 5.0,
          speed: 0.1,
        ),
      );

      expect(detector.detectMotion(logs), MotionState.stationary);
    });

    test('Walking state triggers when speed < 2.0m/s', () {
      final logs = [
        buildLog(latitude: 37.5665, longitude: 126.9780, accuracy: 5.0, speed: 1.2),
        buildLog(latitude: 37.5670, longitude: 126.9785, accuracy: 5.0, speed: 1.5),
      ];

      expect(detector.detectMotion(logs), MotionState.walking);
    });

    test('Vehicle state triggers when speed >= 2.0m/s', () {
      final logs = [
        buildLog(latitude: 37.5665, longitude: 126.9780, accuracy: 5.0, speed: 8.5), // 30.6 km/h
        buildLog(latitude: 37.5690, longitude: 126.9800, accuracy: 5.0, speed: 10.2),
      ];

      expect(detector.detectMotion(logs), MotionState.vehicle);
    });
  });
}
