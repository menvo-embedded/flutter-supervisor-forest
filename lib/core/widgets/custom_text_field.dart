import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText, multiline, readOnly;
  final int maxLines;
  final Widget? prefix, suffix;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;

  const CustomTextField({super.key,required this.label,this.hint,
    this.controller,this.validator,this.keyboardType=TextInputType.text,
    this.obscureText=false,this.multiline=false,this.readOnly=false,
    this.maxLines=5,this.prefix,this.suffix,this.onTap,this.onChanged});

  @override State<CustomTextField> createState() => _State();
}
class _State extends State<CustomTextField> {
  late bool _hide;
  @override void initState(){super.initState();_hide=widget.obscureText;}
  @override
  Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(widget.label,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:AppColors.textPrimary)),
    const SizedBox(height:6),
    TextFormField(
      controller:widget.controller, validator:widget.validator,
      keyboardType:widget.multiline?TextInputType.multiline:widget.keyboardType,
      obscureText:_hide, readOnly:widget.readOnly,
      maxLines:_hide?1:(widget.multiline?widget.maxLines:1),
      minLines:widget.multiline?3:1,
      onTap:widget.onTap, onChanged:widget.onChanged,
      style:const TextStyle(fontSize:14,color:AppColors.textPrimary),
      decoration:InputDecoration(
        hintText:widget.hint,hintStyle:const TextStyle(fontSize:14,color:AppColors.textHint),
        prefixIcon:widget.prefix,
        suffixIcon:widget.obscureText
          ?IconButton(icon:Icon(_hide?Icons.visibility_off_outlined:Icons.visibility_outlined,size:20,color:AppColors.textSecondary),
            onPressed:()=>setState(()=>_hide=!_hide))
          :widget.suffix,
        filled:true,fillColor:widget.readOnly?AppColors.surfaceGrey:AppColors.surface,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:AppColors.borderDefault)),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:AppColors.borderDefault)),
        focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:AppColors.primary,width:2)),
        errorBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:AppColors.red,width:1.5)),
        contentPadding:EdgeInsets.symmetric(horizontal:16,vertical:widget.multiline?14:14),
      ),
    ),
  ]);
}
