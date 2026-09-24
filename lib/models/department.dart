// models/department.dart
class Department {
  final String code;
  final String name;

  Department({required this.code, required this.name});

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      code: json['code'] ?? json['Code'] ?? '',
      name: json['name'] ?? json['Name'] ?? '',
    );
  }
}
