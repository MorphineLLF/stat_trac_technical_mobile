import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    required super.technicianCode,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String? ?? '',
      role: _parseRole(json['role'] as String? ?? ''),
      technicianCode: json['technician_code'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'technician_code': technicianCode,
      };

  static UserRole _parseRole(String value) {
    return switch (value) {
      'technician' => UserRole.technician,
      'senior_technician' => UserRole.seniorTechnician,
      'supervisor' => UserRole.supervisor,
      'admin' => UserRole.admin,
      'customer' => UserRole.customer,
      _ => UserRole.technician,
    };
  }
}
