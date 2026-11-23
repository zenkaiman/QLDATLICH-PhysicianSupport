import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThongBaoSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Random _random = Random();

  static const String _colLoaiThongBao = 'LoaiThongBao';
  static const String _colThongBao = 'ThongBao';
  static const String _subColDanhSach = 'danh_sach';
  
  // ✅ ID bệnh nhân mục tiêu
  static const String _targetBenhNhanId = 'dfAB917v6fRylNd1CiZWBdgFjdk1';

  /// 1. Seeder cho Collection "Loại thông báo"
  static Future<void> seedLoaiThongBao() async {
    print('⏳ Đang tạo dữ liệu cho collection: $_colLoaiThongBao...');
    
    final List<Map<String, dynamic>> loaiThongBaoData = [
      {
        'id': 'he_thong',
        'ten_loai': 'Hệ thống',
        'mo_ta': 'Các thông báo cập nhật, bảo trì hoặc chính sách từ quản trị viên.',
        'icon': 'settings',
        'mau_sac': '#2196F3', // Xanh dương
      },
      {
        'id': 'benh_vien_xac_nhan',
        'ten_loai': 'Xác nhận lịch',
        'mo_ta': 'Thông báo khi lịch hẹn của bệnh nhân được bệnh viện duyệt thành công.',
        'icon': 'check_circle',
        'mau_sac': '#4CAF50', // Xanh lá
      },
      {
        'id': 'benh_vien_huy_lich',
        'ten_loai': 'Hủy lịch',
        'mo_ta': 'Thông báo khi lịch hẹn không được duyệt hoặc bị hủy.',
        'icon': 'cancel',
        'mau_sac': '#F44336', // Đỏ
      },
      {
        'id': 'benh_vien_nhan_nho',
        'ten_loai': 'Nhắc nhở',
        'mo_ta': 'Thông báo nhắc nhở, ví dụ như khi bệnh nhân đến trễ giờ khám.',
        'icon': 'alarm',
        'mau_sac': '#FF9800', // Cam
      },
      {
        'id': 'benh_vien_thong_bao',
        'ten_loai': 'Hoàn thành & Đánh giá',
        'mo_ta': 'Thông báo khi bệnh nhân đã hoàn thành quy trình khám và được kêu gọi đánh giá.',
        'icon': 'star',
        'mau_sac': '#9C27B0', // Tím
      },
    ];

    final writer = _BatchWriter(_firestore);
    for (var data in loaiThongBaoData) {
      final docRef = _firestore.collection(_colLoaiThongBao).doc(data['id']);
      await writer.set(docRef, data);
    }
    await writer.flush();
    print('✅ Đã tạo thành công ${loaiThongBaoData.length} loại thông báo.\n');
  }

  /// 2. Seeder chính: Tạo thông báo cho 1 bệnh nhân cụ thể
  static Future<void> seedThongBaoChoBenhNhan() async {
    print('⏳ Bắt đầu tạo dữ liệu thông báo cho bệnh nhân: $_targetBenhNhanId...');

    final writer = _BatchWriter(_firestore);
    int totalCreated = 0;
    
    // ✅ Bộ đếm số thứ tự riêng cho từng loại mới
    Map<String, int> sequenceCounters = {
      'he_thong': 1, 
      'benh_vien_xac_nhan': 1, 
      'benh_vien_huy_lich': 1, 
      'benh_vien_nhan_nho': 1, 
      'benh_vien_thong_bao': 1
    };

    // ✅ Kho mẫu nội dung thông báo (Templates) đã được cập nhật
    final List<Map<String, dynamic>> templates = [
      // 1. XÁC NHẬN (Lịch đã được duyệt)
      {
        'loai': 'benh_vien_xac_nhan',
        'tieu_de': 'Lịch hẹn của bạn đã được xác nhận',
        'noi_dung': 'Lịch khám của bạn tại khoa {khoa} đã được bệnh viện duyệt thành công. Vui lòng đến đúng giờ hẹn.',
        'hasPhongKham': false,
      },
      // 2. HỦY LỊCH (Lịch không được duyệt)
      {
        'loai': 'benh_vien_huy_lich',
        'tieu_de': 'Lịch hẹn của bạn đã bị hủy',
        'noi_dung': 'Rất tiếc, lịch khám của bạn tại khoa {khoa} không thể thực hiện và đã bị hủy. Vui lòng đặt lịch mới.',
        'hasPhongKham': false,
      },
      // 3. NHẮC NHỞ (Bệnh nhân đến trễ)
      {
        'loai': 'benh_vien_nhan_nho',
        'tieu_de': 'Cảnh báo trễ giờ khám',
        'noi_dung': 'Bạn đã đến trễ so với giờ hẹn ban đầu. Bạn đã được chuyển vào hàng chờ trễ. Vui lòng di chuyển đến {phong_kham} sớm nhất để được khám.',
        'hasPhongKham': true, // ✅ Có phòng khám cụ thể
      },
      // 4. THÔNG BÁO (Hoàn thành khám & Kêu gọi đánh giá)
      {
        'loai': 'benh_vien_thong_bao',
        'tieu_de': 'Hoàn thành khám & Đánh giá trải nghiệm',
        'noi_dung': 'Cảm ơn bạn đã hoàn thành quy trình khám tại khoa {khoa}. Hãy dành chút thời gian đánh giá trải nghiệm của bạn để chúng tôi phục vụ tốt hơn!',
        'hasPhongKham': false,
      },
      // 5. HỆ THỐNG (Mẫu phụ)
      {
        'loai': 'he_thong',
        'tieu_de': 'Chào mừng bạn đến với ứng dụng',
        'noi_dung': 'Cảm ơn bạn đã sử dụng dịch vụ đặt lịch khám. Hãy khám phá các tính năng mới để chăm sóc sức khỏe tốt hơn.',
        'hasPhongKham': false,
      },
    ];

    // Tạo 15 thông báo mẫu rải rác trong 15 ngày qua
    final int soLuongThongBao = 15;

    for (int i = 0; i < soLuongThongBao; i++) {
      // Chọn ngẫu nhiên 1 mẫu
      var template = templates[_random.nextInt(templates.length)];
      String loaiThongBao = template['loai'];
      
      // Tăng số thứ tự và format thành 4 chữ số (0001, 0002...)
      int seq = sequenceCounters[loaiThongBao]!;
      sequenceCounters[loaiThongBao] = seq + 1;
      String thongBaoId = 'TB_${loaiThongBao}_${seq.toString().padLeft(4, '0')}';

      // Dữ liệu giả lập
      String benhVienId = 'BV016';
      String khoaId = 'K001';
      String tenKhoa = 'Nội tổng quát';
      
      // ✅ Xử lý phòng khám: Null nếu không cần, có giá trị nếu là thông báo trễ giờ
      String? phongKhamId = (template['hasPhongKham'] == true) 
          ? '${benhVienId}_${khoaId}_KSNK001' 
          : null;
          
      String tenPhongKham = phongKhamId != null ? 'Phòng khám số 3 (Tầng 2)' : 'phòng khám được chỉ định';

      // Tạo ID lịch hẹn giả lập dựa trên thời gian tạo thông báo (đảm bảo unique)
      DateTime ngayTao = DateTime.now().subtract(Duration(days: i, hours: _random.nextInt(12)));
      String lichHenId = 'LH_20261029_00001';

      // Thay thế biến động trong nội dung
      String tieuDe = template['tieu_de']
          .replaceAll('{khoa}', tenKhoa)
          .replaceAll('{phong_kham}', tenPhongKham);
          
      String noiDung = template['noi_dung']
          .replaceAll('{khoa}', tenKhoa)
          .replaceAll('{phong_kham}', tenPhongKham);

      // ✅ Cấu trúc dữ liệu Flat trong document thông báo
      final thongBaoData = {
        'thong_bao_id': thongBaoId,
        'benh_vien_id': benhVienId,
        'khoa_id': khoaId,
        'phong_kham_id': phongKhamId, // Có thể là null
        'lich_hen_id': lichHenId,
        'ngay_tao': Timestamp.fromDate(ngayTao),
        'benh_nhan_id': _targetBenhNhanId,
        'loai_thong_bao': loaiThongBao, // Tham chiếu đến collection LoaiThongBao
        'tieu_de': tieuDe,
        'noi_dung': noiDung,
        'da_doc': i > 4 ? true : false, // 5 thông báo mới nhất chưa đọc (false), còn lại đã đọc (true)
      };

      // ✅ Đường dẫn: ThongBao/{benh_nhan_id}/danh_sach/{thong_bao_id}
      final docRef = _firestore
          .collection(_colThongBao)
          .doc(_targetBenhNhanId)
          .collection(_subColDanhSach)
          .doc(thongBaoId);

      await writer.set(docRef, thongBaoData);
      totalCreated++;
    }

    await writer.flush(); // Ghi nốt phần còn lại trong batch
    
    print('\n🎉 HOÀN TẤT SEEDING THÔNG BÁO!');
    print('📊 Đã tạo thành công $totalCreated thông báo cho bệnh nhân $_targetBenhNhanId');
  }

  /// Hàm chạy toàn bộ quy trình
  static Future<void> seedAllThongBao() async {
    print('⏳ Bắt đầu seeding toàn bộ hệ thống thông báo...\n');
    await seedLoaiThongBao();
    await seedThongBaoChoBenhNhan();
    print('\n🎉 HOÀN TẤT TOÀN BỘ SEEDING THÔNG BÁO!');
  }
}

/// Gom nhiều lệnh ghi vào 1 batch (Firestore cho tối đa 500 lệnh / batch).
class _BatchWriter {
  final FirebaseFirestore _db;
  WriteBatch? _batch;
  int _count = 0;

  _BatchWriter(this._db) {
    _batch = _db.batch();
  }

  Future<void> set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
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
    if (_count == 0 || _batch == null) return;
    
    try {
      await _batch!.commit();
    } catch (e) {
      print('❌ Lỗi khi commit batch: $e');
      rethrow;
    }
    
    _batch = _db.batch();
    _count = 0;
  }
}