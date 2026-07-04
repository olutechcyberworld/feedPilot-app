// lib/services/local_storage_service.dart

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/feed_status.dart';
import '../models/feed_alert.dart';
import '../models/hopper_weight.dart';

class LocalStorageService {
  static const String _dbName = 'feedpilot.db';
  static const int _dbVersion = 1;

  // Table names
  static const String _tableFeedRecords = 'feed_records';
  static const String _tableAlerts = 'alerts';
  static const String _tableTelemetry = 'telemetry';

  Database? _db;

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Feed cycle records — one row per completed dispense event
    await db.execute('''
      CREATE TABLE $_tableFeedRecords (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id        TEXT    NOT NULL,
        timestamp        TEXT    NOT NULL,
        target_g         INTEGER NOT NULL,
        actual_g         INTEGER NOT NULL,
        fault            INTEGER NOT NULL DEFAULT 0,
        trough_state     TEXT    NOT NULL,
        hopper_state     TEXT    NOT NULL
      )
    ''');

    // Alert records — one row per received feed/alerts payload
    await db.execute('''
      CREATE TABLE $_tableAlerts (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id        TEXT    NOT NULL,
        timestamp        TEXT    NOT NULL,
        alert_type       TEXT    NOT NULL,
        message          TEXT    NOT NULL,
        stock_kg         REAL
      )
    ''');

    // Telemetry snapshots — one row per hopper weight publish received
    // Used by History screen for weight trend display
    await db.execute('''
      CREATE TABLE $_tableTelemetry (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id        TEXT    NOT NULL,
        timestamp        TEXT    NOT NULL,
        hopper_weight_kg REAL    NOT NULL
      )
    ''');
  }

  // ── Internal guard ─────────────────────────────────────────────────────────

  Database get _database {
    assert(_db != null,
        'LocalStorageService.init() must be called before any read or write.');
    return _db!;
  }

  // ── Feed Records ───────────────────────────────────────────────────────────

  /// Persists a completed dispense event derived from a feed/status payload.
  Future<void> insertFeedRecord({
    required String deviceId,
    required LastDispense dispense,
    required TroughState troughState,
    required String hopperState,
  }) async {
    await _database.insert(
      _tableFeedRecords,
      {
        'device_id': deviceId,
        'timestamp': dispense.timestamp.toIso8601String(),
        'target_g': dispense.targetG,
        'actual_g': dispense.actualG,
        'fault': dispense.fault ? 1 : 0,
        'trough_state':
            troughState == TroughState.feedPresent ? 'FEED_PRESENT' : 'EMPTY',
        'hopper_state': hopperState,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Returns all feed records for [deviceId], newest first.
  /// [limit] caps the result set — History screen uses 200 by default.
  Future<List<Map<String, dynamic>>> getFeedRecords({
    required String deviceId,
    int limit = 200,
  }) async {
    return _database.query(
      _tableFeedRecords,
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  // ── Alert Records ──────────────────────────────────────────────────────────

  /// Persists a received alert payload. Called by MQTTService from the
  /// background isolate as well as from the foreground UI isolate.
  Future<void> insertAlert({
    required String deviceId,
    required FeedAlert alert,
  }) async {
    await _database.insert(
      _tableAlerts,
      {
        'device_id': deviceId,
        'timestamp': alert.timestamp.toIso8601String(),
        'alert_type': alert.type.name,
        'message': alert.message,
        'stock_kg': alert.stockKg,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Returns all alert records for [deviceId], newest first.
  Future<List<Map<String, dynamic>>> getAlerts({
    required String deviceId,
    int limit = 100,
  }) async {
    return _database.query(
      _tableAlerts,
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  // ── Telemetry Snapshots ────────────────────────────────────────────────────

  /// Persists a hopper weight snapshot for trend display.
  /// Called every time a hopper/weight MQTT message is received.
  Future<void> insertTelemetry({
    required String deviceId,
    required HopperWeight reading,
  }) async {
    await _database.insert(
      _tableTelemetry,
      {
        'device_id': deviceId,
        'timestamp': reading.timestamp.toIso8601String(),
        'hopper_weight_kg': reading.weightKg,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Returns telemetry snapshots for [deviceId] within the last [hours].
  /// Used to populate the hopper weight trend on the History screen.
  Future<List<Map<String, dynamic>>> getRecentTelemetry({
    required String deviceId,
    int hours = 24,
  }) async {
    final since =
        DateTime.now().subtract(Duration(hours: hours)).toIso8601String();

    return _database.query(
      _tableTelemetry,
      where: 'device_id = ? AND timestamp >= ?',
      whereArgs: [deviceId, since],
      orderBy: 'timestamp ASC',
    );
  }

  // ── Retention Enforcement ──────────────────────────────────────────────────

  /// Deletes telemetry rows older than 180 days (6-month retention window).
  /// Called once at app startup from main.dart after init() completes.
  Future<void> enforceRetentionPolicy({required String deviceId}) async {
    final cutoff =
        DateTime.now().subtract(const Duration(days: 180)).toIso8601String();

    await _database.delete(
      _tableTelemetry,
      where: 'device_id = ? AND timestamp < ?',
      whereArgs: [deviceId, cutoff],
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
