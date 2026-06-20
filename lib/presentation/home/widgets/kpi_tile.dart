import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

/// Ô số liệu KPI cho Dashboard Owner/Admin (đồng bộ từ Web Server)
class KpiTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const KpiTile({super.key,required this.label,required this.value,required this.icon,required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = AppColors.getTextSecondary(isDark);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 12,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.22 : 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color)),
          const Spacer(),
        ]),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
