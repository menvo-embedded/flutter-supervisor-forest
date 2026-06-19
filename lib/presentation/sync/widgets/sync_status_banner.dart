import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../bloc/sync_bloc.dart';
import '../bloc/sync_event.dart';
import '../bloc/sync_state.dart';

/// Banner hiển thị số lượng dữ liệu đang chờ đồng bộ (Module 9 - Offline Mode)
/// Bấm vào để đồng bộ ngay lập tức.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SyncBloc, SyncState>(
      listener: (context, state) {
        if (state is SyncCompleted && state.result.totalSynced > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Đã đồng bộ ${state.result.totalSynced} mục lên server'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      },
      builder: (context, state) {
        int pending = 0;
        bool syncing = false;
        if (state is SyncIdle) pending = state.pendingCount;
        if (state is SyncFailed) pending = state.pendingCount;
        if (state is SyncInProgress) syncing = true;
        if (state is SyncCompleted) pending = state.result.totalPending;

        if (pending == 0 && !syncing) return const SizedBox.shrink();

        return InkWell(
          onTap: syncing ? null : () => context.read<SyncBloc>().add(const SyncRequested()),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.amber.withOpacity(0.15),
            child: Row(children: [
              syncing
                ? const SizedBox(width:16,height:16,child: CircularProgressIndicator(strokeWidth:2, color: AppColors.amber))
                : const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.amber),
              const SizedBox(width: 10),
              Expanded(child: Text(
                syncing ? 'Đang đồng bộ dữ liệu...' : '$pending mục chưa đồng bộ • Chạm để đồng bộ ngay',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
              )),
              if (!syncing) const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF92400E)),
            ]),
          ),
        );
      },
    );
  }
}
