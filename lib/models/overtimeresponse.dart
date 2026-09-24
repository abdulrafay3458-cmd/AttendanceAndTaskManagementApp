class Overtimeresponse {
  final bool success;
  final List<dynamic> overtime;
  final String? error;

  Overtimeresponse({
    required this.success,
    required this.overtime,
    this.error,
  });

  factory Overtimeresponse.fromJson(Map<String, dynamic> json) {
    return Overtimeresponse(
      success: json['success'] ?? false,
      overtime: json['pendingOverTime'] is List ? json['pendingOverTime'] : [],
      error: json['error'],
    );
  }
}