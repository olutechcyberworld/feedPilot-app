// lib/services/local_storage_service.dart

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/feed_status.dart';
import '../models/feed_alert.dart';
import '../models/hopper_weight.dart';

class LocalStorageService {
  static const String _dbName = 'feedpilot.db';
  static const int _dbVersion = 2;

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
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Feed cycle records — one row per completed dispense event.
    // UNIQUE(device_id, timestamp) is the dedup mechanism: feed/status
    // republishes on the same cadence as all other telemetry, but
    // last_dispense only changes when a real dispense completes. Rather
    // than tracking "have I already seen this dispense" in application
    // logic, repeated inserts for the same (device_id, timestamp) are
    // silently absorbed by the database via ConflictAlgorithm.ignore in
    // insertFeedRecord below.
    await db.execute('''
      CREATE TABLE $_tableFeedRecords (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id        TEXT    NOT NULL,
        timestamp        TEXT    NOT NULL,
        target_g         INTEGER NOT NULL,
        actual_g         INTEGER NOT NULL,
        fault            INTEGER NOT NULL DEFAULT 0,
        trough_state     TEXT    NOT NULL,
        hopper_state     TEXT    NOT NULL,
        UNIQUE(device_id, timestamp)
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 → v2: add UNIQUE(device_id, timestamp) to feed_records.
      //
      // This is a destructive migration — it drops and recreates the
      // table rather than copying existing rows forward. That's safe
      // specifically at this point in the project: insertFeedRecord had
      // zero callers until this change (confirmed by code search), so no
      // build in the field has ever actually written a row to this table.
      // There is nothing to preserve.
      //
      // If this service is ever upgraded again from a build that has
      // accumulated real feed history, this should be replaced with a
      // proper migration: create the new table under a temp name, copy
      // rows across with INSERT OR IGNORE (letting the new UNIQUE
      // constraint deduplicate on the way in), drop the old table, then
      // rename. Do not reuse this destructive path once real data exists.
      await db.execute('DROP TABLE IF EXISTS $_tableFeedRecords');
      await db.execute('''
        CREATE TABLE $_tableFeedRecords (
          id               INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id        TEXT    NOT NULL,
          timestamp        TEXT    NOT NULL,
          target_g         INTEGER NOT NULL,
          actual_g         INTEGER NOT NULL,
          fault            INTEGER NOT NULL DEFAULT 0,
          trough_state     TEXT    NOT NULL,
          hopper_state     TEXT    NOT NULL,
          UNIQUE(device_id, timestamp)
        )
      ''');
    }
  }

  // ── Internal guard ─────────────────────────────────────────────────────────

  Database get _database {
    assert(_db != null,
        'LocalStorageService.init() must be called before any read or write.');
    return _db!;
  }

  // ── Feed Records ───────────────────────────────────────────────────────────

  /// Persists a completed dispense event derived from a feed/status payload.
  ///
  /// No-ops if [dispense.timestamp] is null — a null timestamp means the
  /// device has not completed a dispense yet (fresh boot / idle state
  /// before the first feed cycle), which is not a completed event and has
  /// nothing meaningful to write.
  ///
  /// Safe to call on every feed/status message even though the message
  /// republishes on a ~2s cadence: the UNIQUE(device_id, timestamp)
  /// constraint plus ConflictAlgorithm.ignore means repeated calls for the
  /// same completed dispense are silently no-ops at the database level.
  Future<void> insertFeedRecord({
    required String deviceId,
    required LastDispense dispense,
    required TroughState troughState,
    required String hopperState,
  }) async {
    final timestamp = dispense.timestamp;
    if (timestamp == null) return;

    await _database.insert(
      _tableFeedRecords,
      {
        'device_id': deviceId,
        'timestamp': timestamp.toIso8601String(),
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
  /// Called by HistorySyncService, throttled to one call per minute —
  /// see HistorySyncService for why unthrottled persistence isn't used.
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
  /// Called once at HistorySyncService startup.
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
