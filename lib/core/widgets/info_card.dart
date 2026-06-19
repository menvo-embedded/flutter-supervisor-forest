import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class InfoCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  const InfoCard({super.key,required this.title,required this.value,
    required this.icon,this.iconColor,this.subtitle});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);
    final borderColor = AppColors.getBorder(isDark);
    final surfaceColor = AppColors.getSurface(isDark);

    return Card(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(padding:const EdgeInsets.all(16),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(width:36,height:36,decoration:BoxDecoration(
              color:(iconColor??AppColors.primary).withOpacity(isDark ? 0.22 : 0.12),
              borderRadius:BorderRadius.circular(10)),
              child:Icon(icon,size:20,color:iconColor??AppColors.primary)),
            const Spacer(),
          ]),
          const SizedBox(height:12),
          Text(value,style:TextStyle(fontSize:22,fontWeight:FontWeight.w700,color:textPrimary)),
          const SizedBox(height:2),
          Text(title,style:TextStyle(fontSize:12,color:textSecondary,fontWeight:FontWeight.w500)),
          if(subtitle!=null)...[const SizedBox(height:4),
            Text(subtitle!,style:const TextStyle(fontSize:11,color:AppColors.statusActive,fontWeight:FontWeight.w500))],
        ]),
      ),
    );
  }
}
