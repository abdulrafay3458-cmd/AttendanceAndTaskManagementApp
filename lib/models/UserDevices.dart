class UserDevices {
  final String employeeCode;
  final String employeeName;
  String deviceManufacturer;
  String deviceModel;
  bool isProcessing;
  bool isRemoving;

  UserDevices({
    required this.employeeCode,
    required this.employeeName,
    this.deviceManufacturer = "",
    this.deviceModel = "",
    this.isProcessing = false,
    this.isRemoving = false,
  });

  factory UserDevices.fromJson(Map<String, dynamic> json) {
    return UserDevices(
      employeeCode: json['employeeCode'],
      employeeName: json['employeeName'],
      deviceManufacturer: json['deviceManufacturer'] ?? "",
      deviceModel: json['deviceModel'] ?? "",
    );
  }
}
