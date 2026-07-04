// lib/screens/control/control_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/system_health.dart';
import '../../providers/mqtt_provider.dart';
import '../../providers/connectivity_provider.dart';

class ControlScreen extends ConsumerWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(currentTierProvider);
    final mqttService = ref.watch(mqttServiceProvider);
    final restService = ref.watch(restServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Control')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Manual feed trigger
          FilledButton.icon(
            onPressed: tier == ConnectivityTier.deviceOffline
                ? null
                : () {
                    if (tier == ConnectivityTier.fullCloud ||
                        tier == ConnectivityTier.autonomous) {
                      mqttService?.publishFeedTrigger(portionGrams: 150);
                    } else {
                      restService.postFeedTrigger(portionGrams: 150);
                    }
                  },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Trigger Feed Now'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),

          // Restock confirmation
          OutlinedButton.icon(
            onPressed: tier == ConnectivityTier.deviceOffline
                ? null
                : () {
                    if (tier == ConnectivityTier.fullCloud ||
                        tier == ConnectivityTier.autonomous) {
                      mqttService?.publishHopperRestock(amountKg: 5.0);
                    } else {
                      restService.postRestock();
                    }
                  },
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Confirm Restock'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 32),
          Text(
            'Schedule configuration will be available in the next update.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
