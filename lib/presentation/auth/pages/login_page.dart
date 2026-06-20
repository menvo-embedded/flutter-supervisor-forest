import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

/// Màn hình đăng nhập - dùng chung cho 3 vai trò
/// (Forest Worker / Forest Owner / Platform Admin)
/// Sau khi xác thực, HomeShell sẽ tự điều hướng UI theo role.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(AuthLoginRequested(
        email: _emailCtrl.text.trim(), password: _passCtrl.text));
    }
  }

  void _fillDemo(String email) {
    setState((){ _emailCtrl.text = email; _passCtrl.text = '123456'; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.getBg(isDark),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (r)=>false);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message), backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ));
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return SafeArea(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(key: _formKey, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Center(child: Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/logo.png', width: 76, height: 76, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 16),
                  Text('QLR', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: isDark ? AppColors.primary : AppColors.primaryDark, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text('Hệ thống quản lý dữ liệu rừng & Carbon', style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(isDark)), textAlign: TextAlign.center),
                ])),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: AppColors.getSurface(isDark), borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0,4))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Đăng nhập', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Email', hint: 'you@qlr.vn', controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefix: Icon(Icons.email_outlined, size: 20, color: AppColors.getTextSecondary(isDark)),
                      validator: (v){
                        if(v==null||v.isEmpty) return 'Vui lòng nhập email';
                        if(!RegExp(r'^[\w.\-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return 'Email không hợp lệ';
                        return null;
                      }),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Mật khẩu', hint: '••••••••', controller: _passCtrl, obscureText: true,
                      prefix: Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.getTextSecondary(isDark)),
                      validator: (v){
                        if(v==null||v.isEmpty) return 'Vui lòng nhập mật khẩu';
                        if(v.length<6) return 'Tối thiểu 6 ký tự';
                        return null;
                      }),
                    const SizedBox(height: 18),
                    CustomButton(label: 'Đăng nhập', onPressed: _submit, isLoading: isLoading, icon: Icons.login_rounded),
                  ]),
                ),
                const SizedBox(height: 20),
                // ── Demo accounts: minh hoạ phân quyền 3 vai trò ──
                Text('Tài khoản demo (phân quyền):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextSecondary(isDark))),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _DemoChip(label:'Worker', email:'worker@qlr.vn', onTap: _fillDemo),
                  _DemoChip(label:'Owner',  email:'owner@qlr.vn',  onTap: _fillDemo),
                  _DemoChip(label:'Admin',  email:'admin@qlr.vn',  onTap: _fillDemo),
                ]),
                const SizedBox(height: 24),
              ],
            )),
          ));
        },
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  final String label, email;
  final void Function(String) onTap;
  const _DemoChip({required this.label, required this.email, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: ()=>onTap(email), borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.primary.withOpacity(0.18) : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(isDark ? 0.4 : 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_outline_rounded, size: 14, color: isDark ? Colors.white70 : AppColors.primaryDark),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.primaryDark)),
        ]),
      ),
    );
  }
}
