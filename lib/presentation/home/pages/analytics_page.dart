import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../widgets/tree_projection_chart.dart';
import '../widgets/project_comparison_widget.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _selectedSubTab = 0; // 0: Số lượng cây trồng, 1: So sánh

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSubTabButton(0, Icons.trending_up_rounded, 'Số lượng cây trồng', isDark),
                  _buildSubTabButton(1, Icons.compare_arrows_rounded, 'So sánh', isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildActiveWidget(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabButton(int index, IconData icon, String label, bool isDark) {
    final isSelected = _selectedSubTab == index;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () => setState(() => _selectedSubTab = index),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          borderRadius: 12,
          blur: 6,
          customBgColor: isSelected
              ? AppColors.primary
              : (isDark ? const Color(0xFF14241B) : Colors.white.withOpacity(0.5)),
          customBorderColor: isSelected
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.getBorder(isDark).withOpacity(0.3),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : textSecondary),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveWidget() {
    switch (_selectedSubTab) {
      case 0:
        return const TreeProjectionChart();
      case 1:
        return const ProjectComparisonWidget();
      default:
        return const SizedBox.shrink();
    }
  }
}
