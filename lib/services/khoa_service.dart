import 'package:cloud_firestore/cloud_firestore.dart';

class KhungGio {
  final String batDau; // "07:30"
  final String ketThuc; // "11:30"
  const KhungGio(this.batDau, this.ketThuc);

  Map<String, dynamic> toMap() => {'batDau': batDau, 'ketThuc': ketThuc};
  String get text => '$batDau - $ketThuc';

  int get soPhut => _phut(ketThuc) - _phut(batDau);

  static int _phut(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }
}

class KhoaVuaTao {
  final String khoaId;
  final String tenKhoa;
  final int soCaMoiNgay;
  final int gioiHanBenhNhan;
  final List<KhungGio> khungGio;
  final String lichLamViec;

  const KhoaVuaTao({
    required this.khoaId,
    required this.tenKhoa,
    required this.soCaMoiNgay,
    required this.gioiHanBenhNhan,
    required this.khungGio,
    required this.lichLamViec,
  });
}

/// 2..7 = Thứ 2..Thứ 7, 8 = Chủ nhật
String nhanNgay(int d) => d == 8 ? 'CN' : 'Thứ $d';

/// [2,3,4,5,6,7] -> "Thứ 2 đến Thứ 7"; không liên tục -> "Thứ 2, Thứ 4, CN"
String taoLichLamViec(List<int> ngay) {
  final s = [...ngay]..sort();
  if (s.isEmpty) return '';
  if (s.length == 7) return 'Cả tuần';
  final lienTuc = s.length >= 3 && s.last - s.first == s.length - 1;
  if (lienTuc) return '${nhanNgay(s.first)} đến ${nhanNgay(s.last)}';
  return s.map(nhanNgay).join(', ');
}

/// "Phòng 405 - Tầng 4 ..." -> "405"; không tìm thấy -> ""
String tachSoPhong(String tenPhong) {
  final m = RegExp(r'[Pp]hòng\s*([0-9]+[A-Za-z]?)').firstMatch(tenPhong);
  return m?.group(1) ?? '';
}

class KhoaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================================================================
  // BẢNG TIỀN TỐ KHOA (PREFIX) CHUẨN TRÊN HỆ THỐNG FIREBASE
  // =========================================================================
  static const Map<String, String> khoaPrefixMap = {
    'Khoa Nội tổng quát': 'NTQ',
    'Khoa Ngoại tổng quát': 'NGT',
    'Khoa Cấp cứu': 'CC',
    'Khoa Tim mạch': 'TM',
    'Khoa Tiêu hóa': 'TH',
    'Khoa Hô hấp': 'HH',
    'Khoa Thần kinh': 'TK',
    'Khoa Cơ xương khớp': 'CXK',
    'Khoa Sản phụ khoa': 'SPK',
    'Khoa Nhi': 'N',
    'Khoa Mắt': 'M',
    'Khoa Tai Mũi Họng': 'TMH',
    'Khoa Răng Hàm Mặt': 'NHM',
    'Khoa Da liễu': 'DL',
    'Khoa Ung bướu': 'UB',
    'Khoa Thận - Tiết niệu': 'TNU',
    'Khoa Nội tiết': 'NT',
    'Khoa Truyền nhiễm': 'TRI',
    'Khoa Hồi sức tích cực (ICU)': 'HS',
    'Khoa Gây mê hồi sức': 'GM',
    'Khoa Chẩn đoán hình ảnh': 'CDHA',
    'Khoa Xét nghiệm': 'XN',
    'Khoa Vật lý trị liệu': 'VLTL',
    'Khoa Tâm thần': 'TT',
    'Khoa Y học cổ truyền': 'YHCT',
    'Khoa Dinh dưỡng': 'DD',
    'Khoa Huyết học': 'HUY',
    'Khoa Lão khoa': 'LK',
    'Khoa Thẩm mỹ': 'THM',
    'Khoa Kiểm soát nhiễm khuẩn': 'KSNK',
  };

  /// Lấy prefix cho phòng khám dựa trên tên khoa / tên chuyên khoa
  static String layPrefixKhoa(String tenKhoa, [String? tenChuyenKhoa]) {
    final tKhoa = tenKhoa.trim();
    if (khoaPrefixMap.containsKey(tKhoa)) return khoaPrefixMap[tKhoa]!;
    if (tenChuyenKhoa != null &&
        khoaPrefixMap.containsKey(tenChuyenKhoa.trim())) {
      return khoaPrefixMap[tenChuyenKhoa.trim()]!;
    }

    final fullKhoa = tKhoa.startsWith('Khoa ') ? tKhoa : 'Khoa $tKhoa';
    if (khoaPrefixMap.containsKey(fullKhoa)) return khoaPrefixMap[fullKhoa]!;

    for (final entry in khoaPrefixMap.entries) {
      final keyShort = entry.key.replaceAll('Khoa ', '').toLowerCase();
      if (tKhoa.toLowerCase().contains(keyShort) ||
          (tenChuyenKhoa != null &&
              entry.key.toLowerCase().contains(tenChuyenKhoa.toLowerCase()))) {
        return entry.value;
      }
    }

    final cleanName = tKhoa.replaceAll(RegExp(r'^[Kk]hoa\s+'), '').trim();
    final words = cleanName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isNotEmpty) {
      final prefix = words.map((w) => w[0].toUpperCase()).join();
      if (prefix.isNotEmpty) return prefix;
    }

    return 'PK';
  }

  /// Chuẩn hóa ID bệnh viện: ưu tiên mã dạng `BV001`
  Future<String> chuanHoaBenhVienId(String benhVienId) =>
      _chuanHoaBenhVienId(benhVienId);

  Future<String> _chuanHoaBenhVienId(String benhVienId) async {
    final trimmed = benhVienId.trim();
    if (trimmed.startsWith('BV')) return trimmed;

    try {
      final doc = await _db.collection('BenhVien').doc(trimmed).get();
      if (doc.exists) {
        final ma = (doc.data()?['ma_benh_vien'] ?? doc.data()?['maBenhVien'])
            ?.toString();
        if (ma != null && ma.isNotEmpty) return ma;
      }

      final query = await _db
          .collection('BenhVien')
          .where('auth_uid', isEqualTo: trimmed)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final ma =
            (query.docs.first.data()['ma_benh_vien'] ?? query.docs.first.id)
                .toString();
        if (ma.isNotEmpty) return ma;
      }
    } catch (_) {}

    return trimmed;
  }

  /// Sinh ID Khoa theo chuẩn Firebase: K001, K002, K003... (không dùng ID tự sinh hash)
  Future<String> taoKhoaIdTiepTheo(String benhVienId) async {
    final snap = await _db
        .collection('Khoa')
        .doc(benhVienId)
        .collection('danh_sach')
        .get();

    int maxNum = 0;
    final regex = RegExp(r'^K(\d+)$', caseSensitive: false);

    for (final doc in snap.docs) {
      final match = regex.firstMatch(doc.id);
      if (match != null) {
        final numVal = int.tryParse(match.group(1) ?? '') ?? 0;
        if (numVal > maxNum) {
          maxNum = numVal;
        }
      }
    }

    final nextNum = maxNum + 1;
    return 'K${nextNum.toString().padLeft(3, '0')}';
  }

  /// Tạo 1 document `Khoa/{benhVienId}/danh_sach/{K00x}` + N document `PhongKham` theo cấu trúc Firebase
  Future<KhoaVuaTao> themKhoa({
    required String benhVienId,
    required String tenKhoa,
    String? chuyenKhoaId,
    String? tenChuyenKhoa,
    required int soCaMoiNgay,
    required int gioiHanBenhNhan,
    required List<KhungGio> khungGio,
    required List<int> ngayLamViec,
    required List<String> phongKham,
  }) async {
    final bvId = await _chuanHoaBenhVienId(benhVienId);
    if (bvId.isEmpty) {
      throw Exception(
        'Chưa có benhVienId. Hãy truyền ID document trong collection BenhVien vào ThemKhoaScreen.',
      );
    }

    // 1. Tạo khoaId theo cấu trúc K001, K002...
    final khoaId = await taoKhoaIdTiepTheo(bvId);
    final khoaRef = _db
        .collection('Khoa')
        .doc(bvId)
        .collection('danh_sach')
        .doc(khoaId);

    final lich = taoLichLamViec(ngayLamViec);

    // Chuẩn hóa giờ "HH:mm:ss"
    final ds = [...khungGio]..sort((a, b) => a.batDau.compareTo(b.batDau));
    final gioMoRaw = ds.first.batDau;
    final gioDongRaw = ds
        .map((e) => e.ketThuc)
        .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

    final gioMoCua = gioMoRaw.split(':').length == 2
        ? '$gioMoRaw:00'
        : gioMoRaw;
    final gioDongCua = gioDongRaw.split(':').length == 2
        ? '$gioDongRaw:00'
        : gioDongRaw;

    final thoiGianKham = (ds.first.soPhut ~/ gioiHanBenhNhan)
        .clamp(1, 1000)
        .toInt();

    final prefix = layPrefixKhoa(tenKhoa, tenChuyenKhoa);

    // Chuẩn hóa danh sách tên phòng khám (NGT001, NGT002...)
    final List<String> danhSachTenPhong = [];
    for (int i = 0; i < phongKham.length; i++) {
      var ten = phongKham[i].trim();
      if (ten.isEmpty) {
        ten = '$prefix${(i + 1).toString().padLeft(3, '0')}';
      }
      danhSachTenPhong.add(ten);
    }

    final batch = _db.batch();

    // 1) Lưu document Khoa với định dạng tương thích cả Firebase và ứng dụng
    batch.set(khoaRef, {
      'id': khoaId,
      'khoa_id': khoaId,
      'ten_khoa': tenKhoa,
      'tenKhoa': tenKhoa,
      'chuyen_khoa_id': chuyenKhoaId,
      'chuyenKhoaId': chuyenKhoaId,
      'ten_chuyen_khoa': tenChuyenKhoa,
      'tenChuyenKhoa': tenChuyenKhoa,
      'mo_ta': '',
      'moTa': '',
      'so_phong': danhSachTenPhong.length,
      'soPhong': danhSachTenPhong.length,
      'soCaMoiNgay': soCaMoiNgay,
      'gioiHanBenhNhan': gioiHanBenhNhan,
      'phongDau': danhSachTenPhong.isNotEmpty ? danhSachTenPhong.first : '',
      'khungGio': ds.map((e) => e.toMap()).toList(),
      'ngayLamViec': ([...ngayLamViec]..sort()),
      'lichLamViec': lich,
      'trangThai': 'dang_mo',
      'ngay_tao': FieldValue.serverTimestamp(),
      'ngayTao': FieldValue.serverTimestamp(),
      'ngay_cap_nhat': FieldValue.serverTimestamp(),
    });

    // Đồng bộ vào tài khoản BenhVien
    try {
      final bvRef = _db.collection('BenhVien').doc(bvId);
      final bvData = <String, dynamic>{
        'ten_cac_khoa': FieldValue.arrayUnion([tenKhoa]),
      };
      if (chuyenKhoaId != null && chuyenKhoaId.isNotEmpty) {
        bvData['chuyen_khoa_ids'] = FieldValue.arrayUnion([chuyenKhoaId]);
      }
      batch.set(bvRef, bvData, SetOptions(merge: true));
    } catch (_) {}

    // 2) Lưu các phòng khám theo định dạng Firebase (như hình đính kèm)
    for (int i = 0; i < danhSachTenPhong.length; i++) {
      final tenPhong = danhSachTenPhong[i];
      // DocId định dạng: BV001_K001_NGT001
      final pkDocId = '${bvId}_${khoaId}_$tenPhong';

      // 2a. Lưu vào collection gốc `PhongKham` theo hình Firebase
      final rootPkRef = _db.collection('PhongKham').doc(pkDocId);
      batch.set(rootPkRef, {
        'gioDongCua': gioDongCua,
        'gioMoCua': gioMoCua,
        'hospitalId': bvId,
        'khoaId': khoaId,
        'ngayTao': FieldValue.serverTimestamp(),
        'nhanVienId': null,
        'prefixKhoa': prefix,
        'soBenhNhanToiDa': gioiHanBenhNhan,
        'tenKhoaGoc': tenKhoa,
        'tenPhong': tenPhong,
        'thoiGianKham': thoiGianKham,
        // Các trường bổ trợ để truy vấn tương thích:
        'id': pkDocId,
        'hospital_id': bvId,
        'khoa_id': khoaId,
        'ten_phong': tenPhong,
        'ten_khoa_goc': tenKhoa,
        'prefix_khoa': prefix,
        'gio_mo_cua': gioMoCua,
        'gio_dong_cua': gioDongCua,
        'thoi_gian_kham': thoiGianKham,
        'so_benh_nhan_toi_da': gioiHanBenhNhan,
        'nhan_vien_id': null,
        'trang_thai': 'dang_kham',
        'trang_thai_id': 13,
      });

      // 2b. Lưu vào subcollection Khoa/.../phongKham để màn ChiTietKhoaScreen hiển thị
      final subPkRef = khoaRef.collection('phongKham').doc(tenPhong);
      batch.set(subPkRef, {
        'id': pkDocId,
        'tenPhong': tenPhong,
        'soPhong': tachSoPhong(tenPhong),
        'gioMoCua': gioMoCua,
        'gioDongCua': gioDongCua,
        'khungGio': ds.map((e) => e.toMap()).toList(),
        'thoiGianKham': thoiGianKham,
        'soBenhNhanToiDa': gioiHanBenhNhan,
        'trang_thai': 'dang_kham',
        'trang_thai_id': 13,
        'nhanVienId': null,
      });

      // 2c. Lưu vào subcollection PhongKham/{hospitalId}/danh_sach/{khoaId}/danh_sach/{pkDocId}
      final treePkRef = _db
          .collection('PhongKham')
          .doc(bvId)
          .collection('danh_sach')
          .doc(khoaId)
          .collection('danh_sach')
          .doc(pkDocId);
      batch.set(treePkRef, {
        'id': pkDocId,
        'hospital_id': bvId,
        'khoa_id': khoaId,
        'ten_phong': tenPhong,
        'ten_khoa_goc': tenKhoa,
        'prefix_khoa': prefix,
        'gio_mo_cua': gioMoCua,
        'gio_dong_cua': gioDongCua,
        'thoi_gian_kham': thoiGianKham,
        'so_benh_nhan_toi_da': gioiHanBenhNhan,
        'nhan_vien_id': null,
        'ngay_tao': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    return KhoaVuaTao(
      khoaId: khoaId,
      tenKhoa: tenKhoa,
      soCaMoiNgay: soCaMoiNgay,
      gioiHanBenhNhan: gioiHanBenhNhan,
      khungGio: ds,
      lichLamViec: lich,
    );
  }

  /// Cập nhật thông tin khoa khám và đồng bộ danh sách phòng khám
  Future<void> capNhatKhoa({
    required String benhVienId,
    required String khoaId,
    required String tenKhoa,
    String? chuyenKhoaId,
    String? tenChuyenKhoa,
    required int soCaMoiNgay,
    required int gioiHanBenhNhan,
    required List<KhungGio> khungGio,
    required List<int> ngayLamViec,
    required List<String> phongKham,
  }) async {
    final bvId = await _chuanHoaBenhVienId(benhVienId);
    final khoaRef = _db
        .collection('Khoa')
        .doc(bvId)
        .collection('danh_sach')
        .doc(khoaId);
    final lich = taoLichLamViec(ngayLamViec);

    final ds = [...khungGio]..sort((a, b) => a.batDau.compareTo(b.batDau));
    final gioMoRaw = ds.first.batDau;
    final gioDongRaw = ds
        .map((e) => e.ketThuc)
        .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

    final gioMoCua = gioMoRaw.split(':').length == 2
        ? '$gioMoRaw:00'
        : gioMoRaw;
    final gioDongCua = gioDongRaw.split(':').length == 2
        ? '$gioDongRaw:00'
        : gioDongRaw;

    final thoiGianKham = (ds.first.soPhut ~/ gioiHanBenhNhan)
        .clamp(1, 1000)
        .toInt();

    final prefix = layPrefixKhoa(tenKhoa, tenChuyenKhoa);

    final List<String> danhSachTenPhong = [];
    for (int i = 0; i < phongKham.length; i++) {
      var ten = phongKham[i].trim();
      if (ten.isEmpty) {
        ten = '$prefix${(i + 1).toString().padLeft(3, '0')}';
      }
      danhSachTenPhong.add(ten);
    }

    final batch = _db.batch();

    // 1. Cập nhật thông tin khoa
    batch.update(khoaRef, {
      'tenKhoa': tenKhoa,
      'ten_khoa': tenKhoa,
      'chuyenKhoaId': ?chuyenKhoaId,
      'chuyen_khoa_id': ?chuyenKhoaId,
      'tenChuyenKhoa': ?tenChuyenKhoa,
      'ten_chuyen_khoa': ?tenChuyenKhoa,
      'soPhong': danhSachTenPhong.length,
      'so_phong': danhSachTenPhong.length,
      'soCaMoiNgay': soCaMoiNgay,
      'gioiHanBenhNhan': gioiHanBenhNhan,
      'phongDau': danhSachTenPhong.isNotEmpty ? danhSachTenPhong.first : '',
      'khungGio': ds.map((e) => e.toMap()).toList(),
      'ngayLamViec': ([...ngayLamViec]..sort()),
      'lichLamViec': lich,
      'ngayCapNhat': FieldValue.serverTimestamp(),
      'ngay_cap_nhat': FieldValue.serverTimestamp(),
    });

    // 2. Lấy phòng khám cũ để xử lý
    final oldRoomsSnap = await khoaRef.collection('phongKham').get();
    for (final d in oldRoomsSnap.docs) {
      final oldName = (d.data()['tenPhong'] ?? d.id).toString();
      if (!danhSachTenPhong.contains(oldName)) {
        batch.delete(d.reference);
        batch.delete(
          _db.collection('PhongKham').doc('${bvId}_${khoaId}_$oldName'),
        );
      }
    }

    // 3. Thêm hoặc cập nhật phòng khám
    for (final ten in danhSachTenPhong) {
      final pkDocId = '${bvId}_${khoaId}_$ten';
      final subRef = khoaRef.collection('phongKham').doc(ten);
      final rootRef = _db.collection('PhongKham').doc(pkDocId);

      final dataToSet = {
        'id': pkDocId,
        'hospitalId': bvId,
        'khoaId': khoaId,
        'tenPhong': ten,
        'soPhong': tachSoPhong(ten),
        'gioMoCua': gioMoCua,
        'gioDongCua': gioDongCua,
        'prefixKhoa': prefix,
        'tenKhoaGoc': tenKhoa,
        'thoiGianKham': thoiGianKham,
        'soBenhNhanToiDa': gioiHanBenhNhan,
        'trang_thai': 'dang_kham',
        'trang_thai_id': 13,
        'ngayCapNhat': FieldValue.serverTimestamp(),
      };

      batch.set(subRef, dataToSet, SetOptions(merge: true));
      batch.set(rootRef, dataToSet, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Xóa khoa khám và toàn bộ các phòng khám thuộc khoa đó
  Future<void> xoaKhoa({
    required String benhVienId,
    required String khoaId,
  }) async {
    final bvId = await _chuanHoaBenhVienId(benhVienId);
    final khoaRef = _db
        .collection('Khoa')
        .doc(bvId)
        .collection('danh_sach')
        .doc(khoaId);

    final batch = _db.batch();

    // 1. Xóa tất cả phòng khám con trong subcollection của khoa
    final phongs = await khoaRef.collection('phongKham').get();
    for (final d in phongs.docs) {
      batch.delete(d.reference);
    }

    // 2. Xóa tất cả document phòng khám trong root collection `PhongKham`
    try {
      final rootRooms = await _db
          .collection('PhongKham')
          .where('hospitalId', isEqualTo: bvId)
          .where('khoaId', isEqualTo: khoaId)
          .get();
      for (final d in rootRooms.docs) {
        batch.delete(d.reference);
      }
    } catch (_) {}

    // 3. Xóa trong subcollection PhongKham/{bvId}/danh_sach/{khoaId}/danh_sach
    try {
      final treeRooms = await _db
          .collection('PhongKham')
          .doc(bvId)
          .collection('danh_sach')
          .doc(khoaId)
          .collection('danh_sach')
          .get();
      for (final d in treeRooms.docs) {
        batch.delete(d.reference);
      }
    } catch (_) {}

    // 4. Xóa document khoa
    batch.delete(khoaRef);

    await batch.commit();
  }

  /// Lấy danh sách khoa cho màn Trang chủ
  Stream<QuerySnapshot<Map<String, dynamic>>> dsKhoa(String benhVienId) {
    return _db
        .collection('Khoa')
        .doc(benhVienId)
        .collection('danh_sach')
        .snapshots();
  }

  /// Lấy các phòng của một khoa
  Future<List<Map<String, dynamic>>> dsPhong(
    String benhVienId,
    String khoaId,
  ) async {
    final bvId = await _chuanHoaBenhVienId(benhVienId);

    // 1. Lấy từ subcollection phongKham của Khoa
    final snap = await _db
        .collection('Khoa')
        .doc(bvId)
        .collection('danh_sach')
        .doc(khoaId)
        .collection('phongKham')
        .get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }

    // 2. Lấy từ root collection PhongKham
    try {
      final rootSnap = await _db
          .collection('PhongKham')
          .where('hospitalId', isEqualTo: bvId)
          .where('khoaId', isEqualTo: khoaId)
          .get();
      if (rootSnap.docs.isNotEmpty) {
        return rootSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }
    } catch (_) {}

    return [];
  }
}
