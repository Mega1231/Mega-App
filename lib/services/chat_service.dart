import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../models/app_user.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int messagesPerPage = 25;

  /// Generate a consistent chat ID for two participants
  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Get or create a chat room between two users
  Future<ChatRoom> getOrCreateChatRoom({
    required AppUser currentUser,
    required AppUser otherUser,
  }) async {
    final chatId = getChatId(currentUser.uid, otherUser.uid);
    final docRef = _firestore.collection('chats').doc(chatId);
    final doc = await docRef.get();

    if (doc.exists) {
      return ChatRoom.fromFirestore(doc);
    }

    // Create new chat room
    final chatRoom = ChatRoom(
      id: chatId,
      participants: [currentUser.uid, otherUser.uid],
      participantNames: {
        currentUser.uid: currentUser.fullName,
        otherUser.uid: otherUser.fullName,
      },
      participantPhotos: {
        currentUser.uid: currentUser.photoUrl,
        otherUser.uid: otherUser.photoUrl,
      },
      participantRoles: {
        currentUser.uid: currentUser.role,
        otherUser.uid: otherUser.role,
      },
      unreadCount: {
        currentUser.uid: 0,
        otherUser.uid: 0,
      },
      typing: {
        currentUser.uid: false,
        otherUser.uid: false,
      },
    );

    await docRef.set(chatRoom.toMap());
    return chatRoom;
  }

  /// Stream chat rooms for a user (real-time updates)
  Stream<List<ChatRoom>> getChatRoomsStream(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList());
  }

  /// Stream a single chat room by ID (works even if user is not a participant)
  Stream<ChatRoom?> getChatRoomStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.exists ? ChatRoom.fromFirestore(doc) : null);
  }

  /// Stream ALL chat rooms (for admin oversight)
  Stream<List<ChatRoom>> getAllChatRoomsStream() {
    return _firestore
        .collection('chats')
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList());
  }

  /// Stream messages for a chat room (real-time, paginated)
  Stream<List<ChatMessage>> getMessagesStream(String chatId, {int limit = messagesPerPage}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }

  /// Load older messages for pagination
  Future<List<ChatMessage>> loadOlderMessages(
    String chatId, {
    required DateTime before,
    int limit = messagesPerPage,
  }) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
  }

  /// Send a text message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    required String receiverId,
  }) async {
    final batch = _firestore.batch();

    // Add message to subcollection
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final message = ChatMessage(
      id: messageRef.id,
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: MessageType.text,
      status: MessageStatus.sent,
      readBy: [senderId],
      createdAt: DateTime.now(),
    );

    batch.set(messageRef, message.toMap());

    // Update chat room metadata (saves reads on chat list)
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageTime': Timestamp.fromDate(message.createdAt),
      'lastMessageSenderId': senderId,
      'lastMessageType': 'text',
      'unreadCount.$receiverId': FieldValue.increment(1),
      'typing.$senderId': false,
    });

    await batch.commit();

    // Send push notification to receiver
    NotificationService().sendPushNotification(
      receiverId: receiverId,
      type: 'message',
      chatId: chatId,
    );
  }

  /// Send an image message
  Future<void> sendImageMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String receiverId,
    required File imageFile,
  }) async {
    // Upload image to Firebase Storage
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage
        .ref()
        .child('chat_images/$chatId/${senderId}_$timestamp.jpg');
    await ref.putFile(imageFile);
    final imageUrl = await ref.getDownloadURL();

    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final message = ChatMessage(
      id: messageRef.id,
      senderId: senderId,
      senderName: senderName,
      text: '',
      imageUrl: imageUrl,
      type: MessageType.image,
      status: MessageStatus.sent,
      readBy: [senderId],
      createdAt: DateTime.now(),
    );

    batch.set(messageRef, message.toMap());

    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': '📷 Photo',
      'lastMessageTime': Timestamp.fromDate(message.createdAt),
      'lastMessageSenderId': senderId,
      'lastMessageType': 'image',
      'unreadCount.$receiverId': FieldValue.increment(1),
      'typing.$senderId': false,
    });

    await batch.commit();

    // Send push notification to receiver
    NotificationService().sendPushNotification(
      receiverId: receiverId,
      type: 'message',
      chatId: chatId,
    );
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    // Reset unread count for this user
    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount.$userId': 0,
    });

    // Mark recent unread messages as read (batch for cost efficiency)
    final unreadMessages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('readBy', whereNotIn: [[userId]])
        .orderBy('readBy')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    if (unreadMessages.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(userId)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId]),
          'status': 'read',
        });
      }
    }
    await batch.commit();
  }

  /// Set typing indicator
  Future<void> setTyping(String chatId, String userId, bool isTyping) async {
    await _firestore.collection('chats').doc(chatId).update({
      'typing.$userId': isTyping,
    });
  }

  /// Get total unread count for a user across all chats
  Stream<int> getTotalUnreadCount(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
        if (unreadCount != null) {
          total += (unreadCount[userId] as int?) ?? 0;
        }
      }
      return total;
    });
  }

  /// Create a group chat
  Future<ChatRoom> createGroupChat({
    required String groupName,
    required String createdBy,
    required List<AppUser> members,
  }) async {
    final docRef = _firestore.collection('chats').doc();

    final participantIds = members.map((m) => m.uid).toList();
    final participantNames = <String, String>{};
    final participantPhotos = <String, String>{};
    final participantRoles = <String, String>{};
    final unreadCount = <String, int>{};
    final typing = <String, bool>{};

    for (final m in members) {
      participantNames[m.uid] = m.fullName;
      participantPhotos[m.uid] = m.photoUrl;
      participantRoles[m.uid] = m.role;
      unreadCount[m.uid] = 0;
      typing[m.uid] = false;
    }

    final chatRoom = ChatRoom(
      id: docRef.id,
      participants: participantIds,
      participantNames: participantNames,
      participantPhotos: participantPhotos,
      participantRoles: participantRoles,
      unreadCount: unreadCount,
      typing: typing,
      isGroup: true,
      groupName: groupName,
      createdBy: createdBy,
    );

    await docRef.set(chatRoom.toMap());
    return chatRoom;
  }

  /// Add a participant to a group chat
  Future<void> addGroupParticipant(String chatId, AppUser user) async {
    await _firestore.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayUnion([user.uid]),
      'participantNames.${user.uid}': user.fullName,
      'participantPhotos.${user.uid}': user.photoUrl,
      'participantRoles.${user.uid}': user.role,
      'unreadCount.${user.uid}': 0,
      'typing.${user.uid}': false,
    });
  }

  /// Remove a participant from a group chat
  Future<void> removeGroupParticipant(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayRemove([userId]),
      'participantNames.$userId': FieldValue.delete(),
      'participantPhotos.$userId': FieldValue.delete(),
      'participantRoles.$userId': FieldValue.delete(),
      'unreadCount.$userId': FieldValue.delete(),
      'typing.$userId': FieldValue.delete(),
    });
  }

  /// Send a message to a group chat
  Future<void> sendGroupMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    required List<String> participantIds,
  }) async {
    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final message = ChatMessage(
      id: messageRef.id,
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: MessageType.text,
      status: MessageStatus.sent,
      readBy: [senderId],
      createdAt: DateTime.now(),
    );

    batch.set(messageRef, message.toMap());

    final chatRef = _firestore.collection('chats').doc(chatId);
    final updates = <String, dynamic>{
      'lastMessage': text,
      'lastMessageTime': Timestamp.fromDate(message.createdAt),
      'lastMessageSenderId': senderId,
      'lastMessageType': 'text',
      'typing.$senderId': false,
    };

    // Increment unread for all other participants
    for (final pid in participantIds) {
      if (pid != senderId) {
        updates['unreadCount.$pid'] = FieldValue.increment(1);
      }
    }

    batch.update(chatRef, updates);
    await batch.commit();

    // Send push notifications to all other participants
    for (final pid in participantIds) {
      if (pid != senderId) {
        NotificationService().sendPushNotification(
          receiverId: pid,
          type: 'message',
          chatId: chatId,
        );
      }
    }
  }

  /// Send an image to a group chat
  Future<void> sendGroupImageMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required List<String> participantIds,
    required File imageFile,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage
        .ref()
        .child('chat_images/$chatId/${senderId}_$timestamp.jpg');
    await ref.putFile(imageFile);
    final imageUrl = await ref.getDownloadURL();

    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final message = ChatMessage(
      id: messageRef.id,
      senderId: senderId,
      senderName: senderName,
      text: '',
      imageUrl: imageUrl,
      type: MessageType.image,
      status: MessageStatus.sent,
      readBy: [senderId],
      createdAt: DateTime.now(),
    );

    batch.set(messageRef, message.toMap());

    final chatRef = _firestore.collection('chats').doc(chatId);
    final updates = <String, dynamic>{
      'lastMessage': '📷 Photo',
      'lastMessageTime': Timestamp.fromDate(message.createdAt),
      'lastMessageSenderId': senderId,
      'lastMessageType': 'image',
      'typing.$senderId': false,
    };

    for (final pid in participantIds) {
      if (pid != senderId) {
        updates['unreadCount.$pid'] = FieldValue.increment(1);
      }
    }

    batch.update(chatRef, updates);
    await batch.commit();

    for (final pid in participantIds) {
      if (pid != senderId) {
        NotificationService().sendPushNotification(
          receiverId: pid,
          type: 'message',
          chatId: chatId,
        );
      }
    }
  }

  /// Delete a chat room (admin only)
  Future<void> deleteChatRoom(String chatId) async {
    // Delete all messages in subcollection
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection('chats').doc(chatId));
    await batch.commit();
  }
}
