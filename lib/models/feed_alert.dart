// lib/models/feed_alert.dart

enum AlertType {
  hopperLow,
  troughFullSkip,
  dispenseJam,
  gateSealFail,
  calibrationWarning,
  hopperSensorFault,
  insufficientStock,
  unknown,
}

class FeedAlert {
  final AlertType type;
  final String message;
  final double? stockKg;
  final DateTime timestamp;

  const FeedAlert({
    required this.type,
    required this.message,
    this.stockKg,
    required this.timestamp,
  });

  factory FeedAlert.fromJson(Map<String, dynamic> json) {
    return FeedAlert(
      type: _parseAlertType(json['type'] as String),
      message: json['message'] as String,
      stockKg: json['stock_kg'] != null
          ? (json['stock_kg'] as num).toDouble()
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  static AlertType _parseAlertType(String value) {
    switch (value) {
      case 'HOPPER_LOW':
        return AlertType.hopperLow;
      case 'TROUGH_FULL_SKIP':
        return AlertType.troughFullSkip;
      case 'DISPENSE_JAM':
        return AlertType.dispenseJam;
      case 'GATE_SEAL_FAIL':
        return AlertType.gateSealFail;
      case 'CALIBRATION_WARNING':
        return AlertType.calibrationWarning;
      case 'HOPPER_SENSOR_FAULT':
        return AlertType.hopperSensorFault;
      case 'INSUFFICIENT_STOCK':
        return AlertType.insufficientStock;
      default:
        return AlertType.unknown;
    }
  }

  /// Human-readable label for display on the History and Dashboard screens.
  String get displayLabel {
    switch (type) {
      case AlertType.hopperLow:
        return 'Hopper Low';
      case AlertType.troughFullSkip:
        return 'Trough Full — Feed Skipped';
      case AlertType.dispenseJam:
        return 'Dispense Jam';
      case AlertType.gateSealFail:
        return 'Gate Seal Failure';
      case AlertType.calibrationWarning:
        return 'Calibration Warning';
      case AlertType.hopperSensorFault:
        return 'Hopper Sensor Fault';
      case AlertType.insufficientStock:
        return 'Insufficient Stock';
      case AlertType.unknown:
        return 'Unknown Alert';
    }
  }
}
