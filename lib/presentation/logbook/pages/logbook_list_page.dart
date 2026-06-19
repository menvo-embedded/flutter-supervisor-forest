import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/auth/entities/user_entity.dart';
import '../bloc/logbook_bloc.dart';
import '../bloc/logbook_event.dart';
import '../bloc/logbook_state.dart';
import '../../sync/bloc/sync_bloc.dart';
import '../../sync/bloc/sync_event.dart';
import '../../home/widgets/logbook_tile.dart';
import 'logbook_form_page.dart';

/// Module 8 - Danh sách nhật ký hiện trường
/// - Worker: chỉ thấy nhật ký của mình, có FAB tạo mới
/// - Owner/Admin: thấy nhật ký của TẤT CẢ nhân viên (read-only, hiển thị tên người ghi)
class LogbookListPage extends StatelessWidget {
  final UserEntity user;
  const LogbookListPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Nhật Ký Hiện Trường')),
      // Thay đổi tại dòng 25:
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LogbookFormPage(
                      userId: user.id, userName: user.fullName)));
          if (context.mounted) {
            context.read<LogbookBloc>().add(LogbookLoadRequested(
                userId: user.isWorker ? user.id : null));
            context.read<SyncBloc>().add(const SyncStatusChecked());
          }
        },
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<SyncBloc>().add(const SyncRequested());
          context.read<LogbookBloc>().add(
              LogbookLoadRequested(userId: user.isWorker ? user.id : null));
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child:
            BlocBuilder<LogbookBloc, LogbookState>(builder: (context, state) {
          if (state is LogbookLoading)
            return const Center(child: CircularProgressIndicator());

          if (state is LogbookLoaded) {
            if (state.items.isEmpty) {
              return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(
                        child: Icon(Icons.menu_book_outlined,
                            size: 56, color: AppColors.textHint)),
                    SizedBox(height: 12),
                    Center(
                        child: Text('Chưa có nhật ký nào',
                            style: TextStyle(color: AppColors.textSecondary))),
                  ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.items.length,
              itemBuilder: (_, i) =>
                  LogbookTile(item: state.items[i], showUser: !user.isWorker),
            );
          }
          if (state is LogbookFailure) {
            return Center(
                child: Text(state.message,
                    style: const TextStyle(color: AppColors.red)));
          }
          return const SizedBox.shrink();
        }),
      ),
    );
  }
}
