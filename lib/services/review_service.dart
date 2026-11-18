import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/review_model.dart';

class ReviewException implements Exception {
  final String message;
  const ReviewException(this.message);
  @override
  String toString() => message;
}

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _reviewCollection = 'DanhGia';

  /// Lưu đánh giá mới và CẬP NHẬT THỐNG KÊ cho cả KHOA và BỆNH VIỆN
  Future<void> submitReview(ReviewModel review) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // ==========================================
        // BƯỚC 1: THỰC HIỆN TẤT CẢ CÁC LỆNH ĐỌC (READ) TRƯỚC
        // ==========================================
        final khoaRef = _firestore
            .collection('Khoa')
            .doc(review.benhVienId)
            .collection('danh_sach')
            .doc(review.khoaId);
        final khoaDoc = await transaction.get(khoaRef);

        final bvRef = _firestore.collection('BenhVien').doc(review.benhVienId);
        final bvDoc = await transaction.get(bvRef);

        // ==========================================
        // BƯỚC 2: TÍNH TOÁN SỐ LIỆU MỚI
        // ==========================================

        // Tính toán cho Khoa
        int khoaCurrentCount =
            (khoaDoc.data()?['tong_danh_gia'] as num?)?.toInt() ?? 0;
        double khoaCurrentAvg =
            (khoaDoc.data()?['diem_trung_binh'] as num?)?.toDouble() ?? 0.0;

        final newKhoaCount = khoaCurrentCount + 1;
        final newKhoaAvg =
            ((khoaCurrentAvg * khoaCurrentCount) + review.diemDanhGia) /
            newKhoaCount;

        // Tính toán cho Bệnh viện
        int bvCurrentCount =
            (bvDoc.data()?['tong_so_danh_gia'] as num?)?.toInt() ?? 0;
        double bvCurrentAvg =
            (bvDoc.data()?['diem_danh_gia_tb'] as num?)?.toDouble() ?? 0.0;

        final newBvCount = bvCurrentCount + 1;
        final newBvAvg =
            ((bvCurrentAvg * bvCurrentCount) + review.diemDanhGia) / newBvCount;

        // ==========================================
        // BƯỚC 3: THỰC HIỆN TẤT CẢ CÁC LỆNH GHI (WRITE) SAU KHI ĐÃ ĐỌC XONG
        // ==========================================

        // 1. Lưu document đánh giá mới
        final reviewRef = _firestore
            .collection(_reviewCollection)
            .doc(review.id);
        transaction.set(reviewRef, review.toJson());

        // 2. Cập nhật thống kê cho Khoa
        transaction.update(khoaRef, {
          'tong_danh_gia': newKhoaCount,
          'diem_trung_binh': double.parse(
            newKhoaAvg.toStringAsFixed(1),
          ), // Làm tròn 1 chữ số thập phân
        });

        // 3. Cập nhật thống kê cho Bệnh viện
        transaction.update(bvRef, {
          'tong_so_danh_gia': newBvCount,
          'diem_danh_gia_tb': double.parse(
            newBvAvg.toStringAsFixed(1),
          ), // Làm tròn 1 chữ số thập phân
        });
      });

      debugPrint(
        '✅ Đã lưu đánh giá và cập nhật thống kê Khoa & Bệnh viện thành công',
      );
    } catch (e) {
      debugPrint('❌ Lỗi khi lưu đánh giá: $e');
      throw ReviewException('Không thể gửi đánh giá. Vui lòng thử lại.');
    }
  }

  // Kiểm tra xem bệnh nhân đã đánh giá lịch hẹn này chưa
  Future<bool> hasReviewed(String lichHenId, String benhNhanId) async {
    try {
      final snapshot = await _firestore
          .collection(_reviewCollection)
          .where('lich_hen_id', isEqualTo: lichHenId)
          .where('benh_nhan_id', isEqualTo: benhNhanId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Lỗi khi kiểm tra đánh giá: $e');
      return false;
    }
  }

  /// Lấy các đánh giá mới nhất của 1 khoa.
  Future<List<ReviewModel>> getReviewsByDepartment({
    required String hospitalId,
    required String khoaId,
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_reviewCollection)
          .where('benh_vien_id', isEqualTo: hospitalId)
          .where('khoa_id', isEqualTo: khoaId)
          .orderBy('ngay_tao', descending: true)
          .limit(limit)
          .get();

      final reviews = <ReviewModel>[];
      for (final doc in snapshot.docs) {
        try {
          reviews.add(ReviewModel.fromJson(doc.data(), doc.id));
        } catch (e) {
          debugPrint('❌ Lỗi parse document ${doc.id}: $e');
        }
      }
      return reviews;
    } catch (e) {
      debugPrint('❌ Lỗi khi tải đánh giá: $e');
      rethrow;
    }
  }

  /// ✅ HÀM : Lấy nhanh thống kê của BỆNH VIỆN
  Future<Map<String, dynamic>> getHospitalStats({
    required String hospitalId,
  }) async {
    try {
      final bvRef = _firestore.collection('BenhVien').doc(hospitalId);
      final doc = await bvRef.get();

      if (doc.exists) {
        return {
          'tong_danh_gia': (doc.data()?['tong_danh_gia'] as num?)?.toInt() ?? 0,
          'diem_trung_binh':
              (doc.data()?['diem_trung_binh'] as num?)?.toDouble() ?? 0.0,
        };
      }
      return {'tong_danh_gia': 0, 'diem_trung_binh': 0.0};
    } catch (e) {
      debugPrint('❌ Lỗi khi tải thống kê bệnh viện: $e');
      return {'tong_danh_gia': 0, 'diem_trung_binh': 0.0};
    }
  }

  /// ✅ HÀM: Lấy nhanh thống kê của KHOA
  Future<Map<String, dynamic>> getDepartmentStats({
    required String hospitalId,
    required String khoaId,
  }) async {
    try {
      final khoaRef = _firestore
          .collection('Khoa')
          .doc(hospitalId)
          .collection('danh_sach')
          .doc(khoaId);

      final doc = await khoaRef.get();
      if (doc.exists) {
        return {
          'tong_danh_gia': (doc.data()?['tong_danh_gia'] as num?)?.toInt() ?? 0,
          'diem_trung_binh':
              (doc.data()?['diem_trung_binh'] as num?)?.toDouble() ?? 0.0,
        };
      }
      return {'tong_danh_gia': 0, 'diem_trung_binh': 0.0};
    } catch (e) {
      debugPrint('❌ Lỗi khi tải thống kê khoa: $e');
      return {'tong_danh_gia': 0, 'diem_trung_binh': 0.0};
    }
  }
}
