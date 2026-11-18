import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_profile_model.dart';

/// Một lịch hẹn (document trong .../benh_nhan/{id bệnh nhân}/lich_hen/{id lịch hẹn}).
/// Đọc được cả dữ liệu do saveBooking ghi và dữ liệu do LichHenSeeder ghi.
class LichHenModel {
  final String id;
  final String benhVienId;
  final String khoaId;
  final String phongKhamId;
  final String? profileId;
  final String? tenNguoiKham;
  final String? quanHe;
  final String caId; // id của bảng Ca (ca_sang / ca_chieu)
  final String benhNhanId;
  final String trangThaiId; // "1", "2"... (bảng TrangThai)
  final DateTime?
  ngayDat; // ngày khám (field ngay_dat, hoặc ngay_hen của seeder)
  final DateTime? ngayTao;
  final String gioDuKien;
  final int soThuTu;
  final String? maQr;

  // Thông tin hiển thị. Có sẵn nếu lúc đặt lịch đã lưu kèm,
  // nếu không thì service sẽ tra cứu thêm (ca, khoa).
  final String? tenBenhVien;
  final String? tenKhoa;
  final String? tenPhongKham;
  final String? tenCa;
  final String? gioBatDau;
  final String? gioKetThuc;

  const LichHenModel({
    required this.id,
    required this.benhVienId,
    required this.khoaId,
    required this.phongKhamId,
    required this.caId,
    required this.benhNhanId,
    required this.trangThaiId,
    this.ngayDat,
    this.ngayTao,
    this.gioDuKien = '',
    this.soThuTu = 0,
    this.maQr,
    this.tenBenhVien,
    this.tenKhoa,
    this.tenPhongKham,
    this.tenCa,
    this.gioBatDau,
    this.gioKetThuc,
    this.profileId,
    this.tenNguoiKham,
    this.quanHe,
  });

  /// Alias cho code cũ dùng tên ngayHen.
  DateTime? get ngayHen => ngayDat;

  String get profileKey => (profileId == null || profileId!.isEmpty)
      ? FamilyProfileModel.selfId
      : profileId!;

  static DateTime? _toDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  static String? _optString(dynamic v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory LichHenModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return LichHenModel(
      id: id ?? (json['id'] ?? '').toString(),
      benhVienId: (json['benh_vien_id'] ?? '').toString(),
      khoaId: (json['khoa_id'] ?? '').toString(),
      phongKhamId: (json['phong_kham_id'] ?? '').toString(),
      caId: (json['ca_id'] ?? '').toString(),
      benhNhanId: (json['benh_nhan_id'] ?? '').toString(),
      // saveBooking lưu trang_thai_id là chuỗi ("1"), seeder lưu số -> đọc được cả hai
      trangThaiId: (json['trang_thai_id'] ?? '').toString(),
      ngayDat: _toDate(json['ngay_dat'] ?? json['ngay_hen']),
      ngayTao: _toDate(json['ngay_tao']),
      gioDuKien: (json['gio_du_kien'] ?? '').toString(),
      soThuTu: (json['so_thu_tu'] as num?)?.toInt() ?? 0,
      maQr: _optString(json['ma_qr']),
      tenBenhVien: _optString(json['ten_benh_vien']),
      tenKhoa: _optString(json['ten_khoa']),
      tenPhongKham: _optString(json['ten_phong_kham']),
      tenCa: _optString(json['ten_ca']),
      gioBatDau: _optString(json['gio_bat_dau']),
      gioKetThuc: _optString(json['gio_ket_thuc']),
      profileId: _optString(json['profile_id']),
      tenNguoiKham: _optString(json['ten_nguoi_kham']),
      quanHe: _optString(json['quan_he']),
    );
  }

  LichHenModel copyWith({
    String? tenBenhVien,
    String? tenKhoa,
    String? tenPhongKham,
    String? tenCa,
    String? gioBatDau,
    String? gioKetThuc,
  }) {
    return LichHenModel(
      id: id,
      benhVienId: benhVienId,
      khoaId: khoaId,
      phongKhamId: phongKhamId,
      caId: caId,
      benhNhanId: benhNhanId,
      trangThaiId: trangThaiId,
      ngayDat: ngayDat,
      ngayTao: ngayTao,
      gioDuKien: gioDuKien,
      soThuTu: soThuTu,
      maQr: maQr,
      tenBenhVien: tenBenhVien ?? this.tenBenhVien,
      tenKhoa: tenKhoa ?? this.tenKhoa,
      tenPhongKham: tenPhongKham ?? this.tenPhongKham,
      tenCa: tenCa ?? this.tenCa,
      gioBatDau: gioBatDau ?? this.gioBatDau,
      gioKetThuc: gioKetThuc ?? this.gioKetThuc,
      profileId: profileId,
      tenNguoiKham: tenNguoiKham,
      quanHe: quanHe,
    );
  }
}

/// Tình trạng của 1 ca (sáng / chiều) của 1 phòng khám trong 1 ngày.
/// Dùng để hiện "Còn x/y chỗ" khi người dùng chọn ngày.
class CaSlotModel {
  final String caId; // ca_sang / ca_chieu
  final String tenCa; // Ca sáng / Ca chiều
  final String gioBatDau; // 07:30
  final String gioKetThuc; // 12:00
  final int tongSo; // số bệnh nhân tối đa của phòng
  final int daDat; // số lịch hẹn đã có

  const CaSlotModel({
    required this.caId,
    required this.tenCa,
    required this.gioBatDau,
    required this.gioKetThuc,
    required this.tongSo,
    required this.daDat,
  });

  /// Số chỗ còn lại (không âm)
  int get conLai => tongSo - daDat < 0 ? 0 : tongSo - daDat;
  bool get hetCho => conLai <= 0;
}
