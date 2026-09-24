class Designation {
  final int code;
  final String name;

  Designation({required this.code, required this.name});

  factory Designation.fromJson(Map<String, dynamic> json) {
    return Designation(
      code: json['designationCode'],
      name: json['designationName'],
    );
  }
}