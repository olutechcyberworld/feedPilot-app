// lib/providers/device_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the validated 12-character uppercase hex deviceId persisted
/// by the Setup screen. Null means no device has been paired yet —
/// the router redirects to /setup in this state.
final deviceIdProvider = StateProvider<String?>((ref) => null);

/// Loads the persisted deviceId from SharedPreferences at app startup.
/// Called once from main.dart before the widget tree builds.
/// Returns the stored value or null if no device has been paired.
Future<String?> loadStoredDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('device_id');
}

/// Persists the validated deviceId to SharedPreferences.
/// Called by the Setup screen after validation succeeds.
Future<void> persistDeviceId(String deviceId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('device_id', deviceId);
}

/// Clears the stored deviceId. Called by the Settings screen
/// when the farmer triggers the re-pair device option.
Future<void> clearStoredDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('device_id');
}
