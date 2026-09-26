import 'package:flutter/material.dart';

class CustomLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color color;
  final String? message;
  final TextStyle? messageStyle;
  final bool showMessage;

  const CustomLoader({
    super.key,
    this.size = 34,
    this.strokeWidth = 3,
    this.color = Colors.blue,
    this.message,
    this.messageStyle,
    this.showMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: size,
            width: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              color: color,
            ),
          ),
          if (showMessage && message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: messageStyle ??
                  TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
