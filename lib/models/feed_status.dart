// lib/models/feed_status.dart

enum CycleState { idle, dispensing, jam, gateSealFail }

enum TroughState { empty, feedPresent }

class LastDispense {
  final DateTime timestamp;
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
    return LastDispense(
      timestamp: DateTime.parse(json['timestamp'] as String),
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
    return FeedStatus(
      lastDispense:
          LastDispense.fromJson(json['last_dispense'] as Map<String, dynamic>),
      nextSchedule: json['next_schedule'] != null
          ? DateTime.parse(json['next_schedule'] as String)
          : null,
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
