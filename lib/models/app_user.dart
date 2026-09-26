import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String username;
  final String fullName;
  final String role; // 'admin', 'caregiver', 'client', 'family'
  final String phone;
  final String address;
  final double? latitude;
  final double? longitude;
  final String emergencyContact;
  final String photoUrl;
  final String clientNoteUrl;
  final String clientNoteFileName;
  final bool isActive;
  final DateTime createdAt;
  final String linkedClientId; // for family members → points to client uid
  final List<String> familyMemberIds; // for clients → list of family member uids

  AppUser({
    required this.uid,
    required this.username,
    required this.fullName,
    required this.role,
    this.phone = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.emergencyContact = '',
    this.photoUrl = '',
    this.clientNoteUrl = '',
    this.clientNoteFileName = '',
    this.isActive = true,
    this.linkedClientId = '',
    this.familyMemberIds = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isFamily => role == 'family';

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      username: data['username'] ?? '',
      fullName: data['fullName'] ?? '',
      role: data['role'] ?? 'client',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      emergencyContact: data['emergencyContact'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      clientNoteUrl: data['clientNoteUrl'] ?? '',
      clientNoteFileName: data['clientNoteFileName'] ?? '',
      isActive: data['isActive'] ?? true,
      linkedClientId: data['linkedClientId'] ?? '',
      familyMemberIds: List<String>.from(data['familyMemberIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'fullName': fullName,
      'role': role,
      'phone': phone,
      'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'emergencyContact': emergencyContact,
      'photoUrl': photoUrl,
      if (clientNoteUrl.isNotEmpty) 'clientNoteUrl': clientNoteUrl,
      if (clientNoteFileName.isNotEmpty) 'clientNoteFileName': clientNoteFileName,
      'isActive': isActive,
      if (linkedClientId.isNotEmpty) 'linkedClientId': linkedClientId,
      if (familyMemberIds.isNotEmpty) 'familyMemberIds': familyMemberIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
