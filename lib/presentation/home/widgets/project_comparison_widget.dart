import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

class ComparisonProject {
  final String id;
  final String name;
  final double areaHa;
  final String species;
  final double carbonYield; // tCO2e/year
  final String region;
  final int ageYears;
  final String status;

  const ComparisonProject({
    required this.id,
    required this.name,
    required this.areaHa,
    required this.species,
    required this.carbonYield,
    required this.region,
    required this.ageYears,
    required this.status,
  });

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Đã duyệt';
      case 'active':
        return 'Hoạt động';
      case 'pending':
        return 'Chờ duyệt';
      case 'rejected':
        return 'Bị từ chối';
      case 'surveying':
        return 'Khảo sát';
      default:
        return status;
    }
  }

  double get absorptionPerHa => carbonYield / areaHa;
}

class ProjectComparisonWidget extends StatefulWidget {
  const ProjectComparisonWidget({super.key});

  @override
  State<ProjectComparisonWidget> createState() => _ProjectComparisonWidgetState();
}

class _ProjectComparisonWidgetState extends State<ProjectComparisonWidget> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String? _errorMessage;

  List<ComparisonProject> _allProjects = [];
  final Set<String> _comparedProjectIds = {};

  // Filters state
  String _selectedRegion = 'Tất cả';
  String _selectedSpecies = 'Tất cả';
  String _selectedScale = 'Tất cả'; // Tất cả | Nhỏ (<800 ha) | Lớn (>=800 ha)

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("Người dùng chưa đăng nhập.");

      // 1. Get role & owner_id from profiles
      final profile = await _supabase
          .from('profiles')
          .select('role, owner_id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) throw Exception("Không tìm thấy profile.");

      final roleStr = profile['role'] ?? 'worker';
      final isOwner = (roleStr == 'owner' || roleStr == 'forest_owner');
      final ownerId = profile['owner_id'];

      // 2. Fetch specific owner code if owner
      String? ownerCode;
      if (isOwner && ownerId != null) {
        final ownerRes = await _supabase
            .from('forest_owners')
            .select('owner_code')
            .eq('id', ownerId)
            .maybeSingle();
        if (ownerRes != null) {
          ownerCode = ownerRes['owner_code'];
        }
      }

      // 3. Fetch projects
      List<dynamic> projectsData = [];
      try {
        var query = _supabase.from('projects').select('*');
        if (isOwner && ownerCode != null) {
          query = query.eq('owner_code', ownerCode);
        }
        projectsData = await query;
      } catch (e) {
        // Fallback to forest_projects: select explicit columns to avoid stale schema cache or 'area' column issues
        var query = _supabase.from('forest_projects').select('id, project_name, area_ha, tree_species, forest_type, province, year_planted, status, owner_id');
        if (isOwner && ownerId != null) {
          query = query.eq('owner_id', ownerId);
        }
        projectsData = await query;
      }



      _allProjects = projectsData.map<ComparisonProject>((p) {
        final idVal = p['id']?.toString() ?? '';
        final nameVal = p['project_name']?.toString() ?? p['name']?.toString() ?? 'Dự án không tên';
        final double areaVal = double.tryParse(p['area_ha']?.toString() ?? p['area']?.toString() ?? '') ?? 1.0;
        final speciesVal = p['tree_species']?.toString() ?? p['forest_type']?.toString() ?? 'Keo';
        final provinceVal = p['province']?.toString() ?? 'Khác';
        final int yearPlantedVal = int.tryParse(p['year_planted']?.toString() ?? '') ?? 2018;
        final int ageVal = DateTime.now().year - yearPlantedVal;
        final statusVal = p['status']?.toString() ?? 'pending';

        // Yield estimate based on species
        double factor = 8.0;
        if (speciesVal.contains('Thông')) factor = 6.0;
        if (speciesVal.contains('Cao su')) factor = 7.5;
        final double carbonYieldVal = areaVal * factor;

        return ComparisonProject(
          id: idVal,
          name: nameVal,
          areaHa: areaVal,
          species: speciesVal,
          carbonYield: carbonYieldVal,
          region: provinceVal,
          ageYears: ageVal < 1 ? 1 : ageVal,
          status: statusVal,
        );
      }).toList();

      // Check all by default
      _comparedProjectIds.clear();
      _comparedProjectIds.addAll(_allProjects.map((p) => p.id));
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<ComparisonProject> _getFilteredProjects() {
    return _allProjects.where((p) {
      final matchRegion = _selectedRegion == 'Tất cả' || p.region == _selectedRegion;
      final matchSpecies = _selectedSpecies == 'Tất cả' || p.species == _selectedSpecies;
      
      bool matchScale = true;
      if (_selectedScale == 'Nhỏ (<800 ha)') {
        matchScale = p.areaHa < 800;
      } else if (_selectedScale == 'Lớn (>=800 ha)') {
        matchScale = p.areaHa >= 800;
      }

      return matchRegion && matchSpecies && matchScale;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text("Lỗi: $_errorMessage", style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _fetchProjects, child: const Text("Tải lại")),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);

    // Generate dynamic filters based on actual projects in the DB
    final List<String> regionItems = ['Tất cả', ..._allProjects.map((p) => p.region).where((r) => r.isNotEmpty).toSet()];
    final List<String> speciesItems = ['Tất cả', ..._allProjects.map((p) => p.species).where((s) => s.isNotEmpty).toSet()];

    if (!regionItems.contains(_selectedRegion)) _selectedRegion = 'Tất cả';
    if (!speciesItems.contains(_selectedSpecies)) _selectedSpecies = 'Tất cả';

    final filtered = _getFilteredProjects();
    final List<ComparisonProject> comparisonGroup = filtered.where((p) => _comparedProjectIds.contains(p.id)).toList();

    // Find top absorber per Ha in comparison group
    ComparisonProject? topPerformer;
    if (comparisonGroup.isNotEmpty) {
      topPerformer = comparisonGroup.reduce((curr, next) => curr.absorptionPerHa > next.absorptionPerHa ? curr : next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid Filter Panel (Glassmorphism)
        GlassCard(
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Bộ lọc nâng cao:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterDropdown(
                      label: 'Vùng miền',
                      value: _selectedRegion,
                      items: regionItems,
                      onChanged: (val) => setState(() => _selectedRegion = val!),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterDropdown(
                      label: 'Loài cây',
                      value: _selectedSpecies,
                      items: speciesItems,
                      onChanged: (val) => setState(() => _selectedSpecies = val!),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildFilterDropdown(
                label: 'Quy mô diện tích',
                value: _selectedScale,
                items: const ['Tất cả', 'Nhỏ (<800 ha)', 'Lớn (>=800 ha)'],
                onChanged: (val) => setState(() => _selectedScale = val!),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Comparison Bar Chart View
        if (comparisonGroup.isNotEmpty) ...[
          Text(
            'Hiệu suất hấp thụ CO₂ (tCO₂e/ha/năm):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 8),
          Container(
            height: 150.0,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.getBorder(isDark)),
              borderRadius: BorderRadius.circular(16),
              color: isDark ? AppColors.getBg(isDark) : AppColors.getSurfaceGrey(isDark).withOpacity(0.5),
            ),
            child: CustomPaint(
              painter: BarChartPainter(
                projects: comparisonGroup,
                topPerformer: topPerformer,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Projects Selectable List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chọn dự án đưa vào so sánh:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _fetchProjects,
              tooltip: 'Tải lại danh sách từ Supabase',
            ),
          ],
        ),
        const SizedBox(height: 8),
        filtered.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Không tìm thấy dự án phù hợp với bộ lọc.', style: TextStyle(fontSize: 12, color: textSecondary)),
                ),
              )
            : Column(
                children: filtered.map((proj) {
                  final isCompared = _comparedProjectIds.contains(proj.id);
                  final isTop = topPerformer?.id == proj.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      border: Border.all(
                        color: isTop
                            ? AppColors.statusActive
                            : (isCompared ? AppColors.primary.withOpacity(0.4) : AppColors.getBorder(isDark)),
                        width: isTop ? 1.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isTop
                          ? [
                              BoxShadow(
                                color: AppColors.statusActive.withOpacity(0.12),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: CheckboxListTile(
                      activeColor: AppColors.primary,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              proj.name,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                          ),
                          if (isTop) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.workspace_premium_rounded, color: AppColors.amber, size: 16),
                            const SizedBox(width: 2),
                            const Text('Top 1', style: TextStyle(color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${proj.region} • ${proj.species} • ${proj.areaHa.toStringAsFixed(0)} ha • ${proj.ageYears} tuổi • ${proj.statusLabel}',
                        style: TextStyle(fontSize: 10, color: textSecondary),
                      ),
                      value: isCompared,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _comparedProjectIds.add(proj.id);
                          } else {
                            if (_comparedProjectIds.length > 1) {
                              _comparedProjectIds.remove(proj.id);
                            }
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    final textSecondary = AppColors.getTextSecondary(isDark);
    final textPrimary = AppColors.getTextPrimary(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9.5, color: textSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceGreyDark : Colors.white,
            border: Border.all(color: AppColors.getBorder(isDark)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: textSecondary),
              style: TextStyle(fontSize: 12, color: textPrimary),
              dropdownColor: isDark ? AppColors.surfaceGreyDark : Colors.white,
              onChanged: onChanged,
              items: items.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class BarChartPainter extends CustomPainter {
  final List<ComparisonProject> projects;
  final ComparisonProject? topPerformer;
  final bool isDark;

  BarChartPainter({
    required this.projects,
    required this.topPerformer,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (projects.isEmpty) return;

    const paddingX = 90.0;
    const paddingRight = 30.0;
    final graphWidth = size.width - paddingX - paddingRight;
    final rowHeight = size.height / projects.length;

    double maxVal = projects.map((p) => p.absorptionPerHa).reduce(max);
    if (maxVal == 0) maxVal = 1.0;

    final barPaint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < projects.length; i++) {
      final proj = projects[i];
      final val = proj.absorptionPerHa;
      final yPos = i * rowHeight + (rowHeight * 0.15);
      final height = rowHeight * 0.7;

      final barWidth = (val / maxVal) * graphWidth;

      final isTop = topPerformer?.id == proj.id;
      barPaint.color = isTop ? AppColors.statusActive : AppColors.primary;

      final trackPaint = Paint()
        ..color = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(paddingX, yPos, graphWidth, height),
          const Radius.circular(4),
        ),
        trackPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(paddingX, yPos, barWidth.clamp(8.0, graphWidth), height),
          const Radius.circular(4),
        ),
        barPaint,
      );

      textPainter.text = TextSpan(
        text: proj.name,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textPrimary,
        ),
      );
      textPainter.layout(maxWidth: paddingX - 10.0);
      textPainter.paint(
        canvas,
        Offset(5, yPos + (height - textPainter.height) / 2),
      );

      textPainter.text = TextSpan(
        text: val.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
      );
      textPainter.layout();
      canvas.drawCircle(Offset(paddingX + barWidth - 2.0, yPos + height/2), 3.0, Paint()..color = AppColors.surface);
      textPainter.paint(
        canvas,
        Offset(paddingX + barWidth + 6.0, yPos + (height - textPainter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate.projects != projects ||
        oldDelegate.topPerformer != topPerformer ||
        oldDelegate.isDark != isDark;
  }
}
