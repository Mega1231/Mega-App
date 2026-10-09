import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Asks for a short comment (e.g. why a document needs changes). Resolves
/// to the trimmed text, or null when cancelled.
///
/// The dialog owns its controller, so it is disposed only after the dialog's
/// closing animation (disposing it from the caller while the route is still
/// animating out trips a framework assertion).
Future<String?> showCommentDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String hint = '',
  String helper = '',
  String initial = '',
  Color confirmColor = AppTheme.warningColor,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CommentDialog(
      title: title,
      confirmLabel: confirmLabel,
      hint: hint,
      helper: helper,
      initial: initial,
      confirmColor: confirmColor,
    ),
  );
}

class _CommentDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String hint;
  final String helper;
  final String initial;
  final Color confirmColor;

  const _CommentDialog({
    required this.title,
    required this.confirmLabel,
    required this.hint,
    required this.helper,
    required this.initial,
    required this.confirmColor,
  });

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: widget.hint.isEmpty ? null : widget.hint,
            helperText: widget.helper.isEmpty ? null : widget.helper,
            helperMaxLines: 2,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: widget.confirmColor),
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
