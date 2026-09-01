// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'routing/app_router.dart';
import 'providers/history_sync_provider.dart';

class FeedPilotApp extends ConsumerWidget {
  const FeedPilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Forces HistorySyncService into existence as soon as a deviceId is
    // available, independent of which tab is active. Once created it
    // persists for the app's lifetime under default Provider semantics —
    // this watch only needs to fire once to trigger that, not track a
    // rebuild target.
    ref.watch(historySyncServiceProvider);

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
