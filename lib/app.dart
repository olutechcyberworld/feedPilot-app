// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'routing/app_router.dart';

class FeedPilotApp extends ConsumerWidget {
  const FeedPilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FeedPilot',
      debugShowCheckedModeBanner: false,

      // Dark mode enforced — no light theme generated per factory spec.
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      routerConfig: router,
    );
  }
}
