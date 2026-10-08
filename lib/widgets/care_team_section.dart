import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/assignment.dart';
import '../services/agora_call_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../views/common/call_screen.dart';
import '../views/common/chat_screen.dart';

/// The client's caregivers for this week, each with message, call and
/// video. Used on the client and family dashboards.
class CareTeamSection extends StatelessWidget {
  final List<Assignment> caregivers;
  const CareTeamSection({super.key, required this.caregivers});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthViewModel>().currentUser!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Care Team',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${caregivers.length} caregiver${caregivers.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < caregivers.length; i++) ...[
                _CaregiverRow(
                  assignment: caregivers[i],
                  currentUser: currentUser,
                ),
                if (i < caregivers.length - 1)
                  Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: Colors.grey.withValues(alpha: 0.12),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CaregiverRow extends StatelessWidget {
  final Assignment assignment;
  final AppUser currentUser;

  const _CaregiverRow({required this.assignment, required this.currentUser});

  AppUser get _caregiver => AppUser(
        uid: assignment.caregiverId,
        username: '',
        fullName: assignment.caregiverName,
        role: 'caregiver',
        photoUrl: assignment.caregiverPhotoUrl,
      );

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final name = assignment.caregiverName;
    final photo = assignment.caregiverPhotoUrl;
    final shift = assignment.isLiveIn
        ? 'Live-in'
        : assignment.shiftStartTime.isNotEmpty
            ? '${assignment.shiftStartTime} - ${assignment.shiftEndTime}'
            : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (shift.isNotEmpty)
                  Text(
                    shift,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Message',
            icon: const Icon(Icons.chat_bubble_rounded,
                color: AppTheme.primaryColor),
            onPressed: () => _push(
              context,
              ChatScreen(currentUser: currentUser, otherUser: _caregiver),
            ),
          ),
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call_rounded, color: AppTheme.successColor),
            onPressed: () => _push(
              context,
              CallScreen(
                currentUser: currentUser,
                otherUser: _caregiver,
                callType: CallType.audio,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Video',
            icon: const Icon(Icons.videocam_rounded, color: Color(0xFF8B5CF6)),
            onPressed: () => _push(
              context,
              CallScreen(
                currentUser: currentUser,
                otherUser: _caregiver,
                callType: CallType.video,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
