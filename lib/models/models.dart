import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String status;
  final String phone;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.status = 'active',
    this.phone = '',
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUser(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      role: data['role']?.toString() ?? 'patient',
      status: data['status']?.toString() ?? 'active',
      phone: data['phone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role,
        'status': status,
        'phone': phone,
      };
}
