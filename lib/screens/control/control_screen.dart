// lib/screens/control/control_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/system_health.dart';
import '../../models/feed_alert.dart';
import '../../models/feed_status.dart';
import '../../providers/mqtt_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/device_provider.dart';
import '../../services/schedule_config_storage.dart';

/// Result of waiting for a triggered dispense cycle to actually
/// conclude, as opposed to just being acknowledged as received. See
/// _ControlScreenState._awaitDispenseOutcome for why this exists.
enum _DispenseOutcomeKind { success, failure, unknown }

class _DispenseOutcome {
  final _DispenseOutcomeKind kind;
  final int? actualG;
  final String? failureMessage;

  const _DispenseOutcome.success(this.actualG)
      : kind = _DispenseOutcomeKind.success,
        failureMessage = null;
  const _DispenseOutcome.failure(this.failureMessage)
      : kind = _DispenseOutcomeKind.failure,
        actualG = null;
  const _DispenseOutcome.unknown()
      : kind = _DispenseOutcomeKind.unknown,
        actualG = null,
        failureMessage = null;
}

class _ScheduleDraft {
  TimeOfDay time;
  Set<int> days; // 1=Monday .. 7=Sunday, matches firmware daysMask convention
  int portionG;

  _ScheduleDraft(
      {required this.time, required this.days, required this.portionG});

  Map<String, dynamic> toJson() => {
        'time':
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        'days': days.toList()..sort(),
        'portion_g': portionG,
      };
}

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> {
  bool _feedTriggerBusy = false;
  bool _restockBusy = false;
  bool _scheduleSaveBusy = false;

  final _defaultPortionController = TextEditingController(text: '150');
  final _thresholdController = TextEditingController(text: '1.0');
  final List<_ScheduleDraft> _schedules = [];

  static const int _maxSchedules =
      8; // matches firmware FeedConfigData::MAX_SCHEDULES

  @override
  void initState() {
    super.initState();
    _loadPersistedSchedule();
  }

  @override
  void dispose() {
    _defaultPortionController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedSchedule() async {
    final deviceId = ref.read(deviceIdProvider);
    if (deviceId == null) return;
    final saved = await ScheduleConfigStorage.load(deviceId);
    if (saved == null || !mounted) return;

    setState(() {
      _defaultPortionController.text =
          (saved['default_portion_g'] as num?)?.toString() ?? '150';
      _thresholdController.text =
          (saved['hopper_low_threshold_kg'] as num?)?.toString() ?? '1.0';
      _schedules
        ..clear()
        ..addAll((saved['schedules'] as List<dynamic>? ?? []).map((e) {
          final map = e as Map<String, dynamic>;
          final timeParts = (map['time'] as String? ?? '00:00').split(':');
          return _ScheduleDraft(
            time: TimeOfDay(
              hour: int.tryParse(timeParts[0]) ?? 0,
              minute: int.tryParse(timeParts[1]) ?? 0,
            ),
            days: (map['days'] as List<dynamic>? ?? [])
                .map((d) => d as int)
                .toSet(),
            portionG: (map['portion_g'] as num?)?.toInt() ?? 150,
          );
        }));
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Publishes over MQTT, then waits for a matching feed/ack event (up
  /// to 5s). Resolves once the device confirms RECEIPT only — this
  /// does NOT mean the command succeeded, just that it arrived. Callers
  /// that need the actual outcome of a FEED trigger must follow this
  /// with _awaitDispenseOutcome; RESTOCK/CONFIG have no equivalent
  /// async completion beyond "applied", so ack alone is sufficient for
  /// those two.
  Future<bool> _publishAndAwaitAck({
    required String expectedCommand,
    required VoidCallback publish,
  }) async {
    final mqttService = ref.read(mqttServiceProvider);
    if (mqttService == null) return false;

    final completer = Completer<bool>();
    final sub = mqttService.feedAckStream.listen((ack) {
      if (ack.command == expectedCommand && !completer.isCompleted) {
        completer.complete(true);
      }
    });

    publish();

    final acked = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );
    await sub.cancel();
    return acked;
  }

  /// Alert types that represent the OUTCOME of a dispense attempt, as
  /// opposed to independent, threshold-driven alerts (HOPPER_LOW) or
  /// alerts belonging to a different command (CALIBRATION_WARNING,
  /// fired by RESTOCK). Only these are eligible to resolve a pending
  /// feed trigger — anything else arriving during the wait window is
  /// unrelated background noise, not this command's result.
  static const _dispenseOutcomeAlertTypes = {
    AlertType.insufficientStock,
    AlertType.dispenseJam,
    AlertType.troughFullSkip,
    AlertType.gateSealFail,
    AlertType.hopperSensorFault,
  };

  /// Waits for the first real signal that a just-triggered dispense
  /// cycle has actually concluded — success or failure — instead of
  /// treating feed/ack's "RECEIVED" as the final word.
  ///
  /// The ack only proves the device got the request; it fires before
  /// the device has attempted anything. Without this, a trigger sent
  /// to an empty hopper acked normally and then silently dispensed
  /// nothing, with no feedback distinguishing that from success.
  ///
  /// Correlates by TIMESTAMP against [sentAt], not by a request ID —
  /// the MQTT schema doesn't carry one (flagged in the reference card
  /// addendum; a real fix needs a firmware schema change). This is
  /// deliberately just enough to reject a stale alert or status
  /// replayed from the firmware's NVS ring buffer on reconnect, which
  /// would otherwise resolve THIS trigger using a leftover record
  /// from a previous one.
  ///
  /// Timeout covers the firmware's worst realistic case:
  /// JAM_NO_DROP_TIMEOUT_MS (5s) or DISPENSE_VERIFY_SETTLE_MS +
  /// GATE_SEAL_FAIL_TIMEOUT_MS (2s + 3s), plus feed/status's 2s
  /// republish cadence as margin. If nothing arrives in that window,
  /// the device genuinely hasn't confirmed anything — that's the one
  /// case "no response" should actually describe.
  Future<_DispenseOutcome> _awaitDispenseOutcome(DateTime sentAt) async {
    final mqttService = ref.read(mqttServiceProvider);
    if (mqttService == null) return const _DispenseOutcome.unknown();

    final completer = Completer<_DispenseOutcome>();

    final alertSub = mqttService.feedAlertStream.listen((alert) {
      if (completer.isCompleted) return;
      if (!_dispenseOutcomeAlertTypes.contains(alert.type)) return;
      if (alert.timestamp.isBefore(sentAt)) return; // stale/replayed
      completer.complete(_DispenseOutcome.failure(alert.displayLabel));
    });

    final statusSub = mqttService.feedStatusStream.listen((status) {
      if (completer.isCompleted) return;
      if (status.cycleState != CycleState.idle) return;
      final ts = status.lastDispense.timestamp;
      if (ts == null || ts.isBefore(sentAt)) return; // no fresh dispense yet
      completer.complete(_DispenseOutcome.success(status.lastDispense.actualG));
    });

    final outcome = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => const _DispenseOutcome.unknown(),
    );

    await alertSub.cancel();
    await statusSub.cancel();
    return outcome;
  }

  Future<void> _triggerFeed(ConnectivityTier tier) async {
    setState(() => _feedTriggerBusy = true);
    final mqttService = ref.read(mqttServiceProvider);
    final restService = ref.read(restServiceProvider);
    final portion = int.tryParse(_defaultPortionController.text) ?? 150;

    if (tier == ConnectivityTier.fullCloud) {
      final sentAt = DateTime.now();
      final acked = await _publishAndAwaitAck(
        expectedCommand: 'FEED',
        publish: () => mqttService?.publishFeedTrigger(portionGrams: portion),
      );

      if (!acked) {
        // Genuinely true now: the device never even confirmed receipt.
        if (!mounted) return;
        setState(() => _feedTriggerBusy = false);
        _showSnack('No response from device — check connection.');
        return;
      }

      // Ack only proves the command arrived — it fires before the
      // device has attempted anything. Stay busy and wait for the
      // actual result instead of declaring success here.
      _showSnack('Device received command — dispensing...');
      final outcome = await _awaitDispenseOutcome(sentAt);

      if (!mounted) return;
      setState(() => _feedTriggerBusy = false);

      switch (outcome.kind) {
        case _DispenseOutcomeKind.success:
          _showSnack('Dispensed ${outcome.actualG}g.');
          break;
        case _DispenseOutcomeKind.failure:
          _showSnack('Feed not dispensed: ${outcome.failureMessage}');
          break;
        case _DispenseOutcomeKind.unknown:
          _showSnack(
              'Command sent, but device did not confirm the result — check the dashboard.');
          break;
      }
    } else {
      // Tier 2 (REST) has the same underlying gap: POST /control's
      // ACCEPTED response only means the device queued the command,
      // not that anything was dispensed, and RestService does not yet
      // surface cycle_state/feed/alerts equivalents from /sensors to
      // resolve it the way the MQTT path above does. Said honestly
      // here rather than reusing the old, now-inaccurate wording.
      final ok = await restService.postFeedTrigger(portionGrams: portion);
      if (!mounted) return;
      setState(() => _feedTriggerBusy = false);
      _showSnack(ok
          ? 'Feed command accepted by device (outcome not confirmed on this connection tier).'
          : 'No response from device — check connection.');
    }
  }

  Future<void> _confirmRestock(ConnectivityTier tier) async {
    final amountText = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Confirm Restock'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Amount added (kg)',
              hintText: 'e.g. 5.0',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (amountText == null) return; // cancelled
    final amountKg = double.tryParse(amountText);
    if (amountKg == null || amountKg <= 0) {
      _showSnack('Enter a valid amount before confirming.');
      return;
    }

    setState(() => _restockBusy = true);
    final mqttService = ref.read(mqttServiceProvider);
    final restService = ref.read(restServiceProvider);

    bool ok;
    if (tier == ConnectivityTier.fullCloud) {
      ok = await _publishAndAwaitAck(
        expectedCommand: 'RESTOCK',
        publish: () => mqttService?.publishHopperRestock(amountKg: amountKg),
      );
    } else {
      ok = await restService.postRestock(amountKg: amountKg);
    }

    if (!mounted) return;
    setState(() => _restockBusy = false);
    _showSnack(ok
        ? 'Restock of ${amountKg.toStringAsFixed(1)}kg recorded.'
        : 'No response from device — check connection.');
  }

  Future<void> _addScheduleEntry() async {
    if (_schedules.length >= _maxSchedules) {
      _showSnack('Maximum of $_maxSchedules schedule entries reached.');
      return;
    }

    TimeOfDay pickedTime = TimeOfDay.now();
    final Set<int> pickedDays = {};
    final portionController = TextEditingController(text: '150');

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Schedule'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Time: ${pickedTime.format(context)}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: pickedTime);
                        if (t != null) setDialogState(() => pickedTime = t);
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text('Days'),
                    Wrap(
                      spacing: 6,
                      children: List.generate(7, (i) {
                        final dayNum = i + 1; // 1=Monday .. 7=Sunday
                        final selected = pickedDays.contains(dayNum);
                        return FilterChip(
                          label: Text(dayLabels[i]),
                          selected: selected,
                          onSelected: (v) => setDialogState(() {
                            if (v) {
                              pickedDays.add(dayNum);
                            } else {
                              pickedDays.remove(dayNum);
                            }
                          }),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: portionController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Portion (g)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Add')),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    if (pickedDays.isEmpty) {
      _showSnack('Select at least one day.');
      return;
    }

    setState(() {
      _schedules.add(_ScheduleDraft(
        time: pickedTime,
        days: pickedDays,
        portionG: int.tryParse(portionController.text) ?? 150,
      ));
    });
  }

  Future<void> _saveSchedule(ConnectivityTier tier) async {
    setState(() => _scheduleSaveBusy = true);
    final mqttService = ref.read(mqttServiceProvider);
    final restService = ref.read(restServiceProvider);
    final deviceId = ref.read(deviceIdProvider);

    final schedulesJson = _schedules.map((s) => s.toJson()).toList();
    final defaultPortion = int.tryParse(_defaultPortionController.text) ?? 150;
    final threshold = double.tryParse(_thresholdController.text) ?? 1.0;

    bool ok;
    if (tier == ConnectivityTier.fullCloud) {
      ok = await _publishAndAwaitAck(
        expectedCommand: 'CONFIG',
        publish: () => mqttService?.publishFeedConfig(
          schedules: schedulesJson,
          hopperLowThresholdKg: threshold,
          portionGrams: defaultPortion,
        ),
      );
    } else if (tier == ConnectivityTier.localRest) {
      ok = await restService.postConfig(
        schedules: schedulesJson,
        hopperLowThresholdKg: threshold,
        portionGrams: defaultPortion,
      );
    } else {
      ok =
          false; // autonomous / deviceOffline — no transport reaches the device
    }

    if (ok && deviceId != null) {
      await ScheduleConfigStorage.save(
        deviceId: deviceId,
        schedules: schedulesJson,
        hopperLowThresholdKg: threshold,
        defaultPortionG: defaultPortion,
      );
    }

    if (!mounted) return;
    setState(() => _scheduleSaveBusy = false);
    _showSnack(ok
        ? 'Schedule saved to device.'
        : (tier == ConnectivityTier.deviceOffline
            ? 'Device is offline — cannot save schedule.'
            : 'No response from device — check connection.'));
  }

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(currentTierProvider);
    final offline = tier == ConnectivityTier.deviceOffline;

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      appBar: AppBar(title: const Text('Control')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _defaultPortionController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Portion size (g)'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                (offline || _feedTriggerBusy) ? null : () => _triggerFeed(tier),
            icon: _feedTriggerBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_feedTriggerBusy
                ? 'Waiting for device...'
                : 'Trigger Feed Now'),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed:
                (offline || _restockBusy) ? null : () => _confirmRestock(tier),
            icon: _restockBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.inventory_2_outlined),
            label: Text(
                _restockBusy ? 'Waiting for device...' : 'Confirm Restock'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const Divider(height: 48),
          Text('Feed Schedule', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _thresholdController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Low-stock threshold (kg)'),
          ),
          const SizedBox(height: 16),
          ..._schedules.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final dayStr = (s.days.toList()..sort())
                .map((d) => dayLabels[d - 1])
                .join(', ');
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text('${s.time.format(context)} — ${s.portionG}g'),
              subtitle: Text(dayStr),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _schedules.removeAt(i)),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: offline ? null : _addScheduleEntry,
            icon: const Icon(Icons.add),
            label: const Text('Add Schedule Entry'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (offline || _scheduleSaveBusy || _schedules.isEmpty)
                ? null
                : () => _saveSchedule(tier),
            icon: _scheduleSaveBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
                _scheduleSaveBusy ? 'Saving...' : 'Save Schedule to Device'),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }
}
