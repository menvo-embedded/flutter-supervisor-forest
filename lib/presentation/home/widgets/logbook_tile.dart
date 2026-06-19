import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../domain/logbook/entities/logbook_entity.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../logbook/bloc/logbook_bloc.dart';
import '../../logbook/bloc/logbook_event.dart';

/// Item hiển thị 1 bản ghi nhật ký trong danh sách
class LogbookTile extends StatelessWidget {
  final LogbookEntity item;
  final bool showUser;
  const LogbookTile({super.key, required this.item, this.showUser = false});

  void _showLogbookDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LogbookDetailSheet(item: item, showUser: showUser),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showLogbookDetails(context),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          borderRadius: 12,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(item.jobType.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.jobType.displayName,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                      ),
                      item.isSynced ? StatusBadge.synced() : StatusBadge.offline(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        formatDateTimeLocal(item.timestamp),
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                      ),
                      if (showUser) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          item.userName,
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                        ),
                      ],
                      if (item.imagePaths.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.image_outlined, size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          '${item.imagePaths.length} ảnh',
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LogbookDetailSheet extends StatelessWidget {
  final LogbookEntity item;
  final bool showUser;

  const _LogbookDetailSheet({required this.item, required this.showUser});

  Widget _buildMetaRow(BuildContext context, IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.getTextSecondary(isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(isDark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          path,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
            );
          },
        ),
      );
    } else {
      final file = File(path);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: file.existsSync()
            ? Image.file(
                file,
                fit: BoxFit.cover,
              )
            : Container(
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                    SizedBox(height: 4),
                    Text('Ảnh local đã bị xóa', style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final surface = AppColors.getSurface(isDark);

    final authState = context.read<AuthBloc>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.isAdmin;
    final isWorker = authState is AuthAuthenticated && authState.user.isWorker;
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ]
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              // Thanh kéo
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.getTextSecondary(isDark).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(item.jobType.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.jobType.displayName,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            item.isSynced ? StatusBadge.synced() : StatusBadge.offline(),
                            if (item.projectId != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.projectId!,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30, thickness: 0.5),
              
              // Metadata
              _buildMetaRow(context, Icons.access_time_rounded, 'Thời gian ghi nhận', formatDateTimeLocal(item.timestamp), isDark),
              if (showUser || item.userName.isNotEmpty)
                _buildMetaRow(context, Icons.person_outline_rounded, 'Người ghi nhận', item.userName, isDark),
              _buildMetaRow(context, Icons.location_on_outlined, 'Tọa độ GPS hiện trường', item.gpsString, isDark),
              
              const SizedBox(height: 14),
              
              // Chi tiết công việc
              Text(
                'Nội dung công việc',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.getBorder(isDark)),
                ),
                child: Text(
                  item.description.isNotEmpty ? item.description : 'Không có mô tả chi tiết.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: textPrimary),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Phần ảnh
              if (item.imagePaths.isNotEmpty) ...[
                Text(
                  'Hình ảnh hiện trường (${item.imagePaths.length})',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: item.imagePaths.length,
                    itemBuilder: (context, index) {
                      final path = item.imagePaths[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 220,
                        child: _buildImage(path),
                      );
                    },
                  ),
                ),
              ],

              if (isAdmin) ...[
                const Divider(height: 30, thickness: 0.5),
                CustomButton(
                  label: 'Xóa Nhật Ký',
                  icon: Icons.delete_forever_rounded,
                  color: AppColors.red,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialCtx) => AlertDialog(
                        title: const Text('Xác nhận xóa'),
                        content: const Text('Bạn có chắc chắn muốn xóa nhật ký này không? Hành động này không thể hoàn tác.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialCtx),
                            child: const Text('Hủy'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialCtx); // Đóng dialog
                              Navigator.pop(context); // Đóng bottom sheet
                              context.read<LogbookBloc>().add(
                                    LogbookDeleted(
                                      id: item.id!,
                                      serverId: item.serverId,
                                      userId: isWorker ? currentUserId : null,
                                    ),
                                  );
                            },
                            child: const Text('Xóa', style: TextStyle(color: AppColors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}
