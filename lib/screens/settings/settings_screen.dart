// lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/device_provider.dart';
import '../../routing/app_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(deviceIdProvider) ?? 'Not paired';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Device ID'),
            subtitle: Text(deviceId),
            leading: const Icon(Icons.memory),
          ),
          const Divider(),
          ListTile(
            title: const Text('Re-pair Device'),
            leading: const Icon(Icons.qr_code),
            onTap: () async {
              await clearStoredDeviceId();
              ref.read(deviceIdProvider.notifier).state = null;
              if (context.mounted) context.go(AppRoutes.setup);
            },
          ),
          ListTile(
            title: const Text('About FeedPilot'),
            leading: const Icon(Icons.info_outline),
            onTap: () => context.push(AppRoutes.about),
          ),
        ],
      ),
    );
  }
}
