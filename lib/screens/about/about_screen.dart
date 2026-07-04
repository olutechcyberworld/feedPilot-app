// lib/screens/about/about_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../providers/device_provider.dart';

/// FeedPilot About screen.
/// Factory spec: MATERIAL_3 dark | branded, three-card layout.
/// Card 1: Academic project information.
/// Card 2: Developer information (Olutech Cyberworld).
/// Card 3: App and device information.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(deviceIdProvider) ?? 'Not paired';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── App logo + name header ─────────────────────────────────────────
          Center(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Image.asset(
                  'assets/images/app_icon.png',
                  height: 80,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.agriculture,
                    size: 80,
                    color: AppTheme.primaryGreenLight,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'FeedPilot',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.onSurfacePrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Automated Poultry Feeding System',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceTertiary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),

          // ── Card 1: Project Information ────────────────────────────────────
          const _AboutCard(
            icon: Icons.school_outlined,
            title: 'Project Information',
            children: [
              _AboutRow(
                label: 'Project',
                value: 'Automated Poultry Feeding System',
              ),
              _CardDivider(),
              _AboutRow(
                label: 'Students',
                value: 'Tella Tobiloba Abayomi\nFasakin Kemi Victoria',
                multiline: true,
              ),
              _CardDivider(),
              _AboutRow(
                label: 'Matric Numbers',
                value: 'CPE/HND/F24/051\nCPE/HND/F24/054',
                multiline: true,
              ),
              _CardDivider(),
              _AboutRow(
                label: 'Supervisor',
                value: 'Engr (Mrs) Oyediji F.T',
              ),
              _CardDivider(),
              _AboutRow(
                label: 'Institution',
                value: 'Federal Polytechnic Ile-Oluji, Ondo State',
                multiline: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Card 2: Developer Information ─────────────────────────────────
          _AboutCard(
            icon: Icons.code_outlined,
            title: 'Developer',
            children: [
              // Olutech logo + brand name
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/olutech_logo.png',
                      height: 32,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.code,
                        color: AppTheme.primaryGreenLight,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Olutech Cyberworld',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppTheme.onSurfacePrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        Text(
                          'Software & IoT Development',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const _CardDivider(),
              const _AboutRow(
                label: 'Contact',
                value: '07015594518',
              ),
              const _CardDivider(),
              const _AboutRow(
                label: 'Email',
                value: 'olutechcyberworld@gmail.com',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Card 3: App & Project Summary ─────────────────────────────────
          _AboutCard(
            icon: Icons.info_outline,
            title: 'About This App',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'FeedPilot is an IoT companion application for an '
                  'embedded poultry feeding system, enabling farmers to '
                  'monitor hopper stock levels, trigger manual feed '
                  'cycles, and receive real-time alerts from a '
                  'cloud-connected ESP32 device over MQTT.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceSecondary,
                        height: 1.6,
                      ),
                ),
              ),
              const _CardDivider(),
              const _AboutRow(
                label: 'Package',
                value: 'com.olutech.feed_pilot',
              ),
              const _CardDivider(),
              _AboutRow(
                label: 'Paired Device',
                value: deviceId,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Shared card primitives ─────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _AboutCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primaryGreenLight),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.primaryGreenLight,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.outlineColor),

          // Card body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  final bool multiline;

  const _AboutRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: multiline
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.onSurfaceTertiary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfacePrimary,
                        height: 1.5,
                      ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.onSurfaceTertiary,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfacePrimary,
                        ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: AppTheme.outlineColor);
  }
}
