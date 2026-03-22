import 'package:cloud_firestore/cloud_firestore.dart';

/// App user profile – extended data stored in Firestore.
/// Auth identity (email, password) is in Firebase Auth; this model holds
/// profile-only fields. Do not store password_hash – Firebase Auth handles passwords.
class UserProfileModel {
  /// Same as Firebase Auth UID (document id in `users` collection).
  final String id;
  final String email;
  final String username;
  final String? profileImageUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  UserProfileModel({
    required this.id,
    required this.email,
    required this.username,
    this.profileImageUrl,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  factory UserProfileModel.fromMap(Map<String, dynamic> data, String documentId) {
    final createdRaw = data['created_at'];
    final updatedRaw = data['updated_at'];
    final lastLoginRaw = data['last_login_at'];

    DateTime created = DateTime.now();
    if (createdRaw != null) {
      if (createdRaw is Timestamp) {
        created = createdRaw.toDate();
      } else if (createdRaw is String) {
        created = DateTime.tryParse(createdRaw) ?? DateTime.now();
      }
    }

    DateTime updated = DateTime.now();
    if (updatedRaw != null) {
      if (updatedRaw is Timestamp) {
        updated = updatedRaw.toDate();
      } else if (updatedRaw is String) {
        updated = DateTime.tryParse(updatedRaw) ?? DateTime.now();
      }
    }

    DateTime? lastLogin;
    if (lastLoginRaw != null) {
      if (lastLoginRaw is Timestamp) {
        lastLogin = lastLoginRaw.toDate();
      } else if (lastLoginRaw is String) {
        lastLogin = DateTime.tryParse(lastLoginRaw);
      }
    }

    return UserProfileModel(
      id: documentId,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      profileImageUrl: data['profile_image_url'],
      bio: data['bio'],
      createdAt: created,
      updatedAt: updated,
      lastLoginAt: lastLogin,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'profile_image_url': profileImageUrl,
      'bio': bio,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      if (lastLoginAt != null) 'last_login_at': Timestamp.fromDate(lastLoginAt!),
    };
  }

  UserProfileModel copyWith({
    String? id,
    String? email,
    String? username,
    String? profileImageUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
