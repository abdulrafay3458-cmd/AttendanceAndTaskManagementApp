class UserRole {
  final String id; // 🔑 STRING now
  final String name;

  UserRole({
    required this.id,
    required this.name,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'].toString(),
      name: json['name'],
    );
  }
}
