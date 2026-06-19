import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/demo_accounts.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

/// Màn hình đăng nhập - dùng chung cho 3 vai trò
/// Forest Worker / Forest Owner / Platform Admin.
/// Sau khi xác thực, HomeShell sẽ tự điều hướng UI theo role.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthLoginRequested(
              email: _emailCtrl.text.trim(),
              password: _passCtrl.text,
            ),
          );
    }
  }

  void _fillDemo(DemoAccount account) {
    setState(() {
      _emailCtrl.text = account.email;
      _passCtrl.text = account.password;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              gradient: AppColors.forestGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.forest_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'QLR Forest',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Hệ thống quản lý dữ liệu rừng & Carbon',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: 'Email',
                            hint: 'you@qlr.vn',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            prefix: const Icon(
                              Icons.email_outlined,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập email';
                              }

                              final isValidEmail = RegExp(
                                r'^[\w.\-]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value);

                              if (!isValidEmail) {
                                return 'Email không hợp lệ';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          CustomTextField(
                            label: 'Mật khẩu',
                            hint: '••••••••',
                            controller: _passCtrl,
                            obscureText: true,
                            prefix: const Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập mật khẩu';
                              }

                              if (value.length < 6) {
                                return 'Tối thiểu 6 ký tự';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          CustomButton(
                            label: 'Đăng nhập',
                            onPressed: _submit,
                            isLoading: isLoading,
                            icon: Icons.login_rounded,
                          ),
                        ],
                      ),
                    ),
                    if (DemoAccounts.enabled) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Tài khoản demo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Chỉ dùng cho demo nội bộ',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth = (constraints.maxWidth - 8) / 2;

                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: DemoAccounts.accounts
                                .map(
                                  (account) => SizedBox(
                                    width: itemWidth,
                                    child: _DemoAccountButton(
                                      account: account,
                                      onTap: _fillDemo,
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DemoAccountButton extends StatelessWidget {
  final DemoAccount account;
  final void Function(DemoAccount) onTap;

  const _DemoAccountButton({
    required this.account,
    required this.onTap,
  });

  IconData get _icon => switch (account.role) {
        'admin' => Icons.admin_panel_settings_outlined,
        'owner' => Icons.forest_outlined,
        _ => Icons.badge_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(account),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _icon,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    account.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              account.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              account.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.2,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}