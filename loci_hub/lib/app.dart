import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'ui/navigation/app_router.dart';

class LociHubApp extends StatelessWidget {
  const LociHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LociHub',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Dynamically follow system setting
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
