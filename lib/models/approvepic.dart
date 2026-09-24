class ApprovePicModel {
  final String code;
  final String employeeCode;
  final String adminCode;
  final DateTime? approveDate;
  final DateTime? rejectionDate;
  final String? rejectionReason;
  final bool historyStatus;
  final bool status;
  final String companyCode; 

  ApprovePicModel({
    required this.code,
    required this.employeeCode,
    required this.adminCode,
    this.approveDate,
    this.rejectionDate,
    this.rejectionReason,
    required this.historyStatus,
    required this.status,
    required this.companyCode
  });

  factory ApprovePicModel.fromJson(Map<String, dynamic> json) {
    return ApprovePicModel(
      code: json['code'] ?? '',
      employeeCode: json['employeeCode'] ?? '',
      adminCode: json['adminCode'] ?? '',
      approveDate: json['approveDate'] != null
          ? DateTime.parse(json['approveDate'])
          : null,
      rejectionDate: json['rejectionDate'] != null
          ? DateTime.parse(json['rejectionDate'])
          : null,
      rejectionReason: json['rejectionReason'] ?? '',
      historyStatus: json['historyStatus'] == true || json['historyStatus'] == 1,
      status: json['status'] == true,
      companyCode: json['employeeCode'] ?? ''
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'employeeCode': employeeCode,
      'adminCode': adminCode,
      'approveDate': approveDate?.toIso8601String(),
      'rejectionDate': rejectionDate?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'historystatus': historyStatus,
      'status': status,
      'companyCode': companyCode,
    };
  }
}