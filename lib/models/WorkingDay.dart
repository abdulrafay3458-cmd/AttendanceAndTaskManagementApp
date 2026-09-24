class WorkingDay {
  final int weekDay;
  final int minutes;

  WorkingDay({
    required this.weekDay,
    required this.minutes,
  });

  factory WorkingDay.fromJson(Map<String, dynamic> json) {
    return WorkingDay(
      weekDay: json['weekDays'],
      minutes: json['minutes'],
    );
  }
}