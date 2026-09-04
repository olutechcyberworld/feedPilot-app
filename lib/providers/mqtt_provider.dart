// lib/providers/mqtt_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/apfs_topics.dart';
import '../services/mqtt_service.dart';
import '../models/hopper_weight.dart';
import '../models/hopper_stock.dart';
import '../models/feed_status.dart';
import '../models/feed_alert.dart';
import '../models/system_health.dart';
import '../models/local_ip.dart';
import 'device_provider.dart';
import '../models/feed_ack.dart';

/// Provides the APFSTopics instance scoped to the current deviceId.
/// Rebuilds automatically if deviceId changes (re-pair flow).
final apfsTopicsProvider = Provider<APFSTopics?>((ref) {
  final deviceId = ref.watch(deviceIdProvider);
  if (deviceId == null) return null;
  return APFSTopics(deviceId);
});

/// Provides the MqttService instance. Disposed when the provider
/// is no longer needed, which closes all stream controllers and
/// disconnects from the broker cleanly.
final mqttServiceProvider = Provider<MqttService?>((ref) {
  final topics = ref.watch(apfsTopicsProvider);
  final deviceId = ref.watch(deviceIdProvider);

  if (topics == null || deviceId == null) return null;

  final service = MqttService(topics: topics, deviceId: deviceId);

  // Start the connection as soon as the service exists. Without this,
  // the service sits fully wired (topics, streams, providers all watching)
  // but never actually opens a socket to the broker. connect() is safe to
  // call here — it early-returns if already connecting/connected, and this
  // provider only rebuilds when deviceId changes (re-pair), which is
  // exactly when a fresh connection is wanted.
  service.connect();

  ref.onDispose(() => service.dispose());

  return service;
});

// ── Stream providers — one per telemetry topic ─────────────────────────────
// Each StreamProvider exposes the corresponding MqttService stream.
// The UI layer consumes these via ref.watch() — no direct MqttService
// references exist in any screen or widget file.

final hopperWeightStreamProvider = StreamProvider<HopperWeight>((ref) {
  final service = ref.watch(mqttServiceProvider);
  if (service == null) return const Stream.empty();
  return service.hopperWeightStream;
});

final hopperStockStreamProvider = StreamProvider<HopperStock>((ref) {
  final service = ref.watch(mqttServiceProvider);
  if (service == null) return const Stream.empty();
  return service.hopperStockStream;
});

final feedStatusStreamProvider = StreamProvider<FeedStatus>((ref) {
  final service = ref.watch(mqttServiceProvider);
  if (service == null) return const Stream.empty();
  return service.feedStatusStream;
});

final feedAlertStreamProvider = StreamProvider<FeedAlert>((ref) {
  final service = ref.watch(mqttServiceProvider);
  if (service == null) return const Stream.empty();
  return service.feedAlertStream;
});

final systemHealthStreamProvider = StreamProvider<SystemHealth>((ref) {
  final service = ref.watch(mqttServiceProvider);
  if (service == null) return const Stream.empty();
  return service.systemHealthStream;
});

final localIpStreamProvider = StreamProvider<LocalIp>((ref) {
  final service = ref.watch(mqttServiceProvider);
  if (service == null) return const Stream.empty();
  return service.localIpStream;
});

final mqttConnectionStateStreamProvider =
    StreamProvider<MqttServiceState>((ref) {
  final service = ref.watch(mqttServiceProvider);
  if (service == null) return const Stream.empty();
  return service.connectionStateStream;
});

final feedAckStreamProvider = StreamProvider<FeedAck>((ref) {
  final service = ref.watch(mqttServiceProvider);
  if (service == null) return const Stream.empty();
  return service.feedAckStream;
});
