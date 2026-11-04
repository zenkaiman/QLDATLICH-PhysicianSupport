enum TrangThaiNgayKhamC1 {
  dungNgay,     // Hôm nay đúng ngày hẹn khám
  chuaToiNgay,  // Lịch hẹn ở tương lai (chưa tới ngày khám)
  daQuaHan,     // Lịch hẹn ở quá khứ (đã quá hạn hoặc đã khám)
  khongXacDinh, // Lỗi hoặc không tìm thấy
}

class KetQuaQuetQrC1 {
  final bool thanhCong;
  final String thongBao;
  final String chiTietLoi;
  final TrangThaiNgayKhamC1 trangThaiNgayKham;
  final int? soThuTu;
  final String? gioKhamDuKien;
  final String? ngayKham;
  final String? hoTen;
  final String? maLichHen;
  final String? maBenhNhan;
  final String? namSinhGioiTinh;
  final String? cccd;
  final String? bhyt;
  final String? khoaKham;
  final String? phongKham;
  final String? caKham;
  final String? bacSi;

  const KetQuaQuetQrC1({
    required this.thanhCong,
    required this.thongBao,
    this.chiTietLoi = '',
    this.trangThaiNgayKham = TrangThaiNgayKhamC1.dungNgay,
    this.soThuTu,
    this.gioKhamDuKien,
    this.ngayKham,
    this.hoTen,
    this.maLichHen,
    this.maBenhNhan,
    this.namSinhGioiTinh,
    this.cccd,
    this.bhyt,
    this.khoaKham,
    this.phongKham,
    this.caKham,
    this.bacSi,
  });
}
