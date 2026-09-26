import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  final Color backgroundColor;
  final Color titleColor;
  final Color iconColor;

  final double elevation;
  final double titleFontSize;
  final FontWeight titleFontWeight;

  final bool centerTitle;
  final bool showBackButton;

  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onBackTap;

  final double toolbarHeight;
  final TextStyle? titleStyle;

  const CustomAppBar({
    super.key,
    required this.title,
    this.backgroundColor = Colors.white,
    this.titleColor = Colors.black,
    this.iconColor = Colors.black,
    this.elevation = 0,
    this.titleFontSize = 18,
    this.titleFontWeight = FontWeight.w600,
    this.centerTitle = true,
    this.showBackButton = true,
    this.actions,
    this.leading,
    this.onBackTap,
    this.toolbarHeight = kToolbarHeight,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: elevation,
      centerTitle: centerTitle,
      toolbarHeight: toolbarHeight,
      automaticallyImplyLeading: false,
      leading: leading ??
          (showBackButton
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: iconColor,
                    size: 20,
                  ),
                  onPressed: onBackTap ?? () => Navigator.pop(context),
                )
              : null),
      title: Text(
        title,
        style: titleStyle ??
            TextStyle(
              color: titleColor,
              fontSize: titleFontSize,
              fontWeight: titleFontWeight,
            ),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
}
