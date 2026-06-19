import 'package:equatable/equatable.dart';

enum UserRole { platformAdmin, forestOwner, forestWorker }

UserRole userRoleFromApi(String v) {
  switch (v) {
    case 'admin':
    case 'platform_admin':
      return UserRole.platformAdmin;
    case 'owner':
    case 'forest_owner':
      return UserRole.forestOwner;
    case 'worker':
    case 'forest_worker':
    default:
      return UserRole.forestWorker;
  }
}

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.platformAdmin:
        return 'Quản trị viên';
      case UserRole.forestOwner:
        return 'Chủ rừng';
      case UserRole.forestWorker:
        return 'Nhân viên hiện trường';
    }
  }

  String get apiValue {
    switch (this) {
      case UserRole.platformAdmin:
        return 'platform_admin';
      case UserRole.forestOwner:
        return 'forest_owner';
      case UserRole.forestWorker:
        return 'forest_worker';
    }
  }

  /// RBAC: quyền theo vai trò
  bool get canManageUsers   => this == UserRole.platformAdmin;
  bool get canViewAllData   => this != UserRole.forestWorker;
  bool get canCreateLogbook => true;
}

class UserEntity extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String token;
  final String refreshToken;
  final String status;
  final String? ownerId;
  final DateTime? lastLogin;

  const UserEntity({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.token,
    required this.refreshToken,
    this.status = 'active',
    this.ownerId,
    this.lastLogin,
  });

  bool get isActive => status == 'active';
  bool get isAdmin => role == UserRole.platformAdmin;
  bool get isOwner => role == UserRole.forestOwner;
  bool get isWorker => role == UserRole.forestWorker;
  bool get hasOwnerScope => ownerId != null && ownerId!.isNotEmpty;

  UserEntity copyWith({
    String? token,
    String? refreshToken,
    String? status,
    String? ownerId,
    DateTime? lastLogin,
  }) {
    return UserEntity(
      id: id,
      fullName: fullName,
      email: email,
      phone: phone,
      role: role,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        role,
        token,
        status,
        ownerId,
      ];
}