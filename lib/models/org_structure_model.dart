// Models for the new Team / TeamMember / ReportingEmployee structure.
// Named distinctly from the existing `TeamMember` class in
// services/teammember.dart (which is an unrelated employee-display model)
// to avoid any import collision.

class TeamModel {
  final String teamId;
  final String companyId;
  final String teamName;
  final bool status;
  final String teamHeadId;
  final String? teamHeadName;
  final int memberCount;

  TeamModel({
    required this.teamId,
    required this.companyId,
    required this.teamName,
    required this.status,
    required this.teamHeadId,
    this.teamHeadName,
    required this.memberCount,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      teamId: json['teamId']?.toString() ?? '',
      companyId: json['companyId']?.toString() ?? '',
      teamName: json['teamName']?.toString() ?? '',
      status: json['status'] ?? true,
      teamHeadId: json['teamHeadId']?.toString() ?? '',
      teamHeadName: json['teamHeadName']?.toString(),
      memberCount: json['memberCount'] ?? 0,
    );
  }
}

class TeamMemberRecord {
  final String teamMemberId;
  final String teamId;
  final String employeeId;
  final String? employeeName;
  final String? employeeCode;
  final DateTime? effeciveFrom;
  final DateTime? effectiveTo;
  final bool status;

  TeamMemberRecord({
    required this.teamMemberId,
    required this.teamId,
    required this.employeeId,
    this.employeeName,
    this.employeeCode,
    this.effeciveFrom,
    this.effectiveTo,
    required this.status,
  });

  factory TeamMemberRecord.fromJson(Map<String, dynamic> json) {
    return TeamMemberRecord(
      teamMemberId: json['teamMemberId']?.toString() ?? '',
      teamId: json['teamId']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      employeeName: json['employeeName']?.toString(),
      employeeCode: json['employeeCode']?.toString(),
      effeciveFrom: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,

      effectiveTo: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,

      status: json['status'] ?? true,
    );
  }
}

// One row per person under a manager, at any depth — used for the "reporting
// head sees everyone under their team lead" visibility requirement.
class SubordinateModel {
  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final int depth;
  final String directManagerId;

  SubordinateModel({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.depth,
    required this.directManagerId,
  });

  factory SubordinateModel.fromJson(Map<String, dynamic> json) {
    return SubordinateModel(
      employeeId: json['employeeId']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      depth: json['depth'] ?? 1,
      directManagerId: json['directManagerId']?.toString() ?? '',
    );
  }
}
