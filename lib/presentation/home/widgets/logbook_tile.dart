import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/logbook/entities/logbook_entity.dart';

/// Item hiển thị 1 bản ghi nhật ký trong danh sách
class LogbookTile extends StatelessWidget {
  final LogbookEntity item;
  final bool showUser;
  const LogbookTile({super.key, required this.item, this.showUser = false});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5EAE7))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(item.jobType.emoji,
                  style: const TextStyle(fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(item.jobType.displayName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary))),
                  item.isSynced ? StatusBadge.synced() : StatusBadge.offline(),
                ]),
                const SizedBox(height: 4),
                Text(item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.access_time_rounded,
                      size: 12, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(formatDateTimeLocal(item.timestamp),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                  if (showUser) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.person_outline_rounded,
                        size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(item.userName,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint)),
                  ],
                  if (item.imagePaths.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.image_outlined,
                        size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text('${item.imagePaths.length} ảnh',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint)),
                  ],
                ]),
              ])),
        ]),
      );
}
