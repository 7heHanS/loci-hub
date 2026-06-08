import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/tracking_constants.dart';
import '../../core/utils/timezone_utils.dart';
import '../../data/database/app_database.dart';
import '../../data/database/dao/daily_journal_dao.dart';
import '../../data/database/dao/location_log_dao.dart';
import '../../data/models/daily_journal.dart';
import '../../data/models/location_log.dart';
import 'motion_detector.dart';

class LocationBackgroundService {
  /// Initializes the background service configuration.
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Must be explicitly started by the user
        isForegroundMode: true,
        notificationChannelId: 'loci_hub_tracking',
        initialNotificationTitle: 'LociHub 위치 추적',
        initialNotificationContent: '추적 시작 대기 중...',
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Starts the background location tracking foreground service.
  Future<bool> startTracking() async {
    final service = FlutterBackgroundService();
    return await service.startService();
  }

  /// Stops the background tracking service.
  Future<void> stopTracking() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  /// Checks if the tracking service is currently running.
  Future<bool> isTracking() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure that background plugins are registered in the background Isolate
  DartPluginRegistrant.ensureInitialized();

  // Create its own Database connection within the background isolate context
  final db = AppDatabase();
  await db.initialize();
  final journalDao = DailyJournalDao(db);
  final locationDao = LocationLogDao(db);
  final motionDetector = MotionDetector();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  bool isTracking = true;

  service.on('stopService').listen((event) async {
    isTracking = false;
    await service.stopSelf();
  });

  MotionState motionState = MotionState.walking;
  int currentInterval = TrackingConstants.intervalWalkingSeconds;

  while (isTracking) {
    try {
      // 1. Fetch current GPS position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final journalDate = TimezoneUtils.epochToJournalDate(nowSeconds);

      // 2. Ensure daily journal exists to respect the foreign key constraint
      final existingJournal = await journalDao.getByDate(journalDate);
      if (existingJournal == null) {
        final newJournal = DailyJournal(
          journalDate: journalDate,
          createdAt: nowSeconds,
          updatedAt: nowSeconds,
        );
        await journalDao.insertOrReplace(newJournal);
      }

      // 3. Write location point to database
      final log = LocationLog(
        journalDate: journalDate,
        timestamp: nowSeconds,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
        provider: 'gps',
        activityType: motionState.name,
        createdAt: nowSeconds,
      );
      await locationDao.insertBatch([log]);

      // Update journal update timestamp
      await journalDao.updateTimestamp(journalDate);

      // 4. Fetch recent logs to run motion detection
      final recentLogs = await locationDao.getByDateSorted(journalDate);
      final samples = recentLogs.length > TrackingConstants.recentSampleCount
          ? recentLogs.sublist(recentLogs.length - TrackingConstants.recentSampleCount)
          : recentLogs;

      // 5. Detect motion and dynamically adjust interval
      motionState = motionDetector.detectMotion(samples);
      switch (motionState) {
        case MotionState.stationary:
          currentInterval = TrackingConstants.intervalStationarySeconds;
          break;
        case MotionState.walking:
          currentInterval = TrackingConstants.intervalWalkingSeconds;
          break;
        case MotionState.vehicle:
          currentInterval = TrackingConstants.intervalVehicleSeconds;
          break;
      }

      // 6. Update notification UI in foreground service context
      final stateText = motionState == MotionState.stationary
          ? '정지 상태'
          : motionState == MotionState.walking
              ? '도보 이동 중'
              : '차량 이동 중';

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'LociHub 위치 추적 중',
          content: '상태: $stateText | 수집 주기: $currentInterval초',
        );
      }

      // Send update callback to main UI isolate
      service.invoke('update', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'activityType': motionState.name,
        'timestamp': nowSeconds,
      });

    } catch (e) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'LociHub 위치 추적 중',
          content: 'GPS 신호 대기 중... (오류: $e)',
        );
      }
    }

    // Dynamic wait interval
    await Future.delayed(Duration(seconds: currentInterval));
  }
}
