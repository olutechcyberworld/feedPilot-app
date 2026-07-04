// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'config/mqtt_config.dart';
import 'providers/storage_provider.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast if .env credentials were not injected at build time.
  // This assertion is stripped in release builds automatically.
  MqttConfig.assertConfigured();

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
