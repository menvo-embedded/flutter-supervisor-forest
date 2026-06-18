import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override List<Object?> get props => [];
}

/// Người dùng nhập email/password và bấm "Đăng nhập"
class AuthLoginRequested extends AuthEvent {
  final String email, password;
  const AuthLoginRequested({required this.email, required this.password});
  @override List<Object?> get props => [email, password];
}

/// Đăng xuất
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Kiểm tra session khi mở app (Splash)
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}
