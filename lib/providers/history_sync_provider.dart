// lib/providers/history_sync_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/history_sync_service.dart';
import 'device_provider.dart';
import 'mqtt_provider.dart';
import 'storage_provider.dart';

/// Provides the HistorySyncService instance and starts it.
///
/// Must be read at least once outside the History screen's widget tree
/// (see app.dart) so it's constructed — and stays alive — for the whole
/// app session via Riverpod's default Provider lifetime (not autoDispose),
/// independent of which tab is currently active. Mirrors the same pattern
/// already used by connectivityServiceProvider.
final historySyncServiceProvider = Provider<HistorySyncService?>((ref) {
  final deviceId = ref.watch(deviceIdProvider);
  final mqttService = ref.watch(mqttServiceProvider);
  final storage = ref.watch(localStorageServiceProvider);

  if (deviceId == null || mqttService == null) return null;

  final service = HistorySyncService(
    deviceId: deviceId,
    storage: storage,
    mqttService: mqttService,
  );

  service.init();

  ref.onDispose(() => service.dispose());

  return service;
});
