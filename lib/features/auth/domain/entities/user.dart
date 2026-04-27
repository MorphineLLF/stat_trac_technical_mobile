import 'package:flutter/foundation.dart';

enum UserRole { technician, seniorTechnician, supervisor, admin, customer }

@immutable
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.technicianCode,
  });

  final int id;
  final String name;
  final String email;
  final UserRole role;
  final String technicianCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is User && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
