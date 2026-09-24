class TeamMember {
  final String employeeId;
  final String name;
  final String email;
  final String department;

  final String designation;
  final int designationCode; // Changed from int to String

  final String companyCode;
  final String machineId;
  final String phone;
  final String leadCode;
  final String joinDate;

  final bool isAppUser;
  final bool isActive;

  final String roleId;
  final String? role;

  final int standardHourCode; // Changed from int to String

  TeamMember({
    required this.employeeId,
    required this.name,
    required this.email,
    required this.department,
    required this.designation,
    required this.designationCode,
    required this.companyCode,
    required this.machineId,
    required this.phone,
    required this.leadCode,
    required this.joinDate,
    required this.isAppUser,
    required this.isActive,
    required this.roleId,
    this.role,
    required this.standardHourCode,
  });

  // In services/teammember.dart
TeamMember copyWith({
  String? employeeId,
  String? name,
  String? email,
  String? phone,
  String? department,
  String? designation,
  int? designationCode,
  String? companyCode,
  int? standardHourCode,
  String? leadCode,
  String? machineId,
  String? joinDate,
  bool? isActive,
  bool? isAppUser,
  String? roleId,
  String? role,
}) {
  return TeamMember(
    employeeId: employeeId ?? this.employeeId,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    department: department ?? this.department,
    designation: designation ?? this.designation,
    designationCode: designationCode ?? this.designationCode,
    companyCode: companyCode ?? this.companyCode,
    standardHourCode: standardHourCode ?? this.standardHourCode,
    leadCode: leadCode ?? this.leadCode,
    machineId: machineId ?? this.machineId,
    joinDate: joinDate ?? this.joinDate,
    isActive: isActive ?? this.isActive,
    isAppUser: isAppUser ?? this.isAppUser,
    roleId: roleId ?? this.roleId,
    role: role ?? this.role,
  );
}

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      employeeId: json['employeeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      department: json['department']?.toString() ?? '',

      designation:
          json['designationName']?.toString() ??
          json['designation']?.toString() ??
          '',

      designationCode: json['designationCode']?? '',

      companyCode: json['companyCode']?.toString() ?? '',
      machineId: json['machineId']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      leadCode: json['leadCode']?.toString() ?? '',
      joinDate: json['joinDate']?.toString() ?? '',

      isAppUser: json['isAppUser'] ?? false,
      isActive: json['isActive'] ?? true,

      roleId: json['roleId']?.toString() ?? '',
      role: json['role']?.toString(),

      standardHourCode: json['standardHourCode'] ?? '',
    );
  }
}