// lib/models/hopper_stock.dart

class HopperStock {
  final double stockKg;
  final int stockPercent;
  final double restockBaselineKg;
  final DateTime timestamp;

  const HopperStock({
    required this.stockKg,
    required this.stockPercent,
    required this.restockBaselineKg,
    required this.timestamp,
  });

  factory HopperStock.fromJson(Map<String, dynamic> json) {
    return HopperStock(
      stockKg: (json['stock_kg'] as num).toDouble(),
      stockPercent: json['stock_percent'] as int,
      restockBaselineKg: (json['restock_baseline_kg'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() =>
      'HopperStock(stockKg: $stockKg, stockPercent: $stockPercent%, '
      'baseline: $restockBaselineKg)';
}
