// amigos_modelos.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/xp_service.dart';

// ═══════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════
enum FriendStatus { online, away, playing, reading, offline }
enum FriendFilter { all, online, offline, favorites, recent }
enum MessageStatus { sending, sent, delivered, read }

// ═══════════════════════════════════════════════════════════════════
// EXTENSÃO DE STATUS
// ═══════════════════════════════════════════════════════════════════
extension FriendStatusExt on FriendStatus {
  String get label {
    switch (this) {
      case FriendStatus.online:  return 'Online';
      case FriendStatus.away:    return 'Ausente';
      case FriendStatus.playing: return 'Jogando';
      case FriendStatus.reading: return 'Lendo notícias';
      case FriendStatus.offline: return 'Offline';
    }
  }

  Color get color {
    switch (this) {
      case FriendStatus.online:  return const Color(0xFF43B581);
      case FriendStatus.away:    return const Color(0xFFFAA61A);
      case FriendStatus.playing: return const Color(0xFF7289DA);
      case FriendStatus.reading: return const Color(0xFFFF6B00);
      case FriendStatus.offline: return const Color(0xFF747F8D);
    }
  }

  IconData get icon {
    switch (this) {
      case FriendStatus.online:  return Icons.circle;
      case FriendStatus.away:    return Icons.access_time_rounded;
      case FriendStatus.playing: return Icons.sports_esports_rounded;
      case FriendStatus.reading: return Icons.article_rounded;
      case FriendStatus.offline: return Icons.circle_outlined;
    }
  }

  static FriendStatus fromString(String? value) {
    switch (value) {
      case 'online':  return FriendStatus.online;
      case 'away':    return FriendStatus.away;
      case 'playing': return FriendStatus.playing;
      case 'reading': return FriendStatus.reading;
      default:        return FriendStatus.offline;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODELO DE AMIGO
// ═══════════════════════════════════════════════════════════════════
class FriendModel {
  final String uid;
  final String username;
  final String displayName;
  final String avatarId;
  final int level;
  final int totalXp;
  final int xpForNextLevel;
  final FriendStatus status;
  final DateTime? lastActivity;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final MessageStatus? lastMessageStatus;
  final int unreadCount;
  final bool isFavorite;
  final bool isTyping;
  final List<String> achievements;
  final int rank;
  final String? chatId;

  const FriendModel({
    required this.uid,
    required this.username,
    required this.displayName,
    this.avatarId = 'animais_01',
    required this.level,
    required this.totalXp,
    required this.xpForNextLevel,
    required this.status,
    this.lastActivity,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.lastMessageStatus,
    this.unreadCount = 0,
    this.isFavorite = false,
    this.isTyping = false,
    this.achievements = const [],
    this.rank = 0,
    this.chatId,
  });

  bool get isOnline => status != FriendStatus.offline;

  double get xpProgress {
    final xpAtThisLevel = XpService.xpRequiredForLevel(level);
    final xpAtNextLevel = XpService.xpRequiredForLevel(level + 1);
    final needed = xpAtNextLevel - xpAtThisLevel;
    if (needed <= 0) return 1.0;
    final current = totalXp - xpAtThisLevel;
    return (current / needed).clamp(0.0, 1.0);
  }

  FriendModel copyWith({
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    MessageStatus? lastMessageStatus,
    int? unreadCount,
    bool? isTyping,
    String? chatId,
    bool? isFavorite,
    FriendStatus? status,
    String? avatarId,
  }) {
    return FriendModel(
      uid: uid,
      username: username,
      displayName: displayName,
      avatarId: avatarId ?? this.avatarId,
      level: level,
      totalXp: totalXp,
      xpForNextLevel: xpForNextLevel,
      status: status ?? this.status,
      lastActivity: lastActivity,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      unreadCount: unreadCount ?? this.unreadCount,
      isFavorite: isFavorite ?? this.isFavorite,
      isTyping: isTyping ?? this.isTyping,
      achievements: achievements,
      rank: rank,
      chatId: chatId ?? this.chatId,
    );
  }

  factory FriendModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final last = (d['lastActivity'] as Timestamp?)?.toDate();
    final statusStr = d['status'] as String?;
    final status = FriendStatusExt.fromString(statusStr);
    final lvl    = (d['level']   as num?)?.toInt() ?? 1;
    final xp     = (d['totalXp'] as num?)?.toInt() ?? 0;
    final nextXp = XpService.xpRequiredForLevel(lvl + 1);

    return FriendModel(
      uid:            doc.id,
      username:       (d['username']    as String?) ?? '',
      displayName:    (d['displayName'] as String?) ?? 'Usuário',
      avatarId:       (d['avatarId']    as String?) ?? 'animais_01',
      level:          lvl,
      totalXp:        xp,
      xpForNextLevel: nextXp,
      status:         status,
      lastActivity:   last,
      unreadCount:    (d['unreadCount'] as num?)?.toInt() ?? 0,
      isFavorite:     (d['isFavorite']  as bool?)   ?? false,
      isTyping:       (d['isTyping']    as bool?)   ?? false,
      achievements:   List<String>.from(d['achievements'] ?? []),
      rank:           (d['rank']        as num?)?.toInt() ?? 0,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODELO DE SOLICITAÇÃO DE AMIZADE
// ═══════════════════════════════════════════════════════════════════
class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String status; // 'pending' | 'accepted' | 'declined'
  final DateTime? sentAt;
  final DateTime? acceptedAt;

  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    this.sentAt,
    this.acceptedAt,
  });

  factory FriendRequest.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      id:          doc.id,
      fromUid:     (d['fromUid']  as String?) ?? '',
      toUid:       (d['toUid']    as String?) ?? '',
      status:      (d['status']   as String?) ?? 'pending',
      sentAt:      (d['sentAt']   as Timestamp?)?.toDate(),
      acceptedAt:  (d['acceptedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isPending  => status == 'pending';
  bool get isAccepted => status == 'accepted';
}
