// lib/models/feed_ack.dart

class FeedAck {
  final String command; // 'FEED' | 'RESTOCK' | 'CONFIG'
  final String status; // 'RECEIVED'
  final DateTime? timestamp;

  const FeedAck({required this.command, required this.status, this.timestamp});

  factory FeedAck.fromJson(Map<String, dynamic> json) {
    return FeedAck(
      command: json['command'] as String? ?? '',
      status: json['status'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
    );
  }
}
