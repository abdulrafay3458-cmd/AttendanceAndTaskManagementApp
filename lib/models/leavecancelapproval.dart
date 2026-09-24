class LeavecancelapprovalModel {
  final String id;
  final String employeeCode;
  final String employeeName;
  // final DateTime fromDate;
  // final DateTime toDate;
    final DateTime submissionDate;
  final String approverEmployeeCode;
  final String? purpose;
  final String state;
  final DateTime? approveDate;
  final String? reason;
  final DateTime? rejectDate;
  final DateTime leaveDate;

  LeavecancelapprovalModel({
    required this.id,
    required this.employeeCode,
    required this.employeeName,
    // required this.fromDate,
    // required this.toDate,
    required this.submissionDate,
    required this.approverEmployeeCode,
    this.purpose,
    required this.state,
    this.approveDate,
    this.reason,
    this.rejectDate,
    required this.leaveDate
  });

  factory LeavecancelapprovalModel.fromJson(Map<String, dynamic> json) {
    return LeavecancelapprovalModel(
      id: json['id']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      // fromDate: DateTime.parse(json['fromDate']?.toString() ?? DateTime.now().toString()),
      // toDate: DateTime.parse(json['toDate']?.toString() ?? DateTime.now().toString()),
      approverEmployeeCode: json['approverEmployeeCode']?.toString() ?? '',
      purpose: json['purpose']?.toString(),
      state: json['state']?.toString() ?? '',
      approveDate: json['approveDate'] != null 
          ? DateTime.parse(json['approveDate'].toString())
          : null,
      reason: json['reason']?.toString(),
      rejectDate: json['rejectDate'] != null 
          ? DateTime.parse(json['rejectDate'].toString())
          : null,
      leaveDate: DateTime.parse(json['leaveDate']?.toString() ?? DateTime.now().toString()),
      submissionDate:  DateTime.parse(json['submissionDate']?.toString() ?? DateTime.now().toString())
    );
  }

  // int get totalDays {
  //   final difference = toDate.difference(fromDate).inDays;
  //   return difference + 1;
  // }
}