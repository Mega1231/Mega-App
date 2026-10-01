import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../models/assignment.dart';
import '../../theme/app_theme.dart';
import '../../services/agora_call_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/caregiver_home_viewmodel.dart';
import '../../viewmodels/clock_viewmodel.dart';
import '../../widgets/custom_loader.dart';
import 'caregiver_schedule_screen.dart';
import 'caregiver_chat_screen.dart';
import 'caregiver_reports_screen.dart';
import 'create_report_screen.dart';
import '../client/client_reports_screen.dart';
import '../common/call_screen.dart';
import '../common/chat_screen.dart';
import '../common/profile_screen.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  int _currentIndex = 0;

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.currentUser;

    final uid = user?.uid ?? '';
    final userName = user?.fullName ?? '';
    final userPhoto = user?.photoUrl ?? '';

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CaregiverHomeViewModel(caregiverId: uid)..loadData(),
        ),
        ChangeNotifierProvider(
          create: (_) => ClockViewModel(
            caregiverId: uid,
            caregiverName: userName,
            caregiverPhotoUrl: userPhoto,
          )..loadData(),
        ),
      ],
      child: Builder(
        builder: (ctx) {
          final vm = ctx.watch<CaregiverHomeViewModel>();
          final pages = [
            _CaregiverHome(vm: vm, onSwitchTab: switchToTab),
            CaregiverScheduleScreen(vm: vm),
            const CaregiverChatScreen(),
            const CaregiverReportsScreen(),
          ];

          return Scaffold(
            body: IndexedStack(index: _currentIndex, children: pages),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.calendar_month), label: 'Schedule'),
                NavigationDestination(
                    icon: Icon(Icons.chat), label: 'Chat'),
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

class _CaregiverHome extends StatefulWidget {
  final CaregiverHomeViewModel vm;
  final void Function(int) onSwitchTab;

  const _CaregiverHome({required this.vm, required this.onSwitchTab});

  @override
  State<_CaregiverHome> createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<_CaregiverHome> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _calculateCardHeight(
      BuildContext context, List<Assignment> assignments) {
    final clockVm = context.watch<ClockViewModel>();
    final hasActiveClockIn = assignments.any((a) =>
        clockVm.isClockedIn &&
        clockVm.activeRecord?.assignmentId == a.id);
    // Base height for card content + clock button
    double height = 200;
    if (hasActiveClockIn) height += 60; // Timer + clock out button extra space
    // Check if any assignment has care plan
    final hasNotes = assignments.any((a) {
      final profile = widget.vm.clientProfiles[a.clientId];
      return profile != null && profile.clientNoteUrl.isNotEmpty;
    });
    if (hasNotes) height += 50;
    return height;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final onSwitchTab = widget.onSwitchTab;
    final authVm = context.watch<AuthViewModel>();
    final userName = authVm.currentUser?.fullName ?? 'Caregiver';
    final today = DateTime.now();
    final todayShort = DateFormat('E').format(today);
    final todayAssignments = vm.getAssignmentsForDay(todayShort, date: today);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mega Homecare Inc'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                final user = context.read<AuthViewModel>().currentUser;
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
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  backgroundImage:
                      (authVm.currentUser?.photoUrl ?? '').isNotEmpty
                          ? NetworkImage(authVm.currentUser!.photoUrl)
                          : null,
                  child: (authVm.currentUser?.photoUrl ?? '').isEmpty
                      ? Text(
                          (authVm.currentUser?.fullName ?? '?')[0]
                              .toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        )
                      : null,
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
              message: 'Loading your dashboard...',
            )
          : RefreshIndicator(
              onRefresh: vm.refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome
                    Text(
                      _greeting(),
                      style: const TextStyle(
                          fontSize: 16, color: AppTheme.textSecondary),
                    ),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Today's overview card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Today\'s Overview',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMM d').format(DateTime.now()),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _InfoItem(
                                'Visits Today',
                                '${todayAssignments.length}',
                                Icons.location_on,
                              ),
                              _InfoItem(
                                'Total Clients',
                                '${vm.clientCount}',
                                Icons.people,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Today's visits
                    Text(
                      todayAssignments.isNotEmpty
                          ? 'Today\'s Visits'
                          : 'No Visits Today',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (todayAssignments.isEmpty)
                      _NoVisitsCard()
                    else ...[
                      // Swipeable client cards
                      SizedBox(
                        height: _calculateCardHeight(context, todayAssignments),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: todayAssignments.length,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                          },
                          itemBuilder: (context, index) {
                            final a = todayAssignments[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: _ClientVisitCard(
                                assignment: a,
                                clientProfile:
                                    vm.clientProfiles[a.clientId],
                              ),
                            );
                          },
                        ),
                      ),
                      // Dot indicators
                      if (todayAssignments.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              todayAssignments.length,
                              (index) => GestureDetector(
                                onTap: () {
                                  _pageController.animateToPage(
                                    index,
                                    duration:
                                        const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  width:
                                      _currentPage == index ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _currentPage == index
                                        ? AppTheme.primaryColor
                                        : AppTheme.primaryColor
                                            .withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),

                    // All assigned clients
                    if (vm.assignments.isNotEmpty) ...[
                      const Text(
                        'Your Clients',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...vm.assignments.map(
                        (a) => _ClientTile(
                          assignment: a,
                          clientProfile: vm.clientProfiles[a.clientId],
                          familyMembers: vm.familyMembersOf(a.clientId),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAction(
                            label: 'Submit Report',
                            icon: Icons.add_circle,
                            color: AppTheme.successColor,
                            onTap: () {
                              final homeVm = context.read<CaregiverHomeViewModel>();
                              showCreateReportSheet(
                                  context, homeVm.assignments);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickAction(
                            label: 'View Schedule',
                            icon: Icons.calendar_month,
                            color: AppTheme.warningColor,
                            onTap: () => onSwitchTab(1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _NoVisitsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: 40,
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'No visits scheduled for today',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enjoy your day off!',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ClientVisitCard extends StatelessWidget {
  final Assignment assignment;
  final AppUser? clientProfile;

  const _ClientVisitCard({
    required this.assignment,
    this.clientProfile,
  });

  @override
  Widget build(BuildContext context) {
    final address = clientProfile?.address ?? '';
    final clockVm = context.watch<ClockViewModel>();
    final isClockedInHere =
        clockVm.isClockedIn &&
        clockVm.activeRecord?.assignmentId == assignment.id;
    final isClockedInElsewhere =
        clockVm.isClockedIn && !isClockedInHere;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isClockedInHere
            ? Border.all(color: AppTheme.successColor, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: assignment.clientPhotoUrl.isNotEmpty
                      ? NetworkImage(assignment.clientPhotoUrl)
                      : null,
                  child: assignment.clientPhotoUrl.isEmpty
                      ? Text(
                          assignment.clientName.isNotEmpty
                              ? assignment.clientName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.clientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (assignment.shiftStartTime.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              assignment.isLiveIn ? Icons.home : Icons.schedule,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              assignment.isLiveIn
                                  ? 'Live-in'
                                  : '${assignment.shiftStartTime} - ${assignment.shiftEndTime}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // View Notes button
            if (clientProfile != null &&
                clientProfile!.clientNoteUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openClientNote(
                    context,
                    clientProfile!.clientNoteUrl,
                    clientProfile!.clientNoteFileName,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    _getNoteIcon(clientProfile!.clientNoteFileName),
                    size: 18,
                  ),
                  label: Text(
                    'View Care Plan: ${clientProfile!.clientNoteFileName}',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Clock In / Out button
            if (isClockedInHere) ...[
              // Timer display
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer,
                        size: 18, color: AppTheme.successColor),
                    const SizedBox(width: 8),
                    Text(
                      clockVm.elapsedFormatted,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: clockVm.isClocking
                      ? null
                      : () => _handleClockOut(context, clockVm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: clockVm.isClocking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.logout, size: 20),
                  label: Text(
                      clockVm.isClocking ? 'Clocking Out...' : 'Clock Out'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (clockVm.isClocking || isClockedInElsewhere)
                      ? null
                      : () => _handleClockIn(context, clockVm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: clockVm.isClocking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.login, size: 20),
                  label: Text(
                    isClockedInElsewhere
                        ? 'Clocked in elsewhere'
                        : clockVm.isClocking
                            ? 'Verifying location...'
                            : 'Clock In',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getNoteIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image;
    return Icons.description;
  }

  Future<void> _openClientNote(
      BuildContext context, String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        await OpenFile.open(file.path);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _handleClockIn(
      BuildContext context, ClockViewModel clockVm) async {
    final success = await clockVm.clockIn(assignment);
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clocked in successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else if (clockVm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(clockVm.error!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      clockVm.clearError();
    }
  }

  Future<void> _handleClockOut(
      BuildContext context, ClockViewModel clockVm) async {
    final success = await clockVm.clockOut();
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clocked out successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else if (clockVm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(clockVm.error!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      clockVm.clearError();
    }
  }
}

class _ClientTile extends StatelessWidget {
  final Assignment assignment;
  final AppUser? clientProfile;
  final List<AppUser> familyMembers;

  const _ClientTile({
    required this.assignment,
    this.clientProfile,
    this.familyMembers = const [],
  });

  @override
  Widget build(BuildContext context) {
    final address = clientProfile?.address ?? '';
    final currentUser = context.read<AuthViewModel>().currentUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.08),
                backgroundImage: assignment.clientPhotoUrl.isNotEmpty
                    ? NetworkImage(assignment.clientPhotoUrl)
                    : null,
                child: assignment.clientPhotoUrl.isEmpty
                    ? Text(
                        assignment.clientName.isNotEmpty
                            ? assignment.clientName[0].toUpperCase()
                            : '?',
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
                      assignment.clientName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            assignment.schedule,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (clientProfile != null &&
              clientProfile!.clientNoteUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openClientNote(
                  context,
                  clientProfile!.clientNoteUrl,
                  clientProfile!.clientNoteFileName,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  _getNoteIcon(clientProfile!.clientNoteFileName),
                  size: 16,
                ),
                label: Text(
                  'View Care Plan',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientReportsScreen(
                    clientId: assignment.clientId,
                    title: '${assignment.clientName} – Care Notes',
                    showBackButton: true,
                    emptyMessage:
                        'No notes yet.\nReports from all caregivers of this client will appear here.',
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.history_edu, size: 16),
              label: const Text(
                'Care Notes (all caregivers)',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          if (currentUser != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ContactButton(
                  icon: Icons.chat,
                  label: 'Chat',
                  color: AppTheme.primaryColor,
                  onTap: () {
                    final clientUser = AppUser(
                      uid: assignment.clientId,
                      username: '',
                      fullName: assignment.clientName,
                      role: 'client',
                      photoUrl: assignment.clientPhotoUrl,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          currentUser: currentUser,
                          otherUser: clientUser,
                        ),
                      ),
                    );
                  },
                ),
                _ContactButton(
                  icon: Icons.call,
                  label: 'Call',
                  color: AppTheme.successColor,
                  onTap: () {
                    final clientUser = AppUser(
                      uid: assignment.clientId,
                      username: '',
                      fullName: assignment.clientName,
                      role: 'client',
                      photoUrl: assignment.clientPhotoUrl,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          currentUser: currentUser,
                          otherUser: clientUser,
                          callType: CallType.audio,
                        ),
                      ),
                    );
                  },
                ),
                _ContactButton(
                  icon: Icons.videocam,
                  label: 'Video',
                  color: AppTheme.warningColor,
                  onTap: () {
                    final clientUser = AppUser(
                      uid: assignment.clientId,
                      username: '',
                      fullName: assignment.clientName,
                      role: 'client',
                      photoUrl: assignment.clientPhotoUrl,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          currentUser: currentUser,
                          otherUser: clientUser,
                          callType: CallType.video,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (familyMembers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.family_restroom,
                      size: 14,
                      color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  const Text(
                    'Family Members',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              ...familyMembers.map(
                (m) => _FamilyContactRow(member: m, currentUser: currentUser),
              ),
            ],
          ],
        ],
      ),
    );
  }

  IconData _getNoteIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image;
    return Icons.description;
  }

  Future<void> _openClientNote(
      BuildContext context, String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        await OpenFile.open(file.path);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

class _FamilyContactRow extends StatelessWidget {
  final AppUser member;
  final AppUser currentUser;

  const _FamilyContactRow({required this.member, required this.currentUser});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE67E22).withValues(alpha: 0.1),
            backgroundImage: member.photoUrl.isNotEmpty
                ? NetworkImage(member.photoUrl)
                : null,
            child: member.photoUrl.isEmpty
                ? Text(
                    member.fullName.isNotEmpty
                        ? member.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE67E22),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.fullName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Chat',
            icon: const Icon(Icons.chat, color: AppTheme.primaryColor),
            onPressed: () => _push(
              context,
              ChatScreen(currentUser: currentUser, otherUser: member),
            ),
          ),
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call, color: AppTheme.successColor),
            onPressed: () => _push(
              context,
              CallScreen(
                currentUser: currentUser,
                otherUser: member,
                callType: CallType.audio,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Video',
            icon: const Icon(Icons.videocam, color: AppTheme.warningColor),
            onPressed: () => _push(
              context,
              CallScreen(
                currentUser: currentUser,
                otherUser: member,
                callType: CallType.video,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
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

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoItem(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
