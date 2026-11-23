import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhongKhamSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Random _random = Random();

  // ==========================================
  // 1. MAPPING TÊN KHOA → PREFIX
  // ==========================================
  static final Map<String, String> _khoaPrefixMap = {
    'Khoa Nội tổng quát': 'NTQ', 'Khoa Ngoại tổng quát': 'NGT', 'Khoa Cấp cứu': 'CC',
    'Khoa Tim mạch': 'TM', 'Khoa Tiêu hóa': 'TH', 'Khoa Hô hấp': 'HH',
    'Khoa Thần kinh': 'TK', 'Khoa Cơ xương khớp': 'CXK', 'Khoa Sản phụ khoa': 'SPK',
    'Khoa Nhi': 'N', 'Khoa Mắt': 'M', 'Khoa Tai Mũi Họng': 'TMH',
    'Khoa Răng Hàm Mặt': 'NHM', 'Khoa Da liễu': 'DL', 'Khoa Ung bướu': 'UB',
    'Khoa Thận - Tiết niệu': 'TNU', 'Khoa Nội tiết': 'NT', 'Khoa Truyền nhiễm': 'TRI',
    'Khoa Hồi sức tích cực (ICU)': 'HS', 'Khoa Gây mê hồi sức': 'GM',
    'Khoa Chẩn đoán hình ảnh': 'CDHA', 'Khoa Xét nghiệm': 'XN',
    'Khoa Vật lý trị liệu': 'VLTL', 'Khoa Tâm thần': 'TT',
    'Khoa Y học cổ truyền': 'YHCT', 'Khoa Dinh dưỡng': 'DD',
    'Khoa Huyết học': 'HUY', 'Khoa Lão khoa': 'LK', 'Khoa Thẩm mỹ': 'THM',
    'Khoa Kiểm soát nhiễm khuẩn': 'KSNK',
  };

  static final List<String> _gioMoCua = ['07:00:00', '07:30:00', '08:00:00', '08:30:00'];
  static final List<String> _gioDongCua = ['16:00:00', '16:30:00', '17:00:00', '17:30:00', '18:00:00'];

  static const int _maxBatchSize = 400; // Firestore cho tối đa 500 lệnh / batch
  static const int _hospitalsPerChunk = 10; // số bệnh viện đọc song song mỗi lượt

  // Lấy id các bệnh viện: chỉ đọc document bệnh viện (role = benh_vien),
  // KHÔNG quét mọi collection 'danh_sach' (Khoa, phòng khám, chuyên khoa... cũng tên đó).
  static Future<List<String>> _loadHospitalIds() async {
    final snapshot = await _firestore
        .collection('BenhVien')
        .get();
    return snapshot.docs.map((d) => d.id).toList();
  }

  /// Tạo dữ liệu Phòng Khám theo cấu trúc FLAT.
  /// Collection: PhongKham (Top-level), Document ID: {hospitalId}_{khoaId}_{tenPhong}
  ///
  /// [hospitalIds]: chỉ seed các bệnh viện này (vd ['BV001'] để thử). null = tất cả.
  /// [force]: false thì bỏ qua nếu collection PhongKham đã có dữ liệu.
  static Future<void> seedPhongKham({
    List<String>? hospitalIds,
    bool force = false,
  }) async {
    print('⏳ Bắt đầu tạo dữ liệu Phòng Khám (Cấu trúc Flat)...');
    print('📋 collection("PhongKham").doc("{hospitalId}_{khoaId}_{roomName}")');

    try {
      // Đã seed rồi thì không chạy lại (tránh ghi đè dữ liệu mỗi lần mở app)
      if (!force) {
        final existed = await _firestore.collection('PhongKham').limit(1).get();
        if (existed.docs.isNotEmpty) {
          print(
            '⚠️ Đã có dữ liệu phong_kham, bỏ qua. '
            '(Gọi seedPhongKham(force: true) để seed lại)',
          );
          return;
        }
      }

      // 1. Danh sách bệnh viện
      final ids = hospitalIds ?? await _loadHospitalIds();
      print('🏥 Tìm thấy ${ids.length} bệnh viện cần seed.');

      int totalPhongKham = 0;
      int totalKhoa = 0;
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      // 2. Xử lý từng nhóm bệnh viện (đọc khoa của mỗi bệnh viện bằng 1 truy vấn nhỏ)
      for (int i = 0; i < ids.length; i += _hospitalsPerChunk) {
        final chunk = ids.sublist(i, min(i + _hospitalsPerChunk, ids.length));

        final khoaResults = await Future.wait(
          chunk.map((hospitalId) async {
            final snapshot = await _firestore
                .collection('Khoa')
                .doc(hospitalId)
                .collection('danh_sach')
                .get();
            return MapEntry(hospitalId, snapshot.docs);
          }),
        );

        // 3. Tạo 2-4 phòng khám cho mỗi khoa
        for (final entry in khoaResults) {
          final hospitalId = entry.key;

          for (final khoaDoc in entry.value) {
            final khoaId = khoaDoc.id;
            final tenKhoa = (khoaDoc.data()['ten_khoa'] ?? 'Khoa không tên').toString();
            final prefix = _khoaPrefixMap[tenKhoa] ?? 'PK';
            final numPhong = _random.nextInt(3) + 2;
            totalKhoa++;

            for (int r = 1; r <= numPhong; r++) {
              final roomName = '$prefix${r.toString().padLeft(3, '0')}';
              final docId = '${hospitalId}_${khoaId}_$roomName';

              batch.set(_firestore.collection('PhongKham').doc(docId), {
                'hospitalId': hospitalId,
                'khoaId': khoaId,
                'tenPhong': roomName,
                'tenKhoaGoc': tenKhoa,
                'prefixKhoa': prefix,
                'gioMoCua': _gioMoCua[_random.nextInt(_gioMoCua.length)],
                'gioDongCua': _gioDongCua[_random.nextInt(_gioDongCua.length)],
                'thoiGianKham': [15, 20, 30][_random.nextInt(3)],
                'soBenhNhanToiDa': 20 + _random.nextInt(31),
                'nhanVienId': null,
                'ngayTao': FieldValue.serverTimestamp(),
              });

              batchCount++;
              totalPhongKham++;

              // Đủ 400 lệnh thì ghi xuống Firestore rồi tạo batch mới
              if (batchCount >= _maxBatchSize) {
                await batch.commit();
                batch = _firestore.batch();
                batchCount = 0;
              }
            }
          }
        }

        print(
          '   ✅ Đã xử lý ${min(i + _hospitalsPerChunk, ids.length)}/${ids.length} '
          'bệnh viện ($totalPhongKham phòng khám)',
        );
      }

      // Ghi nốt phần còn lại
      if (batchCount > 0) await batch.commit();

      print('\n🎉 HOÀN TẤT SEEDING PHÒNG KHÁM!');
      print('📊 Số khoa: $totalKhoa · Số phòng khám đã tạo: $totalPhongKham');
    } catch (e) {
      print('❌ Lỗi nghiêm trọng khi seed phòng khám: $e');
      rethrow;
    }
  }
}