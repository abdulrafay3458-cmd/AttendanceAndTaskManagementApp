import 'package:attendance_app/services/tasktimelog.dart';

class TaskModel {
  final String id;
  final String taskTitle;
  final String taskDescription;
  final String? clientName;
  final String assignedBy;
  final String assignedByName;
  final String assignedTo;
  final String assignedToName;
  final DateTime assignedDate;
  final DateTime? dueDate;
  final String priority;
  final String status;
  final double totalHoursWorked;
  final List<TaskTimeLog> timeLogs;
  final String taskPreference;
  final String? clientCode;
  final int? currentDayStartTime;
  final DateTime serverNow;

  TaskModel({
    required this.id,
    required this.taskTitle,
    required this.taskDescription,
    this.clientName,
    required this.assignedBy,
    required this.assignedByName,
    required this.assignedTo,
    required this.assignedToName,
    required this.assignedDate,
    this.dueDate,
    required this.priority,
    required this.status,
    required this.totalHoursWorked,
    required this.timeLogs,
    required this.taskPreference,
    this.clientCode,
    this.currentDayStartTime,
    required this.serverNow,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id']?.toString() ?? '',
      taskTitle: json['taskTitle']?.toString() ?? '',
      taskDescription: json['taskDescription']?.toString() ?? '',
      assignedBy: json['assignedBy']?.toString() ?? '',
      assignedByName: json['assignedByName']?.toString() ?? '',
      clientName: json['clientName'] ?? '',
      assignedTo: json['assignedTo']?.toString() ?? '',
      assignedToName: json['assignedToName']?.toString() ?? '',
      assignedDate: DateTime.parse(json['assignedDate']),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      priority: json['priority']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      totalHoursWorked: (json['totalHoursWorked'] as num?)?.toDouble() ?? 0.0,
      timeLogs: (json['timeLogs'] as List<dynamic>? ?? [])
          .map((e) => TaskTimeLog.fromJson(e))
          .toList(),
      taskPreference: json['taskPreference']?.toString() ?? '',
      clientCode: json['clientCode']?.toString(),
      currentDayStartTime: json['currentDayStartTime'] != null
          ? (json['currentDayStartTime'] as num).toInt()
          : 0,
      serverNow: DateTime.parse(json['serverNow']),
    );
  }
}
