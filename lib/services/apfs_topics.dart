// lib/services/apfs_topics.dart

/// Constructs all nine MQTT topic strings for the Automated Poultry
/// Feeding System, scoped to a specific device via its MAC-derived ID.
///
/// Instantiate once after the Setup screen validates and persists the
/// deviceId, then inject the instance into MQTTService as a constructor
/// dependency. No other file in the codebase may hardcode a topic string.
///
/// [deviceId] must be a 12-character uppercase hex string derived from
/// the ESP32 MAC address with colons stripped (e.g. "246F28ABCDEF").
/// The Setup screen enforces this format via regex ^[0-9A-F]{12}$ before
/// constructing this instance.
class APFSTopics {
  final String deviceId;

  const APFSTopics(this.deviceId);

  // ── Telemetry — Node → App (subscribe, QoS 1) ─────────────────────────────

  /// Live hopper weight in kg published after every HX711 read cycle.
  /// Payload: { "weight_kg": double, "timestamp": ISO8601 }
  String get hopperWeight => 'farm/$deviceId/hopper/weight';

  /// Software-tracked remaining stock estimate after each dispense cycle.
  /// Payload: { "stock_kg": double, "stock_percent": int,
  ///            "restock_baseline_kg": double, "timestamp": ISO8601 }
  String get hopperStock => 'farm/$deviceId/hopper/stock';

  /// Feed cycle state, last dispense result, next schedule, trough state.
  /// Payload: { "last_dispense": {...}, "next_schedule": ISO8601,
  ///            "cycle_state": String, "trough_state": String }
  /// cycle_state values : IDLE | DISPENSING | JAM | GATE_SEAL_FAIL
  /// trough_state values: EMPTY | FEED_PRESENT
  String get feedStatus => 'farm/$deviceId/feed/status';

  /// Alert events published by the firmware on fault or threshold breach.
  /// Payload: { "type": String, "message": String,
  ///            "stock_kg": double?, "timestamp": ISO8601 }
  /// type values: HOPPER_LOW | TROUGH_FULL_SKIP | DISPENSE_JAM |
  ///              GATE_SEAL_FAIL | CALIBRATION_WARNING
  String get feedAlerts => 'farm/$deviceId/feed/alerts';

  /// Device health telemetry and LWT topic.
  /// Live payload  : { "uptime_s": int, "connectivity_tier": int,
  ///                   "firmware_version": String, "timestamp": ISO8601 }
  /// LWT payload   : { "uptime_s": 0, "connectivity_tier": 0,
  ///                   "firmware_version": "1.0.0",
  ///                   "status": "DEVICE_OFFLINE", "timestamp": "—" }
  /// connectivity_tier: 0 = DEVICE_OFFLINE (LWT sentinel)
  ///                    1 = Autonomous | 2 = Local REST | 3 = Full cloud
  String get systemHealth => 'farm/$deviceId/system/health';

  /// Device local IP and mDNS hostname, published retained at boot.
  /// Payload: { "ip": String, "hostname": "farm.local" }
  String get systemLocalIp => 'farm/$deviceId/system/local_ip';

  // ── Commands — App → Node (publish, QoS 2) ────────────────────────────────

  /// Manual dispense trigger. Executes 8-step gravimetric cycle immediately.
  /// Payload: { "command": "FEED", "portion_g": int, "source": "MANUAL" }
  String get feedTrigger => 'farm/$deviceId/feed/trigger';

  /// Schedule table, portion size, and low-stock threshold configuration.
  /// Payload: { "schedules": [ { "time": "HH:mm", "days": [1–7],
  ///            "portion_g": int } ], "hopper_low_threshold_kg": double,
  ///            "portion_g": int }
  /// days uses ISO weekday numbering: 1 = Monday, 7 = Sunday.
  String get feedConfig => 'farm/$deviceId/feed/config';

  /// Farmer confirms physical hopper refill. Node resets stock estimate
  /// to the current HX711 reading.
  /// Payload: { "command": "RESTOCK", "amount_kg": double }
  String get hopperRestock => 'farm/$deviceId/hopper/restock';

  String get feedAck => 'farm/$deviceId/feed/ack';

  // ── Diagnostic ────────────────────────────────────────────────────────────

  /// Wildcard subscription covering all nine topics for this device.
  /// For diagnostic / MQTT Explorer use only — do not subscribe to this
  /// in production MQTTService code. Use individual getters above so that
  /// QoS levels are applied correctly per topic.
  String get allTopics => 'farm/$deviceId/#';
}
