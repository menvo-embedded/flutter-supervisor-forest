import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

class TreeProjectionChart extends StatefulWidget {
  const TreeProjectionChart({super.key});

  @override
  State<TreeProjectionChart> createState() => _TreeProjectionChartState();
}

class _TreeProjectionChartState extends State<TreeProjectionChart> {
  String _selectedSpecies = 'Keo';
  double _areaHa = 1250.0;
  double _densityRate = 1600.0; // Trees / ha
  int _selectedYear = 15; // Selected year for details card, default mid-span

  // Default tree densities per ha based on species
  final Map<String, double> _speciesDensityDefaults = {
    'Keo': 1600.0,
    'Thông': 1200.0,
    'Cao su': 1400.0,
  };

  void _onSpeciesChanged(String species) {
    setState(() {
      _selectedSpecies = species;
      _densityRate = _speciesDensityDefaults[species] ?? 1500.0;
    });
  }

  // Calculate survival rate tree count at a specific year
  // Natural thinning reduces survival rate from 95% at year 0 down to around 80% at year 30
  double _calculateTreesAt(int year) {
    final double survivalFactor = 0.95 - (year * 0.005); // starts at 95% down to 80%
    return _areaHa * _densityRate * survivalFactor;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);

    // Generate list of points for the 30-year projection
    final List<double> values = List.generate(31, (y) => _calculateTreesAt(y));
    final double maxValue = _areaHa * _densityRate * 0.96; // theoretical max at year 0

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Species Selection Header
          Text(
            'Chọn loài cây trồng:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: _speciesDensityDefaults.keys.map((sp) {
              final isSel = _selectedSpecies == sp;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: () => _onSpeciesChanged(sp),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSel ? AppColors.primary : Colors.transparent,
                      foregroundColor: isSel ? Colors.white : textSecondary,
                      side: BorderSide(
                        color: isSel ? AppColors.primary : AppColors.getBorder(isDark),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(sp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Parameter Sliders
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Diện tích dự án: ',
                style: TextStyle(fontSize: 11.5, color: textSecondary, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_areaHa.toStringAsFixed(0)} ha',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.getBorder(isDark),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.15),
            ),
            child: Slider(
              value: _areaHa,
              min: 50.0,
              max: 3000.0,
              divisions: 59,
              onChanged: (val) => setState(() => _areaHa = val),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mật độ trồng cây: ',
                style: TextStyle(fontSize: 11.5, color: textSecondary, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_densityRate.toStringAsFixed(0)} cây/ha',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.getBorder(isDark),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.15),
            ),
            child: Slider(
              value: _densityRate,
              min: 500.0,
              max: 3000.0,
              divisions: 50,
              onChanged: (val) => setState(() => _densityRate = val),
            ),
          ),
          const SizedBox(height: 16),

          // Chart Display Area
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
                    painter: ProjectionPainter(
                      values: values,
                      maxValue: maxValue,
                      selectedYear: _selectedYear,
                      isDark: isDark,
                    ),
                  ),
                ),
              );
            },
          ),

          // Interactive Year Tooltip Badge (Glassmorphic Detail Card)
          const SizedBox(height: 16),
          GlassCard(
            borderRadius: 12,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text('Năm', style: TextStyle(color: Colors.white70, fontSize: 10)),
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
                        'Số cây sống sót ước tính:',
                        style: TextStyle(fontSize: 10.5, color: textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_calculateTreesAt(_selectedYear).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} cây',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Tỷ lệ sống sót', style: TextStyle(fontSize: 9, color: textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      '${((0.95 - (_selectedYear * 0.005)) * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.statusActive),
                    ),
                    const Text('Suy giảm tự nhiên & tỉa thưa', style: TextStyle(fontSize: 8, color: AppColors.textHint)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Rê tay trên biểu đồ để xem chi tiết theo năm',
              style: TextStyle(fontSize: 10, color: textSecondary, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectionPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final int selectedYear;
  final bool isDark;

  ProjectionPainter({
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
  bool shouldRepaint(covariant ProjectionPainter oldDelegate) {
    return oldDelegate.maxValue != maxValue ||
        oldDelegate.selectedYear != selectedYear ||
        oldDelegate.isDark != isDark;
  }
}
