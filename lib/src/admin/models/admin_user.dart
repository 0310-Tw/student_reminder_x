// file: lib/src/admin/models/admin_user.dart
class AdminUser {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminUser({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminUser.fromMap(String uid, Map<String, dynamic> data) {
    return AdminUser(
      uid: uid,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'student',
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'role': role,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  String get displayName => '$firstName $lastName'.trim();
  bool get isAdmin => role == 'admin';
}
