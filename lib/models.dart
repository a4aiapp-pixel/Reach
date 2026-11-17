import 'package:flutter/foundation.dart';

String str(Object? v) => v?.toString() ?? '';
DateTime dateOf(Object? v) => DateTime.tryParse(str(v))?.toLocal() ?? DateTime.now();

@immutable
class ReachPost {
  const ReachPost({required this.id, required this.ownerId, required this.ownerName,
    required this.title, required this.detail, required this.kind, required this.category,
    required this.city, required this.country, required this.expiresAt,
    required this.createdAt, required this.circleName, required this.scope});
  final String id, ownerId, ownerName, title, detail, kind, category, city, country, circleName, scope;
  final DateTime expiresAt, createdAt;
  factory ReachPost.fromJson(Map<String, dynamic> j) => ReachPost(
    id: str(j['id']), ownerId: str(j['owner_id']), ownerName: str(j['owner_name']),
    title: str(j['title']), detail: str(j['detail']), kind: str(j['kind']),
    category: str(j['category']), city: str(j['city']), country: str(j['country']),
    expiresAt: dateOf(j['expires_at']), createdAt: dateOf(j['created_at']),
    circleName: str(j['circle_name']), scope: str(j['scope']));
  bool get expired => expiresAt.isBefore(DateTime.now());
}

@immutable
class ReachRequest {
  const ReachRequest({required this.id, required this.postId, required this.postTitle,
    required this.senderId, required this.senderName, required this.message,
    required this.status, required this.createdAt});
  final String id, postId, postTitle, senderId, senderName, message, status;
  final DateTime createdAt;
  factory ReachRequest.fromJson(Map<String, dynamic> j) => ReachRequest(
    id:str(j['id']),postId:str(j['post_id']),postTitle:str(j['post_title']),
    senderId:str(j['sender_id']),senderName:str(j['sender_name']),
    message:str(j['message']),status:str(j['status']),createdAt:dateOf(j['created_at']));
}
