import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Storage photos on the web need the bucket's CORS config (see
/// storage.cors.json); without it they fail and WebAvatar shows initials.
ImageProvider webNetworkImage(String url) => NetworkImage(url);

/// Design tokens for the desktop admin panel. The mobile screens use
/// AppTheme directly; the web panel shares its brand colors but has its own
/// spacing, surfaces and typography scale for wide layouts.
class WebTokens {
  static const sidebarBg = Color(0xFF0B1F3A);
  static const sidebarText = Color(0xFFB8C4D6);
  static const sidebarActive = Color(0xFF1D3B66);
  static const pageBg = Color(0xFFF4F6FA);
  static const border = Color(0xFFE3E8EF);
  static const rowHover = Color(0xFFF7F9FC);
  static const radius = 12.0;
  static const pagePadding = EdgeInsets.fromLTRB(32, 28, 32, 32);
  static const maxContentWidth = 1440.0;
}

/// White surface with a hairline border, used for every panel.
class WebCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const WebCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(WebTokens.radius),
        border: Border.all(color: WebTokens.border),
      ),
      child: child,
    );
  }
}

/// Title + subtitle on the left, actions on the right.
class WebPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const WebPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: LayoutBuilder(builder: (context, c) {
        // Narrow windows: actions wrap under the title instead of squeezing it.
        if (c.maxWidth < 720 && actions.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            for (final a in actions) ...[const SizedBox(width: 12), a],
          ],
        );
      }),
    );
  }
}

/// Filter tabs on the left, search on the right; wraps on narrow windows.
class WebToolbar extends StatelessWidget {
  final List<Widget> leading;
  final Widget? trailing;

  const WebToolbar({super.key, this.leading = const [], this.trailing});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 760) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: leading,
            ),
            if (trailing != null) ...[const SizedBox(height: 10), trailing!],
          ],
        );
      }
      return Row(
        children: [
          for (final w in leading) ...[w, const SizedBox(width: 16)],
          const Spacer(),
          ?trailing,
        ],
      );
    });
  }
}

/// KPI tile: icon, big number, label, optional caption.
class WebStatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? caption;
  final VoidCallback? onTap;

  const WebStatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.caption,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(WebTokens.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WebTokens.radius),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WebTokens.radius),
            border: Border.all(color: WebTokens.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (caption != null)
                      Text(
                        caption!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const WebStatusBadge({super.key, required this.label, required this.color});

  factory WebStatusBadge.active(bool isActive) => WebStatusBadge(
        label: isActive ? 'Active' : 'Inactive',
        color: isActive ? AppTheme.successColor : AppTheme.textSecondary,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class WebAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;
  final double size;
  final IconData? placeholderIcon;

  const WebAvatar({
    super.key,
    required this.name,
    this.photoUrl = '',
    this.size = 36,
    this.placeholderIcon,
  });

  /// Shown when there is no photo or it fails to load.
  Widget _placeholder() => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: placeholderIcon != null
            ? Icon(placeholderIcon, size: size * 0.45, color: AppTheme.primaryColor)
            : Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
      );

  @override
  Widget build(BuildContext context) {
    // Image + errorBuilder so a photo that fails to load (e.g. missing
    // CORS) falls back to initials instead of an empty circle.
    return ClipOval(
      child: photoUrl.isEmpty
          ? _placeholder()
          : Image(
              image: webNetworkImage(photoUrl),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(),
            ),
    );
  }
}

class WebSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const WebSearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: SizedBox(
      height: 40,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14),
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: WebTokens.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: WebTokens.border),
          ),
        ),
      ),
      ),
    );
  }
}

/// Segmented filter, e.g. All / Active / Inactive with counts.
class WebFilterTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const WebFilterTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: i == selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: i == selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: i == selected
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple column-based table: a header row and hoverable rows. Columns are
/// flex weights so the table fills the available width.
class WebTable extends StatelessWidget {
  final List<String> headers;
  final List<int> flex;
  final List<List<Widget>> rows;
  final ValueChanged<int>? onRowTap;
  final Widget? empty;

  const WebTable({
    super.key,
    required this.headers,
    required this.flex,
    required this.rows,
    this.onRowTap,
    this.empty,
  }) : assert(headers.length == flex.length);

  @override
  Widget build(BuildContext context) {
    return WebCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFC),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(WebTokens.radius),
              ),
              border: Border(bottom: BorderSide(color: WebTokens.border)),
            ),
            child: Row(
              children: [
                for (int i = 0; i < headers.length; i++)
                  Expanded(
                    flex: flex[i],
                    child: Text(
                      headers[i].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (rows.isEmpty && empty != null)
            Padding(padding: const EdgeInsets.all(40), child: empty)
          else
            for (int r = 0; r < rows.length; r++)
              _HoverRow(
                isLast: r == rows.length - 1,
                onTap: onRowTap == null ? null : () => onRowTap!(r),
                child: Row(
                  children: [
                    for (int i = 0; i < rows[r].length; i++)
                      Expanded(
                        flex: flex[i],
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: rows[r][i],
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _HoverRow extends StatefulWidget {
  final Widget child;
  final bool isLast;
  final VoidCallback? onTap;

  const _HoverRow({required this.child, required this.isLast, this.onTap});

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _hover ? WebTokens.rowHover : Colors.white,
            borderRadius: widget.isLast
                ? const BorderRadius.vertical(
                    bottom: Radius.circular(WebTokens.radius),
                  )
                : null,
            border: widget.isLast
                ? null
                : const Border(bottom: BorderSide(color: WebTokens.border)),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class WebEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const WebEmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

Future<bool> webConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title),
      content: SizedBox(width: 420, child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                destructive ? AppTheme.errorColor : AppTheme.primaryColor,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

void webToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      // Also used by shared dialogs in the mobile app, where 420 is wider
      // than the screen.
      width: (MediaQuery.of(context).size.width - 32).clamp(0, 420).toDouble(),
      backgroundColor: error ? AppTheme.errorColor : AppTheme.textPrimary,
    ),
  );
}
