import 'package:equatable/equatable.dart';
abstract class Failure extends Equatable {
  final String message;
  const Failure({required this.message});
  @override List<Object> get props => [message];
}
class ServerFailure     extends Failure { final int? code; const ServerFailure({required super.message, this.code}); @override List<Object> get props => [message, code??0]; }
class CacheFailure      extends Failure { const CacheFailure({required super.message}); }
class NetworkFailure    extends Failure { const NetworkFailure({super.message='Mất kết nối. Dữ liệu lưu offline.'}); }
class AuthFailure       extends Failure { const AuthFailure({super.message='Sai tài khoản hoặc mật khẩu.'}); }
class GpsFailure        extends Failure { const GpsFailure({super.message='Không lấy GPS. Kiểm tra quyền vị trí.'}); }
class ValidationFailure extends Failure { const ValidationFailure({required super.message}); }
