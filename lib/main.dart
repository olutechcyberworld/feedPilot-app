// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'config/mqtt_config.dart';
import 'providers/storage_provider.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail visibly in every build mode — debug, profile, and release —
  // if .env credentials were not injected at build time. This is a plain
  // runtime branch, not assert(), so it is never stripped.
  if (!MqttConfig.isConfigured) {
    runApp(const _ConfigErrorApp());
    return;
  }

  // Initialise SQLite before the widget tree builds.
  // The localStorageServiceProvider reads this instance synchronously.
  final storageService = LocalStorageService();
  await storageService.init();

  runApp(
    ProviderScope(
      overrides: [
        // Inject the already-initialised storage service so the provider
        // never calls init() a second time.
        localStorageServiceProvider.overrideWithValue(storageService),
      ],
      child: const FeedPilotApp(),
    ),
  );
}

/// Shown instead of the real app when MQTT_BROKER_HOST / MQTT_USERNAME /
/// MQTT_PASSWORD are missing at build time — i.e. the app was run or built
/// without `--dart-define-from-file=.env`. Prevents a silent, undiagnosable
/// "stuck on offline" state with no error trail.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                SizedBox(height: 16),
                Text(
                  'MQTT configuration missing.\n\n'
                  'Build with: flutter run --dart-define-from-file=.env',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
