class AppUser {
  final String uid;
  final String name;
  final String role;
  final String email;

  AppUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.email,
  });

  factory AppUser.fromMap(String uid, Map<dynamic, dynamic> data) {
    return AppUser(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
    };
  }
}
