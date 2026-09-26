import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;

  final String? hintText;
  final String? labelText;

  final TextInputType keyboardType;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;

  final int maxLines;
  final int? maxLength;

  final Widget? prefixIcon;
  final Widget? suffixIcon;

  final Color fillColor;
  final Color textColor;
  final Color hintColor;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color errorBorderColor;

  final double borderRadius;
  final double fontSize;

  final EdgeInsetsGeometry contentPadding;

  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function()? onTap;

  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final TextStyle? labelStyle;

  const CustomTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.fillColor = const Color(0xffF5F5F5),
    this.textColor = Colors.black,
    this.hintColor = Colors.grey,
    this.borderColor = Colors.transparent,
    this.focusedBorderColor = Colors.blue,
    this.errorBorderColor = Colors.red,
    this.borderRadius = 12,
    this.fontSize = 15,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
    this.validator,
    this.onChanged,
    this.onTap,
    this.textStyle,
    this.hintStyle,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      validator: validator,
      onChanged: onChanged,
      onTap: onTap,
      style: textStyle ??
          TextStyle(
            color: textColor,
            fontSize: fontSize,
          ),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        counterText: '',
        contentPadding: contentPadding,
        hintStyle: hintStyle ??
            TextStyle(
              color: hintColor,
              fontSize: fontSize,
            ),
        labelStyle: labelStyle ??
            TextStyle(
              color: hintColor,
              fontSize: fontSize,
            ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: focusedBorderColor, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: errorBorderColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: errorBorderColor, width: 1.4),
        ),
      ),
    );
  }
}
