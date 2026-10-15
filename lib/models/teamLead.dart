class TeamLead {
  final String id;
  final String code;
  final String name;
 
  TeamLead({required this.code, required this.name, required this.id});
 
  factory TeamLead.fromJson(Map<String, dynamic> json) {
    return TeamLead(
      id: json['employeeId'] ?? json['EmployeeId'] ?? '',
      code: json['code'] ?? json['Code'] ?? '',
      name: json['name'] ?? json['Name'] ?? '',
    );
  }
}