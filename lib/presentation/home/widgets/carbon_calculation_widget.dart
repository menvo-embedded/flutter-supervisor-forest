import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

class CarbonProject {
  final String id;
  final String name;
  final double areaHa;
  final String species;
  final int ageYears;
  final double carbonAbsorptionRate; // tCO2e/ha/year
  final double annualCarbonAbsorption; // tCO2e/year
  final double accumulatedCarbonStock; // tCO2e
  final String status;
  final String region;

  CarbonProject({
    required this.id,
    required this.name,
    required this.areaHa,
    required this.species,
    required this.ageYears,
    required this.carbonAbsorptionRate,
    required this.annualCarbonAbsorption,
    required this.accumulatedCarbonStock,
    required this.status,
    required this.region,
  });
}

class CarbonCalculationWidget extends StatefulWidget {
  const CarbonCalculationWidget({super.key});

  @override
  State<CarbonCalculationWidget> createState() => _CarbonCalculationWidgetState();
}

class _CarbonCalculationWidgetState extends State<CarbonCalculationWidget> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  List<CarbonProject> _allProjects = [];
  CarbonProject? _selectedProject;
  int _selectedYear = 15; // Selected year for projection tooltip, default mid-span

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

      // 2. Fetch projects
      var query = _supabase.from('forest_projects').select('id, project_name, area_ha, tree_species, year_planted, status, province, owner_id');
      if (isOwner && ownerId != null) {
        query = query.eq('owner_id', ownerId);
      }
      final List<dynamic> projectsData = await query;

      _allProjects = projectsData.map<CarbonProject>((p) {
        final idVal = p['id']?.toString() ?? '';
        final nameVal = p['project_name']?.toString() ?? 'Dự án không tên';
        final double areaVal = double.tryParse(p['area_ha']?.toString() ?? '') ?? 0.0;
        final speciesVal = p['tree_species']?.toString() ?? 'Keo';
        final int yearPlantedVal = int.tryParse(p['year_planted']?.toString() ?? '') ?? 2018;
        final int ageVal = DateTime.now().year - yearPlantedVal;
        final statusVal = p['status']?.toString() ?? 'pending';
        final provinceVal = p['province']?.toString() ?? 'Khác';

        // Standard sequestration coefficients (tCO2e/ha/year)
        double rate = 8.5; // default Keo
        if (speciesVal.contains('Thông')) rate = 12.5;
        else if (speciesVal.contains('Cao su')) rate = 9.8;
        else if (speciesVal.contains('Bạch đàn')) rate = 8.0;

        final double annualAbs = areaVal * rate;
        final double accumStock = annualAbs * (ageVal < 1 ? 1 : ageVal);

        return CarbonProject(
          id: idVal,
          name: nameVal,
          areaHa: areaVal,
          species: speciesVal,
          ageYears: ageVal < 1 ? 1 : ageVal,
          carbonAbsorptionRate: rate,
          annualCarbonAbsorption: annualAbs,
          accumulatedCarbonStock: accumStock,
          status: statusVal,
          region: provinceVal,
        );
      }).toList();

      if (_allProjects.isNotEmpty) {
        _selectedProject = _allProjects.first;
      }
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

  double _calculateCarbonProjectionAt(int year) {
    if (_selectedProject == null) return 0.0;
    return _selectedProject!.areaHa * _selectedProject!.carbonAbsorptionRate * year;
  }

  void _handleDrag(Offset localPosition, double chartWidth) {
    const paddingX = 40.0;
    final graphWidth = chartWidth - paddingX - 20.0;
    final dragX = localPosition.dx - paddingX;

    if (dragX >= 0 && dragX <= graphWidth) {
      final percentage = dragX / graphWidth;
      final year = (percentage * 30).round().clamp(0, 30);
      setState(() {
        _selectedYear = year;
      });
    }
  }

  String _fmtNum(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
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
              const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 48),
              const SizedBox(height: 12),
              Text('Lỗi tải dữ liệu: $_errorMessage', style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchProjects,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allProjects.isEmpty) {
      return GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.park_outlined, color: AppColors.getTextSecondary(isDark), size: 48),
            const SizedBox(height: 12),
            Text(
              'Chưa có dữ liệu dự án lâm nghiệp để tính toán Carbon.',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Vui lòng khai báo dự án mới ở mục Dự Án trước.',
              style: TextStyle(color: textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final double totalArea = _allProjects.fold(0.0, (sum, p) => sum + p.areaHa);
    final double totalCarbonStock = _allProjects.fold(0.0, (sum, p) => sum + p.accumulatedCarbonStock);
    final double annualCarbonAbs = _allProjects.fold(0.0, (sum, p) => sum + p.annualCarbonAbsorption);

    // Dynamic points for projection chart
    final List<double> projectionValues = List.generate(31, (y) => _calculateCarbonProjectionAt(y));
    final double maxProjValue = _calculateCarbonProjectionAt(30) == 0 ? 1000.0 : _calculateCarbonProjectionAt(30) * 1.05;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── TOP KPI GRID ───
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.9,
          children: [
            _buildKpiCard(
              context,
              'Tích Lũy Carbon',
              _fmtNum(totalCarbonStock),
              'tCO₂e',
              Icons.eco_rounded,
              AppColors.primary,
              isDark,
            ),
            _buildKpiCard(
              context,
              'Hấp Thụ Hàng Năm',
              _fmtNum(annualCarbonAbs),
              'tCO₂e/năm',
              Icons.bolt_rounded,
              AppColors.amber,
              isDark,
            ),
            _buildKpiCard(
              context,
              'Tổng Diện Tích',
              _fmtNum(totalArea),
              'ha',
              Icons.landscape_rounded,
              Colors.blue,
              isDark,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ─── PROJECTION CHART SECTION ───
        Text(
          'Dự đoán tích lũy hấp thụ Carbon (30 năm):',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 10),
        GlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project Dropdown Selector
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dự án trực quan:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.getBorder(isDark)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CarbonProject>(
                        value: _selectedProject,
                        dropdownColor: AppColors.getSurface(isDark),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                        onChanged: (p) => setState(() {
                          _selectedProject = p;
                          _selectedYear = 15;
                        }),
                        items: _allProjects.map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Interactive Chart Display
              LayoutBuilder(
                builder: (context, constraints) {
                  final chartWidth = constraints.maxWidth;
                  return GestureDetector(
                    onHorizontalDragUpdate: (details) => _handleDrag(details.localPosition, chartWidth),
                    onTapDown: (details) => _handleDrag(details.localPosition, chartWidth),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 10, right: 10),
                      child: CustomPaint(
                        painter: CarbonProjectionPainter(
                          values: projectionValues,
                          maxValue: maxProjValue,
                          selectedYear: _selectedYear,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Interactive Tooltip Card
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Text('Năm', style: TextStyle(color: Colors.white70, fontSize: 9)),
                        Text(
                          '$_selectedYear',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tích lũy Carbon dự kiến:',
                          style: TextStyle(fontSize: 10, color: textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_fmtNum(_calculateCarbonProjectionAt(_selectedYear))} tCO₂e',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Tín chỉ & Giá trị', style: TextStyle(fontSize: 9, color: textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtNum(_calculateCarbonProjectionAt(_selectedYear))} Credits',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.statusActive),
                      ),
                      Text(
                        '~ \$${_fmtNum(_calculateCarbonProjectionAt(_selectedYear) * 10)} USD',
                        style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Rê tay trên biểu đồ để xem dự đoán theo năm',
                  style: TextStyle(fontSize: 9.5, color: textSecondary, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ─── INDIVIDUAL PROJECT SEQUESTRATION LIST ───
        Text(
          'Trữ lượng Carbon chi tiết theo dự án:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _allProjects.length,
          itemBuilder: (context, index) {
            final p = _allProjects[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GlassCard(
                borderRadius: 12,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(isDark ? 0.22 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.park_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${p.species} • ${p.areaHa.toStringAsFixed(0)} ha • Tuổi: ${p.ageYears} năm',
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${_fmtNum(p.accumulatedCarbonStock)} tCO₂e',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                        Text(
                          '${p.annualCarbonAbsorption.toStringAsFixed(1)} tCO₂e/năm',
                          style: TextStyle(fontSize: 9.5, color: textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
    Color accentColor,
    bool isDark,
  ) {
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);

    return GlassCard(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  unit,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 8.5, color: textSecondary, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CarbonProjectionPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final int selectedYear;
  final bool isDark;

  CarbonProjectionPainter({
    required this.values,
    required this.maxValue,
    required this.selectedYear,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const paddingX = 40.0;
    const paddingY = 20.0;
    final graphWidth = size.width - paddingX - 20.0;
    final graphHeight = size.height - paddingY - 10.0;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = AppColors.primary
      ..strokeCap = StrokeCap.round;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 1. Draw Grid lines & Y-axis labels
    const yDivisions = 4;
    for (int i = 0; i <= yDivisions; i++) {
      final yFactor = i / yDivisions;
      final yPos = size.height - paddingY - (yFactor * graphHeight);

      // Draw grid line
      canvas.drawLine(
        Offset(paddingX, yPos),
        Offset(size.width - 20.0, yPos),
        gridPaint,
      );

      // Label values
      final val = maxValue * yFactor;
      String label = val >= 1000000 
          ? '${(val / 1000000).toStringAsFixed(1)}M' 
          : val >= 1000 ? '${(val / 1000).toStringAsFixed(0)}k' : val.toStringAsFixed(0);
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 8.5,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(paddingX - textPainter.width - 6.0, yPos - textPainter.height / 2));
    }

    // 2. Draw X-axis year labels
    const xDivisions = 6;
    for (int i = 0; i <= xDivisions; i++) {
      final year = (i * 30 / xDivisions).round();
      final xFactor = year / 30;
      final xPos = paddingX + (xFactor * graphWidth);

      textPainter.text = TextSpan(
        text: 'N$year',
        style: TextStyle(
          fontSize: 8.5,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(xPos - textPainter.width / 2, size.height - paddingY + 4.0),
      );
    }

    // 3. Draw projection line (Spline path)
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final xFactor = i / 30;
      final yFactor = values[i] / (maxValue == 0 ? 1 : maxValue);
      final xPos = paddingX + (xFactor * graphWidth);
      final yPos = size.height - paddingY - (yFactor * graphHeight);

      if (i == 0) {
        path.moveTo(xPos, yPos);
      } else {
        path.lineTo(xPos, yPos);
      }
    }
    canvas.drawPath(path, linePaint);

    // 4. Fill below the line (gradient)
    final fillPath = Path.from(path)
      ..lineTo(paddingX + graphWidth, size.height - paddingY)
      ..lineTo(paddingX, size.height - paddingY)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withOpacity(0.35),
          AppColors.primary.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(paddingX, size.height - paddingY - graphHeight, graphWidth, graphHeight))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 5. Draw Selected Year indicator vertical line and dot
    final selXFactor = selectedYear / 30;
    final selYFactor = values[selectedYear] / (maxValue == 0 ? 1 : maxValue);
    final selX = paddingX + (selXFactor * graphWidth);
    final selY = size.height - paddingY - (selYFactor * graphHeight);

    // Vertical dashed line
    final dashPaint = Paint()
      ..color = isDark ? Colors.white70 : AppColors.primary
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    
    double startY = size.height - paddingY;
    while (startY > selY) {
      canvas.drawLine(
        Offset(selX, startY),
        Offset(selX, (startY - 4).clamp(selY, size.height - paddingY)),
        dashPaint,
      );
      startY -= 8;
    }

    // Glowing dot
    final glowPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(selX, selY), 8.0, glowPaint);

    final dotPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(selX, selY), 4.5, dotPaint);

    final outerDotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(selX, selY), 4.5, outerDotPaint);
  }

  @override
  bool shouldRepaint(covariant CarbonProjectionPainter oldDelegate) {
    return oldDelegate.maxValue != maxValue ||
        oldDelegate.selectedYear != selectedYear ||
        oldDelegate.isDark != isDark;
  }
}
