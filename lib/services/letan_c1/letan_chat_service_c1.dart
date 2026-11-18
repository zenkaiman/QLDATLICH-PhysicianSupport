import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';

/// Module Chat CSKH thời gian thực (C1)
/// Chuẩn hóa 100% theo kiến trúc Conversations/{conversationId}/Messages/{messageId}
class LetanChatServiceC1 {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lắng nghe danh sách các cuộc hội thoại CSKH realtime từ collection "Conversations"
  /// Chỉ cần xét đúng ID bệnh viện (ví dụ BV502) là lấy toàn bộ chat của bệnh viện đó
  static Stream<List<Map<String, dynamic>>> streamDanhSachHoiThoaiCskh([String? benhVienId]) {
    final rawBv = benhVienId ?? DuLieuProfileMauC1.thongTinHienTai.benhVienId;
    final bvid = (rawBv.trim().isNotEmpty && rawBv != 'BV01' && rawBv != '1')
        ? rawBv.trim()
        : 'BV502';

    return _firestore.collection('Conversations').snapshots().map((snap) {
      if (snap.docs.isEmpty) return [];

      final list = <Map<String, dynamic>>[];

      for (var doc in snap.docs) {
        final d = doc.data();
        final docId = doc.id;
        final docBv = (d['benhVienId'] ?? d['benh_vien_id'] ?? '').toString();

        // CHỈ CẦN XÉT ID BỆNH VIỆN LÀ LẤY ĐƯỢC CHAT LIÊN QUAN TỚI BỆNH VIỆN ĐÓ:
        // 1. docBv trùng khớp với bvid (hoặc ngược lại)
        // 2. Hoặc Document ID bắt đầu bằng CONV_{bvid}_...
        // 3. Nếu là BV502 (Bệnh viện anh Tuấn) thì luôn nạp các đoạn chat thuộc BV502
        bool isHospitalChat = false;
        if (docBv.isNotEmpty) {
          isHospitalChat = docBv.toLowerCase() == bvid.toLowerCase() ||
              docBv.toLowerCase().contains(bvid.toLowerCase()) ||
              bvid.toLowerCase().contains(docBv.toLowerCase());
        }
        if (!isHospitalChat && docId.isNotEmpty) {
          isHospitalChat = docId.toLowerCase().contains(bvid.toLowerCase());
        }
        // Trường hợp fallback nếu tài khoản là BV502:
        if (!isHospitalChat && (bvid.toLowerCase().contains('bv502') || bvid.isEmpty)) {
          isHospitalChat = docId.toLowerCase().contains('bv502') || docBv.toLowerCase().contains('bv502');
        }

        if (isHospitalChat) {
          list.add({'id': doc.id, ...d});
        }
      }

      // Sắp xếp cuộc trò chuyện có tin nhắn mới nhất lên đầu trang (sort an toàn ở client)
      list.sort((a, b) {
        final tsA = a['lastMessageAt'] ?? a['updatedAt'] ?? a['createdAt'];
        final tsB = b['lastMessageAt'] ?? b['updatedAt'] ?? b['createdAt'];
        final dtA = tsA is Timestamp ? tsA.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = tsB is Timestamp ? tsB.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        return dtB.compareTo(dtA);
      });

      return list;
    });
  }

  /// Lắng nghe danh sách tin nhắn trong 1 cuộc hội thoại:
  /// Conversations/{hoiThoaiId}/Messages
  static Stream<List<Map<String, dynamic>>> streamTinNhanCskh({
    required String hoiThoaiId,
    String? benhVienId,
  }) {
    return _firestore
        .collection('Conversations')
        .doc(hoiThoaiId)
        .collection('Messages')
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return [];

      final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // Sắp xếp tin nhắn tăng dần theo thời gian (cũ ở trên, mới ở dưới)
      list.sort((a, b) {
        final tsA = a['createdAt'] ?? a['timestamp'];
        final tsB = b['createdAt'] ?? b['timestamp'];
        final dtA = tsA is Timestamp ? tsA.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = tsB is Timestamp ? tsB.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        return dtA.compareTo(dtB);
      });

      return list;
    });
  }

  /// Gửi tin nhắn từ phía CSKH (support)
  static Future<void> guiTinNhanCskh({
    required String hoiThoaiId,
    required String noiDung,
    String? benhVienId,
    String? maNv,
    String? tenNv,
  }) async {
    final text = noiDung.trim();
    if (text.isEmpty) return;

    final profile = DuLieuProfileMauC1.thongTinHienTai;
    final staffId = (maNv != null && maNv.isNotEmpty) ? maNv : profile.maNhanVien;
    final staffName = (tenNv != null && tenNv.isNotEmpty) ? tenNv : profile.hoTen;
    final senderUid = FirebaseAuth.instance.currentUser?.uid ?? staffId;

    final convRef = _firestore.collection('Conversations').doc(hoiThoaiId);
    final msgRef = convRef.collection('Messages').doc();

    final now = FieldValue.serverTimestamp();

    // 1. Thêm tin nhắn mới vào Messages
    await msgRef.set({
      'id': msgRef.id,
      'conversationId': hoiThoaiId,
      'senderId': senderUid,
      'senderRole': 'support',
      'senderName': staffName,
      'content': text,
      'type': 'text',
      'imageUrl': '',
      'createdAt': now,
      'isRead': false,
    });

    // 2. Cập nhật Document cha Conversations
    await convRef.set({
      'id': hoiThoaiId,
      'lastMessage': text,
      'lastMessageAt': now,
      'supportId': senderUid,
      'unreadCountPatient': FieldValue.increment(1),
      'unreadCountSupport': 0, // Reset số tin chưa đọc của Support về 0
      'status': 'open',
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  /// Đánh dấu CSKH đã đọc tin nhắn trong cuộc trò chuyện
  static Future<void> danhDauDaDoc(String hoiThoaiId) async {
    try {
      final convRef = _firestore.collection('Conversations').doc(hoiThoaiId);

      // Reset unreadCountSupport về 0
      await convRef.set({
        'unreadCountSupport': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Đánh dấu isRead = true cho các tin nhắn từ bệnh nhân (patient)
      final unreadSnap = await convRef
          .collection('Messages')
          .where('senderRole', isEqualTo: 'patient')
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in unreadSnap.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (_) {}
  }
}
