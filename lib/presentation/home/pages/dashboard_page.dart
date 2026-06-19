import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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

  // Species data for the owner view (persisted in SharedPreferences)
  final List<Map<String, dynamic>> _ownerSpecies = [
    {'name': 'Keo Lai', 'trees': 85420, 'area': 500.0, 'color': AppColors.primary, 'emoji': '🌱'},
    {'name': 'Bạch đàn', 'trees': 50000, 'area': 350.0, 'color': AppColors.statusActive, 'emoji': '🌿'},
    {'name': 'Cao su', 'trees': 35000, 'area': 250.0, 'color': AppColors.primaryMid, 'emoji': '🌴'},
    {'name': 'Thông', 'trees': 15000, 'area': 150.0, 'color': Colors.blue, 'emoji': '🌲'},
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();

    if (widget.user.isOwner) {
      _loadOwnerData();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOwnerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (var sp in _ownerSpecies) {
        final name = sp['name'] as String;
        final treesKey = 'owner_trees_$name';
        final areaKey = 'owner_area_$name';
        if (prefs.containsKey(treesKey)) {
          sp['trees'] = prefs.getInt(treesKey);
        }
        if (prefs.containsKey(areaKey)) {
          sp['area'] = prefs.getDouble(areaKey);
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading owner data: $e');
    }
  }

  Future<void> _saveOwnerData(String name, int trees, double area) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('owner_trees_$name', trees);
      await prefs.setDouble('owner_area_$name', area);
      await _loadOwnerData();
    } catch (e) {
      debugPrint('Error saving owner data: $e');
    }
  }

  void _showEditSpeciesDialog(BuildContext context, Map<String, dynamic> sp) {
    final name = sp['name'] as String;
    final treesController = TextEditingController(text: sp['trees'].toString());
    final areaController = TextEditingController(text: sp['area'].toString());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getSurface(isDark),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Khai báo tài nguyên: $name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: treesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Số lượng cây (Cây)',
                    labelStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: areaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Diện tích (ha)',
                    labelStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final trees = int.tryParse(treesController.text) ?? 0;
                      final area = double.tryParse(areaController.text) ?? 0.0;
                      if (trees <= 0 || area <= 0.0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập giá trị hợp lệ lớn hơn 0'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      _saveOwnerData(name, trees, area);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Lưu lại',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
  List<Widget> _ownerBody(BuildContext context, bool isDark) {
    int totalTrees = 0;
    double totalArea = 0.0;
    double carbonStock = 0.0;

    for (var sp in _ownerSpecies) {
      final name = sp['name'] as String;
      final trees = sp['trees'] as int;
      final area = sp['area'] as double;
      totalTrees += trees;
      totalArea += area;

      double factor = 0.137;
      if (name == 'Keo Lai') factor = 0.137;
      else if (name == 'Bạch đàn') factor = 0.135;
      else if (name == 'Cao su') factor = 0.138;
      else if (name == 'Thông') factor = 0.142;

      carbonStock += trees * factor;
    }

    return [
      // Carbon quota ring
      _CarbonRingCard(isDark: isDark, earned: carbonStock),
      const SizedBox(height: 16),
      // KPI row — 4 tiles với trend
      const _SectionLabel('Chỉ số dự án'),
      const SizedBox(height: 10),
      _OwnerKpiGrid(
        isDark: isDark,
        totalTrees: totalTrees,
        totalArea: totalArea,
        carbonStock: carbonStock,
      ),
      const SizedBox(height: 20),
      // Species resources management
      const _SectionLabel('Chi tiết tài nguyên & Mật độ phân bổ'),
      const SizedBox(height: 10),
      _OwnerResourceList(
        speciesList: _ownerSpecies,
        onEdit: (sp) => _showEditSpeciesDialog(context, sp),
      ),
      const SizedBox(height: 20),
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
  }

  // ─── PLATFORM ADMIN ───────────────────────────────────────────────────────
  List<Widget> _adminBody(BuildContext context, bool isDark) => [
        // System health panel
        _SystemHealthCard(isDark: isDark),
        const SizedBox(height: 16),
        // KPI row — system-wide stats
        const _SectionLabel('Chỉ số hệ thống'),
        const SizedBox(height: 10),
        _AdminKpiGrid(isDark: isDark),
        const SizedBox(height: 20),
        
        // GIS Interactive Map Section
        const _SectionLabel('Bản đồ phân bố dự án GIS'),
        const SizedBox(height: 10),
        const _AdminMapSection(),
        const SizedBox(height: 20),

        // Owner stats section
        const _SectionLabel('Thống kê theo chủ rừng'),
        const SizedBox(height: 10),
        const _AdminOwnerStatsTable(),
        const SizedBox(height: 20),

        // Overview species charts section
        const _SectionLabel('Tỷ lệ phân bổ loài cây & Diện tích'),
        const SizedBox(height: 10),
        const _AdminChartsSection(),
        const SizedBox(height: 20),

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
  final double earned;
  const _CarbonRingCard({required this.isDark, required this.earned});

  @override
  Widget build(BuildContext context) {
    const quota = 30000.0;
    final pct = (earned / quota).clamp(0.0, 1.0);

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
          Text('${_formatNum(earned.round())} tCO₂e',
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
  final int totalTrees;
  final double totalArea;
  final double carbonStock;

  const _OwnerKpiGrid({
    required this.isDark,
    required this.totalTrees,
    required this.totalArea,
    required this.carbonStock,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _KpiTrendTile(label: 'Diện tích', value: '${_formatNum(totalArea.round())} ha',
            icon: Icons.landscape_rounded, color: AppColors.primary,
            trend: '+2.3%', trendUp: true),
        _KpiTrendTile(label: 'Tổng số cây', value: _formatNum(totalTrees),
            icon: Icons.park_rounded, color: AppColors.statusActive,
            trend: '+5.1%', trendUp: true),
        _KpiTrendTile(label: 'Carbon tCO₂e', value: _formatNum(carbonStock.round()),
            icon: Icons.cloud_outlined, color: AppColors.primaryMid,
            trend: '+12.4%', trendUp: true),
        const _KpiTrendTile(label: 'Nhân viên', value: '4',
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

// ─────────────────────────────────────────────────────────────────────────────
// NEW HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _OwnerResourceList extends StatelessWidget {
  final List<Map<String, dynamic>> speciesList;
  final Function(Map<String, dynamic>) onEdit;

  const _OwnerResourceList({
    required this.speciesList,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: speciesList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final sp = speciesList[index];
        final name = sp['name'] as String;
        final trees = sp['trees'] as int;
        final area = sp['area'] as double;
        final emoji = sp['emoji'] as String;
        final color = sp['color'] as Color;

        // Density = trees / area (cây/ha)
        final density = area > 0 ? trees / area : 0.0;
        
        String densityLabel;
        Color badgeBgColor;
        Color badgeTextColor;

        if (density >= 180) {
          densityLabel = 'Mật độ Dày';
          badgeBgColor = isDark ? const Color(0x33EF4444) : const Color(0xFFFEE2E2);
          badgeTextColor = const Color(0xFFEF4444);
        } else if (density < 80) {
          densityLabel = 'Mật độ Thưa';
          badgeBgColor = isDark ? const Color(0x333B82F6) : const Color(0xFFDBEAFE);
          badgeTextColor = const Color(0xFF3B82F6);
        } else {
          densityLabel = 'Mật độ Vừa phải';
          badgeBgColor = isDark ? const Color(0x3310B981) : const Color(0xFFD1FAE5);
          badgeTextColor = const Color(0xFF10B981);
        }

        return GestureDetector(
          onTap: () => onEdit(sp),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.getBorder(isDark)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Emoji & Color indicator
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                          const Spacer(),
                          // Edit pencil icon
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: AppColors.getTextSecondary(isDark).withOpacity(0.6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${_formatNum(trees)} cây',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                          Text(
                            '  •  ',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.getTextSecondary(isDark).withOpacity(0.5),
                            ),
                          ),
                          Text(
                            '${_formatNum(area)} ha',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Density info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mật độ: ${density.toStringAsFixed(1)} cây/ha',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.getTextSecondary(isDark).withOpacity(0.8),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              densityLabel,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: badgeTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminMapSection extends StatefulWidget {
  const _AdminMapSection();

  @override
  State<_AdminMapSection> createState() => _AdminMapSectionState();
}

class _AdminMapSectionState extends State<_AdminMapSection> {
  final MapController _mapController = MapController();
  Map<String, dynamic>? _selectedProject;

  // 6 projects list exactly matching web dashboard data
  final List<Map<String, dynamic>> _projects = [
    {
      'code': 'PRJ-0001',
      'name': 'Dak Lak Project 01',
      'ownerName': 'Nguyễn Văn A',
      'province': 'Đắk Lắk',
      'district': 'Krông Bông',
      'commune': 'Hòa Phong',
      'area': 1250.50,
      'treeSpecies': 'Keo Lai',
      'status': 'Hoạt động',
      'lat': 12.6,
      'lng': 108.25,
      'trees': 85420,
    },
    {
      'code': 'PRJ-0002',
      'name': 'Lam Dong Project 02',
      'ownerName': 'Nguyễn Văn A',
      'province': 'Lâm Đồng',
      'district': 'Di Linh',
      'commune': 'Tân Châu',
      'area': 980.75,
      'treeSpecies': 'Bạch đàn',
      'status': 'Hoạt động',
      'lat': 11.58,
      'lng': 108.07,
      'trees': 50000,
    },
    {
      'code': 'PRJ-0003',
      'name': 'Gia Lai Project 01',
      'ownerName': 'Công ty CP Green Forest',
      'province': 'Gia Lai',
      'district': 'Chư Sê',
      'commune': 'Ia Pal',
      'area': 1320.30,
      'treeSpecies': 'Thông',
      'status': 'Hoạt động',
      'lat': 13.65,
      'lng': 108.05,
      'trees': 15000,
    },
    {
      'code': 'PRJ-0004',
      'name': 'Quang Tri Project 01',
      'ownerName': 'Hợp tác xã Rừng Bền Vững',
      'province': 'Quảng Trị',
      'district': 'Đakrông',
      'commune': 'Tà Long',
      'area': 760.40,
      'treeSpecies': 'Keo Lai',
      'status': 'Đang khảo sát',
      'lat': 16.62,
      'lng': 106.85,
      'trees': 10000,
    },
    {
      'code': 'PRJ-0005',
      'name': 'Quang Nam Project 01',
      'ownerName': 'Hoàng Thị D',
      'province': 'Quảng Nam',
      'district': 'Nam Trà My',
      'commune': 'Trà Mai',
      'area': 660.20,
      'treeSpecies': 'Bạch đàn',
      'status': 'Hoạt động',
      'lat': 15.18,
      'lng': 108.07,
      'trees': 35000,
    },
    {
      'code': 'PRJ-0006',
      'name': 'Dak Lak Project 02',
      'ownerName': 'Lê Thị B',
      'province': 'Đắk Lắk',
      'district': 'Buôn Đôn',
      'commune': 'Ea Wer',
      'area': 980.75,
      'treeSpecies': 'Keo Lai',
      'status': 'Nháp',
      'lat': 12.95,
      'lng': 107.78,
      'trees': 45000,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.getBorder(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(13.8, 108.0),
                initialZoom: 5.8,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.qlr.forest.mobile',
                  tileDisplay: const TileDisplay.fadeIn(),
                ),
                MarkerLayer(
                  markers: _projects.map((proj) {
                    final isSelected = _selectedProject != null && _selectedProject!['code'] == proj['code'];
                    return Marker(
                      point: LatLng(proj['lat'], proj['lng']),
                      width: 42,
                      height: 42,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedProject = proj;
                          });
                          _mapController.move(LatLng(proj['lat'], proj['lng']), 8.0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.red : AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.forest,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            // Top overlay zoom/pan indicators
            Positioned(
              top: 10,
              right: 10,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 0.5);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.getSurface(isDark).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.getBorder(isDark)),
                      ),
                      child: Icon(Icons.add, size: 18, color: AppColors.getTextPrimary(isDark)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 0.5);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.getSurface(isDark).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.getBorder(isDark)),
                      ),
                      child: Icon(Icons.remove, size: 18, color: AppColors.getTextPrimary(isDark)),
                    ),
                  ),
                ],
              ),
            ),

            // Center location button
            Positioned(
              top: 86,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  _mapController.move(const LatLng(13.8, 108.0), 5.8);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(isDark).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.getBorder(isDark)),
                  ),
                  child: Icon(Icons.center_focus_strong, size: 16, color: AppColors.getTextPrimary(isDark)),
                ),
              ),
            ),

            // Details overlay
            if (_selectedProject != null)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(isDark).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.getBorder(isDark)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedProject!['name'],
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedProject = null;
                              });
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Chủ rừng: ${_selectedProject!['ownerName']}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Diện tích: ${_formatNum(_selectedProject!['area'])} ha',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                          Text(
                            'Loài cây: ${_selectedProject!['treeSpecies']}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Vị trí: ${_selectedProject!['commune']}, ${_selectedProject!['province']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedProject!['status'] == 'Hoạt động'
                                  ? const Color(0xFF22C55E).withOpacity(0.15)
                                  : _selectedProject!['status'] == 'Đang khảo sát'
                                      ? Colors.orange.withOpacity(0.15)
                                      : Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _selectedProject!['status'],
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _selectedProject!['status'] == 'Hoạt động'
                                    ? const Color(0xFF22C55E)
                                    : _selectedProject!['status'] == 'Đang khảo sát'
                                        ? Colors.orange
                                        : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminOwnerStatsTable extends StatelessWidget {
  const _AdminOwnerStatsTable();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final List<Map<String, dynamic>> ownerStats = [
      {
        'code': 'OWN-0001',
        'name': 'Nguyễn Văn A',
        'type': 'Cá nhân',
        'speciesCount': 2,
        'speciesDetails': 'Keo Lai, Bạch đàn',
        'totalTrees': 135420,
        'totalArea': 2231.25,
        'avatarColor': Colors.teal,
      },
      {
        'code': 'OWN-0002',
        'name': 'Lê Thị B',
        'type': 'Cá nhân',
        'speciesCount': 1,
        'speciesDetails': 'Keo Lai',
        'totalTrees': 45000,
        'totalArea': 980.75,
        'avatarColor': Colors.amber,
      },
      {
        'code': 'OWN-0007',
        'name': 'Green Forest',
        'type': 'Doanh nghiệp',
        'speciesCount': 1,
        'speciesDetails': 'Thông',
        'totalTrees': 15000,
        'totalArea': 1320.30,
        'avatarColor': Colors.indigo,
      },
      {
        'code': 'OWN-0004',
        'name': 'HTX Rừng Bền Vững',
        'type': 'Hợp tác xã',
        'speciesCount': 1,
        'speciesDetails': 'Keo Lai',
        'totalTrees': 10000,
        'totalArea': 760.40,
        'avatarColor': Colors.purple,
      },
      {
        'code': 'OWN-0006',
        'name': 'Hoàng Thị D',
        'type': 'Cá nhân',
        'speciesCount': 1,
        'speciesDetails': 'Bạch đàn',
        'totalTrees': 35000,
        'totalArea': 660.20,
        'avatarColor': Colors.blueGrey,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: ownerStats.map((stat) {
          final isLast = ownerStats.last == stat;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: stat['avatarColor'].withOpacity(0.12),
                      child: Text(
                        stat['name'][0].toUpperCase(),
                        style: TextStyle(
                          color: stat['avatarColor'],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  stat['name'],
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getTextPrimary(isDark),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.getSurfaceGrey(isDark),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.getBorder(isDark)),
                                ),
                                child: Text(
                                  stat['type'],
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    color: AppColors.getTextSecondary(isDark),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sở hữu: ${stat['speciesDetails']} (${stat['speciesCount']} loài)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_formatNum(stat['totalTrees'])} cây',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatNum(stat['totalArea'])} ha',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: AppColors.getBorder(isDark).withOpacity(0.5),
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _AdminChartsSection extends StatelessWidget {
  const _AdminChartsSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    const double totalArea = 5952.9;
    const int totalTrees = 305420;

    final speciesStats = [
      {'name': 'Keo Lai', 'trees': 140420, 'area': 2991.65, 'color': AppColors.primary, 'pct': 46.0},
      {'name': 'Bạch đàn', 'trees': 115000, 'area': 1640.95, 'color': AppColors.statusActive, 'pct': 37.6},
      {'name': 'Cao su', 'trees': 35000, 'area': 250.0, 'color': AppColors.primaryMid, 'pct': 11.4},
      {'name': 'Thông', 'trees': 15000, 'area': 1070.30, 'color': Colors.blue, 'pct': 5.0},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Custom Donut Chart
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(130, 130),
                        painter: _PieChartPainter(
                          values: speciesStats.map((e) => (e['trees'] as int).toDouble()).toList(),
                          colors: speciesStats.map((e) => e['color'] as Color).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatNum(totalTrees),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                          Text(
                            'Tổng số cây',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.getTextSecondary(isDark),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Legend
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: speciesStats.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: item['color'] as Color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['name'] as String,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(item['pct'] as double).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: item['color'] as Color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Total Area & Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '${_formatNum(totalArea.round())} ha',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tổng diện tích hệ thống',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 28, color: AppColors.getBorder(isDark)),
              Column(
                children: [
                  Text(
                    '4 loài chính',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.statusActive,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Đa dạng sinh học',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  const _PieChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0.0, (sum, val) => sum + val);
    if (total == 0.0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius - 6);

    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final double sweepAngle = (values[i] / total) * 2 * math.pi;

      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle + 0.05, sweepAngle - 0.1, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter old) => old.values != values || old.colors != colors;
}

/// Helper function to format large numbers with commas
String _formatNum(num n) {
  if (n is double) {
    if (n == n.roundToDouble()) {
      n = n.toInt();
    } else {
      final parts = n.toStringAsFixed(1).split('.');
      final intPart = int.tryParse(parts[0]) ?? 0;
      return '${_formatNum(intPart)}.${parts[1]}';
    }
  }
  final str = n.toString();
  final buffer = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    buffer.write(str[i]);
    count++;
    if (count % 3 == 0 && i > 0) {
      buffer.write(',');
    }
  }
  return buffer.toString().split('').reversed.join();
}



