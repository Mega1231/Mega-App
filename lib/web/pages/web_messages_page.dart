import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../models/chat_message.dart';
import '../../models/chat_room.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../web_widgets.dart';

/// Two-pane messages: every conversation on the left, the selected one on
/// the right. Admins can post where they are a member, turn group messaging
/// on/off, create groups and manage members. Other chats are view-only.
class WebMessagesPage extends StatefulWidget {
  const WebMessagesPage({super.key});

  @override
  State<WebMessagesPage> createState() => _WebMessagesPageState();
}

class _WebMessagesPageState extends State<WebMessagesPage> {
  final _service = ChatService();
  late final Stream<List<ChatRoom>> _rooms = _service.getAllChatRoomsStream();
  String? _selectedId;
  String _query = '';
  int _filter = 0; // 0 all, 1 groups, 2 direct

  String _title(ChatRoom r) =>
      r.isGroup ? r.groupName : r.participantNames.values.join(' & ');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatRoom>>(
      stream: _rooms,
      builder: (context, snap) {
        final rooms = snap.data ?? const <ChatRoom>[];
        final q = _query.trim().toLowerCase();
        final visible = rooms.where((r) {
          if (_filter == 1 && !r.isGroup) return false;
          if (_filter == 2 && r.isGroup) return false;
          return q.isEmpty || _title(r).toLowerCase().contains(q);
        }).toList();
        final selected = rooms.where((r) => r.id == _selectedId).firstOrNull;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: MediaQuery.of(context).size.width < 1200 ? 280 : 340,
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 16, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Messages',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        IconButton.outlined(
                          tooltip: 'New message',
                          onPressed: () => _newDirect(context),
                          icon: const Icon(Icons.edit_square, size: 18),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _newGroup(context),
                          icon: const Icon(Icons.group_add_outlined, size: 18),
                          label: const Text('New group'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search conversations',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: WebTokens.border),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: WebFilterTabs(
                      labels: const ['All', 'Groups', 'Direct'],
                      selected: _filter,
                      onChanged: (i) => setState(() => _filter = i),
                    ),
                  ),
                  const Divider(height: 1, color: WebTokens.border),
                  Expanded(
                    child: snap.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (_, i) => _RoomTile(
                              room: visible[i],
                              title: _title(visible[i]),
                              selected: visible[i].id == _selectedId,
                              onTap: () =>
                                  setState(() => _selectedId = visible[i].id),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: WebTokens.border),
            Expanded(
              child: selected == null
                  ? const Center(
                      child: WebEmptyState(
                        icon: Icons.forum_outlined,
                        message: 'Choose a conversation',
                      ),
                    )
                  : _ChatPane(
                      key: ValueKey(selected.id),
                      room: selected,
                      title: _title(selected),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _newDirect(BuildContext context) async {
    final admin = context.read<AuthViewModel>().currentUser!;
    final person = await showDialog<AppUser>(
      context: context,
      builder: (_) => _PersonPickerDialog(adminId: admin.uid),
    );
    if (person == null || !context.mounted) return;
    try {
      final room = await _service.getOrCreateChatRoom(
          currentUser: admin, otherUser: person);
      if (mounted) {
        setState(() {
          _filter = 0;
          _selectedId = room.id;
        });
      }
    } catch (e) {
      if (context.mounted) {
        webToast(context, 'Could not start chat: $e', error: true);
      }
    }
  }

  Future<void> _newGroup(BuildContext context) async {
    final admin = context.read<AuthViewModel>().currentUser!;
    final room = await showDialog<ChatRoom>(
      context: context,
      builder: (_) => _GroupDialog(admin: admin),
    );
    if (room != null && mounted) setState(() => _selectedId = room.id);
  }
}

class _RoomTile extends StatelessWidget {
  final ChatRoom room;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _RoomTile({
    required this.room,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = room.lastMessageTime;
    final today = DateUtils.isSameDay(t, DateTime.now());
    return Material(
      color: selected
          ? AppTheme.primaryColor.withValues(alpha: 0.07)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? AppTheme.primaryColor : Colors.transparent,
                width: 3,
              ),
              bottom: const BorderSide(color: WebTokens.border),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (room.isGroup ? AppTheme.successColor : AppTheme.primaryColor)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  room.isGroup ? Icons.groups_outlined : Icons.chat_bubble_outline,
                  size: 19,
                  color: room.isGroup ? AppTheme.successColor : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        if (t != null)
                          Text(
                            today
                                ? DateFormat('h:mm a').format(t)
                                : DateFormat('MMM d').format(t),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (room.messagingDisabled) ...[
                          const Icon(Icons.speaker_notes_off,
                              size: 13, color: AppTheme.errorColor),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            room.lastMessage.isNotEmpty
                                ? room.lastMessage
                                : room.isGroup
                                    ? '${room.participants.length} members'
                                    : 'No messages yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
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

class _ChatPane extends StatefulWidget {
  final ChatRoom room;
  final String title;

  const _ChatPane({super.key, required this.room, required this.title});

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final _service = ChatService();
  final _input = TextEditingController();
  late final Stream<List<ChatMessage>> _messages =
      _service.getMessagesStream(widget.room.id, limit: 100);
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(AppUser admin) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (widget.room.isGroup) {
        await _service.sendGroupMessage(
          chatId: widget.room.id,
          senderId: admin.uid,
          senderName: admin.fullName,
          text: text,
          participantIds: widget.room.participants,
        );
      } else {
        await _service.sendMessage(
          chatId: widget.room.id,
          senderId: admin.uid,
          senderName: admin.fullName,
          text: text,
          receiverId: widget.room.getOtherParticipantId(admin.uid),
        );
      }
      _input.clear();
    } catch (e) {
      if (mounted) webToast(context, 'Could not send: $e', error: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _sendPhoto(AppUser admin) async {
    final picked =
        await FilePicker.pickFiles(type: FileType.image, withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;
    setState(() => _sending = true);
    try {
      if (widget.room.isGroup) {
        await _service.sendGroupImageMessage(
          chatId: widget.room.id,
          senderId: admin.uid,
          senderName: admin.fullName,
          participantIds: widget.room.participants,
          imageBytes: bytes,
        );
      } else {
        await _service.sendImageMessage(
          chatId: widget.room.id,
          senderId: admin.uid,
          senderName: admin.fullName,
          receiverId: widget.room.getOtherParticipantId(admin.uid),
          imageBytes: bytes,
        );
      }
    } catch (e) {
      if (mounted) webToast(context, 'Could not send photo: $e', error: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _toggleMessaging() async {
    final disable = !widget.room.messagingDisabled;
    final ok = await webConfirm(
      context,
      title: disable ? 'Turn off messaging?' : 'Turn messaging back on?',
      message: disable
          ? 'Members of "${widget.room.groupName}" will no longer be able to send messages. Admins can still post.'
          : 'Members of "${widget.room.groupName}" will be able to send messages again.',
      confirmLabel: disable ? 'Turn off' : 'Turn on',
      destructive: disable,
    );
    if (!ok) return;
    try {
      await _service.setGroupMessagingDisabled(widget.room.id, disable);
    } catch (e) {
      if (mounted) webToast(context, 'Could not update group: $e', error: true);
    }
  }

  /// Labelled buttons when there is room, icon buttons on narrow windows so
  /// the title keeps its space.
  List<Widget> _groupActions(BuildContext context, ChatRoom room) {
    final compact = MediaQuery.of(context).size.width < 1200;
    final toggleIcon = room.messagingDisabled
        ? Icons.speaker_notes
        : Icons.speaker_notes_off_outlined;
    final toggleLabel =
        room.messagingDisabled ? 'Turn messaging on' : 'Turn messaging off';
    void openMembers() => showDialog(
          context: context,
          builder: (_) => _MembersDialog(room: room),
        );
    if (compact) {
      return [
        IconButton.outlined(
          tooltip: toggleLabel,
          onPressed: _toggleMessaging,
          icon: Icon(toggleIcon, size: 18),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Members',
          onPressed: openMembers,
          icon: const Icon(Icons.people_outline, size: 18),
        ),
      ];
    }
    return [
      OutlinedButton.icon(
        onPressed: _toggleMessaging,
        icon: Icon(toggleIcon, size: 18),
        label: Text(toggleLabel),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: openMembers,
        icon: const Icon(Icons.people_outline, size: 18),
        label: const Text('Members'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AuthViewModel>().currentUser!;
    final room = widget.room;
    final isMember = room.participants.contains(admin.uid);

    return Container(
      color: WebTokens.pageBg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: WebTokens.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        room.isGroup
                            ? '${room.participants.length} members${isMember ? '' : ' · you are not a member'}'
                            : isMember
                                ? 'Direct message'
                                : 'Viewing conversation (read only)',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (room.isGroup) ..._groupActions(context, room),
              ],
            ),
          ),
          if (room.isGroup && room.messagingDisabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: AppTheme.errorColor.withValues(alpha: 0.07),
              child: const Text(
                'Messaging is off for members — only admins can post',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.errorColor),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messages,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!;
                if (msgs.isEmpty) {
                  return const Center(
                    child: WebEmptyState(
                        icon: Icons.chat_outlined, message: 'No messages yet'),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final older = i + 1 < msgs.length ? msgs[i + 1] : null;
                    final newDay = older == null ||
                        !DateUtils.isSameDay(older.createdAt, m.createdAt);
                    return Column(
                      children: [
                        if (newDay) _DaySeparator(m.createdAt),
                        _Bubble(message: m, mine: m.senderId == admin.uid),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (isMember)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Send a photo',
                    onPressed: _sending ? null : () => _sendPhoto(admin),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _send(admin),
                      decoration: InputDecoration(
                        hintText: 'Write a message…',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: WebTokens.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _sending ? null : () => _send(admin),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Send'),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: const Text(
                'Admin view — read only',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final DateTime date;
  const _DaySeparator(this.date);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: WebTokens.border),
          ),
          child: Text(DateFormat('EEEE, MMM d, yyyy').format(date),
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(
            color: mine ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: mine ? null : Border.all(color: WebTokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(m.senderName,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor)),
              if (m.type == MessageType.image && (m.imageUrl ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(m.imageUrl!,
                        width: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined)),
                  ),
                )
              else
                Text(m.text,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: mine ? Colors.white : AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(
                DateFormat('h:mm a').format(m.createdAt),
                style: TextStyle(
                    fontSize: 11,
                    color: mine
                        ? Colors.white.withValues(alpha: 0.75)
                        : AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Active users, used to pick group members.
Future<List<AppUser>> _activeUsers() async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .where('isActive', isEqualTo: true)
      .get();
  return snap.docs.map(AppUser.fromFirestore).toList()
    ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
}

const _roleOrder = ['client', 'family', 'caregiver', 'admin'];
const _roleLabels = {
  'client': 'Clients',
  'family': 'Family members',
  'caregiver': 'Caregivers',
  'admin': 'Admins',
};

class _GroupDialog extends StatefulWidget {
  final AppUser admin;
  const _GroupDialog({required this.admin});

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  final _name = TextEditingController();
  List<AppUser>? _users;
  final Set<String> _picked = {};
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _activeUsers().then((u) {
      if (mounted) {
        setState(() => _users = u.where((x) => x.uid != widget.admin.uid).toList());
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty || _picked.isEmpty) return;
    setState(() => _saving = true);
    try {
      final members = [
        widget.admin,
        ..._users!.where((u) => _picked.contains(u.uid)),
      ];
      final room = await ChatService().createGroupChat(
        groupName: _name.text.trim(),
        createdBy: widget.admin.uid,
        members: members,
      );
      if (mounted) {
        webToast(context, 'Group "${room.groupName}" created');
        Navigator.pop(context, room);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        webToast(context, 'Could not create group: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final users = (_users ?? [])
        .where((u) => q.isEmpty || u.fullName.toLowerCase().contains(q))
        .toList();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('New group'),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Group name'),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search people',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _users == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        for (final role in _roleOrder)
                          if (users.any((u) => u.role == role)) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                              child: Text(_roleLabels[role]!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary)),
                            ),
                            for (final u in users.where((u) => u.role == role))
                              CheckboxListTile(
                                dense: true,
                                value: _picked.contains(u.uid),
                                onChanged: (on) => setState(() => on == true
                                    ? _picked.add(u.uid)
                                    : _picked.remove(u.uid)),
                                title: Text(u.fullName),
                                subtitle: Text('@${u.username}'),
                              ),
                          ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        Text('${_picked.length} selected',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || _name.text.trim().isEmpty || _picked.isEmpty
              ? null
              : _create,
          child: const Text('Create group'),
        ),
      ],
    );
  }
}

class _MembersDialog extends StatefulWidget {
  final ChatRoom room;
  const _MembersDialog({required this.room});

  @override
  State<_MembersDialog> createState() => _MembersDialogState();
}

class _MembersDialogState extends State<_MembersDialog> {
  late final Set<String> _members = {...widget.room.participants};
  late final Map<String, String> _names = {...widget.room.participantNames};
  List<AppUser>? _users;
  AppUser? _toAdd;

  @override
  void initState() {
    super.initState();
    _activeUsers().then((u) {
      if (mounted) setState(() => _users = u);
    });
  }

  Future<void> _remove(String uid) async {
    final ok = await webConfirm(
      context,
      title: 'Remove ${_names[uid] ?? 'member'}?',
      message: 'They will no longer see or post in this group.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ChatService().removeGroupParticipant(widget.room.id, uid);
      setState(() => _members.remove(uid));
    } catch (e) {
      if (mounted) webToast(context, 'Could not remove: $e', error: true);
    }
  }

  Future<void> _add() async {
    final u = _toAdd;
    if (u == null) return;
    try {
      await ChatService().addGroupParticipant(widget.room.id, u);
      setState(() {
        _members.add(u.uid);
        _names[u.uid] = u.fullName;
        _toAdd = null;
      });
    } catch (e) {
      if (mounted) webToast(context, 'Could not add: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates =
        (_users ?? []).where((u) => !_members.contains(u.uid)).toList();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('${widget.room.groupName} · members'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AppUser>(
                    initialValue: _toAdd,
                    isExpanded: true,
                    hint: Text(_users == null ? 'Loading…' : 'Add a person'),
                    items: [
                      for (final u in candidates)
                        DropdownMenuItem(
                            value: u,
                            child: Text('${u.fullName} · ${u.role}')),
                    ],
                    onChanged: (v) => setState(() => _toAdd = v),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _toAdd == null ? null : _add,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final uid in _members)
                    ListTile(
                      dense: true,
                      leading: WebAvatar(name: _names[uid] ?? '?', size: 30),
                      title: Text(_names[uid] ?? uid),
                      trailing: TextButton(
                        onPressed: () => _remove(uid),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.errorColor),
                        child: const Text('Remove'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Pick one active person to message directly.
class _PersonPickerDialog extends StatefulWidget {
  final String adminId;
  const _PersonPickerDialog({required this.adminId});

  @override
  State<_PersonPickerDialog> createState() => _PersonPickerDialogState();
}

class _PersonPickerDialogState extends State<_PersonPickerDialog> {
  List<AppUser>? _users;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _activeUsers().then((u) {
      if (mounted) {
        setState(() => _users = u.where((x) => x.uid != widget.adminId).toList());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final users = (_users ?? [])
        .where((u) => q.isEmpty || u.fullName.toLowerCase().contains(q))
        .toList();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('New message'),
      content: SizedBox(
        width: 460,
        height: 480,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search people',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _users == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        for (final role in _roleOrder)
                          if (users.any((u) => u.role == role)) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                              child: Text(_roleLabels[role]!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary)),
                            ),
                            for (final u in users.where((u) => u.role == role))
                              ListTile(
                                dense: true,
                                leading: WebAvatar(
                                    name: u.fullName,
                                    photoUrl: u.photoUrl,
                                    size: 32),
                                title: Text(u.fullName),
                                subtitle: Text('@${u.username}'),
                                onTap: () => Navigator.pop(context, u),
                              ),
                          ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
