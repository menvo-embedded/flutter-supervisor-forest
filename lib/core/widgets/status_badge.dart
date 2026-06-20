import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key,required this.label,required this.color});
  factory StatusBadge.active()   => const StatusBadge(label:'Hoạt động', color:AppColors.statusActive);
  factory StatusBadge.draft()    => const StatusBadge(label:'Nháp',      color:AppColors.statusDraft);
  factory StatusBadge.inactive() => const StatusBadge(label:'Dừng',      color:AppColors.textSecondary);
  factory StatusBadge.offline()  => const StatusBadge(label:'Offline',   color:AppColors.amber);
  factory StatusBadge.synced()   => const StatusBadge(label:'Đã đồng bộ',color:AppColors.statusActive);

  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
    decoration:BoxDecoration(color:color.withOpacity(0.12),borderRadius:BorderRadius.circular(12)),
    child:Text(label,style:TextStyle(fontSize:11,fontWeight:FontWeight.w500,color:color)),
  );
}
