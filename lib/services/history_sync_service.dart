// lib/services/history_sync_service.dart

import 'dart:async';
import '../models/feed_status.dart';
import 'local_storage_service.dart';
import 'mqtt_service.dart';

/// Bridges live MQTT telemetry into local persistent storage.
///
/// LocalStorageService's insert methods (insertFeedRecord, insertAlert,
/// insertTelemetry) are fully implemented but have no caller anywhere in
/// the app — the Dashboard consumes MqttService's streams live, but
/// nothing was ever writing them to SQLite. This service is that missing
/// bridge; without it, the History screen has no data to read regardless
/// of how long the device has been running.
///
/// Instantiated once per paired device via historySyncServiceProvider and
/// kept alive for the app's lifetime — deliberately NOT scoped to the
/// History screen's widget lifecycle, since that would stop capturing
/// records the moment the farmer navigates to another tab.
class HistorySyncService {
  final String deviceId;
  final LocalStorageService storage;
  final MqttService mqttService;

  HistorySyncService({
    required this.deviceId,
    required this.storage,
    required this.mqttService,
  });

  StreamSubscription<FeedStatus>? _feedStatusSub;
  StreamSubscription? _feedAlertSub;
  StreamSubscription? _hopperWeightSub;

  // ── Telemetry throttle ───────────────────────────────────────────────────
  // hopper/weight publishes on a ~2s cadence (matches the firmware's HX711
  // read loop). Persisting every message is unbounded growth — roughly
  // 43,000 rows/day — with no benefit to the History screen's trend chart,
  // which doesn't need second-level resolution. One row per minute keeps
  // the table bounded indefinitely while still giving a usable trend line.
  static const Duration _telemetryInterval = Duration(minutes: 1);
  DateTime? _lastTelemetryInsertAt;

  Future<void> init() async {
    // Safe to run on every launch — simple age-based delete, not a
    // one-time migration.
    await storage.enforceRetentionPolicy(deviceId: deviceId);

    // ── Feed records ──────────────────────────────────────────────────────
    // Dedup is enforced at the schema level (UNIQUE(device_id, timestamp)
    // + ConflictAlgorithm.ignore in LocalStorageService), so it's safe to
    // attempt an insert on every feed/status message — repeats of the same
    // completed dispense are silently absorbed by the database rather than
    // filtered here. insertFeedRecord itself skips null timestamps (no
    // dispense has happened yet).
    _feedStatusSub = mqttService.feedStatusStream.listen((status) {
      // hopper_state has no source field in any locked MQTT payload —
      // feed/status only carries trough_state. Recorded as 'UNKNOWN' until
      // a hopper-side sensor state is added to the schema.
      storage.insertFeedRecord(
        deviceId: deviceId,
        dispense: status.lastDispense,
        troughState: status.troughState,
        hopperState: 'UNKNOWN',
      );
    });

    // ── Alerts ────────────────────────────────────────────────────────────
    // Alerts are discrete, one-shot events — no dedup needed.
    _feedAlertSub = mqttService.feedAlertStream.listen((alert) {
      storage.insertAlert(deviceId: deviceId, alert: alert);
    });

    // ── Telemetry ─────────────────────────────────────────────────────────
    _hopperWeightSub = mqttService.hopperWeightStream.listen((reading) {
      final now = DateTime.now();
      if (_lastTelemetryInsertAt != null &&
          now.difference(_lastTelemetryInsertAt!) < _telemetryInterval) {
        return;
      }
      _lastTelemetryInsertAt = now;
      storage.insertTelemetry(deviceId: deviceId, reading: reading);
    });
  }

  Future<void> dispose() async {
    await _feedStatusSub?.cancel();
    await _feedAlertSub?.cancel();
    await _hopperWeightSub?.cancel();
  }
}
