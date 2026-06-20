import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../bloc/logbook_bloc.dart';
import '../bloc/logbook_event.dart';
import '../bloc/logbook_state.dart';
import '../../../domain/logbook/entities/logbook_entity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart';

/// Module 8 - Forest Logbook: Biểu mẫu ghi nhật ký hiện trường
class LogbookFormPage extends StatefulWidget {
  final String userId, userName;
  const LogbookFormPage({super.key, required this.userId, required this.userName});
  @override State<LogbookFormPage> createState() => _State();
}

class _State extends State<LogbookFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();
  JobType? _jobType;
  final List<File> _images = [];

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  Future<void> _pickImage(ImageSource src) async {
    if (_images.length >= 10) { _toast('Đã đạt giới hạn 10 ảnh.', err:true); return; }
    try {
      final img = await _picker.pickImage(source: src, imageQuality: 80, maxWidth: 1920);
      if (img != null) setState(() => _images.add(File(img.path)));
    } catch (e) { _toast('Không thể chụp ảnh: $e', err:true); }
  }

  void _showPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.getBorder(isDark)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Thêm ảnh hiện trường',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(isDark)),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _SrcBtn(icon: Icons.camera_alt_outlined, label: 'Chụp ảnh',
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); })),
              const SizedBox(width: 14),
              Expanded(child: _SrcBtn(icon: Icons.photo_library_outlined, label: 'Thư viện',
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); })),
            ]),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _toast(String msg, {bool err=false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: err?AppColors.red:AppColors.primary,
    behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  void _submit() {
    if (!(_formKey.currentState?.validate()??false)) return;
    if (_jobType==null) { _toast('Vui lòng chọn loại công việc.', err:true); return; }
    context.read<LogbookBloc>().add(LogbookSubmitted(logbook: LogbookEntity(
      jobType: _jobType!, description: _descCtrl.text.trim(),
      imagePaths: _images.map((f)=>f.path).toList(),
      latitude: 0, longitude: 0, timestamp: DateTime.now(),
      userId: widget.userId, userName: widget.userName,
    )));
  }

  IconData _jobIcon(JobType t) => switch(t) {
    JobType.plantingTrees => Icons.park_outlined,
    JobType.treeCare => Icons.eco_outlined,
    JobType.fertilizing => Icons.water_drop_outlined,
    JobType.growthInspection => Icons.search_outlined,
    JobType.patrol => Icons.directions_walk_outlined,
    JobType.firePrevention => Icons.local_fire_department_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.getBg(isDark),
      appBar: AppBar(title: const Text('Nhật Ký Hiện Trường')),
      body: BlocConsumer<LogbookBloc, LogbookState>(
        listener: (context, state) {
          if (state is LogbookSubmitSuccess) {
            _toast(state.isOnline ? 'Đã lưu & đồng bộ lên server!' : 'Đã lưu offline. Sẽ đồng bộ khi có mạng.');
            Navigator.pop(context);
          } else if (state is LogbookFailure) {
            _toast(state.message, err:true);
          }
        },
        builder: (context, state) {
          final loading = state is LogbookSubmitting;
          return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key:_formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionHeader(icon: Icons.assignment_outlined, title: 'Thông tin công việc'),
              const SizedBox(height: 14),
              CustomDropdown<JobType>(
                label: 'Loại công việc *', hint: 'Chọn loại công việc...', value: _jobType,
                prefix: Icon(Icons.work_outline_rounded, size: 20, color: AppColors.getTextSecondary(isDark)),
                items: JobType.values.map((t)=>DropdownMenuItem(value:t, child: Row(children:[
                  Icon(_jobIcon(t), size:18, color: AppColors.primary), const SizedBox(width:8), Text(t.displayName),
                ]))).toList(),
                onChanged: (v)=>setState(()=>_jobType=v),
                validator: (v)=>v==null?'Vui lòng chọn loại công việc':null),
              const SizedBox(height: 18),
              CustomTextField(label: 'Mô tả chi tiết *', hint: 'Mô tả công việc đã thực hiện...',
                controller: _descCtrl, multiline: true, maxLines: 6,
                validator: (v){
                  if(v==null||v.trim().isEmpty) return 'Vui lòng nhập mô tả';
                  if(v.trim().length<10) return 'Mô tả quá ngắn (tối thiểu 10 ký tự)';
                  return null;
                }),
              const SizedBox(height: 22), Divider(color: AppColors.getBorder(isDark)), const SizedBox(height: 18),
              Row(children: [
                const _SectionHeader(icon: Icons.photo_camera_outlined, title: 'Ảnh hiện trường'),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_images.length}/10', style: TextStyle(fontSize:12,fontWeight:FontWeight.w600,color: isDark ? Colors.white : AppColors.primary))),
              ]),
              const SizedBox(height: 12),
              GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3, crossAxisSpacing:10, mainAxisSpacing:10, childAspectRatio:1),
                itemCount: _images.length + (_images.length<10?1:0),
                itemBuilder: (_, i) => i==_images.length
                  ? _AddBtn(onTap: _showPicker)
                  : _Thumb(file: _images[i], index: i+1, onRemove: ()=>setState(()=>_images.removeAt(i)))),
              const SizedBox(height: 8),
              Text('Hỗ trợ JPG, PNG • Tối đa 10 ảnh/nhật ký', style: TextStyle(fontSize:12,color:AppColors.getTextSecondary(isDark))),
              const SizedBox(height: 22),
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primary.withOpacity(0.18) : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(isDark ? 0.35 : 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.gps_fixed_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tọa độ GPS', style: TextStyle(fontSize:12,fontWeight:FontWeight.w600,color: isDark ? Colors.white : AppColors.primaryDark)),
                    const SizedBox(height:2),
                    Text('Vị trí + thời gian sẽ được ghi tự động khi lưu', style: TextStyle(fontSize:11,color:AppColors.getTextSecondary(isDark))),
                  ])),
                ])),
              const SizedBox(height: 22),
              CustomButton(label: 'Lưu Nhật Ký', onPressed: loading?null:_submit, isLoading: loading, icon: Icons.save_rounded),
              const SizedBox(height: 30),
            ]),
          ));
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon; final String title;
  const _SectionHeader({required this.icon, required this.title});
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(children: [
      Icon(icon, color: AppColors.primary, size: 20), const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize:15,fontWeight:FontWeight.w700,color:AppColors.getTextPrimary(isDark))),
    ]);
  }
}
class _SrcBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _SrcBtn({required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primary.withOpacity(0.18) : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(isDark ? 0.45 : 0.3)),
      ),
      child: Column(children: [
        Icon(icon, color: AppColors.primary, size: 30), const SizedBox(height:6),
        Text(label, style: TextStyle(color: isDark ? Colors.white : AppColors.primaryDark, fontWeight: FontWeight.w600)),
      ]),
    ));
  }
}
class _AddBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddBtn({required this.onTap});
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(onTap: onTap, child: Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(isDark ? 0.6 : 0.4), width:1.5),
      ),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 26), SizedBox(height:4),
        Text('Thêm ảnh', style: TextStyle(fontSize:11,color:AppColors.primary,fontWeight:FontWeight.w500))])));
  }
}
class _Thumb extends StatelessWidget {
  final File file; final int index; final VoidCallback onRemove;
  const _Thumb({required this.file, required this.index, required this.onRemove});
  @override Widget build(BuildContext context) => Stack(children: [
    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
    Positioned(bottom:4,left:4, child: Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
      child: Text('$index', style: const TextStyle(color: Colors.white, fontSize:10)))),
    Positioned(top:4,right:4, child: GestureDetector(onTap: onRemove, child: Container(padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
      child: const Icon(Icons.close, color: Colors.white, size:14)))),
  ]);
}
