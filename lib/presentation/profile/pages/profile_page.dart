import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../domain/auth/entities/user_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../sync/bloc/sync_bloc.dart';
import '../../sync/bloc/sync_event.dart';
import '../../sync/bloc/sync_state.dart';
import '../../theme/bloc/theme_bloc.dart';
import '../../theme/bloc/theme_event.dart';

/// Module 3 - Hồ sơ cá nhân + đăng xuất + trạng thái đồng bộ + cài đặt theme
class ProfilePage extends StatelessWidget {
  final UserEntity user;
  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBg(isDark),
      appBar: AppBar(
        title: const Text('Hồ Sơ Cá Nhân'),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.primary,
        foregroundColor: isDark ? AppColors.textPrimaryDark : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + thông tin ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: isDark ? AppColors.forestGradientDark : AppColors.forestGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.3) : AppColors.primary.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.fullName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role.label,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Thông tin chi tiết ──
            _Section(
              title: 'Thông tin tài khoản',
              isDark: isDark,
              children: [
                _InfoRow(icon: Icons.badge_outlined, label: 'Mã nhân viên', value: user.id, isDark: isDark),
                _InfoRow(icon: Icons.phone_outlined, label: 'Số điện thoại', value: user.phone.isEmpty ? '—' : user.phone, isDark: isDark),
                _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user.email, isDark: isDark),
                Row(children: [
                  Icon(Icons.verified_user_outlined, size: 18, color: textSecondary),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Trạng thái', style: TextStyle(fontSize: 13, color: textSecondary))),
                  user.status == 'active'
                      ? StatusBadge.active()
                      : (user.status == 'locked'
                          ? const StatusBadge(label: 'Đã khóa', color: AppColors.statusLocked)
                          : StatusBadge.inactive()),
                ]),
              ],
            ),
            const SizedBox(height: 16),

            // ── Đồng bộ dữ liệu ──
            BlocBuilder<SyncBloc, SyncState>(builder: (context, state) {
              int pending = 0;
              bool syncing = false;
              DateTime? lastSync;
              if (state is SyncIdle) pending = state.pendingCount;
              if (state is SyncFailed) pending = state.pendingCount;
              if (state is SyncInProgress) syncing = true;
              if (state is SyncCompleted) {
                pending = state.result.totalPending;
                lastSync = DateTime.now();
              }

              return _Section(
                title: 'Đồng bộ dữ liệu (Offline → Server)',
                isDark: isDark,
                children: [
                  Row(children: [
                    Icon(
                      pending > 0 ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                      size: 20,
                      color: pending > 0 ? AppColors.amber : AppColors.statusActive,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pending > 0 ? '$pending mục đang chờ đồng bộ' : 'Tất cả dữ liệu đã đồng bộ',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                    ),
                  ]),
                  if (lastSync != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 30),
                      child: Text(
                        'Đồng bộ lần cuối: ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Đồng bộ ngay',
                    icon: Icons.sync_rounded,
                    isLoading: syncing,
                    isOutlined: true,
                    onPressed: () => context.read<SyncBloc>().add(const SyncRequested()),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),

            // ── Cấu hình Theme & Tùy chọn khác ──
            _Section(
              title: 'Cài đặt & Hỗ trợ',
              isDark: isDark,
              children: [
                // Theme Toggle Switch Row
                Row(
                  children: [
                    Icon(
                      isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                      size: 18,
                      color: textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chế độ giao diện tối',
                        style: TextStyle(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Switch(
                      value: isDark,
                      activeColor: AppColors.accent,
                      onChanged: (val) {
                        context.read<ThemeBloc>().add(ThemeModeChanged(
                          val ? ThemeMode.dark : ThemeMode.light,
                        ));
                      },
                    ),
                  ],
                ),
                const Divider(height: 10, thickness: 0.5),
                _ActionRow(icon: Icons.lock_reset_rounded, label: 'Đổi mật khẩu', onTap: () {}, isDark: isDark),
                _ActionRow(icon: Icons.notifications_outlined, label: 'Thông báo', onTap: () {}, isDark: isDark),
                _ActionRow(icon: Icons.help_outline_rounded, label: 'Trợ giúp & Hỗ trợ', onTap: () {}, isDark: isDark),
              ],
            ),
            const SizedBox(height: 24),

            CustomButton(
              label: 'Đăng xuất',
              icon: Icons.logout_rounded,
              isOutlined: true,
              color: AppColors.red,
              onPressed: () {
                context.read<AuthBloc>().add(const AuthLogoutRequested());
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;

  const _Section({
    required this.title,
    required this.children,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 12),
          ...children.expand((w) => [w, const SizedBox(height: 12)]).toList()..removeLast(),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.getTextSecondary(isDark)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(isDark)),
        ),
      ),
      Text(
        value,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(isDark)),
      ),
    ]);
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.getTextSecondary(isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.getTextPrimary(isDark)),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.getTextSecondary(isDark).withOpacity(0.5)),
        ]),
      ),
    );
  }
}
