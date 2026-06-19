import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/auth/entities/user_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../sync/bloc/sync_bloc.dart';
import '../../sync/bloc/sync_event.dart';
import '../../sync/bloc/sync_state.dart';

/// Module 3 - Hồ sơ cá nhân + đăng xuất + trạng thái đồng bộ
class ProfilePage extends StatelessWidget {
  final UserEntity user;
  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Hồ Sơ Cá Nhân')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Avatar + thông tin ──
          Container(
            width: double.infinity, padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(gradient: AppColors.forestGradient, borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              CircleAvatar(radius: 36, backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white))),
              const SizedBox(height: 12),
              Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.symmetric(horizontal:12,vertical:5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                child: Text(user.role.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Thông tin chi tiết ──
          _Section(title: 'Thông tin tài khoản', children: [
            _InfoRow(icon: Icons.badge_outlined, label: 'Mã nhân viên', value: user.id),
            _InfoRow(icon: Icons.phone_outlined, label: 'Số điện thoại', value: user.phone.isEmpty?'—':user.phone),
            _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user.email),
            Row(children: [
              const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              const Expanded(child: Text('Trạng thái', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
              user.status=='active' ? StatusBadge.active() : (user.status=='locked' ? const StatusBadge(label:'Đã khóa', color: AppColors.statusLocked) : StatusBadge.inactive()),
            ]),
          ]),
          const SizedBox(height: 16),

          // ── Đồng bộ dữ liệu ──
          BlocBuilder<SyncBloc, SyncState>(builder: (context, state) {
            int pending = 0; bool syncing = false; DateTime? lastSync;
            if (state is SyncIdle) pending = state.pendingCount;
            if (state is SyncFailed) pending = state.pendingCount;
            if (state is SyncInProgress) syncing = true;
            if (state is SyncCompleted) { pending = state.result.totalPending; lastSync = DateTime.now(); }

            return _Section(title: 'Đồng bộ dữ liệu (Offline → Server)', children: [
              Row(children: [
                Icon(pending>0?Icons.cloud_off_rounded:Icons.cloud_done_rounded, size:20,
                  color: pending>0?AppColors.amber:AppColors.statusActive),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  pending>0 ? '$pending mục đang chờ đồng bộ' : 'Tất cả dữ liệu đã đồng bộ',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
              ]),
              if (lastSync!=null) Padding(padding: const EdgeInsets.only(top:6,left:30),
                child: Text('Đồng bộ lần cuối: ${lastSync.hour.toString().padLeft(2,'0')}:${lastSync.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint))),
              const SizedBox(height: 12),
              CustomButton(label: 'Đồng bộ ngay', icon: Icons.sync_rounded, isLoading: syncing, isOutlined: true,
                onPressed: () => context.read<SyncBloc>().add(const SyncRequested())),
            ]);
          }),
          const SizedBox(height: 16),

          // ── Cài đặt khác ──
          _Section(title: 'Khác', children: [
            _ActionRow(icon: Icons.lock_reset_rounded, label: 'Đổi mật khẩu', onTap: (){}),
            _ActionRow(icon: Icons.notifications_outlined, label: 'Thông báo', onTap: (){}),
            _ActionRow(icon: Icons.help_outline_rounded, label: 'Trợ giúp & Hỗ trợ', onTap: (){}),
          ]),
          const SizedBox(height: 24),

          CustomButton(label: 'Đăng xuất', icon: Icons.logout_rounded, isOutlined: true, color: AppColors.red,
            onPressed: () {
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (r)=>false);
            }),
          const SizedBox(height: 30),
        ],
      )),
    );
  }
}

class _Section extends StatelessWidget {
  final String title; final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5EAE7))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      ...children.expand((w) => [w, const SizedBox(height: 12)]).toList()..removeLast(),
    ]),
  );
}
class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: AppColors.textSecondary), const SizedBox(width: 10),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
  ]);
}
class _ActionRow extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: Row(children: [
    Icon(icon, size: 18, color: AppColors.textSecondary), const SizedBox(width: 10),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
  ]));
}
