// lib/services/rest_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hopper_weight.dart';
import '../models/hopper_stock.dart';
import '../models/feed_status.dart';
import '../models/local_ip.dart';

/// Provides Tier 2 local REST access to the ESP32 HTTP server.
///
/// The ESP32 serves GET /sensors and POST /control on farm.local
/// (mDNS hostname). This service polls GET /sensors every 2 seconds
/// when active and exposes the result via streams that mirror the
/// MQTT stream interface in MqttService, allowing the provider layer
/// to switch data sources transparently.
///
/// This service is only active when ConnectivityService reports
/// ConnectivityTier.localRest. The provider layer activates and
/// deactivates it accordingly.
class RestService {
  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _requestTimeout = Duration(seconds: 3);

  // Prefer mDNS hostname. Falls back to IP if LocalIp is provided
  // and mDNS resolution fails on the local Android network stack.
  String? _baseUrl;
  String? _fallbackUrl;
  bool _active = false;
  Timer? _pollTimer;

  final _hopperWeightController = StreamController<HopperWeight>.broadcast();
  final _hopperStockController = StreamController<HopperStock>.broadcast();
  final _feedStatusController = StreamController<FeedStatus>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // ── Public streams ─────────────────────────────────────────────────────────

  Stream<HopperWeight> get hopperWeightStream => _hopperWeightController.stream;
  Stream<HopperStock> get hopperStockStream => _hopperStockController.stream;
  Stream<FeedStatus> get feedStatusStream => _feedStatusController.stream;

  /// Error stream — ConnectivityService watches this to detect
  /// when local REST access is also unavailable (Tier 2 → Tier 1).
  Stream<String> get errorStream => _errorController.stream;

  bool get isActive => _active;

  // ── URL configuration ──────────────────────────────────────────────────────

  /// Called by the provider layer when a system/local_ip MQTT payload
  /// is received, providing the device's mDNS hostname and IP address.
  void configureUrls(LocalIp localIp) {
    _baseUrl = localIp.restBaseUrl; // http://farm.local
    _fallbackUrl = localIp.restBaseUrlByIp; // http://192.168.x.x
  }

  // ── Activation lifecycle ───────────────────────────────────────────────────

  /// Activates polling. Called by the provider layer when
  /// ConnectivityTier transitions to localRest.
  void activate() {
    if (_active) return;
    _active = true;
    _startPolling();
  }

  /// Deactivates polling. Called when MQTT connectivity is restored
  /// or when the app moves to the background.
  void deactivate() {
    _active = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollSensors());
    _pollSensors(); // immediate first fetch, do not wait for first tick
  }

  Future<void> _pollSensors() async {
    if (!_active) return;

    final url = _buildUrl('/sensors');
    if (url == null) {
      _errorController.add('RestService: no base URL configured. '
          'Waiting for system/local_ip payload.');
      return;
    }

    try {
      final response = await http.get(Uri.parse(url)).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        _parseSensorResponse(response.body);
      } else {
        _errorController.add(
          'RestService: GET /sensors returned ${response.statusCode}',
        );
      }
    } on TimeoutException {
      // mDNS resolution may be failing — try IP fallback on next tick.
      // Error is emitted so ConnectivityService can log it.
      _errorController.add(
        'RestService: GET /sensors timed out on $_baseUrl',
      );
      if (_fallbackUrl != null && _baseUrl != _fallbackUrl) {
        _baseUrl = _fallbackUrl; // promote fallback for subsequent polls
      }
    } catch (e) {
      _errorController.add('RestService: GET /sensors error: $e');
    }
  }

  void _parseSensorResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;

      // hopper/weight equivalent
      _hopperWeightController.add(
        HopperWeight(
          weightKg: (json['hopper_weight_kg'] as num).toDouble(),
          timestamp: DateTime.now(),
        ),
      );

      // hopper/stock equivalent
      _hopperStockController.add(
        HopperStock(
          stockKg: (json['hopper_stock_kg'] as num).toDouble(),
          stockPercent: _inferStockPercent(
            json['hopper_stock_kg'] as num,
          ),
          restockBaselineKg: 0.0, // not available in REST response
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _errorController.add('RestService: parse error: $e\nBody: $body');
    }
  }

  int _inferStockPercent(num stockKg) {
    // The REST /sensors endpoint does not return stock_percent directly.
    // This is a best-effort inference. The provider layer will prefer
    // the MQTT hopper/stock stream value when available, which carries
    // the authoritative restock_baseline_kg for accurate percentage.
    // This value is only used during Tier 2 operation.
    return (stockKg * 20).clamp(0, 100).toInt(); // assumes 5 kg baseline
  }

  // ── Commands ───────────────────────────────────────────────────────────────

  /// Issues a manual feed command via POST /control.
  /// Returns true if the command was accepted by the device.
  Future<bool> postFeedTrigger({required int portionGrams}) async {
    return _postControl({
      'command': 'FEED',
      'portion_g': portionGrams,
    });
  }

  /// Issues a restock confirmation via POST /control.
  Future<bool> postRestock() async {
    return _postControl({'command': 'RESTOCK'});
  }

  Future<bool> _postControl(Map<String, dynamic> body) async {
    final url = _buildUrl('/control');
    if (url == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['status'] == 'ACCEPTED';
      }
      return false;
    } catch (e) {
      _errorController.add('RestService: POST /control error: $e');
      return false;
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  String? _buildUrl(String path) {
    if (_baseUrl == null) return null;
    return '$_baseUrl$path';
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    deactivate();
    await _hopperWeightController.close();
    await _hopperStockController.close();
    await _feedStatusController.close();
    await _errorController.close();
  }
}
