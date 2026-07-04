// lib/providers/connectivity_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/system_health.dart';
import '../services/connectivity_service.dart';
import '../services/rest_service.dart';
import 'mqtt_provider.dart';

/// Provides the ConnectivityService instance.
final connectivityServiceProvider = Provider<ConnectivityService?>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  if (mqttService == null) return null;

  final service = ConnectivityService(mqttService: mqttService);
  service.init();

  ref.onDispose(() => service.dispose());

  return service;
});

/// Provides the RestService instance.
/// Activated and deactivated by the connectivity tier stream below.
final restServiceProvider = Provider<RestService>((ref) {
  final service = RestService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Exposes the active connectivity tier as a stream.
/// The Dashboard connectivity badge and the ConnectivityService
/// both consume this provider.
final connectivityTierStreamProvider = StreamProvider<ConnectivityTier>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  if (service == null) return const Stream.empty();

  // Side-effect: activate or deactivate RestService based on tier changes.
  // This is the wiring point between ConnectivityService and RestService.
  final restService = ref.watch(restServiceProvider);
  service.tierStream.listen((tier) {
    if (tier == ConnectivityTier.localRest) {
      restService.activate();
    } else {
      restService.deactivate();
    }
  });

  return service.tierStream;
});

/// Convenience provider that returns the last known tier synchronously.
/// Used by the Control screen to decide whether to use MQTT publish
/// or REST POST /control for manual feed commands.
final currentTierProvider = Provider<ConnectivityTier>((ref) {
  final tierAsync = ref.watch(connectivityTierStreamProvider);
  return tierAsync.when(
    data: (tier) => tier,
    loading: () => ConnectivityTier.deviceOffline,
    error: (_, __) => ConnectivityTier.deviceOffline,
  );
});
