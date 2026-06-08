import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/permission_handler.dart';

/// Provider for managing photo matching tolerance in minutes (1, 3, 5, 10, 30).
final matchingToleranceProvider = StateProvider<int>((ref) {
  return 5; // Default is 5 minutes
});

/// Provider to check and monitor photo access level.
final photoPermissionProvider = FutureProvider.autoDispose<PhotoAccessLevel>((ref) async {
  return await AppPermissionHandler.checkPhotoAccess();
});
