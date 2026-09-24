// models/company.dart
class Company {
  final String code;
  final String name;

  Company({required this.code, required this.name});

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      code: json['code'] ?? json['Code'] ?? '',
      name: json['name'] ?? json['Name'] ?? '',
    );
  }
}
