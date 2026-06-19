import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

class ComparisonProject {
  final String name;
  final double areaHa;
  final String species;
  final double carbonYield; // tCO2e/year
  final String region;
  final int ageYears;

  const ComparisonProject({
    required this.name,
    required this.areaHa,
    required this.species,
    required this.carbonYield,
    required this.region,
    required this.ageYears,
  });

  double get absorptionPerHa => carbonYield / areaHa;
}

class ProjectComparisonWidget extends StatefulWidget {
  const ProjectComparisonWidget({super.key});

  @override
  State<ProjectComparisonWidget> createState() => _ProjectComparisonWidgetState();
}

class _ProjectComparisonWidgetState extends State<ProjectComparisonWidget> {
  // Mock projects
  final List<ComparisonProject> _allProjects = const [
    ComparisonProject(name: 'Dak Lak Project 01', areaHa: 1250.5, species: 'Keo', carbonYield: 10004.0, region: 'Tây Nguyên', ageYears: 6),
    ComparisonProject(name: 'Lâm Đồng Pine Reserve', areaHa: 850.0, species: 'Thông', carbonYield: 5100.0, region: 'Tây Nguyên', ageYears: 12),
    ComparisonProject(name: 'Gia Lai Rubber Farm', areaHa: 1500.0, species: 'Cao su', carbonYield: 11250.0, region: 'Tây Nguyên', ageYears: 8),
    ComparisonProject(name: 'Sơn La Acacia Project', areaHa: 620.0, species: 'Keo', carbonYield: 4340.0, region: 'Tây Bắc', ageYears: 4),
    ComparisonProject(name: 'Yên Bái Community Forest', areaHa: 750.0, species: 'Thông', carbonYield: 4125.0, region: 'Tây Bắc', ageYears: 10),
  ];

  // Selected projects to compare
  final Set<String> _comparedProjectNames = {};

  // Filters state
  String _selectedRegion = 'Tất cả';
  String _selectedSpecies = 'Tất cả';
  String _selectedScale = 'Tất cả'; // Tất cả | Nhỏ (<800 ha) | Lớn (>=800 ha)

  @override
  void initState() {
    super.initState();
    // Compare all by default
    _comparedProjectNames.addAll(_allProjects.map((p) => p.name));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);

    final filtered = _getFilteredProjects();
    final List<ComparisonProject> comparisonGroup = filtered.where((p) => _comparedProjectNames.contains(p.name)).toList();

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
                      items: const ['Tất cả', 'Tây Nguyên', 'Tây Bắc'],
                      onChanged: (val) => setState(() => _selectedRegion = val!),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterDropdown(
                      label: 'Loài cây',
                      value: _selectedSpecies,
                      items: const ['Tất cả', 'Keo', 'Thông', 'Cao su'],
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
        Text(
          'Chọn dự án đưa vào so sánh:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
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
                  final isCompared = _comparedProjectNames.contains(proj.name);
                  final isTop = topPerformer?.name == proj.name;

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
                        '${proj.region} • ${proj.species} • ${proj.areaHa.toStringAsFixed(0)} ha • ${proj.ageYears} tuổi',
                        style: TextStyle(fontSize: 10, color: textSecondary),
                      ),
                      value: isCompared,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _comparedProjectNames.add(proj.name);
                          } else {
                            if (_comparedProjectNames.length > 1) {
                              _comparedProjectNames.remove(proj.name);
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

    const paddingX = 90.0; // Space on the left for project names
    const paddingRight = 30.0;
    final graphWidth = size.width - paddingX - paddingRight;
    final rowHeight = size.height / projects.length;

    // Find max value to scale the bars
    double maxVal = projects.map((p) => p.absorptionPerHa).reduce(max);
    if (maxVal == 0) maxVal = 1.0;

    final barPaint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < projects.length; i++) {
      final proj = projects[i];
      final val = proj.absorptionPerHa;
      final yPos = i * rowHeight + (rowHeight * 0.15);
      final height = rowHeight * 0.7;

      // Scale bar width
      final barWidth = (val / maxVal) * graphWidth;

      // Highlight top performer
      final isTop = topPerformer?.name == proj.name;
      barPaint.color = isTop ? AppColors.statusActive : AppColors.primary;

      // Draw bar background track
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

      // Draw relative bar fill
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(paddingX, yPos, barWidth.clamp(8.0, graphWidth), height),
          const Radius.circular(4),
        ),
        barPaint,
      );

      // Draw project name label
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

      // Draw value text next to the bar
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
