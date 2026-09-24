class LeaveRequestModel {
  final int id;
  final String employeeId;
  final String employeeName;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final double totalDays;
  final String reason;
  final String status;
  final String approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime? createdAt;
 final List<DateTime> availableDates; 

  LeaveRequestModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    required this.status,
    required this.approvedBy,
    this.approvedAt,
    required this.rejectionReason,
    required this.createdAt,
    required this.availableDates
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id'] ?? 0,
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      leaveType: json['leaveType'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      totalDays: (json['totalDays'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'],
      status: json['status'] ?? 'pending',
      approvedBy: json['approvedBy'] ?? '',
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'])
          : null,
      rejectionReason: json['rejectionReason'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      availableDates: (json['availableDates'] as List<dynamic>?)
              ?.map((d) => DateTime.parse(d.toString()))
              .toList() ??
          [],
    );
  }

  // Helper method to check if it's a single day leave
  bool get isSingleDay {
    return startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;
  }

  // Helper method to format date
  String get formattedDate {
    return _formatDate(startDate);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
