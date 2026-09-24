class TaskTimeLogResponse {
  final double hoursWorked;
  final String notes;
  final String startTime;
  final String stopTime;
  final String employeeCode;

  TaskTimeLogResponse({
    required this.hoursWorked,
    required this.notes,
    required this.startTime,
    required this.stopTime,
    required this.employeeCode,
  });

  factory TaskTimeLogResponse.fromJson(Map<String, dynamic> json) {
    return TaskTimeLogResponse(
      hoursWorked: (json['hoursWorked'] ?? 0).toDouble(),
      notes: json['notes'] ?? '',
      startTime: json['startTime'] ?? '',
      stopTime: json['stopTime'] ?? '',
      employeeCode: json['employeeCode'] ?? '',
    );
  }
}
