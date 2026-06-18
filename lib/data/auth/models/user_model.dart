// FILE: lib/data/auth/models/user_model.dart
import 'dart:convert';
import '../../../domain/auth/entities/user_entity.dart';

/// Model tầng Data — chuyển đổi JSON (API/Cache) ↔ UserEntity (Domain)
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.phone,
    required super.role,
    required super.token,
    required super.refreshToken,
    super.status    = 'active',
    super.lastLogin,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id:           j['id']?.toString()           ?? '',
    fullName:     j['fullName']  ?? j['full_name'] ?? '',
    email:        j['email']                    ?? '',
    phone:        j['phone']                    ?? '',
    role:         userRoleFromApi(j['role']     ?? 'forest_worker'),
    token:        j['token']     ?? j['accessToken'] ?? '',
    refreshToken: j['refreshToken']             ?? '',
    status:       j['status']                   ?? 'active',
    lastLogin:    j['lastLogin'] != null
      ? DateTime.tryParse(j['lastLogin']) : null,
  );

  Map<String, dynamic> toJson() => {
    'id':           id,
    'fullName':     fullName,
    'email':        email,
    'phone':        phone,
    'role':         role.apiValue,
    'token':        token,
    'refreshToken': refreshToken,
    'status':       status,
    'lastLogin':    lastLogin?.toIso8601String(),
  };

  String           toJsonString()            => jsonEncode(toJson());
  factory UserModel.fromJsonString(String s) => UserModel.fromJson(jsonDecode(s));
}
