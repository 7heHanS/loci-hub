import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/di/service_locator.dart';
import 'data/database/app_database.dart';
import 'services/location/location_background_service.dart';

Future<void> main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Setup service locator dependency injection
  await setupServiceLocator();

  // 3. Initialize SQLite local database (enables FFI on desktop)
  await getIt<AppDatabase>().initialize();

  // 4. Initialize Background Location Service (Android/iOS only)
  if (Platform.isAndroid || Platform.isIOS) {
    await getIt<LocationBackgroundService>().initialize();
  }

  // 5. Run the root application wrapped in Riverpod's ProviderScope
  runApp(
    const ProviderScope(
      child: LociHubApp(),
    ),
  );
}
