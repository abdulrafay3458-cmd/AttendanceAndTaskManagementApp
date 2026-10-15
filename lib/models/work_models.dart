// lib/models/work_models.dart
// Shapes match GET api/assignments/{id}/work-state and GET api/my-assignments.

import '../widgets/app_date.dart';

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _s(dynamic v) => (v ?? '') as String;
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String);

class TaskInfo {
  final String title;
  final String description;
  final String clientName;
  final String projectName;
  final String taskTypeName;
  final String priority;
  final DateTime? dueDate;

  TaskInfo({
    required this.title,
    required this.description,
    required this.clientName,
    required this.projectName,
    required this.taskTypeName,
    required this.priority,
    required this.dueDate,
  });

  factory TaskInfo.fromJson(Map<String, dynamic> j) => TaskInfo(
        title: _s(j['title']),
        description: _s(j['description']),
        clientName: _s(j['clientName']),
        projectName: _s(j['projectName']),
        taskTypeName: _s(j['taskTypeName']),
        priority: _s(j['priority']),
        dueDate: _date(j['dueDate']),
      );
}

class AssignmentItem {
  final String assignmentId;
  final String taskId;
  final String title;
  final String clientName;
  final String projectName;
  final String priority;
  final String status;
  final DateTime? dueDate;
  final double totalHours;
  final double todayHours;
  final bool isRunning;

  AssignmentItem({
    required this.assignmentId,
    required this.taskId,
    required this.title,
    required this.clientName,
    required this.projectName,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.totalHours,
    required this.todayHours,
    required this.isRunning,
  });

  bool get isCompleted => status.toLowerCase() == 'completed';

  factory AssignmentItem.fromJson(Map<String, dynamic> j) => AssignmentItem(
        assignmentId: j['assignmentId'],
        taskId: j['taskId'],
        title: _s(j['title']),
        clientName: _s(j['clientName']),
        projectName: _s(j['projectName']),
        priority: _s(j['priority']),
        status: _s(j['status']),
        dueDate: _date(j['dueDate']),
        totalHours: _d(j['totalHours']),
        todayHours: _d(j['todayHours']),
        isRunning: j['isRunning'] == true,
      );
}

class WorkSession {
  final DateTime start;
  final DateTime? end;
  final double hours;

  WorkSession({required this.start, this.end, required this.hours});

  bool get isRunning => end == null;

  factory WorkSession.fromJson(Map<String, dynamic> j) => WorkSession(
        start: AppDate.parseUtc(j['startDateTime']),
        end: AppDate.tryParseUtc(j['endDateTime']),
        hours: _d(j['sessionHours']),
      );
}

class DaySummary {
  final String workDate; // yyyy-MM-dd
  final double hours;
  final String summary;

  DaySummary({required this.workDate, required this.hours, required this.summary});

  factory DaySummary.fromJson(Map<String, dynamic> j) => DaySummary(
        workDate: j['workDate'] as String,
        hours: _d(j['dailyTotalHours']),
        summary: _s(j['summary']),
      );
}

class WorkState {
  final TaskInfo task;
  final bool onLeaveToday;
  final bool siteValidationRequired;
  final bool completionSnapshotRequired;
  final DateTime? openSessionStart;
  final bool siteValidatedToday;
  final String todayDate; // server-defined work date (employee's time zone)
  final List<WorkSession> todaySessions;
  final double todayHours; // finished sessions only; add the live timer for a running one
  final String todaySummary;
  final String todayRemarks;
  final List<DaySummary> history;
  final double totalHours;
  final String status;
  final DateTime? serverNow; // UTC instant from the API, used by ServerClock.sync

  WorkState({
    required this.task,
    required this.onLeaveToday,
    required this.siteValidationRequired,
    required this.completionSnapshotRequired,
    required this.openSessionStart,
    required this.siteValidatedToday,
    required this.todayDate,
    required this.todaySessions,
    required this.todayHours,
    required this.todaySummary,
    required this.todayRemarks,
    required this.history,
    required this.totalHours,
    required this.status,
    this.serverNow,
  });

  bool get isRunning => openSessionStart != null;
  bool get isCompleted => status.toLowerCase() == 'completed';

  factory WorkState.fromJson(Map<String, dynamic> j) {
    final flags = (j['taskTypeFlags'] ?? {}) as Map<String, dynamic>;
    final today = (j['today'] ?? {}) as Map<String, dynamic>;
    final open = j['openSession'] as Map<String, dynamic>?;
    return WorkState(
      task: TaskInfo.fromJson((j['taskInfo'] ?? {}) as Map<String, dynamic>),
      onLeaveToday: j['onLeaveToday'] == true,
      siteValidationRequired: flags['siteValidationRequired'] == true,
      completionSnapshotRequired: flags['completionSnapshotRequired'] == true,
      openSessionStart: AppDate.tryParseUtc(open?['startDateTime']),
      siteValidatedToday: j['siteValidatedToday'] == true,
      todayDate: _s(today['workDate']),
      todaySessions: ((today['sessions'] ?? []) as List)
          .map((e) => WorkSession.fromJson(e as Map<String, dynamic>))
          .toList(),
      todayHours: _d(today['dailyTotalHours']),
      todaySummary: _s(today['summary']),
      todayRemarks: _s(today['remarks']),
      history: ((j['history'] ?? []) as List)
          .map((e) => DaySummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalHours: _d(j['totalHours']),
      status: _s(j['status']),
      serverNow: AppDate.tryParseUtc(j['serverNow']),
    );
  }
}