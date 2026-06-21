import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendStatus { online, away, playing, reading, offline }
enum FriendFilter { all, online, offline, favorites, recent }

extension FriendStatusExt on FriendStatus {
  String get label {
    switch (this) {
      case FriendStatus.online:   return 'Online';
      case FriendStatus.away:     return 'Ausente';
      case FriendStatus.playing:  return 'Jogando';
      case FriendStatus.reading:  return 'Lendo notícias';
      case FriendStatus.offline:  return 'Offline';
    }
  }

  Color get color {
    switch (this) {
      case FriendStatus.online:   return const Color(0xFF43B581);
      case FriendStatus.away:     return const Color(0xFFFAA61A);
      case FriendStatus.playing:  return const Color(0xFF7289DA);
      case FriendStatus.reading:  return const Color(0xFFFF6B00);
      case FriendStatus.offline:  return const Color(0xFF747F8D);
    }
  }

  IconData get icon {
    switch (this) {
      case FriendStatus.online:   return Icons.circle;
      case FriendStatus.away:     return Icons.access_time_rounded;
      case FriendStatus.playing:  return Icons.sports_esports_rounded;
      case FriendStatus.reading:  return Icons.article_rounded;
      case FriendStatus.offline:  return Icons.circle_outlined;
    }
  }
}

class FriendModel {
  final String uid;
  final String username;
  final String displayName;
  final int level;
  final int totalXp;
  final int xpForNextLevel;
  final FriendStatus status;
  final DateTime? lastActivity;
  final String? lastMessage;
  final DateTime? lastMessageTime;
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
    required this.level,
    required this.totalXp,
    required this.xpForNextLevel,
    required this.status,
    this.lastActivity,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isFavorite = false,
    this.isTyping = false,
    this.achievements = const [],
    this.rank = 0,
    this.chatId,
  });

  bool get isOnline => status != FriendStatus.offline;

  double get xpProgress {
    final base = (level - 1) * 500;
    final needed = xpForNextLevel - base;
    final current = totalXp - base;
    return (current / needed).clamp(0.0, 1.0);
  }

  FriendModel copyWith({
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isTyping,
    String? chatId,
  }) {
    return FriendModel(
      uid: uid,
      username: username,
      displayName: displayName,
      level: level,
      totalXp: totalXp,
      xpForNextLevel: xpForNextLevel,
      status: status,
      lastActivity: lastActivity,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isFavorite: isFavorite,
      isTyping: isTyping ?? this.isTyping,
      achievements: achievements,
      rank: rank,
      chatId: chatId ?? this.chatId,
    );
  }

  factory FriendModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final last = (d['lastActivity'] as Timestamp?)?.toDate();
    final diffMin = last != null
        ? DateTime.now().difference(last).inMinutes
        : 9999;

    FriendStatus status;
    final statusStr = d['status'] as String? ?? '';
    if (statusStr == 'playing') {
      status = FriendStatus.playing;
    } else if (statusStr == 'reading') {
      status = FriendStatus.reading;
    } else if (statusStr == 'away' || (diffMin >= 5 && diffMin < 30)) {
      status = FriendStatus.away;
    } else if (diffMin < 5) {
      status = FriendStatus.online;
    } else {
      status = FriendStatus.offline;
    }

    final lvl = (d['level'] as num?)?.toInt() ?? 1;
    final xp  = (d['totalXp'] as num?)?.toInt() ?? 0;
    final nextXp = lvl * 500;

    return FriendModel(
      uid: doc.id,
      username: (d['username'] as String?) ?? '',
      displayName: (d['displayName'] as String?) ?? 'Usuário',
      level: lvl,
      totalXp: xp,
      xpForNextLevel: nextXp,
      status: status,
      lastActivity: last,
      unreadCount: (d['unreadCount'] as num?)?.toInt() ?? 0,
      isFavorite: (d['isFavorite'] as bool?) ?? false,
      isTyping: (d['isTyping'] as bool?) ?? false,
      achievements: List<String>.from(d['achievements'] ?? []),
      rank: (d['rank'] as num?)?.toInt() ?? 0,
    );
  }
}
