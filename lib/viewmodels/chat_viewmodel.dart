import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/app_user.dart';
import '../services/chat_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  ChatRoom? _chatRoom;
  ChatRoom? get chatRoom => _chatRoom;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMoreMessages = true;
  bool get hasMoreMessages => _hasMoreMessages;

  bool _isSending = false;
  bool get isSending => _isSending;

  bool _otherUserTyping = false;
  bool get otherUserTyping => _otherUserTyping;

  String? _error;
  String? get error => _error;

  StreamSubscription? _messagesSub;
  StreamSubscription? _chatRoomSub;
  Timer? _typingTimer;

  late String _currentUserId;
  late String _currentUserName;
  late String _otherUserId;
  late String _chatId;

  bool _readOnly = false;
  bool get isReadOnly => _readOnly;

  bool _isGroup = false;
  bool get isGroup => _isGroup;
  List<String> _groupParticipantIds = [];

  int _messageLimit = ChatService.messagesPerPage;

  /// Initialize chat between two users
  Future<void> init({
    required AppUser currentUser,
    required AppUser otherUser,
  }) async {
    _currentUserId = currentUser.uid;
    _currentUserName = currentUser.fullName;
    _otherUserId = otherUser.uid;
    _chatId = _chatService.getChatId(currentUser.uid, otherUser.uid);

    try {
      _chatRoom = await _chatService.getOrCreateChatRoom(
        currentUser: currentUser,
        otherUser: otherUser,
      );

      _listenToMessages();
      _listenToChatRoom();

      // Mark messages as read when opening chat
      await _chatService.markMessagesAsRead(_chatId, _currentUserId);
    } catch (e) {
      _error = 'Failed to load chat: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Initialize from an existing chat room (e.g., admin viewing a conversation)
  Future<void> initFromChatRoom({
    required ChatRoom chatRoom,
    required String currentUserId,
    required String currentUserName,
    bool readOnly = false,
  }) async {
    _currentUserId = currentUserId;
    _currentUserName = currentUserName;
    _chatRoom = chatRoom;
    _chatId = chatRoom.id;
    _readOnly = readOnly;

    if (chatRoom.isGroup) {
      _isGroup = true;
      _groupParticipantIds = chatRoom.participants;
      _otherUserId = '';
    } else {
      _otherUserId = chatRoom.getOtherParticipantId(currentUserId);
    }

    _listenToMessages();
    _listenToChatRoom();

    if (!_readOnly) {
      await _chatService.markMessagesAsRead(_chatId, _currentUserId);
    }
  }

  void _listenToMessages() {
    _messagesSub = _chatService
        .getMessagesStream(_chatId, limit: _messageLimit)
        .listen((msgs) {
      _messages = msgs;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = 'Failed to load messages: $e';
      _isLoading = false;
      notifyListeners();
    });
  }

  void _listenToChatRoom() {
    // A read-only observer (admin) is not a participant, so the
    // participants-filtered stream would never emit — listen to the doc.
    final stream = _readOnly
        ? _chatService.getChatRoomStream(_chatId)
        : _chatService
            .getChatRoomsStream(_currentUserId)
            .map((rooms) => rooms.where((r) => r.id == _chatId).firstOrNull);

    _chatRoomSub = stream.listen((room) {
      if (room != null) {
        _chatRoom = room;
        _otherUserTyping = room.isOtherTyping(_currentUserId);
        notifyListeners();
      }
    });
  }

  /// Load older messages (pagination)
  Future<void> loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final oldestMessage = _messages.last;
      final olderMessages = await _chatService.loadOlderMessages(
        _chatId,
        before: oldestMessage.createdAt,
      );

      if (olderMessages.isEmpty) {
        _hasMoreMessages = false;
      } else {
        _messages.addAll(olderMessages);
        _messageLimit += ChatService.messagesPerPage;
      }
    } catch (e) {
      _error = 'Failed to load older messages';
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Send a text message
  Future<void> sendMessage(String text) async {
    if (_readOnly || text.trim().isEmpty) return;

    _isSending = true;
    notifyListeners();

    try {
      if (_isGroup) {
        await _chatService.sendGroupMessage(
          chatId: _chatId,
          senderId: _currentUserId,
          senderName: _currentUserName,
          text: text.trim(),
          participantIds: _groupParticipantIds,
        );
      } else {
        await _chatService.sendMessage(
          chatId: _chatId,
          senderId: _currentUserId,
          senderName: _currentUserName,
          text: text.trim(),
          receiverId: _otherUserId,
        );
      }
    } catch (e) {
      _error = 'Failed to send message';
    }

    _isSending = false;
    notifyListeners();
  }

  /// Send an image message
  Future<void> sendImage(File imageFile) async {
    if (_readOnly) return;
    _isSending = true;
    notifyListeners();

    try {
      if (_isGroup) {
        await _chatService.sendGroupImageMessage(
          chatId: _chatId,
          senderId: _currentUserId,
          senderName: _currentUserName,
          participantIds: _groupParticipantIds,
          imageFile: imageFile,
        );
      } else {
        await _chatService.sendImageMessage(
          chatId: _chatId,
          senderId: _currentUserId,
          senderName: _currentUserName,
          receiverId: _otherUserId,
          imageFile: imageFile,
        );
      }
    } catch (e) {
      _error = 'Failed to send image';
    }

    _isSending = false;
    notifyListeners();
  }

  /// Handle typing indicator with debounce
  void onTypingChanged(String text) {
    if (text.isNotEmpty) {
      _chatService.setTyping(_chatId, _currentUserId, true);

      // Auto-stop typing after 3 seconds of no input
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chatService.setTyping(_chatId, _currentUserId, false);
      });
    } else {
      _typingTimer?.cancel();
      _chatService.setTyping(_chatId, _currentUserId, false);
    }
  }

  /// Mark messages as read (call when user views messages)
  Future<void> markAsRead() async {
    if (_readOnly) return;
    await _chatService.markMessagesAsRead(_chatId, _currentUserId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _chatRoomSub?.cancel();
    _typingTimer?.cancel();
    // Stop typing when leaving (observers never typed)
    if (!_readOnly) {
      _chatService.setTyping(_chatId, _currentUserId, false);
    }
    super.dispose();
  }
}
