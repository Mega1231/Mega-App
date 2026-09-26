import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image }

enum MessageStatus { sending, sent, read }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageUrl;
  final MessageType type;
  final MessageStatus status;
  final List<String> readBy;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.text = '',
    this.imageUrl,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.readBy = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      type: data['type'] == 'image' ? MessageType.image : MessageType.text,
      status: _parseStatus(data['status']),
      readBy: List<String>.from(data['readBy'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'type': type == MessageType.image ? 'image' : 'text',
      'status': status.name,
      'readBy': readBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static MessageStatus _parseStatus(String? status) {
    switch (status) {
      case 'sending':
        return MessageStatus.sending;
      case 'read':
        return MessageStatus.read;
      default:
        return MessageStatus.sent;
    }
  }

  bool isReadBy(String userId) => readBy.contains(userId);
}
