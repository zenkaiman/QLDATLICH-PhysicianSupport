import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DatabaseMigrationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 🚀 HÀM CHẠY 1 LẦN DUY NHẤT:
  /// Đọc toàn bộ collection 'DanhGia', tính toán lại số liệu
  /// và ghi vào document của 'Khoa' và 'BenhVien'.
  Future<void> backfillReviewStats() async {
    debugPrint(
      '🚀 [MIGRATION] Bắt đầu cập nhật thống kê đánh giá từ dữ liệu cũ...',
    );

    try {
      final snapshot = await _db.collection('DanhGia').get();
      debugPrint('📦 [MIGRATION] Tìm thấy ${snapshot.docs.length} đánh giá.');

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ [MIGRATION] Không có đánh giá nào để cập nhật.');
        return;
      }

      Map<String, Map<String, dynamic>> khoaStats = {};
      Map<String, Map<String, dynamic>> bvStats = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final bvId = data['benh_vien_id']?.toString();
        final khoaId = data['khoa_id']?.toString();
        final rating = (data['diem_danh_gia'] as num?)?.toInt() ?? 0;

        if (bvId == null || khoaId == null) continue;

        // Gom nhóm cho Khoa
        final khoaKey = '$bvId|$khoaId';
        if (!khoaStats.containsKey(khoaKey)) {
          khoaStats[khoaKey] = {
            'bvId': bvId,
            'khoaId': khoaId,
            'count': 0,
            'sum': 0,
          };
        }
        khoaStats[khoaKey]!['count'] =
            (khoaStats[khoaKey]!['count'] as int) + 1;
        khoaStats[khoaKey]!['sum'] =
            (khoaStats[khoaKey]!['sum'] as int) + rating;

        // Gom nhóm cho Bệnh viện
        if (!bvStats.containsKey(bvId)) {
          bvStats[bvId] = {'count': 0, 'sum': 0};
        }
        bvStats[bvId]!['count'] = (bvStats[bvId]!['count'] as int) + 1;
        bvStats[bvId]!['sum'] = (bvStats[bvId]!['sum'] as int) + rating;
      }

      debugPrint(
        '📊 [MIGRATION] Đã gom nhóm xong. Bắt đầu ghi vào Firestore...',
      );

      int updatedKhoaCount = 0;
      int updatedBvCount = 0;

      for (var entry in khoaStats.entries) {
        final data = entry.value;
        final bvId = data['bvId'] as String;
        final khoaId = data['khoaId'] as String;
        final count = data['count'] as int;
        final sum = data['sum'] as int;
        final avg = count > 0 ? sum / count : 0.0;

        final docRef = _db
            .collection('Khoa')
            .doc(bvId)
            .collection('danh_sach')
            .doc(khoaId);

        // Dùng set(merge: true) để tránh lỗi nếu document Khoa chưa tồn tại
        await docRef.set({
          'tong_danh_gia': count,
          'diem_trung_binh': double.parse(avg.toStringAsFixed(1)),
        }, SetOptions(merge: true));

        updatedKhoaCount++;
      }

      for (var entry in bvStats.entries) {
        final bvId = entry.key;
        final count = entry.value['count'] as int;
        final sum = entry.value['sum'] as int;
        final avg = count > 0 ? sum / count : 0.0;

        final docRef = _db.collection('BenhVien').doc(bvId);

        await docRef.set({
          'tong_danh_gia': count,
          'diem_trung_binh': double.parse(avg.toStringAsFixed(1)),
        }, SetOptions(merge: true));

        updatedBvCount++;
      }

      debugPrint('✅ [MIGRATION] HOÀN TẤT!');
      debugPrint('   - Đã cập nhật $updatedKhoaCount document Khoa.');
      debugPrint('   - Đã cập nhật $updatedBvCount document Bệnh viện.');
    } catch (e) {
      debugPrint('❌ [MIGRATION] Lỗi trong quá trình cập nhật: $e');
    }
  }
}
