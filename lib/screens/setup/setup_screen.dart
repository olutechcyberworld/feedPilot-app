// lib/screens/setup/setup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/device_provider.dart';
import '../../services/apfs_topics.dart';
import '../../routing/app_router.dart';

/// First-launch device pairing screen.
/// Accepts the 12-character uppercase hex deviceId via:
///   (A) QR code scan using the device camera.
///   (B) Manual text entry with inline validation.
/// On success, persists deviceId to SharedPreferences and
/// navigates to /dashboard.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _scanning = false;
  bool _loading = false;
  String? _errorMessage;

  static final _deviceIdRegex = RegExp(r'^[0-9A-F]{12}$');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  String? _validate(String? value) {
    if (value == null || value.isEmpty) return 'Device ID is required.';
    final normalised = value.toUpperCase().trim();
    if (!_deviceIdRegex.hasMatch(normalised)) {
      return 'Must be exactly 12 hex characters (0–9, A–F).';
    }
    return null;
  }

  // ── Pairing ────────────────────────────────────────────────────────────────

  Future<void> _pair(String rawInput) async {
    final deviceId = rawInput.toUpperCase().trim();
    if (!_deviceIdRegex.hasMatch(deviceId)) {
      setState(() => _errorMessage = 'Invalid Device ID format.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    await persistDeviceId(deviceId);

    // Construct APFSTopics to validate the deviceId produces valid topics.
    // This is a lightweight sanity check — no network call is made here.
    APFSTopics(deviceId);

    ref.read(deviceIdProvider.notifier).state = deviceId;

    // Router redirect will fire via RouterNotifier and navigate to /dashboard.
    // The explicit go() below is a safety fallback in case the redirect
    // fires before the state update propagates.
    if (mounted) context.go(AppRoutes.dashboard);
  }

  // ── QR scan ────────────────────────────────────────────────────────────────

  void _onQrDetect(BarcodeCapture capture) {
    if (!_scanning) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() => _scanning = false);
    _pair(raw);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Device'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scanning
              ? _buildScanner()
              : _buildForm(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(onDetect: _onQrDetect),
        Positioned(
          top: 16,
          left: 16,
          child: SafeArea(
            child: TextButton.icon(
              onPressed: () => setState(() => _scanning = false),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        const Center(
          child: _ScanFrame(),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'Pair Your Feeder',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan the QR code on your FeedPilot device, or enter the '
              '12-character Device ID printed on the label.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),

            // QR scan button
            OutlinedButton.icon(
              onPressed: () => setState(() => _scanning = true),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or enter manually',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),

            // Manual entry field
            TextFormField(
              controller: _controller,
              validator: _validate,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                hintText: 'e.g. 246F28ABCDEF',
                border: OutlineInputBorder(),
                helperText: '12-character code from device label',
              ),
              onChanged: (_) {
                // Clear error on input change
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  _pair(_controller.text);
                }
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decorative scan frame overlay drawn over the camera viewfinder.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: CustomPaint(painter: _FramePainter()),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const corner = 32.0;

    // Top-left
    canvas.drawLine(Offset.zero, const Offset(corner, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, corner), paint);
    // Top-right
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width - corner, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, corner), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(corner, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - corner), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - corner, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - corner), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
