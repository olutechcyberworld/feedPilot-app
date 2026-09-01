// lib/screens/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../models/feed_status.dart';
import '../../models/system_health.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/mqtt_provider.dart';
import '../../widgets/connectivity_badge.dart';

/// FeedPilot Dashboard — live telemetry hub.
/// Factory spec: MATERIAL_3 dark | MIXED layout.
///
/// Data pattern: each card receives nullable model data derived via
/// AsyncValue.valueOrNull. Null produces a '-' placeholder in the value
/// slot — the card header/label is always visible regardless of data state.
/// No loading spinner ever replaces a card title.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(deviceIdProvider) ?? '';

    // ── Resolve all stream values — null when loading or error ──────────────
    final weight = ref.watch(hopperWeightStreamProvider).valueOrNull;
    final stock = ref.watch(hopperStockStreamProvider).valueOrNull;
    final feedStatus = ref.watch(feedStatusStreamProvider).valueOrNull;
    final health = ref.watch(systemHealthStreamProvider).valueOrNull;
    final tierAsync = ref.watch(connectivityTierStreamProvider);

    final tier = tierAsync.when(
      data: (t) => t,
      loading: () => ConnectivityTier.deviceOffline,
      error: (_, __) => ConnectivityTier.deviceOffline,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/app_icon.png',
              width: 26,
              height: 26,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.agriculture,
                color: AppTheme.primaryGreenLight,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text('FeedPilot'),
          ],
        ),
        actions: [
          ConnectivityBadge(tier: tier),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // ── Device ID sub-header ───────────────────────────────────────────
          if (deviceId.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppTheme.surfaceDark,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.memory,
                      size: 12, color: AppTheme.onSurfaceTertiary),
                  const SizedBox(width: 6),
                  Text(
                    'Device: $deviceId',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: AppTheme.outlineColor),

          // ── Scrollable card body ───────────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Hero: Hopper Weight
                      _HopperWeightHeroCard(weightKg: weight?.weightKg),
                      const SizedBox(height: 12),

                      // Stock Level
                      _StockCard(
                        stockKg: stock?.stockKg,
                        stockPercent: stock?.stockPercent,
                        baselineKg: stock?.restockBaselineKg,
                      ),
                      const SizedBox(height: 12),

                      // 2-column: Trough + Cycle State
                      Row(
                        children: [
                          Expanded(
                            child: _TroughStatusCard(
                              troughState: feedStatus?.troughState,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CycleStateCard(
                              cycleState: feedStatus?.cycleState,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Last Dispense
                      _LastDispenseCard(status: feedStatus),
                      const SizedBox(height: 12),

                      // System Health
                      _SystemHealthCard(health: health),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hopper Weight Hero Card ────────────────────────────────────────────────

class _HopperWeightHeroCard extends StatelessWidget {
  final double? weightKg;
  const _HopperWeightHeroCard({required this.weightKg});

  SensorStatus _status() {
    if (weightKg == null) return SensorStatus.offline;
    if (weightKg! > 2.0) return SensorStatus.safe;
    if (weightKg! > 0.8) return SensorStatus.warning;
    return SensorStatus.danger;
  }

  @override
  Widget build(BuildContext context) {
    final color = statusColor(_status());

    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Left accent bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 4,
                color: color,
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header — always visible
                  Row(
                    children: [
                      const Icon(Icons.scale_outlined,
                          size: 16, color: AppTheme.onSurfaceSecondary),
                      const SizedBox(width: 6),
                      Text('Hopper Weight',
                          style: Theme.of(context).textTheme.labelMedium),
                      const Spacer(),
                      _StatusDot(color: color),
                    ],
                  ),
                  const Spacer(),

                  // Value — '-' when null, animated when data arrives
                  weightKg == null
                      ? Text(
                          '-',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: AppTheme.onSurfaceTertiary,
                                fontWeight: FontWeight.w700,
                              ),
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: weightKg!),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          builder: (context, value, _) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  value.toStringAsFixed(2),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: AppTheme.onSurfacePrimary,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    'kg',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppTheme.onSurfaceSecondary,
                                        ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                  const SizedBox(height: 4),
                  Text(
                    'Live reading from load cell',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stock Level Card ───────────────────────────────────────────────────────

class _StockCard extends StatelessWidget {
  final double? stockKg;
  final int? stockPercent;
  final double? baselineKg;

  const _StockCard({
    required this.stockKg,
    required this.stockPercent,
    required this.baselineKg,
  });

  Color _barColor() {
    if (stockPercent == null) return AppTheme.onSurfaceTertiary;
    if (stockPercent! > 50) return AppTheme.statusOnline;
    if (stockPercent! > 20) return AppTheme.statusLocal;
    return AppTheme.statusOffline;
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _barColor();
    final fraction = ((stockPercent ?? 0) / 100).clamp(0.0, 1.0);
    final hasData = stockPercent != null;

    return _SensorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 16, color: AppTheme.onSurfaceSecondary),
              const SizedBox(width: 6),
              Text('Stock Remaining',
                  style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              hasData
                  ? TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                          begin: 0, end: stockPercent!.toDouble()),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, value, _) {
                        return Text(
                          '${value.toInt()}%',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: barColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                        );
                      },
                    )
                  : Text(
                      '-',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.onSurfaceTertiary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar — shows empty state at 0 when no data
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          Text(
            hasData
                ? '${stockKg!.toStringAsFixed(2)} kg remaining'
                    '${(baselineKg != null && baselineKg! > 0) ? ' of ${baselineKg!.toStringAsFixed(1)} kg baseline' : ''}'
                : '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ── Trough Status Card ─────────────────────────────────────────────────────

class _TroughStatusCard extends StatelessWidget {
  final TroughState? troughState;
  const _TroughStatusCard({required this.troughState});

  @override
  Widget build(BuildContext context) {
    final isEmpty = troughState == TroughState.empty;
    final hasData = troughState != null;

    final color = hasData
        ? (isEmpty ? AppTheme.statusOnline : AppTheme.statusWarning)
        : AppTheme.onSurfaceTertiary;
    final label = hasData ? (isEmpty ? 'Empty' : 'Feed Present') : '-';
    final icon = hasData
        ? (isEmpty ? Icons.check_circle_outline : Icons.warning_amber_outlined)
        : Icons.remove;

    return _SensorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          Row(
            children: [
              const Icon(Icons.water_outlined,
                  size: 16, color: AppTheme.onSurfaceSecondary),
              const SizedBox(width: 6),
              Text('Trough', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 16),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(
              key: ValueKey(troughState),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cycle State Card ───────────────────────────────────────────────────────

class _CycleStateCard extends StatelessWidget {
  final CycleState? cycleState;
  const _CycleStateCard({required this.cycleState});

  String _label() {
    if (cycleState == null) return '-';
    switch (cycleState!) {
      case CycleState.idle:
        return 'Idle';
      case CycleState.dispensing:
        return 'Dispensing';
      case CycleState.jam:
        return 'Jam';
      case CycleState.gateSealFail:
        return 'Gate Fault';
    }
  }

  Color _color() {
    if (cycleState == null) return AppTheme.onSurfaceTertiary;
    switch (cycleState!) {
      case CycleState.idle:
        return AppTheme.onSurfaceSecondary;
      case CycleState.dispensing:
        return AppTheme.statusOnline;
      case CycleState.jam:
        return AppTheme.statusOffline;
      case CycleState.gateSealFail:
        return AppTheme.statusOffline;
    }
  }

  IconData _icon() {
    if (cycleState == null) return Icons.remove;
    switch (cycleState!) {
      case CycleState.idle:
        return Icons.hourglass_empty_outlined;
      case CycleState.dispensing:
        return Icons.play_circle_outline;
      case CycleState.jam:
        return Icons.block_outlined;
      case CycleState.gateSealFail:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    return _SensorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          Row(
            children: [
              const Icon(Icons.sync_outlined,
                  size: 16, color: AppTheme.onSurfaceSecondary),
              const SizedBox(width: 6),
              Text('Cycle', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 16),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(
              key: ValueKey(cycleState),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon(), color: color, size: 28),
                const SizedBox(height: 6),
                Text(
                  _label(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Last Dispense Card ─────────────────────────────────────────────────────

class _LastDispenseCard extends StatelessWidget {
  final FeedStatus? status;
  const _LastDispenseCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final hasData = status != null;
    final hasFault = hasData && status!.lastDispense.fault;

    return _SensorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          Row(
            children: [
              const Icon(Icons.history_outlined,
                  size: 16, color: AppTheme.onSurfaceSecondary),
              const SizedBox(width: 6),
              Text('Last Dispense',
                  style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              if (hasFault)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.statusOffline.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppTheme.statusOffline.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'FAULT',
                    style: TextStyle(
                      color: AppTheme.statusOffline,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Values — '-' when no data
          Row(
            children: [
              _StatPill(
                label: 'Target',
                value: hasData ? '${status!.lastDispense.targetG} g' : '-',
                color: AppTheme.onSurfaceSecondary,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: 'Actual',
                value: hasData ? '${status!.lastDispense.actualG} g' : '-',
                color:
                    hasFault ? AppTheme.statusOffline : AppTheme.statusOnline,
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            (hasData && status!.lastDispense.timestamp != null)
                ? status!.lastDispense.timestamp!
                    .toLocal()
                    .toString()
                    .substring(0, 16)
                : '-',
            style: Theme.of(context).textTheme.labelSmall,
          ),

          if (hasData && status!.nextSchedule != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule_outlined,
                    size: 13, color: AppTheme.onSurfaceTertiary),
                const SizedBox(width: 4),
                Text(
                  'Next: ${status!.nextSchedule!.toLocal().toString().substring(0, 16)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── System Health Card ─────────────────────────────────────────────────────

class _SystemHealthCard extends StatelessWidget {
  final SystemHealth? health;
  const _SystemHealthCard({required this.health});

  @override
  Widget build(BuildContext context) {
    final hasData = health != null;
    final uptimeHours = hasData ? health!.uptimeSeconds ~/ 3600 : 0;
    final uptimeMins = hasData ? (health!.uptimeSeconds % 3600) ~/ 60 : 0;

    return _SensorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined,
                  size: 16, color: AppTheme.onSurfaceSecondary),
              const SizedBox(width: 6),
              Text('System Health',
                  style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              Text(
                hasData ? health!.tierLabel : '-',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.primaryGreenLight,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _StatPill(
                label: 'Uptime',
                value: hasData ? '${uptimeHours}h ${uptimeMins}m' : '-',
                color: AppTheme.onSurfaceSecondary,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: 'Firmware',
                value: hasData ? health!.firmwareVersion : '-',
                color: AppTheme.onSurfaceSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared primitives ──────────────────────────────────────────────────────

class _SensorCard extends StatelessWidget {
  final Widget child;
  const _SensorCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: child,
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.onSurfaceTertiary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

// ── Factory: SensorStatus + color map ─────────────────────────────────────

enum SensorStatus { safe, warning, danger, offline }

Color statusColor(SensorStatus status) {
  switch (status) {
    case SensorStatus.safe:
      return AppTheme.statusOnline;
    case SensorStatus.warning:
      return AppTheme.statusLocal;
    case SensorStatus.danger:
      return AppTheme.statusOffline;
    case SensorStatus.offline:
      return AppTheme.onSurfaceTertiary;
  }
}
