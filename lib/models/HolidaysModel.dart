class Holiday {
  final int day;
  final int month;
  final int year;
  final int weekday;
  final DateTime holidayDate;
  final String title;

  Holiday({
    required this.day,
    required this.month,
    required this.year,
    required this.weekday,
    required this.holidayDate,
    required this.title,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      day: json['day'],
      month: json['month'],
      year: json['year'],
      weekday: json['weekday'],
      holidayDate: DateTime.parse(json['holidayDate']),
      title: json['title'],
    );
  }
}
