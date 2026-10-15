class AssignedTaskModel {
  final String taskId;
  final String title;
  final String description;
  final String assignedBy;
  final String teamName;
  final String priority;
  final DateTime? startDate;
  final DateTime? dueDate;

  final DateTime? serverNow;

  final String? status;
  final String? taskPreference;
  final double totalHoursWorked;

  const AssignedTaskModel({
    required this.taskId,
    required this.title,
    required this.description,
    required this.assignedBy,
    required this.teamName,
    required this.priority,
    this.startDate,
    this.dueDate,
    this.serverNow,
    this.status,
    this.taskPreference,
    this.totalHoursWorked = 0,
  });

  factory AssignedTaskModel.fromJson(Map<String, dynamic> json) {
    final m = <String, dynamic>{
      for (final e in json.entries) e.key.toLowerCase(): e.value,
    };

    String str(List<String> keys, {String fallback = ''}) {
      for (final k in keys) {
        final v = m[k.toLowerCase()];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString();
        }
      }
      return fallback;
    }

    String? optStr(List<String> keys) {
      final v = str(keys);
      return v.isEmpty ? null : v;
    }

    DateTime? date(List<String> keys) {
      final v = str(keys);
      return v.isEmpty ? null : DateTime.tryParse(v);
    }

    double number(List<String> keys) {
      for (final k in keys) {
        final v = m[k.toLowerCase()];

        if (v is num) return v.toDouble();

        if (v is String) {
          final p = double.tryParse(v);
          if (p != null) return p;
        }
      }

      return 0;
    }

    return AssignedTaskModel(
      taskId: str(['taskId', 'id']),
      title: str(['title', 'taskTitle'], fallback: 'Untitled task'),
      description: str(['description', 'taskDescription']),
      assignedBy: str(['assignedBy', 'assignedByName']),
      teamName: str(['teamName']),
      priority: str(['priority'], fallback: 'Medium'),
      startDate: date(['startDate']),
      dueDate: date(['dueDate']),
      serverNow: date(['serverNow']),
      status: optStr(['status']),
      taskPreference: optStr(['taskPreference']),
      totalHoursWorked: number(['totalHoursWorked']),
    );
  }

  String get _statusKey =>
      (status ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  bool get isRunning => _statusKey == 'inprogress';

  bool get isCompleted => _statusKey == 'completed';
}