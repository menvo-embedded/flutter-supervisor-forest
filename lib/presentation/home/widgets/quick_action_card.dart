import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Thẻ hành động nhanh trên Dashboard (Tạo nhật ký / Check-in...)
class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const QuickActionCard({super.key,required this.icon,required this.title,
    required this.subtitle,required this.color,required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAE7))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
      ]),
    ),
  );
}
