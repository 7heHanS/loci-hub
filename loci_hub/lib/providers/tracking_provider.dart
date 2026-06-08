import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/utils/permission_handler.dart';
import '../../services/location/location_background_service.dart';

class TrackingState {
  final bool isTracking;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? currentActivity;
  final String? permissionErrorMessage;

  TrackingState({
    required this.isTracking,
    this.currentLatitude,
    this.currentLongitude,
    this.currentActivity,
    this.permissionErrorMessage,
  });

  TrackingState copyWith({
    bool? isTracking,
    double? currentLatitude,
    double? currentLongitude,
    String? currentActivity,
    String? permissionErrorMessage,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      currentActivity: currentActivity ?? this.currentActivity,
      permissionErrorMessage: permissionErrorMessage,
    );
  }
}

class TrackingNotifier extends StateNotifier<TrackingState> {
  final LocationBackgroundService _locationService;
  StreamSubscription? _serviceSubscription;

  TrackingNotifier(this._locationService) : super(TrackingState(isTracking: false)) {
    _init();
  }

  Future<void> _init() async {
    final running = await _locationService.isTracking();
    state = state.copyWith(isTracking: running);
    
    // Set up listener for updates from background service
    _listenToService();
  }

  void _listenToService() {
    _serviceSubscription?.cancel();
    _serviceSubscription = FlutterBackgroundService().on('update').listen((event) {
      if (event != null) {
        state = state.copyWith(
          currentLatitude: event['latitude'] as double?,
          currentLongitude: event['longitude'] as double?,
          currentActivity: event['activityType'] as String?,
        );
      }
    });

    // Also listen to running status changes if needed, but flutter_background_service does not have status callbacks,
    // so we handle it directly during start/stop methods.
  }

  Future<bool> toggleTracking() async {
    if (state.isTracking) {
      await _locationService.stopTracking();
      state = state.copyWith(
        isTracking: false,
        currentLatitude: null,
        currentLongitude: null,
        currentActivity: null,
      );
      return false;
    } else {
      // 1. Check/Request permissions progressively
      final fineGranted = await AppPermissionHandler.isFineLocationGranted();
      if (!fineGranted) {
        final reqFine = await AppPermissionHandler.requestFineLocation();
        if (!reqFine) {
          state = state.copyWith(
            permissionErrorMessage: '위치 권한(정밀 위치)이 필요합니다.',
          );
          return false;
        }
      }

      // Check notification permission (Android 13+ requirement for foreground service UI)
      final notifGranted = await AppPermissionHandler.isNotificationGranted();
      if (!notifGranted) {
        await AppPermissionHandler.requestNotificationPermission();
      }

      // Check background location permission
      final bgGranted = await AppPermissionHandler.isBackgroundLocationGranted();
      if (!bgGranted) {
        final reqBg = await AppPermissionHandler.requestBackgroundLocation();
        if (!reqBg) {
          // If background permission is not granted, we warning that background tracking won't work in background,
          // but we still start the service so it logs in foreground.
          // In real device, the system prompts them to change to "Allow all the time".
        }
      }

      final success = await _locationService.startTracking();
      if (success) {
        state = state.copyWith(
          isTracking: true,
          permissionErrorMessage: null,
        );
        _listenToService();
      } else {
        state = state.copyWith(
          permissionErrorMessage: '위치 추적 서비스 시작 실패',
        );
      }
      return success;
    }
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    super.dispose();
  }
}

final trackingProvider = StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  return TrackingNotifier(getIt<LocationBackgroundService>());
});
