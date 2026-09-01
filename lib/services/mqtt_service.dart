// lib/services/mqtt_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/mqtt_config.dart';
import '../services/apfs_topics.dart';
import '../models/hopper_weight.dart';
import '../models/hopper_stock.dart';
import '../models/feed_status.dart';
import '../models/feed_alert.dart';
import '../models/system_health.dart';
import '../models/local_ip.dart';

/// Connection state of the MqttService itself — distinct from the
/// mqtt_client package's own MqttConnectionState enum.
enum MqttServiceState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class MqttService {
  final APFSTopics topics;
  final String deviceId;

  MqttService({required this.topics, required this.deviceId});

  // ── Internal client ────────────────────────────────────────────────────────

  MqttServerClient? _client;
  MqttServiceState _connectionState = MqttServiceState.disconnected;
  Timer? _reconnectTimer;
  int _reconnectDelaySeconds = MqttConfig.reconnectInitialDelaySeconds;

  // ── Stream controllers ─────────────────────────────────────────────────────
  // One StreamController per topic. Providers listen to these streams.
  // broadcast() allows multiple listeners (dashboard + background service).

  final _hopperWeightController = StreamController<HopperWeight>.broadcast();
  final _hopperStockController = StreamController<HopperStock>.broadcast();
  final _feedStatusController = StreamController<FeedStatus>.broadcast();
  final _feedAlertController = StreamController<FeedAlert>.broadcast();
  final _systemHealthController = StreamController<SystemHealth>.broadcast();
  final _localIpController = StreamController<LocalIp>.broadcast();
  final _connectionStateController =
      StreamController<MqttServiceState>.broadcast();

  // ── Public streams ─────────────────────────────────────────────────────────

  Stream<HopperWeight> get hopperWeightStream => _hopperWeightController.stream;
  Stream<HopperStock> get hopperStockStream => _hopperStockController.stream;
  Stream<FeedStatus> get feedStatusStream => _feedStatusController.stream;
  Stream<FeedAlert> get feedAlertStream => _feedAlertController.stream;
  Stream<SystemHealth> get systemHealthStream => _systemHealthController.stream;
  Stream<LocalIp> get localIpStream => _localIpController.stream;
  Stream<MqttServiceState> get connectionStateStream =>
      _connectionStateController.stream;

  MqttServiceState get connectionState => _connectionState;

  // ── Connection ─────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_connectionState == MqttServiceState.connected ||
        _connectionState == MqttServiceState.connecting) {
      return;
    }

    _setConnectionState(MqttServiceState.connecting);

    _client = MqttServerClient.withPort(
      MqttConfig.brokerHost,
      MqttConfig.appClientId(deviceId),
      MqttConfig.brokerPort,
    );

    _client!.secure = true;
    _client!.securityContext = SecurityContext.defaultContext;
    _client!.keepAlivePeriod = MqttConfig.keepAliveSeconds;
    _client!.autoReconnect = false; // Managed manually for backoff control
    _client!.logging(on: false);

    // ── LWT registration ───────────────────────────────────────────────────
    // Mirrors the device LWT structure so the Dashboard can distinguish
    // app offline from device offline via the "status" field value.
    final lwtPayload = jsonEncode({
      'uptime_s': 0,
      'connectivity_tier': 0,
      'firmware_version': 'N/A',
      'status': 'APP_OFFLINE',
      'timestamp': 'N/A',
    });

    // Note: mqtt_client defaults to clean session false when startClean()
    // is NOT called. This is the correct behaviour for this design —
    // the broker queues QoS 1 messages during offline windows and delivers
    // on reconnect. Do not add startClean() here.
    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(MqttConfig.appClientId(deviceId))
        .withWillTopic(topics.systemHealth)
        .withWillMessage(lwtPayload)
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .authenticateAs(MqttConfig.brokerUsername, MqttConfig.brokerPassword);

    try {
      await _client!.connect();
    } catch (e) {
      _handleConnectionFailure('Connect exception: $e');
      return;
    }

    if (_client!.connectionStatus?.state != MqttConnectionState.connected) {
      _handleConnectionFailure(
        'Broker rejected connection: '
        '${_client!.connectionStatus?.returnCode}',
      );
      return;
    }

    _setConnectionState(MqttServiceState.connected);
    _reconnectDelaySeconds = MqttConfig.reconnectInitialDelaySeconds;
    _subscribeToAllTopics();
    _listenToIncomingMessages();

    _client!.onDisconnected = _onDisconnected;
  }

  // ── Subscriptions ──────────────────────────────────────────────────────────

  void _subscribeToAllTopics() {
    const qos1 = MqttQos.atLeastOnce;

    _client!.subscribe(topics.hopperWeight, qos1);
    _client!.subscribe(topics.hopperStock, qos1);
    _client!.subscribe(topics.feedStatus, qos1);
    _client!.subscribe(topics.feedAlerts, qos1);
    _client!.subscribe(topics.systemHealth, qos1);
    _client!.subscribe(topics.systemLocalIp, qos1);
  }

  // ── Incoming message dispatch ──────────────────────────────────────────────

  void _listenToIncomingMessages() {
    _client!.updates?.listen((
      List<MqttReceivedMessage<MqttMessage>> messages,
    ) {
      for (final msg in messages) {
        final topic = msg.topic;
        final payload = MqttPublishPayload.bytesToStringAsString(
          (msg.payload as MqttPublishMessage).payload.message,
        );

        try {
          final json = jsonDecode(payload) as Map<String, dynamic>;
          _dispatch(topic, json);
        } catch (e) {
          // Malformed JSON from firmware — log and discard.
          // Do not crash the message loop.
          _logError('JSON parse error on $topic: $e\nPayload: $payload');
        }
      }
    });
  }

  void _dispatch(String topic, Map<String, dynamic> json) {
    if (topic == topics.hopperWeight) {
      _hopperWeightController.add(HopperWeight.fromJson(json));
    } else if (topic == topics.hopperStock) {
      _hopperStockController.add(HopperStock.fromJson(json));
    } else if (topic == topics.feedStatus) {
      _feedStatusController.add(FeedStatus.fromJson(json));
    } else if (topic == topics.feedAlerts) {
      _feedAlertController.add(FeedAlert.fromJson(json));
    } else if (topic == topics.systemHealth) {
      _systemHealthController.add(SystemHealth.fromJson(json));
    } else if (topic == topics.systemLocalIp) {
      _localIpController.add(LocalIp.fromJson(json));
    }
  }

  // ── Publish methods ────────────────────────────────────────────────────────

  /// Publishes a manual feed trigger command at QoS 2.
  void publishFeedTrigger({required int portionGrams}) {
    _publish(
      topic: topics.feedTrigger,
      payload: jsonEncode({
        'command': 'FEED',
        'portion_g': portionGrams,
        'source': 'MANUAL',
      }),
      qos: MqttQos.exactlyOnce,
    );
  }

  /// Publishes a schedule and configuration update at QoS 2.
  void publishFeedConfig({
    required List<Map<String, dynamic>> schedules,
    required double hopperLowThresholdKg,
    required int portionGrams,
  }) {
    _publish(
      topic: topics.feedConfig,
      payload: jsonEncode({
        'schedules': schedules,
        'hopper_low_threshold_kg': hopperLowThresholdKg,
        'portion_g': portionGrams,
      }),
      qos: MqttQos.exactlyOnce,
    );
  }

  /// Publishes a hopper restock confirmation at QoS 2.
  void publishHopperRestock({required double amountKg}) {
    _publish(
      topic: topics.hopperRestock,
      payload: jsonEncode({
        'command': 'RESTOCK',
        'amount_kg': amountKg,
      }),
      qos: MqttQos.exactlyOnce,
    );
  }

  void _publish({
    required String topic,
    required String payload,
    required MqttQos qos,
  }) {
    if (_connectionState != MqttServiceState.connected) {
      _logError('Publish attempted while disconnected — topic: $topic');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(topic, qos, builder.payload!);
  }

  // ── Disconnection and reconnect ────────────────────────────────────────────

  void _onDisconnected() {
    _setConnectionState(MqttServiceState.disconnected);
    _scheduleReconnect();
  }

  void _handleConnectionFailure(String reason) {
    _logError(reason);
    _client?.disconnect();
    _setConnectionState(MqttServiceState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _setConnectionState(MqttServiceState.reconnecting);

    _reconnectTimer = Timer(
      Duration(seconds: _reconnectDelaySeconds),
      () async {
        // Exponential backoff capped at reconnectMaxDelaySeconds
        _reconnectDelaySeconds = (_reconnectDelaySeconds * 2).clamp(
          MqttConfig.reconnectInitialDelaySeconds,
          MqttConfig.reconnectMaxDelaySeconds,
        );
        await connect();
      },
    );
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _client?.disconnect();
    _setConnectionState(MqttServiceState.disconnected);
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  void _setConnectionState(MqttServiceState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void _logError(String message) {
    // assert() is a no-op in release builds — zero log output in production.
    assert(() {
      // ignore: avoid_print
      print('[MqttService] $message');
      return true;
    }());
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    await _hopperWeightController.close();
    await _hopperStockController.close();
    await _feedStatusController.close();
    await _feedAlertController.close();
    await _systemHealthController.close();
    await _localIpController.close();
    await _connectionStateController.close();
    _client?.disconnect();
  }
}
