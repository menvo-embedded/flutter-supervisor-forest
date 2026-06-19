import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/auth/entities/user_entity.dart';
import '../../logbook/bloc/logbook_bloc.dart';
import '../../logbook/bloc/logbook_event.dart';
import '../../logbook/bloc/logbook_state.dart';
import '../../logbook/pages/logbook_form_page.dart';
import '../../theme/bloc/theme_bloc.dart';
import '../../theme/bloc/theme_event.dart';
import '../widgets/logbook_tile.dart';

/// Dashboard RBAC — thiết kế WOW khác nhau rõ rệt giữa Owner và Admin
class DashboardPage extends StatefulWidget {
  final UserEntity user;
  final void Function(int tabIndex)? onNavigateTab;
  const DashboardPage({super.key, required this.user, this.onNavigateTab});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _openLogbookForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogbookFormPage(
          userId: widget.user.id,
          userName: widget.user.fullName,
        ),
      ),
    ).then((_) {
      if (context.mounted) {
        context.read<LogbookBloc>().add(
              LogbookLoadRequested(
                  userId: widget.user.isWorker ? widget.user.id : null),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        context.read<LogbookBloc>().add(
              LogbookLoadRequested(
                  userId: widget.user.isWorker ? widget.user.id : null),
            );
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: FadeTransition(
        opacity: _fadeIn,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _RoleHeader(user: widget.user),
            const SizedBox(height: 20),
            if (widget.user.isWorker) ..._workerBody(context, isDark),
            if (widget.user.isOwner) ..._ownerBody(context, isDark),
            if (widget.user.isAdmin) ..._adminBody(context, isDark),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  // ─── WORKER ───────────────────────────────────────────────────────────────
  List<Widget> _workerBody(BuildContext context, bool isDark) => [
        const _SectionLabel('Thao tác nhanh'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _QuickBtn(
            icon: Icons.note_add_rounded,
            label: 'Ghi nhật ký',
            color: AppColors.primary,
            onTap: () => _openLogbookForm(context),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: _QuickBtn(
            icon: Icons.gps_fixed_rounded,
            label: 'Check-in GPS',
            color: AppColors.primaryMid,
            onTap: () => widget.onNavigateTab?.call(2),
          )),
        ]),
        const SizedBox(height: 24),
        const _SectionLabel('Nhật ký gần đây'),
        const SizedBox(height: 10),
        const _LogbookFeed(showUser: false),
      ];

  // ─── FOREST OWNER ─────────────────────────────────────────────────────────
  List<Widget> _ownerBody(BuildContext context, bool isDark) => [
        // Carbon quota ring
        _CarbonRingCard(isDark: isDark),
        const SizedBox(height: 16),
        // KPI row — 4 tiles với trend
        const _SectionLabel('Chỉ số dự án'),
        const SizedBox(height: 10),
        _OwnerKpiGrid(isDark: isDark),
        const SizedBox(height: 16),
        // Quick actions
        const _SectionLabel('Thao tác nhanh'),
        const SizedBox(height: 10),
        _OwnerActions(onLogbook: () => _openLogbookForm(context)),
        const SizedBox(height: 20),
        // Activity feed
        const _SectionLabel('Hoạt động nhân viên'),
        const SizedBox(height: 10),
        const _LogbookFeed(showUser: true, limit: 5),
      ];

  // ─── PLATFORM ADMIN ───────────────────────────────────────────────────────
  List<Widget> _adminBody(BuildContext context, bool isDark) => [
        // System health panel
        _SystemHealthCard(isDark: isDark),
        const SizedBox(height: 16),
        // KPI row — system-wide stats
        const _SectionLabel('Chỉ số hệ thống'),
        const SizedBox(height: 10),
        _AdminKpiGrid(isDark: isDark),
        const SizedBox(height: 16),
        // Quick actions
        const _SectionLabel('Thao tác nhanh'),
        const SizedBox(height: 10),
        _AdminActions(onLogbook: () => _openLogbookForm(context)),
        const SizedBox(height: 20),
        // Full system feed
        const _SectionLabel('Nhật ký toàn hệ thống'),
        const SizedBox(height: 10),
        const _LogbookFeed(showUser: true, limit: 8),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// ROLE HEADER — gradient + avatar + role badge + dark mode toggle
// ─────────────────────────────────────────────────────────────────────────────
class _RoleHeader extends StatelessWidget {
  final UserEntity user;
  const _RoleHeader({required this.user});

  // Different gradients per role
  LinearGradient _gradient(bool isDark) {
    return isDark
        ? AppColors.forestGradientDark
        : AppColors.forestGradient;
  }

  Color _accentColor() => AppColors.accent;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Chào buổi sáng';
    if (h < 17) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const wd = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accentColor();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: _gradient(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(isDark ? 0.35 : 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar circle with initials
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
            ),
            child: Center(
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting(),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75), fontSize: 11)),
            const SizedBox(height: 2),
            Text(user.fullName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ])),
          // Dark mode toggle
          GestureDetector(
            onTap: () => context
                .read<ThemeBloc>()
                .add(ThemeModeChanged(isDark ? ThemeMode.light : ThemeMode.dark)),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        // Bottom row: date + role badge
        Row(children: [
          Icon(Icons.calendar_today_rounded,
              size: 11, color: Colors.white.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text('${wd[now.weekday - 1]}, ${now.day}/${now.month}/${now.year}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withOpacity(0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                user.isAdmin ? Icons.admin_panel_settings_rounded : Icons.forest_rounded,
                size: 11,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(user.role.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OWNER — Carbon Ring Card (WOW element)
// ─────────────────────────────────────────────────────────────────────────────
class _CarbonRingCard extends StatelessWidget {
  final bool isDark;
  const _CarbonRingCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    const quota = 30000.0;
    const earned = 25430.0;
    const pct = earned / quota;

    final bg = isDark ? const Color(0xFF0B2018) : const Color(0xFFF0FDF4);
    final border = isDark ? const Color(0xFF1B4E32) : const Color(0xFFBBF7D0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        // Animated ring
        SizedBox(
          width: 90,
          height: 90,
          child: CustomPaint(
            painter: _RingPainter(
              progress: pct,
              trackColor:
                  isDark ? const Color(0xFF1B4E32) : const Color(0xFFD1FAE5),
              fillColor: AppColors.primary,
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                Text('quota',
                    style: TextStyle(
                        fontSize: 9,
                        color: AppColors.primary.withOpacity(0.7))),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Carbon tín chỉ',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF4B5563))),
          const SizedBox(height: 4),
          Text('25,430 tCO₂e',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary)),
          const SizedBox(height: 4),
          Text('/ 30,000 tCO₂e mục tiêu',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF))),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: isDark
                  ? const Color(0xFF1B4E32)
                  : const Color(0xFFD1FAE5),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            _Dot(AppColors.statusActive),
            const SizedBox(width: 4),
            Text('Đang hoạt động — 2 dự án',
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280))),
          ]),
        ])),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor, fillColor;
  const _RingPainter(
      {required this.progress,
      required this.trackColor,
      required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width - 10) / 2;

    final track = Paint()
      ..color = trackColor
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, track);

    final fill = Paint()
      ..color = fillColor
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN — System Health Card (WOW element — khác hoàn toàn với owner)
// ─────────────────────────────────────────────────────────────────────────────
class _SystemHealthCard extends StatelessWidget {
  final bool isDark;
  const _SystemHealthCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0B2018) : const Color(0xFFF0FDF4);
    final border = isDark ? const Color(0xFF1B4E32) : const Color(0xFFBBF7D0);
    const greenAccent = AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: greenAccent.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: greenAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.monitor_heart_rounded, color: greenAccent, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('System Health',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.primaryDark)),
            Text('Cập nhật 2 phút trước',
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF))),
          ]),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _Dot(const Color(0xFF22C55E)),
              const SizedBox(width: 5),
              const Text('Tất cả hoạt động',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF22C55E))),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        // Health bars
        _HealthBar(label: 'API Server', value: 0.98, color: const Color(0xFF22C55E), isDark: isDark),
        const SizedBox(height: 8),
        _HealthBar(label: 'Database', value: 0.94, color: greenAccent, isDark: isDark),
        const SizedBox(height: 8),
        _HealthBar(label: 'Sync Engine', value: 0.87, color: const Color(0xFFF59E0B), isDark: isDark),
        const SizedBox(height: 8),
        _HealthBar(label: 'Mobile Push', value: 0.99, color: const Color(0xFF22C55E), isDark: isDark),
      ]),
    );
  }
}

class _HealthBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isDark;
  const _HealthBar({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 90,
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : const Color(0xFF4B5563))),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: isDark ? Colors.white10 : const Color(0xFFD1FAE5),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('${(value * 100).toStringAsFixed(0)}%',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OWNER KPI GRID — với trend indicator
// ─────────────────────────────────────────────────────────────────────────────
class _OwnerKpiGrid extends StatelessWidget {
  final bool isDark;
  const _OwnerKpiGrid({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: const [
        _KpiTrendTile(label: 'Diện tích', value: '1,250 ha',
            icon: Icons.landscape_rounded, color: AppColors.primary,
            trend: '+2.3%', trendUp: true),
        _KpiTrendTile(label: 'Tổng số cây', value: '185,420',
            icon: Icons.park_rounded, color: AppColors.statusActive,
            trend: '+5.1%', trendUp: true),
        _KpiTrendTile(label: 'Carbon tCO₂e', value: '25,430',
            icon: Icons.cloud_outlined, color: AppColors.primaryMid,
            trend: '+12.4%', trendUp: true),
        _KpiTrendTile(label: 'Nhân viên', value: '4',
            icon: Icons.groups_rounded, color: AppColors.primary,
            trend: '0%', trendUp: null),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN KPI GRID — system-wide + màu sắc khác biệt
// ─────────────────────────────────────────────────────────────────────────────
class _AdminKpiGrid extends StatelessWidget {
  final bool isDark;
  const _AdminKpiGrid({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: const [
        _KpiTrendTile(label: 'Chủ rừng', value: '128',
            icon: Icons.people_alt_rounded, color: AppColors.primary,
            trend: '+3', trendUp: true),
        _KpiTrendTile(label: 'Dự án', value: '156',
            icon: Icons.forest_rounded, color: AppColors.primaryMid,
            trend: '+7', trendUp: true),
        _KpiTrendTile(label: 'Diện tích', value: '12,543 ha',
            icon: Icons.map_rounded, color: AppColors.primary,
            trend: '+1.8%', trendUp: true),
        _KpiTrendTile(label: 'Carbon tCO₂e', value: '215k',
            icon: Icons.cloud_outlined, color: AppColors.primaryMid,
            trend: '+8.2%', trendUp: true),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI TILE WITH TREND
// ─────────────────────────────────────────────────────────────────────────────
class _KpiTrendTile extends StatelessWidget {
  final String label, value, trend;
  final IconData icon;
  final Color color;
  final bool? trendUp; // true=up, false=down, null=flat

  const _KpiTrendTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    required this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = AppColors.getSurface(isDark);
    final border = AppColors.getBorder(isDark);

    final trendColor = trendUp == null
        ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
        : trendUp!
            ? const Color(0xFF22C55E)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const Spacer(),
          // Trend badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: trendColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (trendUp != null)
                Icon(
                  trendUp! ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 10,
                  color: trendColor,
                ),
              Text(trend,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: trendColor)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: AppColors.getTextSecondary(isDark),
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS
// ─────────────────────────────────────────────────────────────────────────────
class _OwnerActions extends StatelessWidget {
  final VoidCallback onLogbook;
  const _OwnerActions({required this.onLogbook});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _QuickBtn(icon: Icons.note_add_rounded,
          label: 'Ghi nhật ký', color: AppColors.primary, onTap: onLogbook)),
      const SizedBox(width: 10),
      Expanded(child: _QuickBtn(icon: Icons.map_rounded,
          label: 'Bản đồ GIS', color: AppColors.primaryMid,
          onTap: () {})),
      const SizedBox(width: 10),
      Expanded(child: _QuickBtn(icon: Icons.groups_rounded,
          label: 'Nhân viên', color: AppColors.primary,
          onTap: () {})),
    ]);
  }
}

class _AdminActions extends StatelessWidget {
  final VoidCallback onLogbook;
  const _AdminActions({required this.onLogbook});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _QuickBtn(icon: Icons.note_add_rounded,
          label: 'Ghi nhật ký', color: AppColors.primary, onTap: onLogbook)),
      const SizedBox(width: 10),
      Expanded(child: _QuickBtn(icon: Icons.manage_accounts_rounded,
          label: 'Người dùng', color: AppColors.primaryMid,
          onTap: () {})),
      const SizedBox(width: 10),
      Expanded(child: _QuickBtn(icon: Icons.bar_chart_rounded,
          label: 'Báo cáo', color: AppColors.primary,
          onTap: () {})),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Nút thao tác nhanh dạng icon + label (compact vertical)
class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.25 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 7),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(children: [
      Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 7),
      Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.getTextPrimary(isDark))),
    ]);
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) =>
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGBOOK FEED
// ─────────────────────────────────────────────────────────────────────────────
class _LogbookFeed extends StatelessWidget {
  final bool showUser;
  final int limit;
  const _LogbookFeed({this.showUser = false, this.limit = 3});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              color: AppColors.getSurfaceGrey(isDark),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Icon(Icons.menu_book_outlined,
                  size: 32,
                  color: AppColors.getTextSecondary(isDark)),
              const SizedBox(height: 8),
              Text('Chưa có nhật ký nào',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.getTextSecondary(isDark))),
            ]),
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
