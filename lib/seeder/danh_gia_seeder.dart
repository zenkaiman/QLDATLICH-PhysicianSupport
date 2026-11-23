import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class DanhGiaSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Random _random = Random();

  // ✅ CẤU TRÚC MỚI: Collection cấp cao nhất, không còn nesting
  static const String _colDanhGia = 'DanhGia';

  static final Map<int, List<String>> _reviewsByRating = {
    5: [
      'Bệnh viện rất tốt, bác sĩ tận tình chu đáo.',
      'Dịch vụ tuyệt vời, sẽ giới thiệu cho người thân.',
      'Cơ sở vật chất hiện đại, nhân viên thân thiện.',
      'Khám rất kỹ, giải thích cặn kẽ bệnh tình.',
      'Hài lòng với dịch vụ, quy trình khám nhanh chóng.',
    ],
    4: [
      'Tốt, nhưng thời gian chờ hơi lâu.',
      'Dịch vụ khá ổn, nhân viên hướng dẫn vui vẻ.',
      'Khám kỹ, giá cả hợp lý với chất lượng.',
      'Bác sĩ khám tận tình, nhìn chung là hài lòng.',
    ],
    3: [
      'Bình thường, không có gì đặc biệt.',
      'Dịch vụ tạm được, cần cải thiện thái độ phục vụ.',
      'Khám ổn, nhưng chờ đợi quá lâu so với giờ hẹn.',
    ],
    2: [
      'Chưa hài lòng về dịch vụ tiếp đón.',
      'Chờ quá lâu, bác sĩ khám hơi qua loa.',
      'Nhân viên thiếu chuyên nghiệp trong hướng dẫn.',
    ],
    1: [
      'Rất tệ, trải nghiệm không tốt, không bao giờ quay lại.',
      'Chờ 3 tiếng mà không được khám, quá vô lý.',
      'Bác sĩ thiếu trách nhiệm, không giải thích gì.',
    ],
  };

  /// Seeder chính: Tạo đánh giá khớp CHÍNH XÁC với tong_so_danh_gia và diem_danh_gia_tb
  static Future<void> seedDanhGiaChoTatCa() async {
    print('⏳ Bắt đầu tạo dữ liệu đánh giá (Cấu trúc Flat)...');

    int totalReviews = 0;
    int failedCount = 0;
    final writer = _BatchWriter(_firestore);

    try {
      // 1. Lấy TẤT CẢ bệnh viện
      final benhVienSnapshot = await _firestore.collection('BenhVien').get();
      print('📋 Tìm thấy ${benhVienSnapshot.docs.length} bệnh viện.');

      for (var bvDoc in benhVienSnapshot.docs) {
        final bvData = bvDoc.data();
        final benhVienId = bvDoc.id;
        final tenBenhVien = bvData['ten_benh_vien'] ?? 'Không tên';

        // ✅ Lấy số liệu thống kê thực tế của bệnh viện
        final int tongSoDanhGia = (bvData['tong_so_danh_gia'] as num?)?.toInt() ?? 0;
        final double diemDanhGiaTb = (bvData['diem_danh_gia_tb'] as num?)?.toDouble() ?? 4.5;

        if (tongSoDanhGia == 0) {
          print('   ⏭️ Bỏ qua $tenBenhVien (Chưa có đánh giá nào).');
          continue;
        }

        print('   🏥 Đang xử lý: $tenBenhVien (Cần tạo: $tongSoDanhGia đánh giá, TB: $diemDanhGiaTb sao)');

        // 2. Lấy TẤT CẢ khoa của bệnh viện này
        final khoaSnapshot = await _firestore
            .collection('Khoa')
            .doc(benhVienId)
            .collection('danh_sach')
            .get();

        if (khoaSnapshot.docs.isEmpty) continue;

        final List<Map<String, dynamic>> listKhoa = khoaSnapshot.docs.map((doc) {
          return {'id': doc.id, 'ten_khoa': doc.data()['ten_khoa'] ?? 'Khoa'};
        }).toList();

        // 3. Phân bổ tong_so_danh_gia cho các khoa một cách ngẫu nhiên nhưng có trọng số
        List<int> reviewsPerKhoa = _distributeReviews(tongSoDanhGia, listKhoa.length);

        // 4. Tạo đánh giá cho từng khoa theo số lượng đã phân bổ
        for (int i = 0; i < listKhoa.length; i++) {
          final khoaId = listKhoa[i]['id'] as String;
          final tenKhoa = listKhoa[i]['ten_khoa'] as String;
          final int soDanhGiaCanTao = reviewsPerKhoa[i];

          if (soDanhGiaCanTao == 0) continue;

          print('      🔬 Khoa $tenKhoa ($khoaId): Tạo $soDanhGiaCanTao đánh giá');

          int reviewsLeft = soDanhGiaCanTao;
          final int soNgayTaoDanhGia = 60; // Rải rác trong 60 ngày gần nhất

          for (var day = 0; day < soNgayTaoDanhGia; day++) {
            if (reviewsLeft <= 0) break;

            int maxToday = min(5, reviewsLeft);
            int todayReviews = 0;

            // 40% cơ hội có đánh giá trong một ngày bất kỳ
            if (_random.nextDouble() < 0.4) {
              todayReviews = _random.nextInt(maxToday) + 1;
            }

            reviewsLeft -= todayReviews;

            for (var j = 0; j < todayReviews; j++) {
              try {
                final ngay = DateTime.now().subtract(Duration(days: day));
                final benhNhanId = 'BN${_random.nextInt(900) + 100}';
                final lichHenId = 'LH${ngay.millisecondsSinceEpoch}${_random.nextInt(9000) + 1000}';
                
                // ✅ ID duy nhất cho document đánh giá
                final reviewId = 'DG_${benhVienId}_${khoaId}_${lichHenId}';

                // ✅ Tạo điểm đánh giá xoay quanh diem_danh_gia_tb của bệnh viện
                final diemDanhGia = _generateRatingForTarget(diemDanhGiaTb);
                final reviews = _reviewsByRating[diemDanhGia]!;
                final nhanXet = reviews[_random.nextInt(reviews.length)];
                final anDanh = _random.nextBool();

                // ✅ DỮ LIỆU FLAT: Tất cả trong 1 document duy nhất (Denormalized)
                final reviewData = {
                  'id': reviewId,
                  'benh_vien_id': benhVienId,
                  'ten_benh_vien': tenBenhVien, // Denormalize: Giúp UI hiển thị ngay không cần join
                  'khoa_id': khoaId,
                  'ten_khoa': tenKhoa,          // Denormalize
                  'lich_hen_id': lichHenId,
                  'benh_nhan_id': benhNhanId,
                  'diem_danh_gia': diemDanhGia,
                  'nhan_xet': nhanXet,
                  'an_danh': anDanh ? 1 : 0,
                  'ngay_danh_gia': Timestamp.fromDate(ngay), // Dùng Timestamp để dễ query theo khoảng thời gian
                  'ngay_tao': FieldValue.serverTimestamp(),
                };

                // ✅ Ghi trực tiếp vào collection cấp cao nhất 'danh_gia'
                final docRef = _firestore.collection(_colDanhGia).doc(reviewId);
                await writer.set(docRef, reviewData);

                totalReviews++;
              } catch (e) {
                failedCount++;
              }
            }
          }

          // Nếu vẫn còn dư (do logic random ngày), nhét hết vào ngày hiện tại
          while (reviewsLeft > 0) {
            try {
              final ngay = DateTime.now();
              final benhNhanId = 'BN${_random.nextInt(900) + 100}';
              final lichHenId = 'LH${ngay.millisecondsSinceEpoch}${_random.nextInt(9000) + 1000}';
              final reviewId = 'DG_${benhVienId}_${khoaId}_${lichHenId}';

              final diemDanhGia = _generateRatingForTarget(diemDanhGiaTb);
              final reviews = _reviewsByRating[diemDanhGia]!;
              
              final reviewData = {
                'id': reviewId,
                'benh_vien_id': benhVienId,
                'ten_benh_vien': tenBenhVien,
                'khoa_id': khoaId,
                'ten_khoa': tenKhoa,
                'lich_hen_id': lichHenId,
                'benh_nhan_id': benhNhanId,
                'diem_danh_gia': diemDanhGia,
                'nhan_xet': reviews[_random.nextInt(reviews.length)],
                'an_danh': _random.nextBool() ? 1 : 0,
                'ngay_danh_gia': Timestamp.fromDate(ngay),
                'ngay_tao': FieldValue.serverTimestamp(),
              };

              final docRef = _firestore.collection(_colDanhGia).doc(reviewId);
              await writer.set(docRef, reviewData);
              
              totalReviews++;
              reviewsLeft--;
            } catch (e) {
              failedCount++;
              reviewsLeft--; // Tránh vòng lặp vô hạn nếu lỗi liên tục
            }
          }
        }
      }

      await writer.flush(); // Ghi nốt phần còn lại
      print('\n🎉 HOÀN TẤT SEEDING ĐÁNH GIÁ!');
      print('📊 Tổng số đánh giá đã tạo: $totalReviews');
      print('📊 Số lỗi: $failedCount');

    } catch (e) {
      print('❌ Lỗi khi seeding đánh giá: $e');
      rethrow;
    }
  }

  /// ✅ Thuật toán 1: Phân chia tổng số đánh giá cho N khoa một cách ngẫu nhiên nhưng đảm bảo tổng = targetSum
  static List<int> _distributeReviews(int targetSum, int numKhoa) {
    if (numKhoa == 0) return [];
    if (numKhoa == 1) return [targetSum];

    List<double> weights = List.generate(numKhoa, (_) => _random.nextDouble() + 0.1);
    double totalWeight = weights.reduce((a, b) => a + b);
    
    List<int> result = weights.map((w) => ((w / totalWeight) * targetSum).round()).toList();
    
    int currentSum = result.reduce((a, b) => a + b);
    int diff = targetSum - currentSum;
    
    if (diff > 0) {
      result[0] += diff;
    } else if (diff < 0) {
      for (int i = 0; i < numKhoa && diff < 0; i++) {
        if (result[i] > 0) {
          result[i]--;
          diff++;
        }
      }
    }
    
    result.shuffle(_random);
    return result;
  }

  /// ✅ Thuật toán 2: Tạo điểm đánh giá xoay quanh mức trung bình mục tiêu
  static int _generateRatingForTarget(double targetAvg) {
    double noise = (_random.nextDouble() * 3.0) - 1.5; 
    int rating = (targetAvg + noise).round();
    return rating.clamp(1, 5);
  }

  static Future<void> seedAllDanhGia() async {
    print('⏳ Bắt đầu seeding toàn bộ đánh giá...\n');
    await seedDanhGiaChoTatCa();
    print('\n🎉 HOÀN TẤT TOÀN BỘ SEEDING ĐÁNH GIÁ!');
  }
}

/// Gom nhiều lệnh ghi vào 1 batch (Firestore cho tối đa 500 lệnh / batch).
/// Gom nhiều lệnh ghi vào 1 batch (Firestore cho tối đa 500 lệnh / batch).
class _BatchWriter {
  final FirebaseFirestore _db;
  WriteBatch? _batch; // ✅ Cho phép null
  int _count = 0;

  _BatchWriter(this._db) {
    _batch = _db.batch();
  }

  Future<void> set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    // ✅ Đảm bảo batch không null
    if (_batch == null) {
      _batch = _db.batch();
      _count = 0;
    }
    
    _batch!.set(ref, data);
    _count++;
    
    // Commit khi đạt 400 để an toàn (dưới giới hạn 500 của Firestore)
    if (_count >= 400) {
      await flush();
    }
  }

  Future<void> flush() async {
    // ✅ Chỉ commit nếu có dữ liệu và batch không null
    if (_count == 0 || _batch == null) {
      return;
    }
    
    try {
      await _batch!.commit();
    } catch (e) {
      print('❌ Lỗi khi commit batch: $e');
      rethrow;
    }
    
    // ✅ Reset batch và count
    _batch = _db.batch();
    _count = 0;
  }
}