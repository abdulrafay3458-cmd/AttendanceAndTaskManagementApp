class PreviousDateData {
  final DateTime? checkIn;
  final DateTime? checkOut;
  final bool isLeave;
  final List<TaskRecord> taskList;

  PreviousDateData({
    required this.checkIn,
    required this.checkOut,
    required this.isLeave,
    required this.taskList,
  });

  factory PreviousDateData.fromJson(Map<String, dynamic> json) {
    return PreviousDateData(
      checkIn: json['checkIn'] != null ? DateTime.parse(json['checkIn']) : null,
      checkOut: json['checkOut'] != null ? DateTime.parse(json['checkOut']) : null,
      isLeave: json['isLeave'] ?? false,
      taskList: (json['taskList'] as List?)?.map((item) => TaskRecord.fromJson(item)).toList() ?? [],
    );
  }
    PreviousDateData copyWith({
    DateTime? checkIn,
    DateTime? checkOut,
    bool? isLeave,
    List<TaskRecord>? taskList,
  }) {
    return PreviousDateData(
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      isLeave: isLeave ?? this.isLeave,
      taskList: taskList ?? this.taskList,
    );
  }
}

class TaskRecord {
  final String taskTitle;
  final String taskStatus;
  final double totalHoursWorked;

  TaskRecord({
    required this.taskTitle,
    required this.taskStatus,
    required this.totalHoursWorked,
  });

  factory TaskRecord.fromJson(Map<String, dynamic> json) {
    return TaskRecord(
      taskTitle: json['taskTitle'] ?? '',
      taskStatus: json['taskStatus'] ?? '',
      totalHoursWorked: (json['totalHoursWorked'] as num?)?.toDouble() ?? 0.0,
    );
  }
}