// lib/services/connectivity_service.dart

import 'dart:async';
import '../models/system_health.dart';
import '../services/mqtt_service.dart';

/// Determines the active connectivity tier by observing the MqttService
/// connection state and the last received SystemHealth payload.
///
/// Tier 0 — DEVICE_OFFLINE : LWT received on system/health topic.
/// Tier 1 — Autonomous     : Device is operating but no cloud MQTT.
/// Tier 2 — Local REST     : Cloud MQTT lost; farm WiFi available.
///                           RestService is activated by this service.
/// Tier 3 — Full Cloud     : Full HiveMQ MQTT connectivity confirmed
///                           by live firmware health publish.
///
/// ConnectivityService does not make HTTP requests itself. It determines
/// the tier and exposes it via stream. RestService is responsible for
/// its own HTTP lifecycle. The provider layer wires the two together.
class ConnectivityService {
  final MqttService mqttService;

  ConnectivityService({required this.mqttService});

  // ── Internal state ─────────────────────────────────────────────────────────

  ConnectivityTier _currentTier = ConnectivityTier.deviceOffline;
  StreamSubscription<SystemHealth>? _healthSubscription;
  StreamSubscription<MqttServiceState>? _mqttStateSubscription;

  final _tierController = StreamController<ConnectivityTier>.broadcast();

  // ── Public API ─────────────────────────────────────────────────────────────

  Stream<ConnectivityTier> get tierStream => _tierController.stream;
  ConnectivityTier get currentTier => _currentTier;

  // ── Initialisation ─────────────────────────────────────────────────────────

  void init() {
    // Watch MQTT connection state changes.
    // When MQTT disconnects, we cannot determine tier from health payloads,
    // so we drop to Tier 2 optimistically (farm WiFi may still be available)
    // and let the RestService probe confirm or deny local access.
    _mqttStateSubscription = mqttService.connectionStateStream.listen(
      (state) {
        if (state == MqttServiceState.disconnected ||
            state == MqttServiceState.reconnecting) {
          _setTier(ConnectivityTier.localRest);
        }
        // connected state defers to the health payload for final tier
        // assignment, since the firmware tier field is the authoritative
        // source. We do not assume Tier 3 on MQTT connect alone.
      },
    );

    // Watch live system health payloads.
    // The firmware publishes its own connectivity_tier in this payload,
    // which is the authoritative source for tier classification.
    _healthSubscription = mqttService.systemHealthStream.listen(
      (health) {
        if (health.isOfflineLwt) {
          _setTier(ConnectivityTier.deviceOffline);
        } else {
          _setTier(health.connectivityTier);
        }
      },
    );
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _setTier(ConnectivityTier tier) {
    if (_currentTier == tier) return; // no change, no emit
    _currentTier = tier;
    _tierController.add(tier);
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _healthSubscription?.cancel();
    await _mqttStateSubscription?.cancel();
    await _tierController.close();
  }
}
