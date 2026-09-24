class PendingTask {
  final String id;
  final String title;
  final String? description;
  final String? dueTime;
  final String priority;
  final DateTime assignedDate;

  PendingTask({
    required this.id,
    required this.title,
    this.description,
    this.dueTime,
    required this.priority,
    required this.assignedDate,
  });

  factory PendingTask.fromJson(Map<String, dynamic> json) {
    return PendingTask(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dueTime: json['dueDate'],
      priority: json['priority'],
      assignedDate: DateTime.parse(json['assignedDate']),
    );
  }
}