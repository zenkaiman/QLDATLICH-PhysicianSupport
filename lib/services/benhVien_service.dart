import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_session.dart';

class BenhVienService {
  static final Map<String, String> _cache = {};

  static String _chuanHoa(String k) =>
      k.toLowerCase().replaceAll('_', '').replaceAll(' ', '');

  /// Tìm tên trong dữ liệu document, chấp nhận nhiều kiểu đặt tên field:
  /// ten_benh_vien, tenBenhVien, TenBenhVien, ten, name...
  static String _timTen(Map<String, dynamic> data) {
    const uuTien = ['tenbenhvien', 'tenbv', 'ten', 'name', 'hospitalname'];
    final chuan = {for (final e in data.entries) _chuanHoa(e.key): e.value};
    for (final k in uuTien) {
      final v = chuan[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    // Dự phòng: field nào bắt đầu bằng "ten" và là chuỗi
    for (final e in data.entries) {
      final v = e.value;
      if (_chuanHoa(e.key).startsWith('ten') &&
          v is String &&
          v.trim().isNotEmpty) {
        return v.trim();
      }
    }
    return '';
  }

  /// Lấy tên bệnh viện theo ID.
  /// - Nếu AppSession.benhVienPath có giá trị: đọc thẳng document đó.
  /// - Nếu không: quét collection group `danh_sach`, tìm document có đúng ID
  ///   (bỏ qua nhánh `Khoa/`). Kết quả được nhớ lại.
  /// Trả về chuỗi rỗng nếu không tìm thấy; ném lỗi nếu Firestore từ chối.
  static Future<String> layTen(String benhVienId) async {
    if (_cache.containsKey(benhVienId)) return _cache[benhVienId]!;
    final db = FirebaseFirestore.instance;

    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;
      final path = AppSession.benhVienPath;

      if (path != null) {
        doc = await db.doc(path).get();
        if (!doc.exists) doc = null;
      } else {
        // 1. Kiểm tra trực tiếp trong collection BenhVien/{benhVienId}
        final docDirect = await db.collection('BenhVien').doc(benhVienId).get();
        if (docDirect.exists) {
          doc = docDirect;
        } else {
          // 2. Dự phòng: quét collectionGroup danh_sach
          final all = await db.collectionGroup('danh_sach').get();
          for (final d in all.docs) {
            if (d.id == benhVienId && !d.reference.path.startsWith('Khoa/')) {
              doc = d;
              break;
            }
          }
          if (doc == null) {
            debugPrint(
              '[BenhVienService] Đã quét ${all.docs.length} document '
              'trong danh_sach nhưng không có ID "$benhVienId".',
            );
          }
        }
      }

      if (doc == null) return '';

      final data = doc.data() ?? {};
      debugPrint('[BenhVienService] Tìm thấy: ${doc.reference.path}');
      debugPrint('[BenhVienService] Các field: ${data.keys.toList()}');

      final ten = _timTen(data);
      if (ten.isEmpty) {
        debugPrint('[BenhVienService] Document có nhưng không thấy field tên.');
        return '';
      }
      _cache[benhVienId] = ten;
      return ten;
    } catch (e) {
      debugPrint('[BenhVienService] Lỗi đọc tên bệnh viện: $e');
      rethrow;
    }
  }

  // ---------- Thống kê bệnh nhân theo ngày ----------
  // ThongKe/{benhVienId}/danh_sach/{yyyy-MM-dd}
  //   tongBenhNhan: number, dangKham: number
  static String homNay() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> thongKeHomNay(
    String benhVienId,
  ) => FirebaseFirestore.instance
      .collection('ThongKe')
      .doc(benhVienId)
      .collection('danh_sach')
      .doc(homNay())
      .snapshots();

  /// Gọi mỗi khi có bệnh nhân đăng ký / bắt đầu khám (tự tạo doc nếu chưa có).
  static Future<void> tangBenhNhan(
    String benhVienId, {
    int tong = 1,
    int dangKham = 0,
  }) {
    return FirebaseFirestore.instance
        .collection('ThongKe')
        .doc(benhVienId)
        .collection('danh_sach')
        .doc(homNay())
        .set({
          'tongBenhNhan': FieldValue.increment(tong),
          'dangKham': FieldValue.increment(dangKham),
        }, SetOptions(merge: true));
  }
}