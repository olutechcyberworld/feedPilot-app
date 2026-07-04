// lib/widgets/connectivity_badge.dart

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../models/system_health.dart';

/// Connectivity tier indicator rendered in the Dashboard AppBar.
/// Factory spec: MATERIAL_3 dark | HYBRID transform.
/// Displays a filled dot + label reflecting the active connectivity tier.
///
/// Tier 3 — full cloud MQTT  : green  dot · "Online"
/// Tier 2 — local REST/mDNS  : amber  dot · "Local"
/// Tier 1 — autonomous/RTC   : blue   dot · "Auto"
/// Tier 0 — device offline   : red    dot · "Offline"
class ConnectivityBadge extends StatelessWidget {
  final ConnectivityTier tier;

  const ConnectivityBadge({super.key, required this.tier});

  Color _dotColor() {
    switch (tier) {
      case ConnectivityTier.fullCloud:
        return AppTheme.statusOnline;
      case ConnectivityTier.localRest:
        return AppTheme.statusLocal;
      case ConnectivityTier.autonomous:
        return AppTheme.statusAuto;
      case ConnectivityTier.deviceOffline:
        return AppTheme.statusOffline;
    }
  }

  String _label() {
    switch (tier) {
      case ConnectivityTier.fullCloud:
        return 'Online';
      case ConnectivityTier.localRest:
        return 'Local';
      case ConnectivityTier.autonomous:
        return 'Auto';
      case ConnectivityTier.deviceOffline:
        return 'Offline';
    }
  }

  String _tooltip() {
    switch (tier) {
      case ConnectivityTier.fullCloud:
        return 'Tier 3 — Cloud MQTT connected';
      case ConnectivityTier.localRest:
        return 'Tier 2 — Local network only';
      case ConnectivityTier.autonomous:
        return 'Tier 1 — Device running autonomously';
      case ConnectivityTier.deviceOffline:
        return 'Tier 0 — Device offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _dotColor();

    return Tooltip(
      message: _tooltip(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated dot — pulses color change with AnimatedContainer
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 7,
              height: 7,
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
            ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _label(),
                key: ValueKey(_label()),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
