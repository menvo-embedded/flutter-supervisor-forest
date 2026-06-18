// FILE: lib/presentation/home/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/auth/entities/user_entity.dart';
import '../../logbook/bloc/logbook_bloc.dart';
import '../../logbook/bloc/logbook_event.dart';   // FIX BUG 4: import thiếu
import '../../logbook/bloc/logbook_state.dart';
import '../../logbook/pages/logbook_form_page.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/kpi_tile.dart';
import '../widgets/logbook_tile.dart';

/// Dashboard - layout thay đổi theo VAI TRÒ người dùng (Role-Based UI)
class DashboardPage extends StatelessWidget {
  final UserEntity user;
  final void Function(int tabIndex)? onNavigateTab;
  const DashboardPage({super.key, required this.user, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        context.read<LogbookBloc>().add(
          LogbookLoadRequested(userId: user.isWorker ? user.id : null),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Header(user: user),
          const SizedBox(height: 20),
          if (user.isWorker) ..._workerBody(context),
          if (user.isOwner)  ..._ownerBody(context),
          if (user.isAdmin)  ..._adminBody(context),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  // ─── FOREST WORKER ────────────────────────────────────────────────────
  List<Widget> _workerBody(BuildContext context) => [
    const _SectionTitle('Thao tác nhanh'),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: QuickActionCard(
        icon: Icons.note_add_rounded,
        title: 'Ghi nhật ký',
        subtitle: 'Tạo nhật ký hiện trường mới',
        color: AppColors.primary,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => LogbookFormPage(userId: user.id, userName: user.fullName),
        )).then((_) {
          if (context.mounted) {
            context.read<LogbookBloc>().add(
              LogbookLoadRequested(userId: user.id),
            );
          }
        }),
      )),
      const SizedBox(width: 12),
      Expanded(child: QuickActionCard(
        icon: Icons.gps_fixed_rounded,
        title: 'Check-in GPS',
        subtitle: 'Ghi nhận vị trí làm việc',
        color: AppColors.blue,
        onTap: () => onNavigateTab?.call(2),
      )),
    ]),
    const SizedBox(height: 24),
    const _SectionTitle('Nhật ký gần đây'),
    const SizedBox(height: 10),
    _LogbookPreview(showUser: false),
  ];

  // ─── FOREST OWNER ─────────────────────────────────────────────────────
  List<Widget> _ownerBody(BuildContext context) => [
    const _SectionTitle('Tổng quan khu rừng'),
    const SizedBox(height: 10),
    GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: const [
        KpiTile(label: 'Diện tích',       value: '1,250.50 ha', icon: Icons.landscape_rounded,  color: AppColors.primary),
        KpiTile(label: 'Tổng số cây',     value: '185,420',      icon: Icons.park_rounded,        color: AppColors.statusActive),
        KpiTile(label: 'Carbon (tCO₂e)',  value: '25,430',       icon: Icons.cloud_outlined,      color: AppColors.blue),
        KpiTile(label: 'Nhân viên',       value: '4',            icon: Icons.groups_rounded,      color: AppColors.amber),
      ],
    ),
    const SizedBox(height: 20),
    const _SyncBanner('Số liệu đồng bộ tự động từ Web Server — vai trò Forest Owner.'),
    const SizedBox(height: 20),
    const _SectionTitle('Hoạt động nhân viên'),
    const SizedBox(height: 10),
    _LogbookPreview(showUser: true, limit: 5),
  ];

  // ─── PLATFORM ADMIN ───────────────────────────────────────────────────
  List<Widget> _adminBody(BuildContext context) => [
    const _SectionTitle('Tổng quan hệ thống QLR'),
    const SizedBox(height: 10),
    GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: const [
        KpiTile(label: 'Chủ rừng',     value: '128',      icon: Icons.people_alt_rounded, color: AppColors.primary),
        KpiTile(label: 'Dự án',        value: '156',      icon: Icons.forest_rounded,     color: AppColors.statusActive),
        KpiTile(label: 'Diện tích',    value: '12,543 ha',icon: Icons.map_rounded,        color: AppColors.blue),
        KpiTile(label: 'Carbon tCO₂e', value: '215,430',  icon: Icons.cloud_outlined,     color: AppColors.amber),
      ],
    ),
    const SizedBox(height: 20),
    const _SyncBanner('Dữ liệu realtime — đồng bộ 2 chiều với Web Admin Dashboard.'),
    const SizedBox(height: 20),
    const _SectionTitle('Nhật ký toàn hệ thống'),
    const SizedBox(height: 10),
    _LogbookPreview(showUser: true, limit: 5),
  ];
}

// ─── Private widgets ──────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final UserEntity user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const wd = ['Thứ Hai','Thứ Ba','Thứ Tư','Thứ Năm','Thứ Sáu','Thứ Bảy','Chủ Nhật'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '${wd[now.weekday - 1]}, ${now.day}/${now.month}/${now.year}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Chào, ${user.fullName}',
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role.label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ])),
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 26),
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  );
}

class _SyncBanner extends StatelessWidget {
  final String text;
  const _SyncBanner(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      const Icon(Icons.sync_rounded, size: 18, color: AppColors.primaryDark),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.primaryDark))),
    ]),
  );
}

class _LogbookPreview extends StatelessWidget {
  final bool showUser;
  final int  limit;
  const _LogbookPreview({this.showUser = false, this.limit = 3});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LogbookBloc, LogbookState>(builder: (context, state) {
      if (state is LogbookLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        );
      }
      if (state is LogbookLoaded) {
        if (state.items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Chưa có nhật ký nào. Hãy bắt đầu ghi nhận!',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          );
        }
        return Column(
          children: state.items
            .take(limit)
            .map((e) => LogbookTile(item: e, showUser: showUser))
            .toList(),
        );
      }
      return const SizedBox.shrink();
    });
  }
}
