// lib/models/system_health.dart

/// connectivity_tier values per the locked MQTT schema:
/// 0 = DEVICE_OFFLINE (LWT sentinel — published by broker on abnormal disconnect)
/// 1 = Autonomous     (RTC-driven local operation, no network)
/// 2 = Local REST     (farm WiFi available, cloud MQTT unavailable)
/// 3 = Full Cloud     (full HiveMQ MQTT connectivity)
enum ConnectivityTier {
  deviceOffline, // tier 0
  autonomous, // tier 1
  localRest, // tier 2
  fullCloud, // tier 3
}

class SystemHealth {
  final int uptimeSeconds;
  final ConnectivityTier connectivityTier;
  final String firmwareVersion;
  final bool isOfflineLwt;
  final DateTime? timestamp;

  const SystemHealth({
    required this.uptimeSeconds,
    required this.connectivityTier,
    required this.firmwareVersion,
    required this.isOfflineLwt,
    this.timestamp,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    final tierInt = json['connectivity_tier'] as int;
    // The LWT payload carries "status": "DEVICE_OFFLINE" and tier 0.
    // Live firmware payloads carry no "status" field.
    final bool isLwt = tierInt == 0 && json['status'] == 'DEVICE_OFFLINE';

    return SystemHealth(
      uptimeSeconds: json['uptime_s'] as int,
      connectivityTier: _parseTier(tierInt),
      firmwareVersion: json['firmware_version'] as String,
      isOfflineLwt: isLwt,
      timestamp: json['timestamp'] != null && json['timestamp'] != '—'
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }

  static ConnectivityTier _parseTier(int tier) {
    switch (tier) {
      case 1:
        return ConnectivityTier.autonomous;
      case 2:
        return ConnectivityTier.localRest;
      case 3:
        return ConnectivityTier.fullCloud;
      case 0:
      default:
        return ConnectivityTier.deviceOffline;
    }
  }

  /// Display string for the Dashboard connectivity tier indicator.
  String get tierLabel {
    switch (connectivityTier) {
      case ConnectivityTier.deviceOffline:
        return 'Device Offline';
      case ConnectivityTier.autonomous:
        return 'Autonomous';
      case ConnectivityTier.localRest:
        return 'Local Network';
      case ConnectivityTier.fullCloud:
        return 'Cloud Connected';
    }
  }
}
