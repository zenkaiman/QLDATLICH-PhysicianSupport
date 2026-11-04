import '../config/constants.dart';

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final Role role;
  final String? avatarUrl;
  final String? hospitalId;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.hospitalId,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: Role.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => Role.patient,
      ),
      avatarUrl: json['avatarUrl'],
      hospitalId: json['hospitalId'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role.name,
      'avatarUrl': avatarUrl,
      'hospitalId': hospitalId,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
