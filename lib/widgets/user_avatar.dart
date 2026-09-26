import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A CircleAvatar that shows the user's latest profile photo from Firestore.
/// Falls back to the first letter of [name] if no photo is available.
class UserAvatar extends StatefulWidget {
  final String userId;
  final String name;
  final String photoUrl; // initial/fallback photo URL
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const UserAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.photoUrl = '',
    this.radius = 22,
    this.backgroundColor,
    this.textColor,
  });

  static final Map<String, String> _photoCache = {};

  /// Clear the photo cache (e.g. after a profile photo update)
  static void clearCache() => _photoCache.clear();

  /// Clear a single user from cache
  static void clearUser(String userId) => _photoCache.remove(userId);

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String? _resolvedPhoto;

  @override
  void initState() {
    super.initState();
    _resolvePhoto();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _resolvedPhoto = null;
      _resolvePhoto();
    }
  }

  void _resolvePhoto() {
    // If we already have a photo URL from the widget, use it
    if (widget.photoUrl.isNotEmpty) {
      _resolvedPhoto = widget.photoUrl;
      return;
    }

    // Check cache
    if (UserAvatar._photoCache.containsKey(widget.userId)) {
      _resolvedPhoto = UserAvatar._photoCache[widget.userId];
      return;
    }

    // Fetch from Firestore
    if (widget.userId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get()
          .then((doc) {
        if (!mounted) return;
        final photo = (doc.data()?['photoUrl'] as String?) ?? '';
        UserAvatar._photoCache[widget.userId] = photo;
        if (photo.isNotEmpty) {
          setState(() => _resolvedPhoto = photo);
        }
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _resolvedPhoto ?? '';
    final bgColor =
        widget.backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1);
    final fgColor = widget.textColor ?? AppTheme.primaryColor;
    final letter =
        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    final fontSize = widget.radius * 0.8;

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: bgColor,
      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
      child: photo.isEmpty
          ? Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: fgColor,
                fontSize: fontSize,
              ),
            )
          : null,
    );
  }
}
