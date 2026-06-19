import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../domain/auth/entities/user_entity.dart';
import '../../../domain/checkin/entities/checkin_entity.dart';
import '../bloc/checkin_bloc.dart';
import '../bloc/checkin_event.dart';
import '../bloc/checkin_state.dart';
import '../../sync/bloc/sync_bloc.dart';
import '../../sync/bloc/sync_event.dart';

/// Module 6 & 9 - Check-in/out GPS hiện trường
class CheckinPage extends StatefulWidget {
  final UserEntity user;
  const CheckinPage({super.key, required this.user});
  @override
  State<CheckinPage> createState() => _State();
}

class _State extends State<CheckinPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context
        .read<CheckinBloc>()
        .add(CheckinHistoryRequested(userId: widget.user.id)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Check-in Hiện Trường')),
        body: BlocConsumer<CheckinBloc, CheckinState>(
          listener: (context, state) {
            if (state is CheckinLoaded && state.lastAction != null) {
              final msg = state.lastAction!.isSynced
                  ? '${state.lastAction!.typeLabel} thành công & đã đồng bộ!'
                  : '${state.lastAction!.typeLabel} đã lưu offline. Sẽ đồng bộ sau.';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(msg),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))));
              context.read<SyncBloc>().add(const SyncStatusChecked());
            } else if (state is CheckinFailure) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))));
            }
          },
          builder: (context, state) {
            final loading = state is CheckinLoading;
            bool isCheckedIn = false;
            List<CheckinEntity> history = [];
            if (state is CheckinLoaded) {
              isCheckedIn = state.isCheckedIn;
              history = state.history;
            }

            return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Trạng thái hiện tại ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          gradient: AppColors.forestGradient,
                          borderRadius: BorderRadius.circular(18)),
                      child: Column(children: [
                        Icon(
                            isCheckedIn
                                ? Icons.location_on_rounded
                                : Icons.location_off_rounded,
                            color: Colors.white,
                            size: 40),
                        const SizedBox(height: 10),
                        Text(
                            isCheckedIn
                                ? 'Đang ở hiện trường'
                                : 'Chưa check-in hôm nay',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        if (history.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                  '${history.first.typeLabel} lúc ${formatDateTimeLocal(history.first.timestamp)}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12))),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    // ── Nút check-in/out ──
                    Row(children: [
                      Expanded(
                          child: CustomButton(
                        label: 'Check-in',
                        icon: Icons.login_rounded,
                        isLoading: loading,
                        color: AppColors.primary,
                        onPressed: isCheckedIn
                            ? null
                            : () => context.read<CheckinBloc>().add(
                                CheckinSubmitted(
                                    userId: widget.user.id,
                                    userName: widget.user.fullName,
                                    type: 'check_in')),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: CustomButton(
                        label: 'Check-out',
                        icon: Icons.logout_rounded,
                        isLoading: loading,
                        isOutlined: true,
                        color: AppColors.red,
                        onPressed: !isCheckedIn
                            ? null
                            : () => context.read<CheckinBloc>().add(
                                CheckinSubmitted(
                                    userId: widget.user.id,
                                    userName: widget.user.fullName,
                                    type: 'check_out')),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                        'GPS sẽ được lấy tự động từ thiết bị khi bấm nút trên',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 24),
                    const Text('Lịch sử check-in/out',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    if (history.isEmpty)
                      Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: AppColors.surfaceGrey,
                              borderRadius: BorderRadius.circular(14)),
                          child: const Text('Chưa có lịch sử',
                              style: TextStyle(color: AppColors.textSecondary)))
                    else
                      ...history.map((h) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE5EAE7))),
                            child: Row(children: [
                              Icon(
                                  h.type == 'check_in'
                                      ? Icons.login_rounded
                                      : Icons.logout_rounded,
                                  size: 18,
                                  color: h.type == 'check_in'
                                      ? AppColors.primary
                                      : AppColors.red),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(h.typeLabel,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    Text(h.gpsString,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textHint)),
                                  ])),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(formatDateTimeLocal(h.timestamp),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                    Text(
                                        h.isSynced
                                            ? 'Đã đồng bộ'
                                            : 'Chờ đồng bộ',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: h.isSynced
                                                ? AppColors.statusActive
                                                : AppColors.amber,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                            ]),
                          )),
                    const SizedBox(height: 20),
                  ],
                ));
          },
        ),
      );
}
