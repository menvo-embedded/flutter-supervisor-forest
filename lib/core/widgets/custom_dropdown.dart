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
  Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(label,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:AppColors.textPrimary)),
    const SizedBox(height:6),
    DropdownButtonFormField<T>(
      value:value,items:items,onChanged:onChanged,validator:validator,
      hint:Text(hint,style:const TextStyle(fontSize:14,color:AppColors.textHint)),
      icon:const Icon(Icons.keyboard_arrow_down_rounded,color:AppColors.textSecondary),
      dropdownColor:AppColors.surface,
      style:const TextStyle(fontSize:14,color:AppColors.textPrimary),
      decoration:InputDecoration(
        prefixIcon:prefix,filled:true,fillColor:AppColors.surface,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:AppColors.borderDefault)),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:AppColors.borderDefault)),
        focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:AppColors.primary,width:2)),
        contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
      ),
    ),
  ]);
}
