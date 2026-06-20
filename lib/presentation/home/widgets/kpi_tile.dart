import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Ô số liệu KPI cho Dashboard Owner/Admin (đồng bộ từ Web Server)
class KpiTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const KpiTile({super.key,required this.label,required this.value,required this.icon,required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5EAE7))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color)),
        const Spacer(),
      ]),
      const SizedBox(height: 10),
      Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]),
  );
}
