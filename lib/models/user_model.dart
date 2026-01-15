class AppUser {
  final String uid;
  final String name;
  final String role;
  final String email;
  // Teacher-specific fields (nullable)
  final String? yearsOfExperience;
  final String? subjectExpertise;

  AppUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.email,
    this.yearsOfExperience,
    this.subjectExpertise,
  });

  factory AppUser.fromMap(String uid, Map<dynamic, dynamic> data) {
    return AppUser(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? '',
      yearsOfExperience: data['yearsOfExperience'],
      subjectExpertise: data['subjectExpertise'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'name': name, 'email': email, 'role': role};
    // Only include teacher fields if they are not null
    if (yearsOfExperience != null) {
      map['yearsOfExperience'] = yearsOfExperience;
    }
    if (subjectExpertise != null) {
      map['subjectExpertise'] = subjectExpertise;
    }
    return map;
  }
}
