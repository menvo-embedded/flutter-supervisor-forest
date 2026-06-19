import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

class ESGTrackerWidget extends StatefulWidget {
  const ESGTrackerWidget({super.key});

  @override
  State<ESGTrackerWidget> createState() => _ESGTrackerWidgetState();
}

class _ESGTrackerWidgetState extends State<ESGTrackerWidget> {
  double _creditPriceUsd = 12.0; // Carbon price per credit ($5 - $50)
  final double _carbonCreditsTotal = 25430.0; // Fixed total from dashboard KPI

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);

    // Financial calculations
    final double grossRevenue = _carbonCreditsTotal * _creditPriceUsd;
    final double opCost = grossRevenue * 0.22 + 15000.0; // 22% patrolling cost + fixed management
    final double esgReinvestment = grossRevenue * 0.15; // 15% for communities
    final double netProfit = grossRevenue - opCost - esgReinvestment;
    final double profitMargin = grossRevenue > 0 ? (netProfit / grossRevenue) : 0.0;

    String formatCurrency(double value) {
      return '\$${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} USD';
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carbon Credit Price Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đơn giá tín chỉ Carbon:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              Text(
                '\$${_creditPriceUsd.toStringAsFixed(1)} / tCO₂e',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.getBorder(isDark),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.15),
            ),
            child: Slider(
              value: _creditPriceUsd,
              min: 5.0,
              max: 50.0,
              divisions: 45,
              onChanged: (val) => setState(() => _creditPriceUsd = val),
            ),
          ),
          const SizedBox(height: 16),

          // Circle Gauge and Summary Card
          GlassCard(
            borderRadius: 16,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Circular Gauge CustomPainter
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CustomPaint(
                    painter: MarginGaugePainter(
                      percentage: profitMargin,
                      isDark: isDark,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(profitMargin * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Biên lãi',
                            style: TextStyle(
                              fontSize: 8,
                              color: textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Main Financial Summary
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doanh thu ròng ước tính:',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatCurrency(netProfit),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.statusActive,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dựa trên trữ lượng ${_carbonCreditsTotal.toStringAsFixed(0)} tCO₂e hiện có.',
                        style: TextStyle(fontSize: 9.5, color: textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cost Breakdown Grid List
          Text(
            'Phân bổ dòng tiền chi tiết:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 8),

          _buildFinancialRow(
            context,
            icon: Icons.monetization_on_rounded,
            color: AppColors.primary,
            label: 'Doanh thu gộp (Gross)',
            value: formatCurrency(grossRevenue),
            percentage: 1.0,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildFinancialRow(
            context,
            icon: Icons.shield_rounded,
            color: AppColors.red,
            label: 'Vận hành & Tuần tra (OpEx)',
            value: formatCurrency(opCost),
            percentage: opCost / grossRevenue,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildFinancialRow(
            context,
            icon: Icons.volunteer_activism_rounded,
            color: AppColors.amber,
            label: 'Tái đầu tư ESG & Cộng đồng',
            value: formatCurrency(esgReinvestment),
            percentage: esgReinvestment / grossRevenue,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required double percentage,
    required bool isDark,
  }) {
    final textPrimary = AppColors.getTextPrimary(isDark);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 12,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 5,
              width: double.infinity,
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: double.infinity,
                  color: color,
                  child: FractionallySizedBox(
                    widthFactor: percentage.clamp(0.0, 1.0),
                    child: Container(color: color),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MarginGaugePainter extends CustomPainter {
  final double percentage;
  final bool isDark;

  MarginGaugePainter({required this.percentage, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = AppColors.statusActive
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background track
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw progress arc starting from -90 degrees (top)
    const double startAngle = -pi / 2;
    final double sweepAngle = 2 * pi * percentage.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MarginGaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.isDark != isDark;
  }
}
