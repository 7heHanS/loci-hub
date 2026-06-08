import 'package:permission_handler/permission_handler.dart';

enum PhotoAccessLevel {
  full,
  partial,
  denied,
}

class AppPermissionHandler {
  /// Requests Foreground Location permission (ACCESS_FINE_LOCATION/ACCESS_COARSE_LOCATION).
  /// Returns true if granted.
  static Future<bool> requestFineLocation() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Checks if Foreground Location permission is granted.
  static Future<bool> isFineLocationGranted() async {
    return Permission.location.isGranted;
  }

  /// Requests Background Location permission (ACCESS_BACKGROUND_LOCATION).
  /// Note: Foreground location must be granted first.
  /// Returns true if granted.
  static Future<bool> requestBackgroundLocation() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Checks if Background Location permission is granted.
  static Future<bool> isBackgroundLocationGranted() async {
    return Permission.locationAlways.isGranted;
  }

  /// Requests Notification permission (POST_NOTIFICATIONS).
  /// Returns true if granted.
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Checks if Notification permission is granted.
  static Future<bool> isNotificationGranted() async {
    return Permission.notification.isGranted;
  }

  /// Requests Photo library permissions.
  /// Handles Android 14+ Scoped Storage (Full / Partial / Denied).
  static Future<PhotoAccessLevel> requestPhotoAccess() async {
    final status = await Permission.photos.request();
    if (status.isGranted) {
      return PhotoAccessLevel.full;
    } else if (status.isLimited) {
      return PhotoAccessLevel.partial;
    } else {
      return PhotoAccessLevel.denied;
    }
  }

  /// Checks current Photo library access level.
  static Future<PhotoAccessLevel> checkPhotoAccess() async {
    final status = await Permission.photos.status;
    if (status.isGranted) {
      return PhotoAccessLevel.full;
    } else if (status.isLimited) {
      return PhotoAccessLevel.partial;
    } else {
      return PhotoAccessLevel.denied;
    }
  }

  /// Opens app system settings screen.
  static Future<bool> openAppSettingsScreen() async {
    return openAppSettings();
  }
}
