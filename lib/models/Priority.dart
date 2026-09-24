class Priority {
  final String title;
  final int minHours;
  final int maxHours;

  Priority({
    required this.title,
    required this.minHours,
    required this.maxHours,
  });

  factory Priority.fromJson(Map<String, dynamic> json) {
    return Priority(
      title: json['title'],
      minHours: json['minHours'],
      maxHours: json['maxHours'],
    );
  }
}