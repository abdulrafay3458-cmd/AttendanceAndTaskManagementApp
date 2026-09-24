class LeaveType {
  final String code;
  final String title;

  LeaveType({
    required this.code,
    required this.title,
  });

  factory LeaveType.fromJson(Map<String, dynamic> json) {
    return LeaveType(
      code: json['leaveCode'].toString(),
      title: json['leaveTitle'].toString(),
    );
  }
}
