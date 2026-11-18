import '../config/constants.dart';

class PatientModel {
  final String uid;
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

  PatientModel({
    required this.uid,
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
  }) : ngayTao = ngayTao ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
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
    };
  }

  factory PatientModel.fromMap(Map<String, dynamic> map) {
    return PatientModel(
      uid: map['uid'] ?? '',
      hoTen: map['ho_ten'],
      email: map['email'],
      soDienThoai: map['so_dien_thoai'],
      googleId: map['google'],
      ngaySinh: map['ngay_sinh'] != null
          ? DateTime.parse(map['ngay_sinh'])
          : null,
      gioiTinh: map['gioi_tinh'],
      diaChi: map['dia_chi'],
      trangThaiId: (map['trang_thai_id'] ?? TrangThaiId.hoatDong) == 0
          ? TrangThaiId.hoatDong
          : map['trang_thai_id'],
      ngayTao: map['ngay_tao'] != null ? DateTime.parse(map['ngay_tao']) : null,
      role: map['role'] ?? 'benh_nhan',
      daXacThucEmail: map['da_xac_thuc_email'] ?? false,
      cccd: map['cccd'],
      soBhyt: map['so_bhyt'],
    );
  }

  PatientModel copyWith({
    String? uid,
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
  }) {
    return PatientModel(
      uid: uid ?? this.uid,
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
