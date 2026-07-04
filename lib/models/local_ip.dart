// lib/models/local_ip.dart

class LocalIp {
  final String ip;
  final String hostname;

  const LocalIp({
    required this.ip,
    required this.hostname,
  });

  factory LocalIp.fromJson(Map<String, dynamic> json) {
    return LocalIp(
      ip: json['ip'] as String,
      hostname: json['hostname'] as String,
    );
  }

  /// Base URL used by RestService for Tier 2 HTTP requests.
  /// Prefers mDNS hostname for readability; IP is the fallback if mDNS
  /// resolution fails on the local network.
  String get restBaseUrl => 'http://$hostname';
  String get restBaseUrlByIp => 'http://$ip';

  @override
  String toString() => 'LocalIp(ip: $ip, hostname: $hostname)';
}
