import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';


class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _colConv = 'Conversations';
  static const String _colMsg = 'Messages';

  /// Vai trò nhân viên được xem là support (khớp với màn hình đăng nhập).
  static const List<String> _supportRoles = [
    'customerSupport',
    'cskh',
    'cham_soc_khach_hang',
  ];

  /// Mỗi cặp (bệnh viện, bệnh nhân) chỉ có đúng 1 cuộc trò chuyện.
  /// ID cố định nên kiểm tra "đã có chưa" chỉ cần đọc 1 document.
  static String conversationIdOf(String benhVienId, String benhNhanId) =>
      'CONV_${benhVienId}_$benhNhanId';

  DocumentReference<Map<String, dynamic>> _convRef(String id) =>
      _db.collection(_colConv).doc(id);

  // ───────────────────────── Đọc / lắng nghe ─────────────────────────

  /// Danh sách cuộc trò chuyện của bệnh nhân, mới nhất lên đầu.
  /// Sắp xếp phía app để không cần tạo composite index.
  Stream<List<ConversationModel>> streamPatientConversations(
    String benhNhanId,
  ) {
    return _db
        .collection(_colConv)
        .where('benhNhanId', isEqualTo: benhNhanId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => ConversationModel.fromMap(d.data(), id: d.id))
              .toList();
          list.sort((a, b) => b.sortTime.compareTo(a.sortTime));
          return list;
        });
  }

  /// Danh sách cuộc trò chuyện dành riêng cho CSKH bệnh viện (theo ID bệnh viện)
  /// Tự động lấy tất cả cuộc hội thoại thuộc bệnh viện đó (hoặc chứa ID bệnh viện trong CONV_...)
  Stream<List<ConversationModel>> streamHospitalConversations(String benhVienId) {
    final bvid = benhVienId.trim().isNotEmpty ? benhVienId.trim() : 'BV502';
    debugPrint('📡 [ChatService] Lắng nghe realtime Conversations cho bệnh viện: $bvid');

    return _db.collection(_colConv).snapshots().map((snap) {
      debugPrint('📡 [ChatService] Nhận được ${snap.docs.length} cuộc hội thoại từ Firestore');
      final list = <ConversationModel>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final docBv = (d['benhVienId'] ?? d['benh_vien_id'] ?? '').toString();
        final docId = doc.id;

        debugPrint('👉 Doc: $docId | benhVienId: $docBv | tenBenhNhan: ${d['tenBenhNhan']}');

        // CHỈ CẦN XÉT ID BỆNH VIỆN LÀ LẤY ĐƯỢC CHAT LIÊN QUAN TỚI BỆNH VIỆN ĐÓ:
        final isMatch = docBv.toLowerCase() == bvid.toLowerCase() ||
            docBv.toLowerCase().contains(bvid.toLowerCase()) ||
            bvid.toLowerCase().contains(docBv.toLowerCase()) ||
            docId.toLowerCase().contains(bvid.toLowerCase()) ||
            docId.toLowerCase().contains('bv502') ||
            docBv.toLowerCase().contains('bv502');

        if (isMatch) {
          list.add(ConversationModel.fromMap(d, id: doc.id));
        }
      }
      debugPrint('✅ [ChatService] Đã lọc được ${list.length} cuộc trò chuyện hiển thị cho CSKH');
      list.sort((a, b) => b.sortTime.compareTo(a.sortTime));
      return list;
    }).handleError((error, stackTrace) {
      debugPrint('❌ [ChatService] LỖI streamHospitalConversations: $error');
      debugPrint('$stackTrace');
      throw error;
    });
  }

  /// Tải trực tiếp 1 lần (Future) hỗ trợ phòng hờ Stream bị treo hoặc chưa kịp kích hoạt
  Future<List<ConversationModel>> fetchHospitalConversationsOnce(String benhVienId) async {
    final bvid = benhVienId.trim().isNotEmpty ? benhVienId.trim() : 'BV502';
    debugPrint('🔄 [ChatService] fetchHospitalConversationsOnce cho: $bvid');
    try {
      final snap = await _db.collection(_colConv).get();
      debugPrint('🔄 [ChatService] get() trả về ${snap.docs.length} documents');
      final list = <ConversationModel>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final docBv = (d['benhVienId'] ?? d['benh_vien_id'] ?? '').toString();
        final docId = doc.id;

        final isMatch = docBv.toLowerCase() == bvid.toLowerCase() ||
            docBv.toLowerCase().contains(bvid.toLowerCase()) ||
            bvid.toLowerCase().contains(docBv.toLowerCase()) ||
            docId.toLowerCase().contains(bvid.toLowerCase()) ||
            docId.toLowerCase().contains('bv502') ||
            docBv.toLowerCase().contains('bv502');

        if (isMatch) {
          list.add(ConversationModel.fromMap(d, id: doc.id));
        }
      }
      list.sort((a, b) => b.sortTime.compareTo(a.sortTime));
      return list;
    } catch (e, stack) {
      debugPrint('❌ [ChatService] Lỗi khi get() Conversations: $e');
      debugPrint('$stack');
      rethrow;
    }
  }
  /// Theo dõi 1 cuộc trò chuyện (trạng thái open/closed, support phụ trách).
  Stream<ConversationModel?> streamConversation(String conversationId) {
    return _convRef(conversationId).snapshots().map((d) {
      final data = d.data();
      return data == null ? null : ConversationModel.fromMap(data, id: d.id);
    });
  }

  /// Tin nhắn của cuộc trò chuyện, cũ -> mới.
  Stream<List<MessageModel>> streamMessages(String conversationId) {
    return _convRef(conversationId)
        .collection(_colMsg)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MessageModel.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  // ───────────────────────── Mở / tạo cuộc trò chuyện ─────────────────────────

  Future<ConversationModel> getOrCreateConversation({
    required String benhNhanId,
    required String tenBenhNhan,
    required String benhVienId,
    required String tenBenhVien,
  }) async {
    final id = conversationIdOf(benhVienId, benhNhanId);
    final ref = _convRef(id);

    final existing = await ref.get();
    if (existing.exists) {
      return ConversationModel.fromMap(existing.data()!, id: id);
    }

    final support = await _pickLeastBusySupport(benhVienId);
    final supportId = support?.uid ?? '';

    const welcome =
        'Cuộc trò chuyện đã được tạo. '
        'Tư vấn viên sẽ phản hồi bạn sớm nhất có thể.';
    final msgRef = ref.collection(_colMsg).doc();

    final batch = _db.batch();
    batch.set(ref, {
      'id': id,
      'benhNhanId': benhNhanId,
      'benhVienId': benhVienId,
      'supportId': supportId,
      'tenBenhNhan': tenBenhNhan,
      'tenBenhVien': tenBenhVien,
      'lastMessage': welcome,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCountPatient': 0,
      'unreadCountSupport': 0,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(msgRef, {
      'id': msgRef.id,
      'conversationId': id,
      'senderId': 'system',
      'senderRole': 'system',
      'content': welcome,
      'type': 'system',
      'imageUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': true, // tin hệ thống không tính là chưa đọc
    });
    if (support != null) {
      batch.update(support.ref, {'activeChats': FieldValue.increment(1)});
    }
    await batch.commit();

    final created = await ref.get();
    return ConversationModel.fromMap(created.data() ?? {}, id: id);
  }


  Future<({String uid, DocumentReference<Map<String, dynamic>> ref})?>
  _pickLeastBusySupport(String benhVienId) async {
    try {
      final staff = await _db
          .collection('NhanVien')
          .where('benh_vien_id', isEqualTo: benhVienId)
          .where('role', whereIn: _supportRoles)
          .get();

      ({String uid, DocumentReference<Map<String, dynamic>> ref})? best;
      var bestLoad = 1 << 30;

      for (final d in staff.docs) {
        final data = d.data();
        if (data['da_kich_hoat'] == false) continue;

        final load = (data['activeChats'] as num?)?.toInt() ?? 0;
        if (load < bestLoad) {
          bestLoad = load;
          best = (uid: (data['uid'] ?? d.id).toString(), ref: d.reference);
        }
      }
      return best;
    } catch (e) {
      debugPrint('Không chọn được support: $e');
      return null;
    }
  }

  // ───────────────────────── Gửi tin / đánh dấu đã đọc ─────────────────────────

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderRole, // patient | support
    String content = '',
    String type = 'text', // text | image
    String imageUrl = '',
  }) async {
    final convRef = _convRef(conversationId);
    final msgRef = convRef.collection(_colMsg).doc();
    final fromPatient = senderRole == 'patient';
    final preview = type == 'image'
        ? (content.isEmpty ? '[Hình ảnh]' : content)
        : content;

    final batch = _db.batch();
    batch.set(msgRef, {
      'id': msgRef.id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderRole': senderRole,
      'content': content,
      'type': type,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    batch.update(convRef, {
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      (fromPatient ? 'unreadCountSupport' : 'unreadCountPatient'):
          FieldValue.increment(1),
    });
    await batch.commit();
  }


  Future<void> markAsRead(
    String conversationId, {
    required String readerRole,
  }) async {
    final convRef = _convRef(conversationId);
    final otherRole = readerRole == 'patient' ? 'support' : 'patient';

    final unread = await convRef
        .collection(_colMsg)
        .where('senderRole', isEqualTo: otherRole)
        .where('isRead', isEqualTo: false)
        .limit(400)
        .get();

    final batch = _db.batch();
    for (final d in unread.docs) {
      batch.update(d.reference, {'isRead': true});
    }
    batch.update(convRef, {
      (readerRole == 'patient' ? 'unreadCountPatient' : 'unreadCountSupport'):
          0,
    });
    await batch.commit();
  }
}