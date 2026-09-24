import 'package:flutter/material.dart';
import 'package:attendance_app/models/task_time_log_response.dart';

class TaskReport {
  final String taskid;
  final String taskTitle;
  final String taskStatus;
  final String taskPriority;
  final DateTime? taskDueDate;
  final DateTime? completedAt;
  final List<TaskTimeLogResponse> timeLogs;

  TaskReport({
    required this.taskid,
    required this.taskTitle,
    required this.taskStatus,
    required this.taskPriority,
    this.taskDueDate,
    this.completedAt, 
    required this.timeLogs,
  });

  factory TaskReport.fromJson(Map<String, dynamic> json) {
    return TaskReport(
      taskid: json['taskid'],
      taskTitle: json['taskTitle'],
      taskStatus: json['taskStatus'] ?? 'unknown',
      taskPriority: json['taskPriority'] ?? 'medium',
      taskDueDate: json['taskDueDate'] != null 
          ? DateTime.parse(json['taskDueDate']) 
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      timeLogs: (json['timeLogs'] as List)
          .map((e) => TaskTimeLogResponse.fromJson(e))
          .toList(),
    );
  }
}

extension TaskStatusExtension on TaskReport {
  String get displayStatus {
    if (taskStatus == 'completed' && completedAt != null) {
      // Check if completed late
      if (taskDueDate != null && completedAt!.isAfter(taskDueDate!)) {
        return 'Completed Late';
      }
      return 'Completed';
    }
    
    switch (taskStatus.toLowerCase()) {
      case 'in_progress':
      case 'inprogress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'stopped':
        return 'Stopped';
      default:
        return taskStatus;
    }
  }

  Color get statusColor {
    switch (displayStatus) {
      case 'In Progress':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'Completed Late':
        return Colors.orange;
      case 'Stopped':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}