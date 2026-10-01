import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../models/assignment.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/family_home_viewmodel.dart';
import '../../widgets/custom_loader.dart';
import '../../services/agora_call_service.dart';
import '../common/chat_list_screen.dart';
import '../common/chat_screen.dart';
import '../common/call_screen.dart';
import '../common/profile_screen.dart';
import '../client/client_reports_screen.dart';

class FamilyDashboard extends StatefulWidget {
  const FamilyDashboard({super.key});

  @override
  State<FamilyDashboard> createState() => _FamilyDashboardState();
}

class _FamilyDashboardState extends State<FamilyDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.currentUser;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              FamilyHomeViewModel(familyUserId: user?.uid ?? '')..loadData(),
        ),
      ],
      child: Builder(
        builder: (ctx) {
          final pages = [
            const _FamilyHome(),
            user != null
                ? ChatListScreen(currentUser: user, showAppBar: true)
                : const Center(
                    child: CustomLoader(color: AppTheme.primaryColor)),
            user != null
                ? ClientReportsScreen(clientId: user.linkedClientId)
                : const Center(
                    child: CustomLoader(color: AppTheme.primaryColor)),
          ];

          return Scaffold(
            body: IndexedStack(index: _currentIndex, children: pages),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
                NavigationDestination(
                    icon: Icon(Icons.description), label: 'Reports'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FamilyHome extends StatelessWidget {
  const _FamilyHome();

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final vm = context.watch<FamilyHomeViewModel>();
    final user = authVm.currentUser;
    final userName = user?.fullName ?? 'Family Member';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mega Homecare Inc'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                if (user == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProfileScreen(user: user)),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: vm.isLoading
          ? const CustomLoader(
              color: AppTheme.primaryColor,
              showMessage: true,
              message: 'Loading...',
            )
          : RefreshIndicator(
              onRefresh: vm.refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client info card
                    if (vm.client != null) _ClientInfoCard(client: vm.client!),
                    const SizedBox(height: 16),

                    // Caregiver card
                    if (vm.hasCaregiver)
                      _CareTeamSection(caregivers: vm.caregivers)
                    else
                      _NoCaregiverCard(),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ClientInfoCard extends StatelessWidget {
  final AppUser client;
  const _ClientInfoCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
              backgroundImage: client.photoUrl.isNotEmpty
                  ? NetworkImage(client.photoUrl)
                  : null,
              child: client.photoUrl.isEmpty
                  ? Text(
                      client.fullName.isNotEmpty
                          ? client.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.family_restroom,
                        size: 14,
                        color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    const Text(
                      'Your Family Member',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  client.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Client',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareTeamSection extends StatelessWidget {
  final List<Assignment> caregivers;
  const _CareTeamSection({required this.caregivers});

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

class _NoCaregiverCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_search_outlined,
              size: 40,
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Caregiver Assigned',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A caregiver will be assigned to your\nfamily member soon.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
