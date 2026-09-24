class Daywise {
  final String StandardHours;
  final String OverTime;
  final String WorkingHours;
  final bool? IsLate;

  Daywise({required this.StandardHours, required this.OverTime, required this.WorkingHours, required this.IsLate});

  factory Daywise.fromJson(Map<String, dynamic> json) {
    return Daywise(
      StandardHours: json['StandardHours'] ?? json['standardHours'] ?? '',
      OverTime: json['OverTime'] ?? json['overTime'] ?? '',
      WorkingHours: json['WorkingHours'] ?? json['workingHours'] ?? '',
      IsLate: json['IsLate'] ?? json['isLate'] ?? false,
    );
  }
}