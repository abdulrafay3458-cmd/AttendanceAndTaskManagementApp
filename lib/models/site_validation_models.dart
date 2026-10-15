// lib/models/site_validation_models.dart
// Matches SiteValidationDetailResponse / SiteValidationResultResponse from the API.

DateTime? _utc(dynamic v) {
  if (v == null) return null;
  final s = v as String;
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(s);
  return DateTime.parse(hasZone ? s : '${s}Z');
}

double? _dn(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v) => (v ?? '') as String;

class SiteValidationRequest {
  final String id;
  final String taskId;
  final String taskAssignmentId;
  final String employeeName;
  final DateTime? requestedDateTime;
  final String faceVerificationStatus;
  final String locationVerificationStatus;
  final bool isLate;
  final String taskTitle;
  final String projectName;
  final String clientName;
  final String locationName;
  final DateTime? workStartedAt;
  final DateTime? responseDueDateTime;
  final int secondsRemaining; // server-computed at fetch time (device clock is not trusted)
  final String status;
  final double? calculatedDistance;
  final double allowedRadius;
  final int attemptCount;
  final int maxAttempts;
  final bool canValidate;
  final String? remarks;

  SiteValidationRequest({
    required this.id,
    required this.taskId,
    required this.taskAssignmentId,
    required this.employeeName,
    required this.requestedDateTime,
    required this.faceVerificationStatus,
    required this.locationVerificationStatus,
    required this.isLate,
    required this.taskTitle,
    required this.projectName,
    required this.clientName,
    required this.locationName,
    required this.workStartedAt,
    required this.responseDueDateTime,
    required this.secondsRemaining,
    required this.status,
    required this.calculatedDistance,
    required this.allowedRadius,
    required this.attemptCount,
    required this.maxAttempts,
    required this.canValidate,
    required this.remarks,
  });

  bool get isPending => status.toLowerCase() == 'pending';
  int get attemptsLeft => (maxAttempts - attemptCount).clamp(0, maxAttempts);

  factory SiteValidationRequest.fromJson(Map<String, dynamic> j) => SiteValidationRequest(
        id: j['id'] as String,
        taskId: j['taskId'] as String,
        taskAssignmentId: j['taskAssignmentId'] as String,
        employeeName: _s(j['employeeName']),
        requestedDateTime: _utc(j['requestedDateTime']),
        faceVerificationStatus: _s(j['faceVerificationStatus']),
        locationVerificationStatus: _s(j['locationVerificationStatus']),
        isLate: j['isLate'] == true,
        taskTitle: _s(j['taskTitle']),
        projectName: _s(j['projectName']),
        clientName: _s(j['clientName']),
        locationName: _s(j['locationName']),
        workStartedAt: _utc(j['workStartedAt']),
        responseDueDateTime: _utc(j['responseDueDateTime']),
        secondsRemaining: (j['secondsRemaining'] as num?)?.toInt() ?? 0,
        status: _s(j['status']),
        calculatedDistance: _dn(j['calculatedDistance']),
        allowedRadius: _dn(j['allowedRadius']) ?? 0,
        attemptCount: (j['attemptCount'] as num?)?.toInt() ?? 0,
        maxAttempts: (j['maxAttempts'] as num?)?.toInt() ?? 3,
        canValidate: j['canValidate'] == true,
        remarks: j['remarks'] as String?,
      );
}

class SiteValidationResult {
  final String status;
  final double calculatedDistance;
  final double allowedRadius;
  final bool isLate;

  SiteValidationResult({
    required this.status,
    required this.calculatedDistance,
    required this.allowedRadius,
    required this.isLate,
  });

  factory SiteValidationResult.fromJson(Map<String, dynamic> j) => SiteValidationResult(
        status: _s(j['status']),
        calculatedDistance: _dn(j['calculatedDistance']) ?? 0,
        allowedRadius: _dn(j['allowedRadius']) ?? 0,
        isLate: j['isLate'] == true,
      );
}
