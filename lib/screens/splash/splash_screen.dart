// lib/screens/splash/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';
import '../../providers/device_provider.dart';
import '../../routing/app_router.dart';

/// FeedPilot branded splash screen.
/// Factory spec: MATERIAL_3 dark | SPLASH_DURATION 2500ms |
/// Logo entrance: FadeTransition + ScaleTransition (800ms, easeOutBack) |
/// Text entrance: SlideTransition from bottom, delayed 400ms |
/// Brand footer: fades in at 1200ms delay.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Single controller drives all three animation intervals
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _brandFadeAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Logo: fade + scale 0–800ms
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.44, curve: Curves.easeIn),
      ),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.44, curve: Curves.easeOutBack),
      ),
    );

    // App name + tagline: slide from bottom, 400–800ms
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.22, 0.55, curve: Curves.easeOut),
      ),
    );

    // Brand footer: fades in at 1200ms (0.67 of 1800ms)
    _brandFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.67, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      _loadDeviceId(),
      Future.delayed(const Duration(milliseconds: 8000)),
    ]);
    if (!mounted) return;
    final deviceId = ref.read(deviceIdProvider);
    context.go(deviceId != null ? AppRoutes.dashboard : AppRoutes.setup);
  }

  Future<void> _loadDeviceId() async {
    final stored = await loadStoredDeviceId();
    if (stored != null && mounted) {
      ref.read(deviceIdProvider.notifier).state = stored;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Centered logo + text ─────────────────────────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo: fade + scale
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 96,
                          height: 96,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // App name + tagline: slide from bottom
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          children: [
                            Text(
                              'FeedPilot',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: AppTheme.onSurfacePrimary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Automated Poultry Feeding System',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.onSurfaceSecondary,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 56),

                    // Progress indicator
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Brand footer — fades in at 1200ms ───────────────────────────
            // Logo sits inline beside the credit text, not above it.
            FadeTransition(
              opacity: _brandFadeAnim,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/olutech_logo.png',
                      height: 45,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.code,
                        color: AppTheme.onSurfaceTertiary,
                        size: 35,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      'Developed by \n'
                      'Olutech Cyberworld',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.onSurfaceSecondary,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
