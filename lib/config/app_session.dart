/// Lưu ID bệnh viện đang quản lý
class AppSession {
  static String benhVienId = 'dFmZHBjFNUT1eRzJjXp5';
  static String? benhVienPath;

  /// ---------------------------------------------------------------------------
  /// ĐỊNH DANH BỆNH NHÂN ĐANG ĐĂNG NHẬP
  /// Dùng để lọc thông báo realtime bên phần Bệnh nhân (collection ThongBaoHeThong).
  /// Có thể gán 1 hoặc nhiều định danh tuỳ dữ liệu LichHen đang lưu:
  /// - uidBenhNhan   : Firebase Auth UID
  /// - benhNhanId    : mã / document id trong collection BenhNhan
  /// - soDienThoai   : số điện thoại dùng khi đặt lịch
  /// - emailBenhNhan : email dùng khi đặt lịch
  /// ---------------------------------------------------------------------------
  static String? uidBenhNhan;
  static String? benhNhanId;
  static String? soDienThoaiBenhNhan;
  static String? emailBenhNhan;

  /// Cập nhật định danh bệnh nhân sau khi đăng nhập / đặt lịch / nhận QR
  static void capNhatDinhDanhBenhNhan({
    String? uid,
    String? benhNhanId,
    String? soDienThoai,
    String? email,
  }) {
    if (uid != null && uid.trim().isNotEmpty) uidBenhNhan = uid.trim();
    if (benhNhanId != null && benhNhanId.trim().isNotEmpty) {
      AppSession.benhNhanId = benhNhanId.trim();
    }
    if (soDienThoai != null && soDienThoai.trim().isNotEmpty) {
      soDienThoaiBenhNhan = soDienThoai.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      emailBenhNhan = email.trim();
    }
  }

  /// Xoá định danh khi bệnh nhân đăng xuất
  static void xoaDinhDanhBenhNhan() {
    uidBenhNhan = null;
    benhNhanId = null;
    soDienThoaiBenhNhan = null;
    emailBenhNhan = null;
  }

  /// Danh sách định danh đã chuẩn hoá (bỏ rỗng, email chữ thường)
  static Set<String> get dinhDanhBenhNhan {
    final ketQua = <String>{};
    void them(String? giaTri) {
      final value = (giaTri ?? '').trim();
      if (value.isNotEmpty) ketQua.add(value.toLowerCase());
    }

    them(uidBenhNhan);
    them(benhNhanId);
    them(soDienThoaiBenhNhan);
    them(emailBenhNhan);
    return ketQua;
  }
}
