import 'package:cloud_firestore/cloud_firestore.dart';

class TaiKhoanItem {
  final String? id;
  final String? benhVienId;
  final String maTk;
  final String matKhau;
  final String trangThai;
  final String vaiTro;
  final String role;
  final String khoa;
  final String hoTen;
  final bool daKichHoat;
  final DateTime? ngayTao;

  const TaiKhoanItem({
    this.id,
    this.benhVienId,
    required this.maTk,
    required this.matKhau,
    this.trangThai = 'Đợi kích hoạt',
    this.vaiTro = '',
    this.role = '',
    this.khoa = '',
    this.hoTen = '',
    this.daKichHoat = false,
    this.ngayTao,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'benh_vien_id': benhVienId,
    'maTk': maTk,
    'matKhau': matKhau,
    'trangThai': trangThai,
    'vaiTro': vaiTro,
    'role': role,
    'khoa': khoa,
    'hoTen': hoTen,
    'daKichHoat': daKichHoat,
    'ngayTao': ngayTao?.toIso8601String(),
  };

  factory TaiKhoanItem.fromMap(Map<String, dynamic> map) {
    DateTime? parsedNgayTao;
    final rawNgay = map['ngay_tao'] ?? map['ngayTao'] ?? map['created_at'];
    if (rawNgay is Timestamp) {
      parsedNgayTao = rawNgay.toDate();
    } else if (rawNgay is String && rawNgay.isNotEmpty) {
      parsedNgayTao = DateTime.tryParse(rawNgay);
    }

    final bool isActivated = map['da_kich_hoat'] == true ||
        map['trang_thai'] == 'dang_hoat_dong' ||
        map['trangThai'] == 'Đã kích hoạt';

    return TaiKhoanItem(
      id: map['id']?.toString(),
      benhVienId: (map['benh_vien_id'] ?? map['benhVienId'])?.toString(),
      maTk: (map['maTk'] ?? map['ma_nhan_vien'] ?? map['ma_tai_khoan'] ?? '').toString(),
      matKhau: (map['matKhau'] ?? map['mat_khau'] ?? '123456').toString(),
      trangThai: isActivated ? 'Đã kích hoạt' : (map['trangThai'] ?? map['trang_thai'] ?? 'Đợi kích hoạt').toString(),
      vaiTro: (map['vai_tro'] ?? map['vaiTro'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      khoa: (map['khoa'] ?? map['ten_khoa'] ?? map['tenKhoa'] ?? '').toString(),
      hoTen: (map['ho_ten'] ?? map['hoTen'] ?? '').toString(),
      daKichHoat: isActivated,
      ngayTao: parsedNgayTao,
    );
  }
}

class DotCapTaiKhoan {
  final String id;
  final String tenKhoa;
  final String vaiTro;
  final int soLuong;
  final List<TaiKhoanItem> danhSachTaiKhoan;
  final DateTime thoiGian;

  DotCapTaiKhoan({
    String? id,
    required this.tenKhoa,
    required this.vaiTro,
    required this.soLuong,
    required this.danhSachTaiKhoan,
    DateTime? thoiGian,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       thoiGian = thoiGian ?? DateTime.now();
}

class NhanVienModel {
  final String id;
  final String benhVienId;
  final String hoTen;
  final String maNv;
  final String vaiTro;
  final String role;
  final String khoa;
  final String soDienThoai;
  final String email;
  final String matKhau;
  final bool daKichHoat;
  final bool dangHoatDong;
  final String trangThai;
  final int trangThaiId;
  final DateTime? ngayTao;

  // Lịch phân công theo ngày (TrangThai doc 15: "chờ", doc 16: "đã phân công")
  final String? ngayPhanCong;
  final String? phongPhanCong;
  final String? khoaPhanCong;
  final Map<String, dynamic>? lichPhanCong;

  const NhanVienModel({
    required this.id,
    this.benhVienId = '',
    required this.hoTen,
    required this.maNv,
    required this.vaiTro,
    this.role = '',
    required this.khoa,
    required this.soDienThoai,
    required this.email,
    this.matKhau = '123456',
    this.daKichHoat = true,
    this.dangHoatDong = true,
    this.trangThai = 'dang_hoat_dong',
    this.trangThaiId = 15,
    this.ngayTao,
    this.ngayPhanCong,
    this.phongPhanCong,
    this.khoaPhanCong,
    this.lichPhanCong,
  });

  /// Lấy ID trạng thái (15: "chờ", 16: "đã phân công") cho ngày cụ thể
  int getTrangThaiIdChoNgay(String ngayStr) {
    if (lichPhanCong != null && lichPhanCong!.containsKey(ngayStr)) {
      final pc = lichPhanCong![ngayStr];
      if (pc is Map) {
        final val = pc['trang_thai_id'] ?? pc['trangThaiId'];
        if (val is int) return val;
        if (val != null) return int.tryParse(val.toString()) ?? 15;
      }
    }
    if (ngayPhanCong == ngayStr) {
      return trangThaiId;
    }
    return daPhanCong ? 16 : 15; // Mặc định là 15: "chờ", nếu đã phân công thì 16
  }

  /// Kiểm tra nhân viên đã được phân công trực hay chưa (chung hoặc theo bất kỳ lịch nào)
  bool get daPhanCong {
    if (trangThaiId == 16 ||
        trangThai == 'đã phân công' ||
        trangThai == 'da_phan_cong') {
      return true;
    }
    if (phongPhanCong != null && phongPhanCong!.trim().isNotEmpty) {
      return true;
    }
    if (lichPhanCong != null && lichPhanCong!.isNotEmpty) {
      for (final val in lichPhanCong!.values) {
        if (val is Map) {
          final id = val['trang_thai_id'] ?? val['trangThaiId'];
          final tt = (val['trang_thai'] ?? val['trangThai'] ?? '').toString();
          if (id == 16 || id == '16' || tt == 'đã phân công') {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Lấy tên trạng thái ("chờ" hoặc "đã phân công") cho ngày cụ thể
  String getTenTrangThaiChoNgay(String ngayStr) {
    final id = getTrangThaiIdChoNgay(ngayStr);
    return id == 16 ? 'đã phân công' : 'chờ';
  }

  /// Kiểm tra nhân viên đã được phân công trực trong ngày này chưa
  bool daDuocPhanCongTrongNgay(String ngayStr) {
    return getTrangThaiIdChoNgay(ngayStr) == 16;
  }

  /// Lấy tên phòng khám được phân công trực trong ngày (nếu có)
  String? getPhongPhanCongChoNgay(String ngayStr) {
    if (lichPhanCong != null && lichPhanCong!.containsKey(ngayStr)) {
      final pc = lichPhanCong![ngayStr];
      if (pc is Map) {
        return (pc['phong'] ?? pc['ten_phong'] ?? pc['phong_id'])?.toString();
      }
    }
    if (ngayPhanCong == ngayStr) {
      return phongPhanCong;
    }
    return null;
  }

  factory NhanVienModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final benhVienId = (data['benh_vien_id'] ?? data['benhVienId'] ?? '')
        .toString();
    final maNv =
        (data['ma_nhan_vien'] ?? data['maNv'] ?? data['ma_tai_khoan'] ?? doc.id)
            .toString();
    final vaiTro = (data['vai_tro'] ?? data['vaiTro'] ?? 'Lễ tân').toString();
    final hoTen = (data['ho_ten'] ?? data['hoTen'] ?? 'Nhân viên $maNv')
        .toString();
    final khoa = (data['khoa'] ?? '').toString();
    final sdt = (data['so_dien_thoai'] ?? data['soDienThoai'] ?? '').toString();
    final email = (data['email'] ?? '${maNv.toLowerCase()}@benhvien.vn')
        .toString();
    final matKhau = (data['mat_khau'] ?? data['matKhau'] ?? '123456')
        .toString();
    final trangThai = (data['trang_thai'] ?? '').toString();

    final bool daKichHoat;
    if (data.containsKey('da_kich_hoat')) {
      daKichHoat = data['da_kich_hoat'] == true;
    } else if (data['ngay_kich_hoat'] != null) {
      daKichHoat = true;
    } else {
      daKichHoat = (trangThai == 'dang_hoat_dong' ||
              trangThai == 'da_khoa' ||
              trangThai == 'đã phân công' ||
              trangThai == 'chờ') &&
          trangThai != 'doi_kich_hoat' &&
          trangThai != 'chua_kich_hoat';
    }

    final dangHoatDong = trangThai != 'da_khoa';

    DateTime? dt;
    final nt = data['ngay_tao'] ?? data['ngayTao'];
    if (nt is Timestamp) {
      dt = nt.toDate();
    }

    // Trạng thái theo TrangThai Document 15 ("chờ") và 16 ("đã phân công")
    int ttId = 15;
    final rawTtId = data['trang_thai_id'] ?? data['trangThaiId'];
    if (rawTtId is int) {
      ttId = rawTtId;
    } else if (rawTtId != null) {
      ttId = int.tryParse(rawTtId.toString()) ?? 15;
    }

    final phongPc = (data['phong_phan_cong'] ?? data['phongPhanCong'])?.toString();
    final ngayPc = (data['ngay_phan_cong'] ?? data['ngayPhanCong'])?.toString();
    final khoaPc = (data['khoa_phan_cong'] ?? data['khoaPhanCong'])?.toString();

    final lichPhanCong = data['lich_phan_cong'] is Map
        ? Map<String, dynamic>.from(data['lich_phan_cong'] as Map)
        : null;

    if (ttId != 16 &&
        (trangThai == 'đã phân công' ||
            trangThai == 'da_phan_cong' ||
            (phongPc != null && phongPc.trim().isNotEmpty))) {
      ttId = 16;
    }

    return NhanVienModel(
      id: doc.id,
      benhVienId: benhVienId,
      hoTen: hoTen,
      maNv: maNv,
      vaiTro: vaiTro,
      role: (data['role'] ?? '').toString(),
      khoa: khoa,
      soDienThoai: sdt,
      email: email,
      matKhau: matKhau,
      daKichHoat: daKichHoat,
      dangHoatDong: dangHoatDong,
      trangThai: trangThai,
      trangThaiId: ttId,
      ngayTao: dt,
      ngayPhanCong: ngayPc,
      phongPhanCong: phongPc,
      khoaPhanCong: khoaPc,
      lichPhanCong: lichPhanCong,
    );
  }
}