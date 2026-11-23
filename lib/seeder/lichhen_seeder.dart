import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class LichHenSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Random _random = Random();

  // ✅ CẤU TRÚC MỚI: Collection cấp cao nhất, không còn nesting
  static const String _colLichHen = 'LichHen';
  static const String _benhVienId = 'BV001';
  static const String _tenBenhVien =
      'Bệnh Viện Mẫu'; // Nên lấy từ DB thật, ở đây hardcode để seed nhanh

  /// Các ngày cần seed: 18, 19, 20, 21, 22 / 10 / 2026
  static final List<DateTime> _danhSachNgayHen = [
    DateTime(2026, 10, 18),
    DateTime(2026, 10, 19),
    DateTime(2026, 10, 20),
    DateTime(2026, 10, 21),
    DateTime(2026, 10, 22),
  ];

  static const List<Map<String, String>> _danhSachCa = [
    {
      'id': 'ca_sang',
      'ten_ca': 'Ca sáng',
      'gio_bat_dau': '07:30',
      'gio_ket_thuc': '12:00',
    },
    {
      'id': 'ca_chieu',
      'ten_ca': 'Ca chiều',
      'gio_bat_dau': '13:30',
      'gio_ket_thuc': '17:00',
    },
  ];

  // ───────────────────────── Hàm định dạng ngày ─────────────────────────
  static String _ngayCode(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  static String _ngayHienThi(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ═══════════════════════════════════════════════════════════════
  // 1. SEED BẢNG CA (Giữ nguyên vì đây là collection tham chiếu)
  // ═══════════════════════════════════════════════════════════════
  static Future<void> seedCaKham() async {
    print('⏳ Đang tạo dữ liệu ca khám...');
    try {
      for (final ca in _danhSachCa) {
        await _firestore.collection('Ca').doc(ca['id']).set({
          'id': ca['id'],
          'ten_ca': ca['ten_ca'],
          'gio_bat_dau': ca['gio_bat_dau'],
          'gio_ket_thuc': ca['gio_ket_thuc'],
          'ngay_tao': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      print('✅ Hoàn tất seeding bảng Ca!\n');
    } catch (e) {
      print('❌ Lỗi khi seed bảng Ca: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. SEED LỊCH HẸN (CẤU TRÚC FLAT - TỐI ƯU)
  // ═══════════════════════════════════════════════════════════════
  static Future<void> seedLichHen({bool force = false}) async {
    print('⏳ Đang tạo lịch hẹn (Cấu trúc Flat)...');

    try {
      // ── 1. Kiểm tra bệnh viện ──
      final hospitalDoc = await _firestore
          .collection('BenhVien')
          .doc(_benhVienId)
          .get();
      if (!hospitalDoc.exists) {
        throw Exception(
          'Không tìm thấy bệnh viện $_benhVienId. Hãy seed bệnh viện trước.',
        );
      }
      final tenBenhVien = hospitalDoc.data()?['ten_benh_vien'] ?? _tenBenhVien;

      // ── 2. Lấy tất cả khoa của BV001 ──
      final khoaSnapshot = await _firestore
          .collection('Khoa')
          .doc(_benhVienId)
          .collection('danh_sach')
          .get();

      if (khoaSnapshot.docs.isEmpty) {
        throw Exception('$_benhVienId chưa có khoa nào. Hãy seed Khoa trước.');
      }
      print('🔍 Tìm thấy ${khoaSnapshot.docs.length} khoa của $_benhVienId');

      // ── 3. Lấy phòng khám (✅ ĐÃ CẬP NHẬT: Query từ cấu trúc Flat 'phong_kham') ──
      final List<_KhoaVaPhongKham> khoaList = [];
      for (final khoaDoc in khoaSnapshot.docs) {
        final khoaId = khoaDoc.id;
        final tenKhoa = (khoaDoc.data()['ten_khoa'] ?? 'Khoa').toString();

        // Query trực tiếp collection 'phong_kham' theo hospitalId và khoaId
        final phongKhamSnapshot = await _firestore
            .collection('PhongKham')
            .where('hospitalId', isEqualTo: _benhVienId)
            .where('khoaId', isEqualTo: khoaId)
            .get();

        if (phongKhamSnapshot.docs.isEmpty) {
          print('   ⚠️ Khoa $tenKhoa ($khoaId) chưa có phòng khám nào, bỏ qua');
          continue;
        }

        print(
          '   🔬 Khoa $tenKhoa ($khoaId): ${phongKhamSnapshot.docs.length} phòng khám',
        );
        khoaList.add(_KhoaVaPhongKham(khoaId, tenKhoa, phongKhamSnapshot.docs));
      }

      if (khoaList.isEmpty) {
        throw Exception('Không có khoa nào có phòng khám để tạo lịch hẹn');
      }

      // ── 4. Seed dữ liệu lịch hẹn ──
      int tongLichHen = 0;
      final writer = _BatchWriter(_firestore);

      for (final ngay in _danhSachNgayHen) {
        final ngayCode = _ngayCode(ngay);
        int sttNgay = 0; // Số thứ tự tăng dần trong ngày

        for (final ca in _danhSachCa) {
          for (final khoa in khoaList) {
            for (final phongKhamDoc in khoa.phongKham) {
              final phongKhamId = phongKhamDoc.id;
              final soBenhNhanToiDa = max(
                1,
                (phongKhamDoc.data()['soBenhNhanToiDa'] as num?)?.toInt() ?? 25,
              );

              // Số bệnh nhân ngẫu nhiên của phòng khám này trong ca này
              final soBenhNhan = _random.nextInt(soBenhNhanToiDa) + 1;

              for (int i = 1; i <= soBenhNhan; i++) {
                sttNgay++;
                tongLichHen++;

                final benhNhanId =
                    'BN${tongLichHen.toString().padLeft(4, '0')}';
                final lichHenId =
                    'LH_${ngayCode}_${sttNgay.toString().padLeft(5, '0')}';

                // Giờ dự kiến ngẫu nhiên trong ca
                final int hour = ca['id'] == 'ca_sang'
                    ? _random.nextInt(5) +
                          7 // 7 - 11
                    : _random.nextInt(4) + 13; // 13 - 16
                final int minute = _random.nextInt(4) * 15; // 0, 15, 30, 45
                final gioDuKien =
                    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

                // ✅ DỮ LIỆU FLAT: Tất cả trong 1 document duy nhất (Denormalized)
                final lichHenData = {
                  'id': lichHenId,
                  'benh_nhan_id': benhNhanId,
                  'benh_vien_id': _benhVienId,
                  'ten_benh_vien':
                      tenBenhVien, // Denormalize: Lưu sẵn tên để không cần join
                  'khoa_id': khoa.id,
                  'ten_khoa': khoa.ten, // Denormalize
                  'phong_kham_id': phongKhamId,
                  'ngay_hen': Timestamp.fromDate(ngay),
                  'ca_id': ca['id'],
                  'ten_ca': ca['ten_ca'],
                  'gio_du_kien': gioDuKien,
                  'so_thu_tu': sttNgay,
                  'trang_thai_id': 2, // 2: Đã xác nhận
                  'ma_qr': 'QR_$lichHenId',
                  'qr_da_su_dung': 0,
                  'ngay_tao': FieldValue.serverTimestamp(),
                  'ngay_cap_nhat': FieldValue.serverTimestamp(),
                };

                // ✅ Ghi trực tiếp vào collection cấp cao nhất 'lich_hen'
                final docRef = _firestore
                    .collection(_colLichHen)
                    .doc(lichHenId);
                await writer.set(docRef, lichHenData);

                if (tongLichHen % 200 == 0) {
                  print('   ✅ Đã tạo $tongLichHen lịch hẹn...');
                }
              }
            }
          }
        }
      }

      await writer.flush(); // Ghi nốt phần còn lại
      print('\n🎉 HOÀN TẤT SEEDING LỊCH HẸN!');
      print('📊 Tổng số lịch hẹn đã tạo: $tongLichHen');
      print('🏥 Bệnh viện: $_benhVienId');
      print('🏷️ Số khoa có phòng khám: ${khoaList.length}');
    } catch (e) {
      print('❌ Lỗi khi seed lịch hẹn: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. SEED 1 LỊCH HẸN TEST CHO UID CỤ THỂ (CẤU TRÚC FLAT)
  // ═══════════════════════════════════════════════════════════════
  /// Tạo duy nhất 1 lịch hẹn test cho một UID cụ thể, tự động lấy tên từ Database
  static Future<void> seedSingleTestAppointment({
    String benhNhanId = 'dfAB917v6fRylNd1CiZWBdgFjdk1',
    String benhVienId = 'BV001',
    String khoaId = 'K001',
    String phongKhamId = 'NTQ001',
  }) async {
    print('⏳ Đang tạo 1 lịch hẹn test cho UID: $benhNhanId...');

    // ✅ 1. Tự động lấy TÊN BỆNH VIỆN dựa trên benhVienId
    String tenBenhVien = 'Không xác định';
    final hospitalDoc = await _firestore
        .collection('BenhVien')
        .doc(benhVienId)
        .get();
    if (hospitalDoc.exists) {
      tenBenhVien = hospitalDoc.data()?['ten_benh_vien'] ?? 'Không xác định';
    } else {
      throw Exception(
        '❌ Không tìm thấy bệnh viện với ID: $benhVienId trong Firestore.',
      );
    }

    // ✅ 2. Tự động lấy TÊN KHOA dựa trên khoaId (trong subcollection của bệnh viện đó)
    String tenKhoa = 'Không xác định';
    final khoaDoc = await _firestore
        .collection('Khoa')
        .doc(benhVienId)
        .collection('danh_sach')
        .doc(khoaId)
        .get();

    if (khoaDoc.exists) {
      tenKhoa = khoaDoc.data()?['ten_khoa'] ?? 'Không xác định';
    } else {
      print(
        '⚠️ Cảnh báo: Không tìm thấy khoa với ID: $khoaId. Sẽ dùng tên mặc định.',
      );
    }

    final targetDate = DateTime(2026, 10, 21);
    final lichHenId = 'LH_TEST_${DateTime.now().millisecondsSinceEpoch}';

    // ✅ Dữ liệu Flat cho 1 lịch hẹn test (Đã cập nhật tên thật từ DB)
    final lichHenData = {
      'id': lichHenId,
      'benh_nhan_id': benhNhanId,
      'benh_vien_id': benhVienId,
      'ten_benh_vien': tenBenhVien, // ✅ Tên thật lấy từ DB
      'khoa_id': khoaId,
      'ten_khoa': tenKhoa, // ✅ Tên thật lấy từ DB
      'phong_kham_id': phongKhamId,
      'ngay_dat': Timestamp.fromDate(targetDate),
      'ca_id': 'ca_sang',
      'ten_ca': 'Ca sáng',
      'gio_du_kien': '08:00',
      'so_thu_tu': 1,
      'trang_thai_id': 2,
      'ma_qr': 'QR_TEST_${DateTime.now().millisecondsSinceEpoch}',
      'qr_da_su_dung': 0,
      'ngay_tao': FieldValue.serverTimestamp(),
      'ngay_cap_nhat': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection(_colLichHen).doc(lichHenId).set(lichHenData);
      print('✅ ĐÃ TẠO THÀNH CÔNG lịch hẹn test! ID: $lichHenId');
      print('   👤 UID Bệnh nhân : $benhNhanId');
      print('   🏥 Bệnh viện     : $tenBenhVien ($benhVienId)');
      print('   🔬 Khoa          : $tenKhoa ($khoaId)');
      print('   📅 Ngày khám      : ${_ngayHienThi(targetDate)}');
      print('   🔖 Trạng thái     : 2 (Đã xác nhận)');
    } catch (e) {
      print('❌ Lỗi khi tạo lịch hẹn test: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. SEED 10 LỊCH HẸN ĐỂ TEST MÀN HÌNH THEO DÕI HÀNG CHỜ
  // ═══════════════════════════════════════════════════════════════
  /// Tạo 10 lịch hẹn cho cùng 1 ngày, cùng 1 phòng khám để test real-time queue.
  /// Bệnh nhân chỉ định sẽ nằm ở số thứ tự 5 (giữa hàng chờ).
  static Future<void> seedQueueTestAppointments({
    String benhVienId = 'BV502',
    String khoaId = 'K001',
    String phongKhamId = 'BV502_K001_HH001',
  }) async {
    print(
      '⏳ Đang tạo 10 lịch hẹn test hàng chờ ngẫu nhiên cho ngày 04/11/2026...',
    );

    // 1. Tự động lấy TÊN BỆNH VIỆN
    String tenBenhVien = 'Không xác định';
    final hospitalDoc = await _firestore
        .collection('BenhVien')
        .doc(benhVienId)
        .get();
    if (hospitalDoc.exists) {
      tenBenhVien = hospitalDoc.data()?['ten_benh_vien'] ?? 'Không xác định';
    }

    // 2. Tự động lấy TÊN KHOA
    String tenKhoa = 'Không xác định';
    final khoaDoc = await _firestore
        .collection('Khoa')
        .doc(benhVienId)
        .collection('danh_sach')
        .doc(khoaId)
        .get();
    if (khoaDoc.exists) {
      tenKhoa = khoaDoc.data()?['ten_khoa'] ?? 'Không xác định';
    }

    final targetDate = DateTime(2026, 11, 4);
    final totalAppointments = 15;

    final writer = _BatchWriter(_firestore);

    for (int stt = 11; stt <= totalAppointments; stt++) {
      // ✅ LUÔN tạo UID ngẫu nhiên cho mọi lịch hẹn (không còn bệnh nhân cụ thể)
      final benhNhanId = 'BN_RAND_${stt}_${_random.nextInt(99999)}';

      final lichHenId =
          'LH_QUEUE_${_ngayCode(targetDate)}_${stt.toString().padLeft(5, '0')}';

      // Tạo giờ dự kiến cách nhau 15 phút (08:00, 08:15, 08:30...)
      final int hour = 8 + ((stt - 1) * 15) ~/ 60;
      final int minute = ((stt - 1) * 15) % 60;
      final gioDuKien =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      final lichHenData = {
        'id': lichHenId,
        'benh_nhan_id': benhNhanId,
        'benh_vien_id': benhVienId,
        'ten_benh_vien': tenBenhVien,
        'khoa_id': khoaId,
        'ten_khoa': tenKhoa,
        'phong_kham_id': phongKhamId,
        'ngay_dat': Timestamp.fromDate(targetDate),
        'ca_id': 'ca_chieu',
        'ten_ca': 'Ca chiều',
        'so_thu_tu': stt,
        'trang_thai_id': 2,
        'ma_qr': 'QR_$lichHenId',
        'qr_da_su_dung': 0,
        'ngay_tao': FieldValue.serverTimestamp(),
        'ngay_cap_nhat': FieldValue.serverTimestamp(),
      };

      await writer.set(
        _firestore.collection(_colLichHen).doc(lichHenId),
        lichHenData,
      );
    }

    await writer.flush();

    print('✅ ĐÃ TẠO THÀNH CÔNG 10 lịch hẹn test hàng chờ ngẫu nhiên!');
    print('   📅 Ngày khám      : 04/11/2026');
    print('   🏥 Bệnh viện      : $tenBenhVien ($benhVienId)');
    print('   🔬 Khoa           : $tenKhoa ($khoaId)');
    print('   🔄 Tất cả 10 lịch hẹn đều có UID ngẫu nhiên (STT 1 đến 10).');
  }

    // ═══════════════════════════════════════════════════════════════
  // 6. SEED 39 LỊCH HẸN CỤ THỂ CHO 1 PHÒNG KHÁM (CA SÁNG)
  // ═══════════════════════════════════════════════════════════════
  /// Tạo chính xác 39 lịch hẹn cho BV001, Khoa K001, Phòng BV001_K001_NGT001
  /// Ngày: 10/11/2026, Ca sáng. Thời gian được phân bổ đều từ 07:30 đến 11:24.
  static Future<void> seed39AppointmentsForSpecificRoom({
    String benhVienId = 'BV001',
    String khoaId = 'K001',
    String phongKhamId = 'BV001_K001_NGT001',
    String caId = 'ca_sang',
    DateTime? targetDate,
    int totalAppointments = 25,
  }) async {
    final appointmentDate = targetDate ?? DateTime(2026, 11, 10);
    print('⏳ Đang tạo $totalAppointments lịch hẹn cho phòng khám $phongKhamId...');

    // 1. Tự động lấy TÊN BỆNH VIỆN
    String tenBenhVien = 'Không xác định';
    final hospitalDoc = await _firestore.collection('BenhVien').doc(benhVienId).get();
    if (hospitalDoc.exists) {
      tenBenhVien = hospitalDoc.data()?['ten_benh_vien'] ?? 'Không xác định';
    }

    // 2. Tự động lấy TÊN KHOA
    String tenKhoa = 'Không xác định';
    final khoaDoc = await _firestore
        .collection('Khoa')
        .doc(benhVienId)
        .collection('danh_sach')
        .doc(khoaId)
        .get();
    if (khoaDoc.exists) {
      tenKhoa = khoaDoc.data()?['ten_khoa'] ?? 'Không xác định';
    }

    final writer = _BatchWriter(_firestore);
    final ngayCode = _ngayCode(appointmentDate);

    for (int stt = 1; stt <= totalAppointments; stt++) {
      // Tạo UID bệnh nhân giả lập có quy tắc
      final benhNhanId = 'BN_SPEC_${stt.toString().padLeft(3, '0')}';
      final lichHenId = 'LH_SPEC_${ngayCode}_${stt.toString().padLeft(5, '0')}';

      // ✅ LOGIC PHÂN BỔ GIỜ: 
      // Ca sáng bắt đầu 07:30. 39 bệnh nhân / ~4 giờ = ~6 phút/bệnh nhân.
      // Điều này đảm bảo giờ khám nằm gọn trong khoảng 07:30 - 12:00
      final int minutesToAdd = (stt - 1) * 6; 
      final DateTime appointmentTime = DateTime(
        appointmentDate.year, 
        appointmentDate.month, 
        appointmentDate.day, 
        7, 30 // Bắt đầu lúc 07:30
      ).add(Duration(minutes: minutesToAdd));
      
      final gioDuKien = '${appointmentTime.hour.toString().padLeft(2, '0')}:${appointmentTime.minute.toString().padLeft(2, '0')}';

      final lichHenData = {
        'id': lichHenId,
        'benh_nhan_id': benhNhanId,
        'benh_vien_id': benhVienId,
        'ten_benh_vien': tenBenhVien,
        'khoa_id': khoaId,
        'ten_khoa': tenKhoa,
        'phong_kham_id': phongKhamId,
        'ngay_dat': Timestamp.fromDate(appointmentDate),
        'ca_id': caId,
        'ten_ca': 'Ca sáng',
        'gio_du_kien': gioDuKien,
        'so_thu_tu': stt,
        'trang_thai_id': 2, // 2: Đã xác nhận (sẵn sàng để test check-in)
        'ma_qr': 'QR_$lichHenId',
        'qr_da_su_dung': 0,
        'ngay_tao': FieldValue.serverTimestamp(),
        'ngay_cap_nhat': FieldValue.serverTimestamp(),
      };

      await writer.set(
        _firestore.collection(_colLichHen).doc(lichHenId),
        lichHenData,
      );
    }

    await writer.flush();

    print('✅ ĐÃ TẠO THÀNH CÔNG $totalAppointments lịch hẹn cụ thể!');
    print('   📅 Ngày khám      : ${_ngayHienThi(appointmentDate)}');
    print('   🏥 Bệnh viện      : $tenBenhVien ($benhVienId)');
    print('   🔬 Khoa           : $tenKhoa ($khoaId)');
    print('   🚪 Phòng khám     : $phongKhamId');
    print('   ⏰ Khung giờ      : 07:30 đến 11:24 (Ca sáng, cách đều ~6 phút)');
    print('   🔖 Trạng thái     : 2 (Đã xác nhận)');
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. CHẠY TẤT CẢ
  // ═══════════════════════════════════════════════════════════════
  static Future<void> seedAllLichHen() async {
    print('⏳ Bắt đầu quá trình seeding lịch hẹn...\n');
    try {
      await seedCaKham();
      await seedLichHen();
      await seedSingleTestAppointment();
      print('\n🎉 HOÀN TẤT TOÀN BỘ SEEDING LỊCH HẸN!');
    } catch (error) {
      print('❌ Seeder thất bại: $error');
    }
  }
}

/// Khoa kèm danh sách phòng khám của khoa đó.
class _KhoaVaPhongKham {
  final String id;
  final String ten;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> phongKham;

  _KhoaVaPhongKham(this.id, this.ten, this.phongKham);
}

/// Gom nhiều lệnh ghi vào 1 batch (Firestore cho tối đa 500 lệnh / batch).
class _BatchWriter {
  final FirebaseFirestore _db;
  WriteBatch _batch;
  int _count = 0;

  _BatchWriter(this._db) : _batch = _db.batch();

  Future<void> set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    _batch.set(ref, data);
    _count++;
    if (_count >= 400) await flush(); // Commit khi đạt 400 để an toàn
  }

  Future<void> flush() async {
    if (_count == 0) return;
    await _batch.commit();
    _batch = _db.batch();
    _count = 0;
  }
}
