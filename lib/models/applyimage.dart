class ApplyImageModel {
  final String employeeCode;
  final String faceImage;
  final String companyCode;

  ApplyImageModel({
    required this.employeeCode,
    required this.faceImage,
    required this.companyCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'employeeCode': employeeCode,
      'faceImage': faceImage,
      'companyCode': companyCode,
    };
  }

  factory ApplyImageModel.fromJson(Map<String, dynamic> json) {
    return ApplyImageModel(
      employeeCode: json['employeeCode'] ?? '',
      faceImage: json['faceImage'] ?? '',
      companyCode: json['companyCode'] ?? '',
    );
  }
}
