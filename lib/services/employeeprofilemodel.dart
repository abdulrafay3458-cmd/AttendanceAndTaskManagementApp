class EmployeeProfileModel {
  final String code;
  final String employeeCode;
  final String employeeName;
  final String adminCode;
  final DateTime requestDate;
  final DateTime? approveDate;
  final DateTime? rejectionDate;
  final String? rejectionReason;
  final String faceImage;
  final bool status;
  final String companyCode; 

  EmployeeProfileModel({
    required this.code,
    required this.employeeCode,
    required this.employeeName,
    required this.adminCode,
    required this.requestDate,
    this.approveDate,
    this.rejectionDate,
    this.rejectionReason,
    required this.faceImage,
    required this.status,
    required this.companyCode
  });

  factory EmployeeProfileModel.fromJson(Map<String, dynamic> json) {
    return EmployeeProfileModel(
      code: json['code'] ?? '',
      employeeCode: json['employeeCode'] ?? '',
      adminCode: json['adminCode'] ?? '',
      employeeName: json['employeeName'] ?? '',
      requestDate: DateTime.parse(json['requestDate']),
      approveDate: json['approveDate'] != null
          ? DateTime.parse(json['approveDate'])
          : null,
      rejectionDate: json['rejectionDate'] != null
          ? DateTime.parse(json['rejectionDate'])
          : null,
      rejectionReason: json['rejectionReason'] ?? '',
      faceImage: json['faceImage'] ?? '',
      status: json['status'] == true || json['status'] == 1,
      companyCode: json['companyCode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'employeeCode': employeeCode,
      'employeeName': employeeName,
      'adminCode': adminCode,
      'requestDate': requestDate.toIso8601String(),
      'approveDate': approveDate?.toIso8601String(),
      'rejectionDate': rejectionDate?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'faceImage': faceImage,
      'status': status,
      'companyCode': companyCode,
    };
  }
}