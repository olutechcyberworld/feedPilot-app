// lib/providers/storage_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';

/// Provides the LocalStorageService instance.
/// init() is called in main.dart before the ProviderScope builds,
/// so this provider can be read immediately without an async guard.
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final service = LocalStorageService();
  ref.onDispose(() => service.close());
  return service;
});

// Type alias eliminates the nested generic bracket problem entirely.
// Dart's parser handles the alias reference cleanly in FutureProvider.family.
typedef _Rows = List<Map<String, dynamic>>;

/// Provides the feed records list for the History screen.
/// Family parameter is the deviceId so the cache is per-device,
/// which correctly handles re-pair events without stale data.
final feedRecordsProvider =
    FutureProvider.family<_Rows, String>((ref, deviceId) async {
  final storage = ref.watch(localStorageServiceProvider);
  return storage.getFeedRecords(deviceId: deviceId, limit: 200);
});

/// Provides the alert records list for the History screen.
final alertRecordsProvider =
    FutureProvider.family<_Rows, String>((ref, deviceId) async {
  final storage = ref.watch(localStorageServiceProvider);
  return storage.getAlerts(deviceId: deviceId, limit: 100);
});

/// Provides recent telemetry snapshots for the weight trend display.
/// 24-hour window matches the HiveMQ Free Tier session persistence
/// window — records older than this may not have been delivered.
final recentTelemetryProvider =
    FutureProvider.family<_Rows, String>((ref, deviceId) async {
  final storage = ref.watch(localStorageServiceProvider);
  return storage.getRecentTelemetry(deviceId: deviceId, hours: 24);
});
