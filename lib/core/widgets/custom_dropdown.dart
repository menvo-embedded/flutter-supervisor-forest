import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomDropdown<T> extends StatelessWidget {
  final String label, hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final Widget? prefix;

  const CustomDropdown({super.key,required this.label,required this.hint,
    required this.value,required this.items,required this.onChanged,
    this.validator,this.prefix});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);
    final textHint = isDark ? AppColors.textHintDark : AppColors.textHint;
    final surfaceColor = AppColors.getSurface(isDark);
    final borderColor = AppColors.getBorder(isDark);

    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:TextStyle(fontSize:13,fontWeight:FontWeight.w500,color:textPrimary)),
      const SizedBox(height:6),
      DropdownButtonFormField<T>(
        value:value,items:items,onChanged:onChanged,validator:validator,
        hint:Text(hint,style:TextStyle(fontSize:14,color:textHint)),
        icon:Icon(Icons.keyboard_arrow_down_rounded,color:textSecondary),
        dropdownColor:surfaceColor,
        style:TextStyle(fontSize:14,color:textPrimary),
        decoration:InputDecoration(
          prefixIcon:prefix,filled:true,fillColor:surfaceColor,
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:borderColor)),
          enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:borderColor)),
          focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:AppColors.primary,width:1.5)),
          contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
        ),
      ),
    ]);
  }
}
