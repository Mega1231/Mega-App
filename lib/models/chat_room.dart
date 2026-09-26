import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantPhotos;
  final Map<String, String> participantRoles;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final String lastMessageType;
  final Map<String, int> unreadCount;
  final Map<String, bool> typing;
  final DateTime createdAt;
  final bool isGroup;
  final String groupName;
  final String createdBy;

  ChatRoom({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.participantPhotos = const {},
    this.participantRoles = const {},
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastMessageSenderId = '',
    this.lastMessageType = 'text',
    this.unreadCount = const {},
    this.typing = const {},
    this.isGroup = false,
    this.groupName = '',
    this.createdBy = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantPhotos: Map<String, String>.from(data['participantPhotos'] ?? {}),
      participantRoles: Map<String, String>.from(data['participantRoles'] ?? {}),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      lastMessageType: data['lastMessageType'] ?? 'text',
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      typing: Map<String, bool>.from(data['typing'] ?? {}),
      isGroup: data['isGroup'] ?? false,
      groupName: data['groupName'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'participantRoles': participantRoles,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageType': lastMessageType,
      'unreadCount': unreadCount,
      'typing': typing,
      'isGroup': isGroup,
      if (groupName.isNotEmpty) 'groupName': groupName,
      if (createdBy.isNotEmpty) 'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Get the other participant's name for display
  String getOtherParticipantName(String currentUserId) {
    for (final entry in participantNames.entries) {
      if (entry.key != currentUserId) return entry.value;
    }
    return 'Unknown';
  }

  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  String getOtherParticipantPhoto(String currentUserId) {
    final otherId = getOtherParticipantId(currentUserId);
    return participantPhotos[otherId] ?? '';
  }

  String getOtherParticipantRole(String currentUserId) {
    final otherId = getOtherParticipantId(currentUserId);
    return participantRoles[otherId] ?? '';
  }

  int getUnreadCount(String userId) => unreadCount[userId] ?? 0;

  bool isOtherTyping(String currentUserId) {
    if (isGroup) {
      return typing.entries
          .any((e) => e.key != currentUserId && e.value == true);
    }
    final otherId = getOtherParticipantId(currentUserId);
    return typing[otherId] ?? false;
  }

  /// For group chats: get who is typing
  String getTypingName(String currentUserId) {
    for (final entry in typing.entries) {
      if (entry.key != currentUserId && entry.value == true) {
        return participantNames[entry.key] ?? 'Someone';
      }
    }
    return '';
  }

  /// Display name: group name for groups, other participant name for 1:1
  String getDisplayName(String currentUserId) {
    if (isGroup) return groupName;
    return getOtherParticipantName(currentUserId);
  }
}
