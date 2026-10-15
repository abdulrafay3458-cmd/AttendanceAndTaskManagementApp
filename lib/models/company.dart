// models/company.dart
class Company {
  final String code;
  final String name;
  final String Id;

  Company({required this.code, required this.name , required this.Id});

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      code: json['code'] ?? json['Code'] ?? '',
      name: json['name'] ?? json['Name'] ?? '',
       Id: json['CompanyId'] ?? json['companyId'] ?? '',
    );
  }
}
