import 'package:cloud_firestore/cloud_firestore.dart';

// =========================================================================
// 1. CÁC MODEL VÀ HELPER FUNCTIONS
// =========================================================================

class KhungGio {
  final String batDau;
  final String ketThuc;

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

enum TrangThaiPhong {
  tamDung(12),
  dangKham(13),
  dongCua(14);

  final int ma;
  const TrangThaiPhong(this.ma);

  static TrangThaiPhong tuMa(dynamic v) {
    final int? maSo = v is int ? v : int.tryParse(v?.toString() ?? '');
    switch (maSo) {
      case 12:
        return TrangThaiPhong.tamDung;
      case 14:
        return TrangThaiPhong.dongCua;
      default:
        return TrangThaiPhong.dangKham;
    }
  }
}

class PhongKhamTrangThai {
  final TrangThaiPhong trangThai;
  final DateTime? tamDungTu;
  final int tongPhutTamDung;
  final String? ngayTamDung;

  const PhongKhamTrangThai({
    required this.trangThai,
    this.tamDungTu,
    this.tongPhutTamDung = 0,
    this.ngayTamDung,
  });

  static const PhongKhamTrangThai macDinh = PhongKhamTrangThai(
    trangThai: TrangThaiPhong.dangKham,
  );

  factory PhongKhamTrangThai.tuMap(Map<String, dynamic> d) {
    final ts = d['tam_dung_tu'] ?? d['tamDungTu'];
    final tong = d['tong_phut_tam_dung'] ?? d['tongPhutTamDung'];

    return PhongKhamTrangThai(
      trangThai: TrangThaiPhong.tuMa(d['trang_thai_id'] ?? d['trangThai']),
      tamDungTu: ts is Timestamp ? ts.toDate() : null,
      tongPhutTamDung: tong is num ? tong.toInt() : int.tryParse('$tong') ?? 0,
      ngayTamDung: (d['ngay_tam_dung'] ?? d['ngayTamDung'])?.toString(),
    );
  }

  int phutDangTamDung(DateTime now) {
    if (trangThai != TrangThaiPhong.tamDung || tamDungTu == null) return 0;
    final phut = now.difference(tamDungTu!).inMinutes;
    return phut < 0 ? 0 : phut;
  }

  int phutTamDung(DateTime now) {
    final daTichLuy = ngayTamDung == _ngayId(now) ? tongPhutTamDung : 0;
    return daTichLuy + phutDangTamDung(now);
  }
}

String _ngayId(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String nhanNgay(int d) => d == 8 ? 'CN' : 'Thứ $d';

String taoLichLamViec(List<int> ngay) {
  final s = [...ngay]..sort();
  if (s.isEmpty) return '';
  if (s.length == 7) return 'Cả tuần';
  final lienTuc = s.length >= 3 && s.last - s.first == s.length - 1;
  if (lienTuc) return '${nhanNgay(s.first)} đến ${nhanNgay(s.last)}';
  return s.map(nhanNgay).join(', ');
}

String tachSoPhong(String tenPhong) {
  final m = RegExp(r'[Pp]hòng\s*([0-9]+[A-Za-z]?)').firstMatch(tenPhong);
  return m?.group(1) ?? '';
}

// =========================================================================
// 2. CLASS KHOA SERVICE
// =========================================================================

class KhoaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  static String layPrefixKhoa(String tenKhoa, [String? tenChuyenKhoa]) {
    final tKhoa = tenKhoa.trim();
    if (khoaPrefixMap.containsKey(tKhoa)) return khoaPrefixMap[tKhoa]!;
    if (tenChuyenKhoa != null && khoaPrefixMap.containsKey(tenChuyenKhoa.trim())) {
      return khoaPrefixMap[tenChuyenKhoa.trim()]!;
    }

    final fullKhoa = tKhoa.startsWith('Khoa ') ? tKhoa : 'Khoa $tKhoa';
    if (khoaPrefixMap.containsKey(fullKhoa)) return khoaPrefixMap[fullKhoa]!;

    for (final entry in khoaPrefixMap.entries) {
      final keyShort = entry.key.replaceAll('Khoa ', '').toLowerCase();
      if (tKhoa.toLowerCase().contains(keyShort) ||
          (tenChuyenKhoa != null && entry.key.toLowerCase().contains(tenChuyenKhoa.toLowerCase()))) {
        return entry.value;
      }
    }

    final cleanName = tKhoa.replaceAll(RegExp(r'^[Kk]hoa\s+'), '').trim();
    final words = cleanName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isNotEmpty) {
      final prefix = words.map((w) => w[0].toUpperCase()).join();
      if (prefix.isNotEmpty) return prefix;
    }

    return 'PK';
  }

  Future<String> chuanHoaBenhVienId(String benhVienId) => _chuanHoaBenhVienId(benhVienId);

  Future<String> _chuanHoaBenhVienId(String benhVienId) async {
    final trimmed = benhVienId.trim();
    if (trimmed.startsWith('BV')) return trimmed;

    try {
      final doc = await _db.collection('BenhVien').doc(trimmed).get();
      if (doc.exists) {
        final ma = (doc.data()?['ma_benh_vien'] ?? doc.data()?['maBenhVien'])?.toString();
        if (ma != null && ma.isNotEmpty) return ma;
      }

      final query = await _db.collection('BenhVien').where('auth_uid', isEqualTo: trimmed).limit(1).get();
      if (query.docs.isNotEmpty) {
        final ma = (query.docs.first.data()['ma_benh_vien'] ?? query.docs.first.id).toString();
        if (ma.isNotEmpty) return ma;
      }
    } catch (_) {}

    return trimmed;
  }

  Future<String> taoKhoaIdTiepTheo(String benhVienId) async {
    final snap = await _db.collection('Khoa').doc(benhVienId).collection('danh_sach').get();

    int maxNum = 0;
    final regex = RegExp(r'^K(\d+)$', caseSensitive: false);

    for (final doc in snap.docs) {
      final match = regex.firstMatch(doc.id);
      if (match != null) {
        final numVal = int.tryParse(match.group(1) ?? '') ?? 0;
        if (numVal > maxNum) maxNum = numVal;
      }
    }

    final nextNum = maxNum + 1;
    return 'K${nextNum.toString().padLeft(3, '0')}';
  }

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
      throw Exception('Chưa có benhVienId hợp lệ.');
    }

    final khoaId = await taoKhoaIdTiepTheo(bvId);
    final khoaRef = _db.collection('Khoa').doc(bvId).collection('danh_sach').doc(khoaId);
    final lich = taoLichLamViec(ngayLamViec);

    final ds = [...khungGio]..sort((a, b) => a.batDau.compareTo(b.batDau));
    final gioMoRaw = ds.first.batDau;
    final gioDongRaw = ds.map((e) => e.ketThuc).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

    final gioMoCua = gioMoRaw.split(':').length == 2 ? '$gioMoRaw:00' : gioMoRaw;
    final gioDongCua = gioDongRaw.split(':').length == 2 ? '$gioDongRaw:00' : gioDongRaw;

    final thoiGianKham = (ds.first.soPhut ~/ gioiHanBenhNhan).clamp(1, 1000).toInt();
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

    // 1. Lưu document Khoa
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

    // 2. Đồng bộ vào tài khoản BenhVien
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

    // 3. Lưu các phòng khám
    for (int i = 0; i < danhSachTenPhong.length; i++) {
      final tenPhong = danhSachTenPhong[i];
      final pkDocId = '${bvId}_${khoaId}_$tenPhong';

      // 3a. Root collection PhongKham
      final rootPkRef = _db.collection('PhongKham').doc(pkDocId);
      batch.set(rootPkRef, {
        'id': pkDocId,
        'hospitalId': bvId,
        'hospital_id': bvId,
        'khoaId': khoaId,
        'khoa_id': khoaId,
        'tenPhong': tenPhong,
        'ten_phong': tenPhong,
        'tenKhoaGoc': tenKhoa,
        'ten_khoa_goc': tenKhoa,
        'prefixKhoa': prefix,
        'prefix_khoa': prefix,
        'gioMoCua': gioMoCua,
        'gio_mo_cua': gioMoCua,
        'gioDongCua': gioDongCua,
        'gio_dong_cua': gioDongCua,
        'thoiGianKham': thoiGianKham,
        'thoi_gian_kham': thoiGianKham,
        'soBenhNhanToiDa': gioiHanBenhNhan,
        'so_benh_nhan_toi_da': gioiHanBenhNhan,
        'nhanVienId': null,
        'nhan_vien_id': null,
        'trang_thai': 'dang_kham',
        'trang_thai_id': 13,
        'ngayTao': FieldValue.serverTimestamp(),
        'ngay_tao': FieldValue.serverTimestamp(),
      });

      // 3b. Subcollection dưới Khoa
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

      // 3c. Subcollection cây thư mục PhongKham
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
    final khoaRef = _db.collection('Khoa').doc(bvId).collection('danh_sach').doc(khoaId);
    final lich = taoLichLamViec(ngayLamViec);

    final ds = [...khungGio]..sort((a, b) => a.batDau.compareTo(b.batDau));
    final gioMoRaw = ds.first.batDau;
    final gioDongRaw = ds.map((e) => e.ketThuc).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

    final gioMoCua = gioMoRaw.split(':').length == 2 ? '$gioMoRaw:00' : gioMoRaw;
    final gioDongCua = gioDongRaw.split(':').length == 2 ? '$gioDongRaw:00' : gioDongRaw;

    final thoiGianKham = (ds.first.soPhut ~/ gioiHanBenhNhan).clamp(1, 1000).toInt();
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
      'chuyenKhoaId': chuyenKhoaId,
      'chuyen_khoa_id': chuyenKhoaId,
      'tenChuyenKhoa': tenChuyenKhoa,
      'ten_chuyen_khoa': tenChuyenKhoa,
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

    // 2. Xóa các phòng khám không còn trong danh sách mới
    final oldRoomsSnap = await khoaRef.collection('phongKham').get();
    for (final d in oldRoomsSnap.docs) {
      final oldName = (d.data()['tenPhong'] ?? d.id).toString();
      if (!danhSachTenPhong.contains(oldName)) {
        batch.delete(d.reference);
        batch.delete(_db.collection('PhongKham').doc('${bvId}_${khoaId}_$oldName'));
      }
    }

    // 3. Thêm hoặc cập nhật phòng khám mới
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

  Future<void> xoaKhoa({
    required String benhVienId,
    required String khoaId,
  }) async {
    final bvId = await _chuanHoaBenhVienId(benhVienId);
    final khoaRef = _db.collection('Khoa').doc(bvId).collection('danh_sach').doc(khoaId);
    final batch = _db.batch();

    // 1. Xóa subcollection dưới Khoa
    final phongs = await khoaRef.collection('phongKham').get();
    for (final d in phongs.docs) {
      batch.delete(d.reference);
    }

    // 2. Xóa root collection PhongKham
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

    // 3. Xóa subcollection cây thư mục
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

  Stream<QuerySnapshot<Map<String, dynamic>>> dsKhoa(String benhVienId) {
    return _db.collection('Khoa').doc(benhVienId).collection('danh_sach').snapshots();
  }

  Future<List<Map<String, dynamic>>> dsPhong(String benhVienId, String khoaId) async {
    final bvId = await _chuanHoaBenhVienId(benhVienId);

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

  Stream<PhongKhamTrangThai> theoDoiTrangThaiPhong({
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
  }) {
    return _db.collection('PhongKham').doc(phongKhamId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return PhongKhamTrangThai.macDinh;
      return PhongKhamTrangThai.tuMap(data);
    });
  }

  Future<void> capNhatTrangThaiPhong({
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
    required TrangThaiPhong trangThaiMoi,
  }) async {
    final ref = _db.collection('PhongKham').doc(phongKhamId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Không tìm thấy phòng khám.');
      final data = snap.data()!;
      final hienTai = PhongKhamTrangThai.tuMap(data);
      final now = DateTime.now();
      final homNay = _ngayId(now);

      var tong = hienTai.ngayTamDung == homNay ? hienTai.tongPhutTamDung : 0;

      final dangTamDung = hienTai.trangThai == TrangThaiPhong.tamDung;
      if (dangTamDung && trangThaiMoi != TrangThaiPhong.tamDung) {
        tong += hienTai.phutDangTamDung(now);
      }

      final Object? tamDungTu;
      if (trangThaiMoi != TrangThaiPhong.tamDung) {
        tamDungTu = null;
      } else if (dangTamDung && (data['tam_dung_tu'] ?? data['tamDungTu']) != null) {
        tamDungTu = data['tam_dung_tu'] ?? data['tamDungTu'];
      } else {
        tamDungTu = FieldValue.serverTimestamp();
      }

      tx.update(ref, {
        'trang_thai_id': trangThaiMoi.ma,
        'tam_dung_tu': tamDungTu,
        'tong_phut_tam_dung': tong,
        'ngay_tam_dung': homNay,
        'thoi_gian_cap_nhat': FieldValue.serverTimestamp(),
      });
    });
  }
}