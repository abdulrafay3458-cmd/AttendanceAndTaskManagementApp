class TaskTimeLog {
  final String id;
  final DateTime date;
  final String employeeCode;
  final DateTime? startTime;
  final DateTime? stopTime;
  final double hoursWorked;
  final String notes;

  TaskTimeLog({
    required this.id,
    required this.date,
    required this.employeeCode,
    this.startTime,
    this.stopTime,
    required this.hoursWorked,
    required this.notes,
  });

  factory TaskTimeLog.fromJson(Map<String, dynamic> json) {
    return TaskTimeLog(
      id: json['id']?.toString() ?? '',
      date: DateTime.parse(json['logDate']),
      employeeCode: json['employeeCode'].toString(),
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : null,
      stopTime: json['stopTime'] != null
          ? DateTime.parse(json['stopTime'])
          : null,
      hoursWorked: (json['hoursWorked'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString() ?? '',
    );
  }
}
