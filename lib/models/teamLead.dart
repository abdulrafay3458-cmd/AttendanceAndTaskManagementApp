class TeamLead {
  final String code;
  final String name;
 
  TeamLead({required this.code, required this.name});
 
  factory TeamLead.fromJson(Map<String, dynamic> json) {
    return TeamLead(
      code: json['code'] ?? json['Code'] ?? '',
      name: json['name'] ?? json['Name'] ?? '',
    );
  }
}