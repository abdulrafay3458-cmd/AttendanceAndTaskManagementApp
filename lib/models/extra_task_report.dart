import 'package:attendance_app/models/task_report.dart';

class EmployeeTaskReport {
  final String employeeCode;
  final String employeeName;
  final List<TaskReport> tasks;

  EmployeeTaskReport({
    required this.employeeCode,
    required this.employeeName,
    required this.tasks,
  });

  factory EmployeeTaskReport.fromJson(Map<String, dynamic> json) {
    return EmployeeTaskReport(
      employeeCode: json['employeeCode'],
      employeeName: json['employeeName'],
      tasks: (json['tasks'] as List)
          .map((e) => TaskReport.fromJson(e))
          .toList(),
    );
  }
}
