class StandardHourGroup {
  final int code;
  String title;
  List<StandardHourRequest> hourList;

  StandardHourGroup({
    required this.code,
    required this.title,
    required this.hourList,
  });

  factory StandardHourGroup.fromJson(Map<String, dynamic> json) {
    return StandardHourGroup(
      code: json['Code'] ?? json['code'] ?? 0,
      title: json['Title'] ?? json['title'] ?? '',
      hourList: ((json['HourList'] ?? json['hourList']) as List<dynamic>?)
              ?.map((e) => StandardHourRequest.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class StandardHourGroupRequest {
  final int code;
  final String title;
  final List<StandardHourRequest> hourList;

  StandardHourGroupRequest({
    required this.code,
    required this.title,
    required this.hourList,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'title': title,
      'hourList': hourList.map((h) => h.toJson()).toList(),
    };
  }
}

class StandardHourRequest {
  final int groupCode;
  int weekDay;
  String weekDayName;
  String hours;
  int minutes;
  String? timeIn;
  String? timeOut;
  int? halfDayMinutes;
  String? halfDayHourOnLateArrival;

  StandardHourRequest({
    required this.groupCode,
    required this.weekDay,
    required this.weekDayName,
    required this.hours,
    required this.minutes,
    this.timeIn,
    this.timeOut,
    this.halfDayMinutes,
    this.halfDayHourOnLateArrival,
  });

  factory StandardHourRequest.fromJson(Map<String, dynamic> json) {
    return StandardHourRequest(
      groupCode: json['GroupCode'] ?? json['groupCode'] ?? 0,
      weekDay: json['WeekDay'] ?? json['weekDay'] ?? 0,
      weekDayName: json['WeekDayName'] ?? json['weekDayName'] ?? '',
      hours: (json['Hours'] ?? json['hours'] ?? '0').toString(),
      minutes: json['Minutes'] ?? json['minutes'] ?? 0,
      timeIn: json['TimeIn'] ?? json['timeIn'],
      timeOut: json['TimeOut'] ?? json['timeOut'],
      halfDayMinutes: json['HalfDayMinutes'] ?? json['halfDayMinutes'],
      halfDayHourOnLateArrival:
          json['HalfDayHourOnLateArrival'] ?? json['halfDayHourOnLateArrival'],
    );
  }
  
  static String? _withSeconds(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return hhmm;
    final parts = hhmm.split(':');
    if (parts.length == 2) return '$hhmm:00';
    return hhmm;
  }

  Map<String, dynamic> toJson() {
    return {
      'groupCode': groupCode,
      'weekDay': weekDay,
      'weekDayName': weekDayName,
      'hours': _withSeconds(hours),
      'minutes': minutes,
      'timeIn': _withSeconds(timeIn),
      'timeOut': _withSeconds(timeOut),
      'halfDayMinutes': halfDayMinutes,
      'halfDayHourOnLateArrival': _withSeconds(halfDayHourOnLateArrival),
    };
  }
}