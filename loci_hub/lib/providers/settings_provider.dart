import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/service_locator.dart';
import '../../core/utils/permission_handler.dart';
import '../../main.dart';

/// Provider for managing photo matching tolerance in minutes (1, 3, 5, 10, 30).
final matchingToleranceProvider = StateProvider<int>((ref) {
  return 5; // Default is 5 minutes
});

/// Provider to check and monitor photo access level.
final photoPermissionProvider = FutureProvider.autoDispose<PhotoAccessLevel>((ref) async {
  return await AppPermissionHandler.checkPhotoAccess();
});

/// Provider for the Google Gemini API Key.
/// Falls back to the default provided key if not set.
final geminiApiKeyProvider = StateProvider<String>((ref) {
  final prefs = getIt<SharedPreferences>();
  final savedKey = prefs.getString('gemini_api_key') ?? '';
  if (savedKey.isNotEmpty) return savedKey;
  
  // 1. Check for build-time String.fromEnvironment variables
  const envKey = String.fromEnvironment('GEMINI_API_KEY');
  if (envKey.isNotEmpty) return envKey;

  // 2. Check for automatically copied key from ~/.env during native builds
  if (localEnvApiKey != null && localEnvApiKey!.isNotEmpty) {
    return localEnvApiKey!;
  }

  return '';
});
