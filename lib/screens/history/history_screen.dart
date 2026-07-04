// lib/screens/history/history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/storage_provider.dart';
import '../../providers/device_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(deviceIdProvider) ?? '';
    final records = ref.watch(feedRecordsProvider(deviceId));

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: records.when(
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('No feed records yet.'))
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return ListTile(
                    title: Text('${row['actual_g']} g dispensed'),
                    subtitle: Text(row['timestamp'].toString()),
                    trailing: row['fault'] == 1
                        ? const Icon(Icons.warning, color: Colors.orange)
                        : const Icon(Icons.check_circle, color: Colors.green),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
