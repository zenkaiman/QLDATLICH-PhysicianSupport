import 'package:cloud_firestore/cloud_firestore.dart';

/// Một tin nhắn.
/// Document: Conversations/{conversationId}/Messages/{messageId}
class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderRole; // patient | support | system
  final String content;
  final String type; // text | image | system
  final String imageUrl;
  final DateTime createdAt;
  final bool isRead;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    this.content = '',
    this.type = 'text',
    this.imageUrl = '',
    required this.createdAt,
    this.isRead = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> m, {String? id}) {
    final ts = m['createdAt'];
    return MessageModel(
      id: id ?? (m['id'] ?? '').toString(),
      conversationId: (m['conversationId'] ?? '').toString(),
      senderId: (m['senderId'] ?? '').toString(),
      senderRole: (m['senderRole'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      type: (m['type'] ?? 'text').toString(),
      imageUrl: (m['imageUrl'] ?? '').toString(),
      // createdAt tạm thời null cho tới khi server ghi xong serverTimestamp.
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      isRead: m['isRead'] == true,
    );
  }

  bool get isSystem => type == 'system';
  bool get isImage => type == 'image' && imageUrl.isNotEmpty;
}