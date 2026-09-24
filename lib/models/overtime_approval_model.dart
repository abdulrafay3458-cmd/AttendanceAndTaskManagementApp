class OvertimeApprovalModel {
  final String userTaskId; // identifies this pending request for approve/reject
  final String employeeId;
  final String employeeName;
  final DateTime overtimeDate;
  final double overtimeHours;
  final String reason;

  OvertimeApprovalModel({
    required this.userTaskId,
    required this.employeeId,
    required this.employeeName,
    required this.overtimeDate,
    required this.overtimeHours,
    required this.reason,
  });

  static dynamic _get(Map<String, dynamic> json, String key) {
    if (json.containsKey(key)) return json[key];
    final lower = key[0].toLowerCase() + key.substring(1);
    if (json.containsKey(lower)) return json[lower];
    final upper = key[0].toUpperCase() + key.substring(1);
    if (json.containsKey(upper)) return json[upper];
    return null;
  }

  String get formattedOvertime {
    final totalMinutes = (overtimeHours * 60).round();
    final hrs = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    if (hrs > 0 && mins > 0) {
      return '$hrs hr $mins min';
    } else if (hrs > 0) {
      return '$hrs hr';
    } else {
      return '$mins min';
    }
  }
  
  factory OvertimeApprovalModel.fromJson(Map<String, dynamic> json) {
    final dateRaw = _get(json, 'overtimeDate');
    final hoursRaw = _get(json, 'overtimeHours');

    return OvertimeApprovalModel(
      userTaskId: _get(json, 'userTaskId')?.toString() ?? '',
      employeeId: _get(json, 'employeeId')?.toString() ?? '',
      employeeName: _get(json, 'employeeName')?.toString() ?? 'Unknown',
      overtimeDate: dateRaw != null ? DateTime.parse(dateRaw.toString()) : DateTime.now(),
      overtimeHours: (hoursRaw as num?)?.toDouble() ?? 0.0,
      reason: _get(json, 'reason')?.toString() ?? 'No reason provided',
    );
  }
}