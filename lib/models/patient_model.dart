import '../config/constants.dart';

class PatientModel {
  final String uid;
  final String? maBenhNhan;
  final String? hoTen;
  final String? email;
  final String? soDienThoai;
  final String? googleId;
  final DateTime? ngaySinh;
  final String? gioiTinh;
  final String? diaChi;
  final int? trangThaiId;
  final DateTime? ngayTao;
  final String? role;
  final bool daXacThucEmail;
  final String? cccd;
  final String? soBhyt;
  final bool isBlocked;
  final bool chanDangNhap;
  final String? lyDoKhoa;

  PatientModel({
    required this.uid,
    this.maBenhNhan,
    this.hoTen,
    this.email,
    this.soDienThoai,
    this.googleId,
    this.ngaySinh,
    this.gioiTinh,
    this.diaChi,
    this.trangThaiId = TrangThaiId.hoatDong,
    DateTime? ngayTao,
    this.role = 'benh_nhan',
    this.daXacThucEmail = false,
    this.cccd,
    this.soBhyt,
    this.isBlocked = false,
    this.chanDangNhap = false,
    this.lyDoKhoa,
  }) : ngayTao = ngayTao ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'ma_benh_nhan': maBenhNhan,
      'ho_ten': hoTen,
      'email': email,
      'so_dien_thoai': soDienThoai,
      'google': googleId,
      'ngay_sinh': ngaySinh?.toIso8601String(),
      'gioi_tinh': gioiTinh,
      'dia_chi': diaChi,
      'trang_thai_id': trangThaiId,
      'ngay_tao': ngayTao?.toIso8601String(),
      'role': role,
      'da_xac_thuc_email': daXacThucEmail,
      'cccd': cccd,
      'so_bhyt': soBhyt,
      'is_blocked': isBlocked,
      'chan_dang_nhap': chanDangNhap,
      'ly_do_khoa': lyDoKhoa,
    };
  }

  factory PatientModel.fromMap(Map<String, dynamic> map) {
    final statusId = map['trang_thai_id'] as int?;
    final chan = map['chan_dang_nhap'] == true;
    final blocked = map['is_blocked'] == true ||
        chan ||
        statusId == TrangThaiId.khongHoatDong ||
        map['trang_thai'] == 'khoa';

    return PatientModel(
      uid: map['uid'] ?? '',
      maBenhNhan: map['ma_benh_nhan'],
      hoTen: map['ho_ten'],
      email: map['email'],
      soDienThoai: map['so_dien_thoai'],
      googleId: map['google'],
      ngaySinh: map['ngay_sinh'] != null
          ? DateTime.parse(map['ngay_sinh'])
          : null,
      gioiTinh: map['gioi_tinh'],
      diaChi: map['dia_chi'],
      trangThaiId: (statusId ?? TrangThaiId.hoatDong) == 0
          ? TrangThaiId.hoatDong
          : (statusId ?? TrangThaiId.hoatDong),
      ngayTao: map['ngay_tao'] != null ? DateTime.parse(map['ngay_tao']) : null,
      role: map['role'] ?? 'benh_nhan',
      daXacThucEmail: map['da_xac_thuc_email'] ?? false,
      cccd: map['cccd'],
      soBhyt: map['so_bhyt'],
      isBlocked: blocked,
      chanDangNhap: chan,
      lyDoKhoa: map['ly_do_khoa']?.toString() ?? map['ly_do_chan']?.toString(),
    );
  }

  PatientModel copyWith({
    String? uid,
    String? maBenhNhan,
    String? hoTen,
    String? email,
    String? soDienThoai,
    String? googleId,
    DateTime? ngaySinh,
    String? gioiTinh,
    String? diaChi,
    int? trangThaiId,
    DateTime? ngayTao,
    String? role,
    bool? daXacThucEmail,
    String? cccd,
    String? soBhyt,
    bool? isBlocked,
    bool? chanDangNhap,
    String? lyDoKhoa,
  }) {
    return PatientModel(
      uid: uid ?? this.uid,
      maBenhNhan: maBenhNhan ?? this.maBenhNhan,
      hoTen: hoTen ?? this.hoTen,
      email: email ?? this.email,
      soDienThoai: soDienThoai ?? this.soDienThoai,
      googleId: googleId ?? this.googleId,
      ngaySinh: ngaySinh ?? this.ngaySinh,
      gioiTinh: gioiTinh ?? this.gioiTinh,
      diaChi: diaChi ?? this.diaChi,
      trangThaiId: trangThaiId ?? this.trangThaiId,
      ngayTao: ngayTao ?? this.ngayTao,
      role: role ?? this.role,
      daXacThucEmail: daXacThucEmail ?? this.daXacThucEmail,
      cccd: cccd ?? this.cccd,
      soBhyt: soBhyt ?? this.soBhyt,
      isBlocked: isBlocked ?? this.isBlocked,
      chanDangNhap: chanDangNhap ?? this.chanDangNhap,
      lyDoKhoa: lyDoKhoa ?? this.lyDoKhoa,
    );
  }

  factory PatientModel.fromRegisterEmail({
    required String uid,
    required String hoTen,
    required String email,
    String? role,
  }) {
    return PatientModel(
      uid: uid,
      hoTen: hoTen,
      email: email,
      trangThaiId: TrangThaiId.hoatDong,
      ngayTao: DateTime.now(),
      role: role ?? 'benh_nhan',
      daXacThucEmail: false,
    );
  }

  factory PatientModel.fromRegisterPhone({
    required String uid,
    required String hoTen,
    required String soDienThoai,
    String? role,
  }) {
    return PatientModel(
      uid: uid,
      hoTen: hoTen,
      soDienThoai: soDienThoai,
      trangThaiId: TrangThaiId.hoatDong,
      ngayTao: DateTime.now(),
      role: role ?? 'benh_nhan',
      daXacThucEmail: true,
    );
  }

  factory PatientModel.fromGoogle({
    required String uid,
    required String hoTen,
    required String email,
    required String googleId,
  }) {
    return PatientModel(
      uid: uid,
      hoTen: hoTen,
      email: email,
      googleId: googleId,
      trangThaiId: TrangThaiId.hoatDong,
      ngayTao: DateTime.now(),
      role: 'benh_nhan',
      daXacThucEmail: true,
    );
  }
}