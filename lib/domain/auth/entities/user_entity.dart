// FILE: lib/domain/auth/entities/user_entity.dart
import 'package:equatable/equatable.dart';

enum UserRole { platformAdmin, forestOwner, forestWorker }

/// BUG FIX: Dart extensions không hỗ trợ static methods.
/// Chuyển fromApi thành top-level function.
UserRole userRoleFromApi(String v) {
  switch (v) {
    case 'admin':
    case 'platform_admin': return UserRole.platformAdmin;
    case 'owner':
    case 'forest_owner':   return UserRole.forestOwner;
    case 'worker':
    default:               return UserRole.forestWorker;
  }
}

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.platformAdmin: return 'Quản trị viên';
      case UserRole.forestOwner:   return 'Chủ rừng';
      case UserRole.forestWorker:  return 'Nhân viên hiện trường';
    }
  }

  String get apiValue {
    switch (this) {
      case UserRole.platformAdmin: return 'platform_admin';
      case UserRole.forestOwner:   return 'forest_owner';
      case UserRole.forestWorker:  return 'forest_worker';
    }
  }

  /// RBAC: quyền theo vai trò
  bool get canManageUsers   => this == UserRole.platformAdmin;
  bool get canViewAllData   => this != UserRole.forestWorker;
  bool get canCreateLogbook => this == UserRole.forestWorker ||
                               this == UserRole.platformAdmin;
}

class UserEntity extends Equatable {
  final String    id, fullName, email, phone;
  final UserRole  role;
  final String    token, refreshToken;
  final String    status; // active | inactive | locked
  final DateTime? lastLogin;

  const UserEntity({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.token,
    required this.refreshToken,
    this.status    = 'active',
    this.lastLogin,
  });

  bool get isActive => status == 'active';
  bool get isAdmin  => role == UserRole.platformAdmin;
  bool get isOwner  => role == UserRole.forestOwner;
  bool get isWorker => role == UserRole.forestWorker;

  UserEntity copyWith({
    String?    token,
    String?    refreshToken,
    String?    status,
    DateTime?  lastLogin,
  }) => UserEntity(
    id: id, fullName: fullName, email: email, phone: phone, role: role,
    token:        token        ?? this.token,
    refreshToken: refreshToken ?? this.refreshToken,
    status:       status       ?? this.status,
    lastLogin:    lastLogin    ?? this.lastLogin,
  );

  @override
  List<Object?> get props => [id, email, role, token, status];
}
