// lib/routing/router_notifier.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/device_provider.dart';

/// Bridges Riverpod state to GoRouter's refresh mechanism.
///
/// GoRouter's redirect callback is evaluated only at navigation events
/// and does not watch Riverpod providers on its own. Without this bridge,
/// when the Setup screen persists a deviceId and updates deviceIdProvider,
/// GoRouter never re-evaluates its redirect and the app stays on /setup.
///
/// RouterNotifier listens to deviceIdProvider via ref.listen and calls
/// notifyListeners() on every change. GoRouter is registered with this
/// instance as its refreshListenable, so every notifyListeners() call
/// triggers a full redirect re-evaluation against the current provider state.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    // Begin listening immediately on construction.
    // keepAlive: true ensures the listener is not cancelled when the
    // RouterNotifier itself is briefly out of scope during hot reload.
    _ref.listen<String?>(
      deviceIdProvider,
      (_, __) => notifyListeners(),
    );
  }
}

/// Provider for the RouterNotifier instance.
/// Consumed by appRouterProvider to wire refreshListenable.
final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});
