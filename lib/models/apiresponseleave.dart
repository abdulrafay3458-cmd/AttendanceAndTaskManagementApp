class ApiLeaveResponse {
  final bool success;
  final List<dynamic> leave;
  final String? error;

  ApiLeaveResponse({
    required this.success,
    required this.leave,
    this.error,
  });

  factory ApiLeaveResponse.fromJson(Map<String, dynamic> json) {
    return ApiLeaveResponse(
      success: json['success'] ?? false,
      leave: json['leave'] is List ? json['leave'] : [],
      error: json['error'],
    );
  }
}
