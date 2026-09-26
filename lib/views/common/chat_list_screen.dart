import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../models/chat_room.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/chat_list_viewmodel.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/user_avatar.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final AppUser currentUser;
  final bool showAppBar;

  const ChatListScreen({
    super.key,
    required this.currentUser,
    this.showAppBar = true,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late ChatListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ChatListViewModel();
    _viewModel.init(widget.currentUser);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text('Messages'),
                automaticallyImplyLeading: false,
              )
            : null,
        body: Consumer<ChatListViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (vm.chatRooms.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              itemCount: vm.chatRooms.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 76,
                color: Colors.grey.withValues(alpha: 0.15),
              ),
              itemBuilder: (context, index) {
                final chat = vm.chatRooms[index];
                return _buildChatTile(context, chat);
              },
            );
          },
        ),
        floatingActionButton: widget.currentUser.role == 'admin'
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'groupChat',
                    onPressed: () => _showCreateGroupDialog(context),
                    backgroundColor: AppTheme.successColor,
                    child: const Icon(Icons.group_add),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'directChat',
                    onPressed: () => _showNewChatDialog(context),
                    child: const Icon(Icons.chat),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.forum_outlined,
                size: 56, color: AppTheme.primaryColor.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.currentUser.role == 'admin'
                ? 'Start a conversation with a client or caregiver'
                : 'Your conversations will appear here',
            style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, ChatRoom chat) {
    final isAdmin = widget.currentUser.role == 'admin';
    final currentUserId = widget.currentUser.uid;
    final unread = chat.getUnreadCount(currentUserId);
    final isTyping = chat.isOtherTyping(currentUserId);

    String title;
    String subtitle;
    String? avatarUrl;
    String otherUserId = '';
    String otherRole = '';

    if (chat.isGroup) {
      title = chat.groupName;
      if (isTyping) {
        final typingName = chat.getTypingName(currentUserId);
        subtitle = '$typingName is typing...';
      } else {
        subtitle = chat.lastMessage;
      }
    } else if (isAdmin && !chat.participants.contains(currentUserId)) {
      final names = chat.participantNames.values.toList();
      title = names.join(' & ');
      subtitle = chat.lastMessage;
    } else {
      title = chat.getOtherParticipantName(currentUserId);
      avatarUrl = chat.getOtherParticipantPhoto(currentUserId);
      otherUserId = chat.getOtherParticipantId(currentUserId);
      otherRole = chat.getOtherParticipantRole(currentUserId);
      subtitle = isTyping ? 'typing...' : chat.lastMessage;
    }

    final timeStr = _formatTime(chat.lastMessageTime);

    // Last message icon prefix
    Widget? subtitlePrefix;
    if (!isTyping && chat.lastMessageType == 'image') {
      subtitlePrefix = Icon(Icons.camera_alt_rounded,
          size: 14,
          color: unread > 0 ? AppTheme.textPrimary : AppTheme.textSecondary);
    }

    return InkWell(
      onTap: () => _openChat(context, chat),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Avatar
            _buildChatAvatar(chat, otherUserId, title, avatarUrl, unread > 0),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: unread > 0
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (chat.isGroup)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Group',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.successColor,
                                  ),
                                ),
                              ),
                            if (!chat.isGroup && otherRole.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _roleColor(otherRole)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  otherRole[0].toUpperCase() +
                                      otherRole.substring(1),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _roleColor(otherRole),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              unread > 0 ? FontWeight.w600 : FontWeight.normal,
                          color: unread > 0
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Subtitle row
                  Row(
                    children: [
                      if (subtitlePrefix != null) ...[
                        subtitlePrefix,
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          subtitle.isEmpty ? 'No messages yet' : subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: isTyping
                                ? AppTheme.successColor
                                : (unread > 0
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary),
                            fontWeight:
                                unread > 0 ? FontWeight.w500 : FontWeight.normal,
                            fontStyle:
                                isTyping ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatAvatar(
      ChatRoom chat, String otherUserId, String title, String? avatarUrl, bool hasUnread) {
    if (chat.isGroup) {
      return Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
            child:
                const Icon(Icons.group, color: AppTheme.successColor, size: 26),
          ),
          if (hasUnread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      );
    }

    return Stack(
      children: [
        UserAvatar(
          userId: otherUserId,
          name: title,
          photoUrl: avatarUrl ?? '',
          radius: 28,
        ),
        if (hasUnread)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'caregiver':
        return AppTheme.successColor;
      case 'client':
        return AppTheme.primaryColor;
      case 'family':
        return const Color(0xFFE67E22);
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return DateFormat('h:mm a').format(time);
    } else if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day - 1) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  void _openChat(BuildContext context, ChatRoom chat) {
    final currentUserId = widget.currentUser.uid;

    if (chat.isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            currentUser: widget.currentUser,
            readOnlyChatRoom: chat.participants.contains(currentUserId)
                ? null
                : chat,
            groupChatRoom: chat.participants.contains(currentUserId)
                ? chat
                : null,
          ),
        ),
      );
      return;
    }

    if (!chat.participants.contains(currentUserId)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            currentUser: widget.currentUser,
            readOnlyChatRoom: chat,
          ),
        ),
      );
      return;
    }

    final otherUserId = chat.getOtherParticipantId(currentUserId);

    final otherUser = AppUser(
      uid: otherUserId,
      username: '',
      fullName: chat.getOtherParticipantName(currentUserId),
      role: chat.getOtherParticipantRole(currentUserId),
      photoUrl: chat.getOtherParticipantPhoto(currentUserId),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUser: widget.currentUser,
          otherUser: otherUser,
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateGroupSheet(
        currentUser: widget.currentUser,
        onGroupCreated: (chatRoom) {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                currentUser: widget.currentUser,
                groupChatRoom: chatRoom,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewChatPicker(
        currentUser: widget.currentUser,
        onUserSelected: (otherUser) {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                currentUser: widget.currentUser,
                otherUser: otherUser,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Create Group Sheet
// ─────────────────────────────────────────────────

class _CreateGroupSheet extends StatefulWidget {
  final AppUser currentUser;
  final Function(ChatRoom) onGroupCreated;

  const _CreateGroupSheet({
    required this.currentUser,
    required this.onGroupCreated,
  });

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _groupNameController = TextEditingController();
  // Track selections per group: groupIndex → set of user IDs
  final _selectedPerGroup = <int, Set<String>>{};
  bool _isCreating = false;
  List<_ClientGroup>? _groups;
  List<AppUser>? _allUsers;
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadGroupedUsers();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupedUsers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isActive', isEqualTo: true)
        .get();

    final users = snapshot.docs
        .map((doc) => AppUser.fromFirestore(doc))
        .where((u) => u.uid != widget.currentUser.uid)
        .toList();

    _allUsers = users;

    final clients = users.where((u) => u.role == 'client').toList();
    final familyMembers = users.where((u) => u.role == 'family').toList();
    final caregivers = users.where((u) => u.role == 'caregiver').toList();

    final assignmentSnap = await FirebaseFirestore.instance
        .collection('assignments')
        .where('isActive', isEqualTo: true)
        .get();

    final clientCaregiverMap = <String, Set<String>>{};
    for (final doc in assignmentSnap.docs) {
      final data = doc.data();
      final clientId = data['clientId'] as String? ?? '';
      final caregiverId = data['caregiverId'] as String? ?? '';
      if (clientId.isNotEmpty && caregiverId.isNotEmpty) {
        clientCaregiverMap.putIfAbsent(clientId, () => {}).add(caregiverId);
      }
    }

    final groups = <_ClientGroup>[];
    final assignedCaregiverIds = <String>{};

    for (final client in clients) {
      final family = familyMembers
          .where((f) => f.linkedClientId == client.uid)
          .toList();

      // Only show clients that have family members
      if (family.isEmpty) continue;

      final caregiverIds = clientCaregiverMap[client.uid] ?? {};
      final assignedCaregivers = caregivers
          .where((c) => caregiverIds.contains(c.uid))
          .toList();
      assignedCaregiverIds.addAll(caregiverIds);

      groups.add(_ClientGroup(
        client: client,
        familyMembers: family,
        caregivers: assignedCaregivers,
      ));
    }

    setState(() {
      _groups = groups;
      _isLoadingUsers = false;
    });
  }

  void _toggleUser(int groupIndex, String uid) {
    setState(() {
      final group = _selectedPerGroup.putIfAbsent(groupIndex, () => {});
      if (group.contains(uid)) {
        group.remove(uid);
        if (group.isEmpty) _selectedPerGroup.remove(groupIndex);
      } else {
        group.add(uid);
      }
    });
  }

  bool _isUserSelected(int groupIndex, String uid) =>
      _selectedPerGroup[groupIndex]?.contains(uid) ?? false;

  Set<String> get _allSelectedUserIds {
    final ids = <String>{};
    for (final group in _selectedPerGroup.values) {
      ids.addAll(group);
    }
    return ids;
  }

  bool get _hasSelections => _selectedPerGroup.values.any((g) => g.isNotEmpty);

  void _selectAllInGroup(int groupIndex, _ClientGroup group) {
    setState(() {
      final selected = _selectedPerGroup.putIfAbsent(groupIndex, () => {});
      if (group.client != null) selected.add(group.client!.uid);
      for (final f in group.familyMembers) {
        selected.add(f.uid);
      }
      for (final c in group.caregivers) {
        selected.add(c.uid);
      }
    });
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty || !_hasSelections || _allUsers == null) return;

    setState(() => _isCreating = true);

    try {
      final ids = _allSelectedUserIds;
      final selectedUsers = _allUsers!
          .where((u) => ids.contains(u.uid))
          .toList();
      final members = [widget.currentUser, ...selectedUsers];
      final chatRoom = await ChatService().createGroupChat(
        groupName: name,
        createdBy: widget.currentUser.uid,
        members: members,
      );
      widget.onGroupCreated(chatRoom);
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.error(
        context: context,
        message: 'Failed to create group: $e',
      );
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _allSelectedUserIds.length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) {
          return Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.group_add,
                          color: AppTheme.successColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Create Group Chat',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.withValues(alpha: 0.08),
                        shape: const CircleBorder(),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Group name field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _groupNameController,
                  decoration: InputDecoration(
                    hintText: 'Enter group name',
                    prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryColor, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              if (_hasSelections) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: AppTheme.successColor),
                      const SizedBox(width: 6),
                      Text(
                        '$selectedCount member${selectedCount > 1 ? 's' : ''} selected',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.withValues(alpha: 0.12)),

              // User list
              Expanded(
                child: _isLoadingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : _groups == null || _groups!.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 48,
                                    color: AppTheme.textSecondary
                                        .withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                const Text('No users available',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: _groups!.length,
                            itemBuilder: (_, i) =>
                                _buildClientGroupSection(i, _groups![i]),
                          ),
              ),

              // Create button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating ||
                              !_hasSelections ||
                              _groupNameController.text.trim().isEmpty
                          ? null
                          : _createGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.withValues(alpha: 0.12),
                        disabledForegroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _hasSelections
                                  ? 'Create Group ($selectedCount members)'
                                  : 'Select members to create',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClientGroupSection(int groupIndex, _ClientGroup group) {
    final isUnassigned = group.client == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnassigned
              ? Colors.grey.withValues(alpha: 0.15)
              : AppTheme.primaryColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUnassigned
                  ? Colors.grey.withValues(alpha: 0.04)
                  : AppTheme.primaryColor.withValues(alpha: 0.03),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isUnassigned
                        ? Colors.grey.withValues(alpha: 0.1)
                        : AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isUnassigned ? Icons.person_off_outlined : Icons.person,
                    size: 16,
                    color: isUnassigned
                        ? AppTheme.textSecondary
                        : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isUnassigned
                        ? 'Unassigned Caregivers'
                        : group.client!.fullName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isUnassigned
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (!isUnassigned)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Client',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _selectAllInGroup(groupIndex, group),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.select_all,
                            size: 12, color: AppTheme.successColor),
                        SizedBox(width: 4),
                        Text(
                          'Select All',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Client checkbox
          if (!isUnassigned)
            _buildUserCheckbox(
              groupIndex,
              group.client!,
              'Client',
              AppTheme.primaryColor,
            ),

          // Family members
          if (group.familyMembers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 6, bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.family_restroom,
                      size: 13,
                      color: const Color(0xFFE67E22).withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Text(
                    'Family Members (${group.familyMembers.length})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE67E22).withValues(alpha: 0.8),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            ...group.familyMembers.map((f) => _buildUserCheckbox(
                  groupIndex,
                  f,
                  'Family',
                  const Color(0xFFE67E22),
                )),
          ],

          // Caregivers
          if (group.caregivers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 6, bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.medical_services_outlined,
                      size: 13,
                      color: AppTheme.successColor.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Text(
                    isUnassigned
                        ? 'Caregivers (${group.caregivers.length})'
                        : 'Assigned Caregivers (${group.caregivers.length})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successColor.withValues(alpha: 0.8),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            ...group.caregivers.map((c) => _buildUserCheckbox(
                  groupIndex,
                  c,
                  'Caregiver',
                  AppTheme.successColor,
                )),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildUserCheckbox(
      int groupIndex, AppUser user, String roleLabel, Color color) {
    final isSelected = _isUserSelected(groupIndex, user.uid);

    return InkWell(
      onTap: () => _toggleUser(groupIndex, user.uid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.grey.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            UserAvatar(
              userId: user.uid,
              name: user.fullName,
              photoUrl: user.photoUrl,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                user.fullName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientGroup {
  final AppUser? client;
  final List<AppUser> familyMembers;
  final List<AppUser> caregivers;

  _ClientGroup({
    required this.client,
    required this.familyMembers,
    required this.caregivers,
  });
}

// ─────────────────────────────────────────────────
// New Chat Picker
// ─────────────────────────────────────────────────

class _NewChatPicker extends StatelessWidget {
  final AppUser currentUser;
  final Function(AppUser) onUserSelected;

  const _NewChatPicker({
    required this.currentUser,
    required this.onUserSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.chat_bubble_outline,
                          color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'New Conversation',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.withValues(alpha: 0.08),
                        shape: const CircleBorder(),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.withValues(alpha: 0.12)),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('isActive', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = snapshot.data!.docs
                        .map((doc) => AppUser.fromFirestore(doc))
                        .where((u) => u.uid != currentUser.uid)
                        .toList();

                    if (users.isEmpty) {
                      return const Center(
                        child: Text('No users available',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 72,
                        color: Colors.grey.withValues(alpha: 0.1),
                      ),
                      itemBuilder: (_, index) {
                        final user = users[index];
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: UserAvatar(
                            userId: user.uid,
                            name: user.fullName,
                            photoUrl: user.photoUrl,
                          ),
                          title: Text(user.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            user.role[0].toUpperCase() + user.role.substring(1),
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppTheme.textSecondary, size: 20),
                          onTap: () => onUserSelected(user),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
