import '../config/constants.dart';

class HospitalModel {
  final int? id;
  final String? maBenhVien; // Mã chuẩn: BV001, BV500, BV501...
  final String? uid;        // Đồng bộ với maBenhVien hoặc docId
  final String? authUid;    // Firebase Auth UID
  final String? tenBenhVien;
  final String? diaChi;
  final String? moTa;
  final String? hinhAnh;
  final int? trangThaiHopTacId;
  final double? diemDanhGiaTb;
  final int? tongSoDanhGia;
  final DateTime? ngayHopTac;
  final DateTime? ngayTao;
  final String? coSo;
  final String? bhyt;
  final String? email;
  final String? role;
  final bool daXacThucEmail;

  final double? viDo; // Latitude
  final double? kinhDo; // Longitude

  final List<String>? chuyenKhoaIds; // Ví dụ: ['CK01', 'CK04'] -> Dùng để query filter
  final List<String>? tenCacKhoa;    // Ví dụ: ['Khoa Tim mạch', 'Khoa Hô hấp'] -> Dùng để hiển thị UI nhanh

  final bool isBlocked;
  final bool chanDangNhap;
  final String? lyDoKhoa;

  HospitalModel({
    this.id,
    this.maBenhVien,
    this.uid,
    this.authUid,
    this.tenBenhVien,
    this.diaChi,
    this.moTa,
    this.hinhAnh,
    this.trangThaiHopTacId,
    this.diemDanhGiaTb = 0.0,
    this.tongSoDanhGia = 0,
    this.ngayHopTac,
    DateTime? ngayTao,
    this.coSo,
    this.bhyt,
    this.email,
    this.role = 'benh_vien',
    this.daXacThucEmail = false,
    this.viDo,
    this.kinhDo,
    this.chuyenKhoaIds,
    this.tenCacKhoa,
    this.isBlocked = false,
    this.chanDangNhap = false,
    this.lyDoKhoa,
  }) : ngayTao = ngayTao ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ma_benh_vien': maBenhVien ?? uid,
      'uid': uid ?? maBenhVien,
      if (authUid != null) 'auth_uid': authUid,
      'ten_benh_vien': tenBenhVien,
      'dia_chi': diaChi,
      'mo_ta': moTa,
      'hinh_anh': hinhAnh,
      if (trangThaiHopTacId != null) 'trang_thai_hop_tac_id': trangThaiHopTacId,
      'da_gui_don': false,
      'da_xac_thuc': false,
      'diem_danh_gia_tb': diemDanhGiaTb,
      'tong_so_danh_gia': tongSoDanhGia,
      'ngay_hop_tac': ngayHopTac?.toIso8601String(),
      'ngay_tao': ngayTao?.toIso8601String(),
      'co_so': coSo ?? 'Tu_nhan',
      'bhyt': bhyt ?? 'Co_BHYT',
      'co_bhyt': (bhyt != null ? bhyt == 'Co_BHYT' : true),
      'email': email,
      'role': role,
      'da_xac_thuc_email': daXacThucEmail,
      'vi_do': viDo,
      'kinh_do': kinhDo,
      'chuyen_khoa_ids': chuyenKhoaIds ?? <String>[],
      'ten_cac_khoa': tenCacKhoa ?? <String>[],
      'is_blocked': isBlocked,
      'chan_dang_nhap': chanDangNhap,
      'ly_do_khoa': lyDoKhoa,
    };
  }

  factory HospitalModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawMaBv = (map['ma_benh_vien'] ?? map['maBenhVien'] ?? (docId != null && docId.startsWith('BV') ? docId : null))?.toString();
    final rawUid = (map['uid'] ?? map['benh_vien_id'] ?? rawMaBv ?? docId)?.toString();
    final rawAuthUid = (map['auth_uid'] ?? map['authUid'])?.toString();
    final rawTen = (map['ten_benh_vien'] ?? map['tenBenhVien'] ?? map['ten'] ?? '').toString();

    // Trích xuất id kiểu int từ map hoặc maBenhVien / docId (BV500 -> 500)
    int? parsedId;
    if (map['id'] is int) {
      parsedId = map['id'];
    } else if (map['id'] is num) {
      parsedId = (map['id'] as num).toInt();
    } else if (map['id'] != null) {
      parsedId = int.tryParse(map['id'].toString());
    } else if (rawMaBv != null) {
      final match = RegExp(r'\d+').firstMatch(rawMaBv);
      if (match != null) {
        parsedId = int.tryParse(match.group(0)!);
      }
    } else if (docId != null) {
      final match = RegExp(r'\d+').firstMatch(docId);
      if (match != null) {
        parsedId = int.tryParse(match.group(0)!);
      }
    }

    // Nếu rawUid là Auth UID (không bắt đầu bằng BV), chuyển sang authUid
    String? cleanAuthUid = rawAuthUid;
    if (rawUid != null && !rawUid.startsWith('BV') && cleanAuthUid == null) {
      cleanAuthUid = rawUid;
    }

    final maBv = rawMaBv ?? (parsedId != null ? 'BV${parsedId.toString().padLeft(3, '0')}' : null);
    final effectiveUid = maBv ?? (rawUid != null && rawUid.startsWith('BV') ? rawUid : (parsedId != null ? 'BV${parsedId.toString().padLeft(3, '0')}' : rawUid));

    final statusId = map['trang_thai_hop_tac_id'] is int
        ? map['trang_thai_hop_tac_id'] as int
        : int.tryParse(map['trang_thai_hop_tac_id']?.toString() ?? '') ?? TrangThaiId.choDuyet;

    final chan = map['chan_dang_nhap'] == true;
    final blocked = map['is_blocked'] == true ||
        chan ||
        statusId != TrangThaiId.hopTac ||
        map['trang_thai'] == 'huy_hop_tac';

    return HospitalModel(
      id: parsedId,
      maBenhVien: maBv ?? effectiveUid,
      uid: effectiveUid ?? maBv,
      authUid: cleanAuthUid,
      tenBenhVien: rawTen.isNotEmpty ? rawTen : null,
      diaChi: map['dia_chi'] ?? map['diaChi'],
      moTa: map['mo_ta'] ?? map['moTa'],
      hinhAnh: map['hinh_anh'] ?? map['hinhAnh'],
      trangThaiHopTacId: statusId,
      diemDanhGiaTb: (map['diem_danh_gia_tb'] as num?)?.toDouble() ?? 0.0,
      tongSoDanhGia: map['tong_so_danh_gia'] is int
          ? map['tong_so_danh_gia']
          : int.tryParse(map['tong_so_danh_gia']?.toString() ?? '') ?? 0,
      ngayHopTac: map['ngay_hop_tac'] != null
          ? DateTime.tryParse(map['ngay_hop_tac'].toString())
          : null,
      ngayTao: map['ngay_tao'] != null ? DateTime.tryParse(map['ngay_tao'].toString()) : null,
      coSo: map['co_so'] ??
          map['coSo'] ??
          (map['loai_hinh'] != null &&
                  map['loai_hinh'].toString().toLowerCase().contains('công')
              ? 'Cong_lap'
              : 'Tu_nhan'),
      bhyt: map['bhyt']?.toString() ??
          (map['co_bhyt'] == false ? 'Khong_BHYT' : 'Co_BHYT'),
      email: map['email'],
      role: map['role'] ?? 'benh_vien',
      daXacThucEmail: map['da_xac_thuc_email'] ?? false,
      viDo: (map['vi_do'] as num?)?.toDouble(),
      kinhDo: (map['kinh_do'] as num?)?.toDouble(),
      chuyenKhoaIds: map['chuyen_khoa_ids'] != null
          ? List<String>.from(map['chuyen_khoa_ids'])
          : const [],
      tenCacKhoa: map['ten_cac_khoa'] != null
          ? List<String>.from(map['ten_cac_khoa'])
          : const [],
      isBlocked: blocked,
      chanDangNhap: chan,
      lyDoKhoa: map['ly_do_khoa']?.toString() ??
          map['ly_do_huy']?.toString() ??
          map['ly_do_chan']?.toString(),
    );
  }

  HospitalModel copyWith({
    int? id,
    String? maBenhVien,
    String? uid,
    String? authUid,
    String? tenBenhVien,
    String? diaChi,
    String? moTa,
    String? hinhAnh,
    int? trangThaiHopTacId,
    double? diemDanhGiaTb,
    int? tongSoDanhGia,
    DateTime? ngayHopTac,
    DateTime? ngayTao,
    String? coSo,
    String? bhyt,
    String? email,
    String? role,
    bool? daXacThucEmail,
    double? viDo,
    double? kinhDo,
    List<String>? chuyenKhoaIds,
    List<String>? tenCacKhoa,
    bool? isBlocked,
    bool? chanDangNhap,
    String? lyDoKhoa,
  }) {
    return HospitalModel(
      id: id ?? this.id,
      maBenhVien: maBenhVien ?? this.maBenhVien,
      uid: uid ?? this.uid,
      authUid: authUid ?? this.authUid,
      tenBenhVien: tenBenhVien ?? this.tenBenhVien,
      diaChi: diaChi ?? this.diaChi,
      moTa: moTa ?? this.moTa,
      hinhAnh: hinhAnh ?? this.hinhAnh,
      trangThaiHopTacId: trangThaiHopTacId ?? this.trangThaiHopTacId,
      diemDanhGiaTb: diemDanhGiaTb ?? this.diemDanhGiaTb,
      tongSoDanhGia: tongSoDanhGia ?? this.tongSoDanhGia,
      ngayHopTac: ngayHopTac ?? this.ngayHopTac,
      ngayTao: ngayTao ?? this.ngayTao,
      coSo: coSo ?? this.coSo,
      bhyt: bhyt ?? this.bhyt,
      email: email ?? this.email,
      role: role ?? this.role,
      daXacThucEmail: daXacThucEmail ?? this.daXacThucEmail,
      viDo: viDo ?? this.viDo,
      kinhDo: kinhDo ?? this.kinhDo,
      chuyenKhoaIds: chuyenKhoaIds ?? this.chuyenKhoaIds,
      tenCacKhoa: tenCacKhoa ?? this.tenCacKhoa,
      isBlocked: isBlocked ?? this.isBlocked,
      chanDangNhap: chanDangNhap ?? this.chanDangNhap,
      lyDoKhoa: lyDoKhoa ?? this.lyDoKhoa,
    );
  }

  factory HospitalModel.fromRegisterEmail({
    int? id,
    String? maBenhVien,
    required String uid,
    String? authUid,
    required String tenBenhVien,
    required String email,
    String? diaChi,
    String? role,
  }) {
    return HospitalModel(
      id: id,
      maBenhVien: maBenhVien,
      uid: uid,
      authUid: authUid,
      tenBenhVien: tenBenhVien,
      email: email,
      diaChi: diaChi,
      trangThaiHopTacId: null,
      ngayTao: DateTime.now(),
      coSo: 'Tu_nhan',
      bhyt: 'Co_BHYT',
      chuyenKhoaIds: const [],
      tenCacKhoa: const [],
      role: role ?? 'benh_vien',
      daXacThucEmail: false,
    );
  }
}