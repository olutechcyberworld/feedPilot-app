// lib/models/feed_status.dart

enum CycleState { idle, dispensing, jam, gateSealFail }

enum TroughState { empty, feedPresent }

class LastDispense {
  final DateTime? timestamp;
  final int targetG;
  final int actualG;
  final bool fault;

  const LastDispense({
    required this.timestamp,
    required this.targetG,
    required this.actualG,
    required this.fault,
  });

  factory LastDispense.fromJson(Map<String, dynamic> json) {
    // Firmware publishes "" for timestamp before any dispense has ever
    // occurred — this is the expected first-boot / idle state, not
    // malformed data. DateTime.tryParse returns null on "" instead of
    // throwing, so that state renders as "no dispense yet" rather than
    // dropping the entire feed/status message.
    return LastDispense(
      timestamp: DateTime.tryParse(json['timestamp'] as String),
      targetG: json['target_g'] as int,
      actualG: json['actual_g'] as int,
      fault: json['fault'] as bool,
    );
  }
}

class FeedStatus {
  final LastDispense lastDispense;
  final DateTime? nextSchedule;
  final CycleState cycleState;
  final TroughState troughState;

  const FeedStatus({
    required this.lastDispense,
    this.nextSchedule,
    required this.cycleState,
    required this.troughState,
  });

  factory FeedStatus.fromJson(Map<String, dynamic> json) {
    // Same reasoning as LastDispense.timestamp: "" means "no schedule
    // configured yet", a valid state, not an error. Guard against both
    // JSON null and empty string, and use tryParse so it can't throw.
    final rawNextSchedule = json['next_schedule'] as String?;
    final parsedNextSchedule =
        (rawNextSchedule == null || rawNextSchedule.isEmpty)
            ? null
            : DateTime.tryParse(rawNextSchedule);

    return FeedStatus(
      lastDispense:
          LastDispense.fromJson(json['last_dispense'] as Map<String, dynamic>),
      nextSchedule: parsedNextSchedule,
      cycleState: _parseCycleState(json['cycle_state'] as String),
      troughState: _parseTroughState(json['trough_state'] as String),
    );
  }

  static CycleState _parseCycleState(String value) {
    switch (value) {
      case 'DISPENSING':
        return CycleState.dispensing;
      case 'JAM':
        return CycleState.jam;
      case 'GATE_SEAL_FAIL':
        return CycleState.gateSealFail;
      case 'IDLE':
      default:
        return CycleState.idle;
    }
  }

  static TroughState _parseTroughState(String value) {
    return value == 'FEED_PRESENT'
        ? TroughState.feedPresent
        : TroughState.empty;
  }
}
