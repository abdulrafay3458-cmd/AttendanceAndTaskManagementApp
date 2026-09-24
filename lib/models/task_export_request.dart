import 'package:intl/intl.dart';

class ExportRequest {
  final DateTime startDate;    
  final DateTime endDate;     
  final String managerId;
  final String? employeeId;
  final String viewType;

  ExportRequest({
    required this.startDate,
    required this.endDate,
    required this.managerId,
    this.employeeId,
    this.viewType = 'Day'
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'managerId': managerId,
      'startDate': DateFormat('yyyy-MM-dd').format(startDate),
      'endDate': DateFormat('yyyy-MM-dd').format(endDate),
      'viewType': viewType,
    };

    if (employeeId != null) {
      data['employeeId'] = employeeId;
    }

    return data;
  }
}