class StandardHourGroup {
  final int id;
  final String name;
 
  StandardHourGroup({
    required this.id,
    required this.name,
  });
 
  factory StandardHourGroup.fromJson(Map<String, dynamic> json) {
    return StandardHourGroup(
      id: json['code'],
      name: json['title'],
    );
  }
}