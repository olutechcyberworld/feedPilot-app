// lib/services/schedule_config_storage.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last schedule config the app successfully sent to a
/// device, keyed by deviceId.
///
/// This exists because the locked MQTT schema has no node-to-app topic
/// that reports current config back — feed/config is App -> Node only.
/// Without this, the Control screen's schedule list would silently
/// reset to empty every time it's left and reopened, even though the
/// device is still running whatever was last saved.
class ScheduleConfigStorage {
  static String _key(String deviceId) => 'schedule_config_$deviceId';

  static Future<void> save({
    required String deviceId,
    required List<Map<String, dynamic>> schedules,
    required double hopperLowThresholdKg,
    required int defaultPortionG,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'schedules': schedules,
      'hopper_low_threshold_kg': hopperLowThresholdKg,
      'default_portion_g': defaultPortionG,
    });
    await prefs.setString(_key(deviceId), payload);
  }

  static Future<Map<String, dynamic>?> load(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(deviceId));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
