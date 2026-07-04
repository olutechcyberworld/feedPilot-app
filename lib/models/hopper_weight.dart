// lib/models/hopper_weight.dart

class HopperWeight {
  final double weightKg;
  final DateTime timestamp;

  const HopperWeight({
    required this.weightKg,
    required this.timestamp,
  });

  factory HopperWeight.fromJson(Map<String, dynamic> json) {
    return HopperWeight(
      weightKg: (json['weight_kg'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() =>
      'HopperWeight(weightKg: $weightKg, timestamp: $timestamp)';
}
