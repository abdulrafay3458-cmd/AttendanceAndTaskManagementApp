class AttendanceRecord {
  final String employeeCode;
  final DateTime? attendanceDate;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? checkInSource;
  final String? checkOutSource;
  final String? totalHours;
  final String? status;
  final String? deviceName;
  final String? location;
  final String? employeeName;
 
  AttendanceRecord({
    required this.employeeCode,
    this.attendanceDate,
    this.checkInTime,
    this.checkOutTime,
    this.checkInSource,
    this.checkOutSource,
    this.totalHours,
    this.status,
    this.deviceName,
    this.location,
    this.employeeName,
  });
 
  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value.toString().isEmpty) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }
 
    return AttendanceRecord(
      employeeCode: json['employeeCode']?.toString() ?? '',
 
      attendanceDate: parseDate(json['attendanceDate']),
 
      checkInTime: parseDate(json['checkInTime']),
 
      checkOutTime: parseDate(json['checkOutTime']),
 
      checkInSource: json['checkInSource']?.toString(),
      checkOutSource: json['checkOutSource']?.toString(),
      totalHours: json['totalHours']?.toString(),
      status: json['status']?.toString(),
      deviceName: json['deviceName']?.toString(),
      location: json['location']?.toString(),
 
      employeeName: json['employee'] != null
          ? json['employee']['name']?.toString()
          : null,
    );
  }
}