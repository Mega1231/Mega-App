import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_room.dart';
import '../models/app_user.dart';
import '../services/chat_service.dart';

class ChatListViewModel extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<ChatRoom> _chatRooms = [];
  List<ChatRoom> get chatRooms => _chatRooms;

  int _totalUnread = 0;
  int get totalUnread => _totalUnread;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  StreamSubscription? _chatRoomsSub;
  StreamSubscription? _unreadSub;

  String? _currentUserId;
  bool _isAdmin = false;

  void init(AppUser user) {
    _currentUserId = user.uid;
    _isAdmin = user.role == 'admin';
    _listenToChatRooms();
    _listenToUnreadCount();
  }

  void _listenToChatRooms() {
    final stream = _isAdmin
        ? _chatService.getAllChatRoomsStream()
        : _chatService.getChatRoomsStream(_currentUserId!);

    _chatRoomsSub = stream.listen((rooms) {
      _chatRooms = rooms;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _isLoading = false;
      notifyListeners();
    });
  }

  void _listenToUnreadCount() {
    if (_currentUserId == null) return;
    _unreadSub = _chatService.getTotalUnreadCount(_currentUserId!).listen((count) {
      _totalUnread = count;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _chatRoomsSub?.cancel();
    _unreadSub?.cancel();
    super.dispose();
  }
}
