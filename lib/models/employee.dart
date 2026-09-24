class Employee {
  final String employeeId;
  final String name;
  final String email;
  final String department;
  final String designation;
  final String? faceImageBase64;
  final String companyCode;
  final String employeeCode;
  final List<String> role;              // <-- was String
  final bool? imageApproved;
  final bool? isDeviceRegistered;
  final bool? anyDeviceRegistered;
  bool AppliedDeviceRegistration;

  Employee({
    required this.employeeId,
    required this.name,
    required this.email,
    required this.department,
    required this.designation,
    required this.faceImageBase64,
    required this.companyCode,
    required this.employeeCode,
    required this.role,
    required this.imageApproved,
    this.isDeviceRegistered,
    this.anyDeviceRegistered,
    this.AppliedDeviceRegistration = false,
  });

  String get primaryRole => role.isNotEmpty ? role.first : '';

  String get rolesLabel => role.join(', ');

  factory Employee.fromJson(Map<String, dynamic> json) {
    List<String> parsedRole = [];
    final rawRole = json['role'];
    if (rawRole is List) {
      parsedRole = rawRole.map((e) => e.toString()).toList();
    } else if (rawRole is String && rawRole.isNotEmpty) {
      parsedRole = [rawRole];
    }

    return Employee(
      employeeId: json['employeeId']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      companyCode: (json['CompanyCode'] ?? json['companyCode'])?.toString() ?? '',
      faceImageBase64: json['faceImageBase64']?.toString(),
      role: parsedRole,
      imageApproved: json['imageApproved'] as bool? ?? false,
      isDeviceRegistered: json['isDeviceRegistered'] as bool? ?? false,
      anyDeviceRegistered:
          (json['AnyDeviceRegistered'] ?? json['anyDeviceRegistered']) as bool? ?? false,
    );
  }

  Employee copyWith({String? faceImageBase64, bool? imageApproved}) {
    return Employee(
      employeeId: this.employeeId,
      employeeCode: this.employeeCode,
      name: this.name,
      email: this.email,
      department: this.department,
      designation: this.designation,
      companyCode: this.companyCode,
      faceImageBase64: faceImageBase64 ?? this.faceImageBase64,
      role: this.role,
      imageApproved: imageApproved ?? this.imageApproved,
      isDeviceRegistered: this.isDeviceRegistered,
      anyDeviceRegistered: this.anyDeviceRegistered,
      AppliedDeviceRegistration: this.AppliedDeviceRegistration,
    );
  }
}