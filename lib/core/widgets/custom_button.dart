import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? color;
  final double height;
  final double? width;

  const CustomButton({super.key,required this.label,this.onPressed,
    this.isLoading=false,this.isOutlined=false,this.icon,
    this.color,this.height=52,this.width});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary;
    Widget child = isLoading
        ? SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2.5,color:isOutlined?bg:Colors.white))
        : Row(mainAxisSize:MainAxisSize.min,children:[
            if(icon!=null)...[Icon(icon,size:19,color:isOutlined?bg:Colors.white),const SizedBox(width:7)],
            Text(label,style:TextStyle(fontSize:15,fontWeight:FontWeight.w600,color:isOutlined?bg:Colors.white)),
          ]);
    final shape = RoundedRectangleBorder(borderRadius:BorderRadius.circular(12));
    final sz = Size(width??double.infinity, height);
    if(isOutlined) return SizedBox(width:width??double.infinity,height:height,
      child:OutlinedButton(onPressed:isLoading?null:onPressed,
        style:OutlinedButton.styleFrom(foregroundColor:bg,side:BorderSide(color:bg,width:1.5),shape:shape,minimumSize:sz),
        child:child));
    return SizedBox(width:width??double.infinity,height:height,
      child:ElevatedButton(onPressed:isLoading?null:onPressed,
        style:ElevatedButton.styleFrom(backgroundColor:bg,shape:shape,elevation:0,minimumSize:sz,
          disabledBackgroundColor:bg.withOpacity(0.6)),
        child:child));
  }
}
