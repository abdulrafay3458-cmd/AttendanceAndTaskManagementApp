class ApproveimageresponseModel {
    final String EmpCode;
    final String Image;
    final bool Status;

    ApproveimageresponseModel({
      required this.EmpCode,
      required this.Image,
      required this.Status,
    });

    factory ApproveimageresponseModel.fromJson(Map<String, dynamic> json){
      return ApproveimageresponseModel(
      EmpCode: json['empCode'] ?? '',
      Image: json['image'] ?? '',
      Status: json['status'] == true);
    }

    Map<String, dynamic> toJson() {
    return {
      'empCode': EmpCode,
      'image': Image,
      'status': Status,
    };
    }
}