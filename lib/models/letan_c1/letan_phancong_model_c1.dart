import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một bản ghi phân công ca trực từ Collection /PhanCong/{benhVienId}/danh_sach
class PhanCongCaTrucModelC1 {
  final bool duocPhanCong; // true khi trang_thai_id == 16 hoặc trang_thai == "đã phân công"
  final int trangThaiId; // Mã số trạng thái (16 là "đã phân công")
  final String trangThai; // "đã phân công"
  final String tenKhoa; // "Khoa Cơ xương khớp"
  final String phongId; // "CXK001"
  final String tenPhong; // "CXK001"
  final String vaiTro; // "CSKH" hoặc "Lễ tân"
  final String maNhanVien; // "BV502_CSKH_CXK_01"
  final String tenNhanVien; // "cuoc xương"
  final String ngay; // "2026-11-13" (yyyy-MM-dd)
  final String prefixKhoa;
  final DateTime? ngayCapNhat;
  final String lyDoKhoa; // Lý do nếu bị khóa

  const PhanCongCaTrucModelC1({
    required this.duocPhanCong,
    required this.trangThaiId,
    required this.trangThai,
    required this.tenKhoa,
    required this.phongId,
    required this.tenPhong,
    required this.vaiTro,
    required this.maNhanVien,
    required this.tenNhanVien,
    required this.ngay,
    this.prefixKhoa = '',
    this.ngayCapNhat,
    this.lyDoKhoa = '',
  });

  /// Trạng thái mặc định khi chưa tìm thấy phân công
  factory PhanCongCaTrucModelC1.chuaPhanCong({
    String lyDo = 'Tài khoản chưa được Bệnh viện phân công ca trực hôm nay (Chờ kích hoạt ca trực)',
    int trangThaiId = 0,
    String trangThai = 'Chờ phân công',
    String tenKhoa = '',
    String phongId = '',
    String tenPhong = '',
    String vaiTro = '',
    String maNhanVien = '',
    String tenNhanVien = '',
    String ngay = '',
  }) {
    return PhanCongCaTrucModelC1(
      duocPhanCong: false,
      trangThaiId: trangThaiId,
      trangThai: trangThai,
      tenKhoa: tenKhoa,
      phongId: phongId,
      tenPhong: tenPhong,
      vaiTro: vaiTro,
      maNhanVien: maNhanVien,
      tenNhanVien: tenNhanVien,
      ngay: ngay,
      lyDoKhoa: lyDo,
    );
  }

  /// Khởi tạo từ Map dữ liệu Firestore Document
  factory PhanCongCaTrucModelC1.fromMap(Map<String, dynamic> data) {
    final rawId = data['trang_thai_id'] ?? data['trangThaiId'] ?? 0;
    final int statusId = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
    final String statusStr = (data['trang_thai'] ?? data['trangThai'] ?? '').toString();

    // QUY TẮC PHÂN CÔNG: Bắt buộc trang_thai_id == 16 (hoặc trang_thai == "đã phân công")
    final bool isAssigned = (statusId == 16) || statusStr.trim().toLowerCase() == 'đã phân công';

    DateTime? updated;
    if (data['ngay_cap_nhat'] is Timestamp) {
      updated = (data['ngay_cap_nhat'] as Timestamp).toDate();
    }

    final tenKhoa = (data['ten_khoa'] ?? data['tenKhoa'] ?? '').toString();
    final phongId = (data['phong_id'] ?? data['phongId'] ?? '').toString();
    final tenPhong = (data['ten_phong'] ?? data['tenPhong'] ?? data['phong_id'] ?? '').toString();
    final vaiTro = (data['vai_tro'] ?? data['vaiTro'] ?? '').toString();
    final maNv = (data['ma_nhan_vien'] ?? data['nhan_vien_id'] ?? data['maNhanVien'] ?? '').toString();
    final tenNv = (data['ten_nhan_vien'] ?? data['tenNhanVien'] ?? '').toString();
    final ngay = (data['ngay'] ?? '').toString();
    final prefixKhoa = (data['prefix_khoa'] ?? '').toString();

    String lyDoKhoa = '';
    if (!isAssigned) {
      lyDoKhoa = statusStr.isNotEmpty
          ? 'Bệnh viện chưa kích hoạt ca trực: Trạng thái hiện tại là "$statusStr", vui lòng chờ Bệnh viện phân công để mở khóa.'
          : 'Tài khoản chưa được Bệnh viện phân công ca trực.';
    }

    return PhanCongCaTrucModelC1(
      duocPhanCong: isAssigned,
      trangThaiId: statusId,
      trangThai: statusStr.isNotEmpty ? statusStr : (isAssigned ? 'đã phân công' : 'chờ phân công'),
      tenKhoa: tenKhoa,
      phongId: phongId,
      tenPhong: tenPhong,
      vaiTro: vaiTro,
      maNhanVien: maNv,
      tenNhanVien: tenNv,
      ngay: ngay,
      prefixKhoa: prefixKhoa,
      ngayCapNhat: updated,
      lyDoKhoa: lyDoKhoa,
    );
  }
}
