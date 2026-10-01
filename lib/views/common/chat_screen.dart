import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../models/chat_message.dart';
import '../../models/chat_room.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../widgets/user_avatar.dart';
import '../../services/agora_call_service.dart';
import '../../services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final AppUser currentUser;
  final AppUser? otherUser;
  final ChatRoom? readOnlyChatRoom;
  final ChatRoom? groupChatRoom;

  const ChatScreen({
    super.key,
    required this.currentUser,
    this.otherUser,
    this.readOnlyChatRoom,
    this.groupChatRoom,
  }) : assert(otherUser != null ||
            readOnlyChatRoom != null ||
            groupChatRoom != null);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  late ChatViewModel _viewModel;

  bool get _isReadOnly => widget.readOnlyChatRoom != null;
  bool get _isGroup => widget.groupChatRoom != null;
  bool get _isAdmin => widget.currentUser.role == 'admin';

  Future<void> _toggleGroupMessaging(ChatRoom room) async {
    final disable = !room.messagingDisabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(disable ? 'Disable messaging?' : 'Enable messaging?'),
        content: Text(disable
            ? 'Members of "${room.groupName}" will no longer be able to send messages. Admins can still post.'
            : 'Members of "${room.groupName}" will be able to send messages again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(disable ? 'Disable' : 'Enable'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ChatService().setGroupMessagingDisabled(room.id, disable);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update group: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _messagingToggleAction() {
    return Consumer<ChatViewModel>(
      builder: (_, vm, _) {
        final room =
            vm.chatRoom ?? widget.groupChatRoom ?? widget.readOnlyChatRoom!;
        final disabled = room.messagingDisabled;
        return IconButton(
          icon: Icon(disabled ? Icons.speaker_notes_off : Icons.speaker_notes),
          tooltip: disabled ? 'Enable messaging' : 'Disable messaging',
          onPressed: () => _toggleGroupMessaging(room),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = ChatViewModel();
    if (_isReadOnly) {
      _viewModel.initFromChatRoom(
        chatRoom: widget.readOnlyChatRoom!,
        currentUserId: widget.currentUser.uid,
        currentUserName: widget.currentUser.fullName,
        readOnly: true,
      );
    } else if (_isGroup) {
      _viewModel.initFromChatRoom(
        chatRoom: widget.groupChatRoom!,
        currentUserId: widget.currentUser.uid,
        currentUserName: widget.currentUser.fullName,
      );
    } else {
      _viewModel.init(
        currentUser: widget.currentUser,
        otherUser: widget.otherUser!,
      );
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _viewModel.markAsRead();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _viewModel.loadMoreMessages();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showGroupMembersSheet() {
    if (!_isGroup) return;
    final chatRoom = _viewModel.chatRoom ?? widget.groupChatRoom!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _GroupMembersSheet(
        chatRoom: chatRoom,
        currentUser: widget.currentUser,
        onMemberAdded: () {
          _viewModel.initFromChatRoom(
            chatRoom: chatRoom,
            currentUserId: widget.currentUser.uid,
            currentUserName: widget.currentUser.fullName,
          );
        },
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    _viewModel.sendMessage(text);
    _messageController.clear();
  }

  Future<void> _pickAndSendImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (picked != null) {
      _viewModel.sendImage(File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (_isReadOnly) _buildReadOnlyBanner(),
            Expanded(child: _buildMessageList()),
            if (!_isReadOnly && !_isGroup) _buildTypingIndicator(),
            if (_isGroup) _buildGroupTypingIndicator(),
            if (!_isReadOnly && !_isGroup) _buildInputBar(),
            if (_isGroup)
              Consumer<ChatViewModel>(
                builder: (_, vm, _) {
                  final disabled = (vm.chatRoom ?? widget.groupChatRoom!)
                      .messagingDisabled;
                  if (!disabled) return _buildInputBar();
                  if (!_isAdmin) return _buildMessagingDisabledBanner();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMessagingDisabledBanner(adminView: true),
                      _buildInputBar(),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTypingIndicator() {
    return Consumer<ChatViewModel>(
      builder: (_, vm, __) {
        if (vm.chatRoom == null ||
            !vm.chatRoom!.isOtherTyping(widget.currentUser.uid)) {
          return const SizedBox.shrink();
        }
        final name = vm.chatRoom!.getTypingName(widget.currentUser.uid);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          alignment: Alignment.centerLeft,
          color: Colors.white,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                child: _TypingDots(color: AppTheme.successColor),
              ),
              const SizedBox(width: 8),
              Text(
                '$name is typing...',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isGroup) {
      final groupChat = widget.groupChatRoom!;
      final memberCount = groupChat.participants.length;
      return AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.group, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(groupChat.groupName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '$memberCount members',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isAdmin) _messagingToggleAction(),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.group_add),
              tooltip: 'Manage members',
              onPressed: () => _showGroupMembersSheet(),
            ),
        ],
      );
    }

    if (_isReadOnly) {
      final names = widget.readOnlyChatRoom!.participantNames.values.toList();
      return AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(names.join(' & '),
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis),
            Text(
              'Viewing conversation',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          if (_isAdmin && widget.readOnlyChatRoom!.isGroup)
            _messagingToggleAction(),
        ],
      );
    }

    return AppBar(
      title: Row(
        children: [
          UserAvatar(
            userId: widget.otherUser!.uid,
            name: widget.otherUser!.fullName,
            photoUrl: widget.otherUser!.photoUrl,
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            textColor: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUser!.fullName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Consumer<ChatViewModel>(
                  builder: (_, vm, child) => Text(
                    vm.otherUserTyping ? 'typing...' : widget.otherUser!.role,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: vm.otherUserTyping
                          ? Colors.greenAccent
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                currentUser: widget.currentUser,
                otherUser: widget.otherUser!,
                callType: CallType.audio,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.videocam_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                currentUser: widget.currentUser,
                otherUser: widget.otherUser!,
                callType: CallType.video,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chat_bubble_outline,
                      size: 48,
                      color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No messages yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Send a message to start the conversation',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary.withValues(alpha: 0.8)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          reverse: true,
          itemCount: vm.messages.length + (vm.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == vm.messages.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final message = vm.messages[index];
            final isSent = _isReadOnly
                ? false
                : message.senderId == widget.currentUser.uid;
            final showDate = _shouldShowDate(vm.messages, index);

            // Check if next message is from same sender (for grouping)
            final showTail = index == 0 ||
                vm.messages[index - 1].senderId != message.senderId;

            return Column(
              children: [
                if (showDate) _buildDateSeparator(message.createdAt),
                _buildMessageBubble(message, isSent, showTail),
              ],
            );
          },
        );
      },
    );
  }

  bool _shouldShowDate(List<ChatMessage> messages, int index) {
    if (index == messages.length - 1) return true;
    final current = messages[index].createdAt;
    final next = messages[index + 1].createdAt;
    return current.day != next.day ||
        current.month != next.month ||
        current.year != next.year;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isSent, bool showTail) {
    final showSenderLabel = _isReadOnly ||
        (_isGroup && message.senderId != widget.currentUser.uid);

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: showTail ? 8 : 2,
          left: isSent ? 48 : 0,
          right: isSent ? 0 : 48,
        ),
        decoration: BoxDecoration(
          color: isSent ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isSent || !showTail ? 18 : 4),
            bottomRight: Radius.circular(!isSent || !showTail ? 18 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isSent || !showTail ? 18 : 4),
            bottomRight: Radius.circular(!isSent || !showTail ? 18 : 4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSenderLabel) _buildGroupSenderLabel(message),
              if (message.type == MessageType.image &&
                  message.imageUrl != null)
                GestureDetector(
                  onTap: () => _showFullImage(message.imageUrl!),
                  child: ClipRRect(
                    borderRadius: showSenderLabel
                        ? BorderRadius.zero
                        : const BorderRadius.vertical(
                            top: Radius.circular(18)),
                    child: Image.network(
                      message.imageUrl!,
                      width: 240,
                      height: 240,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 240,
                          height: 240,
                          color: Colors.grey.withValues(alpha: 0.1),
                          child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                    ),
                  ),
                ),
              if (message.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    showSenderLabel ? 4 : 10,
                    14,
                    2,
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: isSent ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
              // Timestamp + read receipt
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 10, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSent
                            ? Colors.white.withValues(alpha: 0.6)
                            : AppTheme.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                    if (isSent) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.readBy.length > 1
                            ? Icons.done_all
                            : Icons.done,
                        size: 14,
                        color: message.readBy.length > 1
                            ? const Color(0xFF53BDEB)
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSenderLabel(ChatMessage message) {
    final chatRoom =
        widget.readOnlyChatRoom ?? widget.groupChatRoom ?? _viewModel.chatRoom;
    final role = chatRoom?.participantRoles[message.senderId] ?? '';
    final roleLabel =
        role.isNotEmpty ? role[0].toUpperCase() + role.substring(1) : '';

    const colors = [
      AppTheme.primaryColor,
      AppTheme.successColor,
      Color(0xFFE67E22),
      Color(0xFF9B59B6),
      Color(0xFFE74C3C),
      Color(0xFF1ABC9C),
    ];
    final participantIndex =
        chatRoom?.participants.indexOf(message.senderId) ?? 0;
    final color = colors[participantIndex % colors.length];

    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.senderName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (roleLabel.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.warningColor.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility_outlined,
              size: 16,
              color: AppTheme.warningColor.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            'Admin view — read only',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.warningColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagingDisabledBanner({bool adminView = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: AppTheme.errorColor.withValues(alpha: 0.06),
      child: SafeArea(
        top: false,
        bottom: !adminView,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.speaker_notes_off,
                size: 16, color: AppTheme.errorColor.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                adminView
                    ? 'Messaging is disabled for members — only admins can post'
                    : 'Messaging has been disabled by admin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.errorColor.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Consumer<ChatViewModel>(
      builder: (_, vm, child) {
        if (!vm.otherUserTyping) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          alignment: Alignment.centerLeft,
          color: Colors.white,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                child: _TypingDots(color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.otherUser!.fullName} is typing...',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton(
                icon: Icon(Icons.add_circle_outline,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                    size: 26),
                onPressed: _pickAndSendImage,
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  onChanged: (text) => _viewModel.onTypingChanged(text),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  minLines: 1,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Consumer<ChatViewModel>(
                builder: (_, vm, child) => GestureDetector(
                  onTap: vm.isSending ? null : _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: vm.isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Typing Dots Animation
// ─────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final bounce = (t < 0.5) ? t * 2 : (1 - t) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.3 + bounce * 0.7),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────
// Group Members Sheet
// ─────────────────────────────────────────────────

class _GroupMembersSheet extends StatefulWidget {
  final ChatRoom chatRoom;
  final AppUser currentUser;
  final VoidCallback onMemberAdded;

  const _GroupMembersSheet({
    required this.chatRoom,
    required this.currentUser,
    required this.onMemberAdded,
  });

  @override
  State<_GroupMembersSheet> createState() => _GroupMembersSheetState();
}

class _GroupMembersSheetState extends State<_GroupMembersSheet> {
  final _chatService = ChatService();
  bool _showAddMember = false;

  Future<void> _removeMember(String userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member'),
        content: Text('Remove $name from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Remove', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _chatService.removeGroupParticipant(widget.chatRoom.id, userId);
    widget.onMemberAdded();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _addMember(AppUser user) async {
    await _chatService.addGroupParticipant(widget.chatRoom.id, user);
    widget.onMemberAdded();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Color _memberRoleColor(String role) {
    switch (role) {
      case 'caregiver':
        return AppTheme.successColor;
      case 'client':
        return AppTheme.primaryColor;
      case 'family':
        return const Color(0xFFE67E22);
      case 'admin':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.chatRoom.participants;
    final names = widget.chatRoom.participantNames;
    final roles = widget.chatRoom.participantRoles;
    final photos = widget.chatRoom.participantPhotos;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
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
                    Text(
                      _showAddMember
                          ? 'Add Member'
                          : 'Members (${members.length})',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (!_showAddMember)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showAddMember = true),
                        icon: const Icon(Icons.person_add_outlined, size: 18),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    if (_showAddMember)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showAddMember = false),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back'),
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
              const SizedBox(height: 8),
              Divider(height: 1, color: Colors.grey.withValues(alpha: 0.12)),

              if (_showAddMember)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('isActive', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final users = snapshot.data!.docs
                          .map((doc) => AppUser.fromFirestore(doc))
                          .where((u) => !members.contains(u.uid))
                          .toList();

                      if (users.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 48,
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              const Text('No users to add',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            leading: UserAvatar(
                              userId: user.uid,
                              name: user.fullName,
                              photoUrl: user.photoUrl,
                            ),
                            title: Text(user.fullName,
                                style:
                                    const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              user.role[0].toUpperCase() +
                                  user.role.substring(1),
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.successColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.add,
                                    color: AppTheme.successColor, size: 20),
                                onPressed: () => _addMember(user),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 72,
                      color: Colors.grey.withValues(alpha: 0.1),
                    ),
                    itemBuilder: (_, index) {
                      final uid = members[index];
                      final name = names[uid] ?? 'Unknown';
                      final role = roles[uid] ?? '';
                      final photo = photos[uid] ?? '';
                      final isCurrentUser = uid == widget.currentUser.uid;
                      final isCreator = uid == widget.chatRoom.createdBy;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        leading: UserAvatar(
                          userId: uid,
                          name: name,
                          photoUrl: photo,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                            ),
                            if (isCurrentUser)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            if (isCreator)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _memberRoleColor(role)
                                    .withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                role.isNotEmpty
                                    ? role[0].toUpperCase() +
                                        role.substring(1)
                                    : '',
                                style: TextStyle(
                                  color: _memberRoleColor(role),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: !isCurrentUser && !isCreator
                            ? Container(
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.errorColor.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.remove,
                                      color: AppTheme.errorColor, size: 20),
                                  onPressed: () => _removeMember(uid, name),
                                ),
                              )
                            : null,
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
