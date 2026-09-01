// lib/config/mqtt_config.dart

class MqttConfig {
  MqttConfig._(); // prevent instantiation — constants class only

  // ── Broker ────────────────────────────────────────────────────────────────
  static const String brokerHost = String.fromEnvironment(
    'MQTT_BROKER_HOST',
    defaultValue: '',
  );
  static const int brokerPort = 8883;
  static const bool tlsEnabled = true;

  // ── Shared credential ─────────────────────────────────────────────────────
  // Single HiveMQ credential used by both the ESP32 firmware and the
  // Flutter app. Session collision is avoided not by separate credentials
  // but by distinct MQTT Client IDs (see appClientId / nodeClientId below).
  // MQTT 3.1.1 enforces Client ID uniqueness per session, not credential
  // uniqueness — two connections with the same username/password but
  // different Client IDs coexist without conflict.
  static const String brokerUsername = String.fromEnvironment(
    'MQTT_USERNAME',
    defaultValue: '',
  );
  static const String brokerPassword = String.fromEnvironment(
    'MQTT_PASSWORD',
    defaultValue: '',
  );

  // ── Connection behaviour ──────────────────────────────────────────────────
  static const int keepAliveSeconds = 60;
  static const bool cleanSession = false;
  // cleanSession false: broker queues QoS 1 messages during offline window
  // (up to 24 hours on HiveMQ Free Tier) and delivers on reconnect

  // ── Client ID factories ───────────────────────────────────────────────────
  // deviceId is the 12-character uppercase hex MAC string from the Setup screen.
  // appClientId is used directly by this Flutter app's MQTTService.
  // nodeClientId is documented for reference only — the ESP32 firmware
  // constructs its own Client ID independently in its own codebase.
  static String appClientId(String deviceId) => 'feedpilot-app-$deviceId';
  static String nodeClientId(String deviceId) => 'feedpilot-node-$deviceId';

  // ── Reconnect backoff ─────────────────────────────────────────────────────
  static const int reconnectInitialDelaySeconds = 5;
  static const int reconnectMaxDelaySeconds = 300;

  // ── QoS levels ────────────────────────────────────────────────────────────
  static const int qosTelemetry = 1; // Node → App
  static const int qosCommands = 2; // App → Node

  // ── Startup validation ────────────────────────────────────────────────────
  // Runtime check — NOT gated behind assert(), because assert() is stripped
  // in release builds. A missing .env at release-build time must fail the
  // same visible way in every build mode, or it fails silently exactly when
  // there's no debugger attached to catch it (e.g. a demo/exam build).
  static bool get isConfigured =>
      brokerHost.isNotEmpty &&
      brokerUsername.isNotEmpty &&
      brokerPassword.isNotEmpty;
}
