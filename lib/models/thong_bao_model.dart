import 'package:cloud_firestore/cloud_firestore.dart';

import 'nhan_vien_model.dart';

/// Model dữ liệu Thông báo trong hệ thống Bệnh viện
class ThongBaoModel {
  final String id;
  final String tieuDe;
  final String noiDungNgan;
  final String noiDungChiTiet;
  final DateTime thoiGian;
  final String loai; // 'kich_hoat_tai_khoan', 'he_thong', 'lich_hen',...
  final bool daDoc;
  final String? benhVienId;
  final String? maNhanVien;
  final String? tenNhanVien;
  final String? khoa;
  final String? vaiTro;
  final Map<String, dynamic>? metadata;

  // Trạng thái phân công công việc
  final bool daPhanCong;
  final int trangThaiId; // 15: Chờ, 16: Đã phân công
  final String? phongPhanCong;
  final String? ngayPhanCong;

  const ThongBaoModel({
    required this.id,
    required this.tieuDe,
    required this.noiDungNgan,
    required this.noiDungChiTiet,
    required this.thoiGian,
    this.loai = 'kich_hoat_tai_khoan',
    this.daDoc = false,
    this.benhVienId,
    this.maNhanVien,
    this.tenNhanVien,
    this.khoa,
    this.vaiTro,
    this.metadata,
    this.daPhanCong = false,
    this.trangThaiId = 15,
    this.phongPhanCong,
    this.ngayPhanCong,
  });

  ThongBaoModel copyWith({
    bool? daDoc,
    bool? daPhanCong,
    int? trangThaiId,
    String? phongPhanCong,
    String? ngayPhanCong,
    String? noiDungNgan,
    String? noiDungChiTiet,
  }) {
    return ThongBaoModel(
      id: id,
      tieuDe: tieuDe,
      noiDungNgan: noiDungNgan ?? this.noiDungNgan,
      noiDungChiTiet: noiDungChiTiet ?? this.noiDungChiTiet,
      thoiGian: thoiGian,
      loai: loai,
      daDoc: daDoc ?? this.daDoc,
      benhVienId: benhVienId,
      maNhanVien: maNhanVien,
      tenNhanVien: tenNhanVien,
      khoa: khoa,
      vaiTro: vaiTro,
      metadata: metadata,
      daPhanCong: daPhanCong ?? this.daPhanCong,
      trangThaiId: trangThaiId ?? this.trangThaiId,
      phongPhanCong: phongPhanCong ?? this.phongPhanCong,
      ngayPhanCong: ngayPhanCong ?? this.ngayPhanCong,
    );
  }

  /// Tạo thông báo từ đối tượng NhanVienModel đã kích hoạt
  factory ThongBaoModel.fromNhanVienKichHoat({
    required NhanVienModel nv,
    required bool daDoc,
    DateTime? thoiGianKichHoat,
    bool? daPhanCong,
    int? trangThaiId,
    String? phongPhanCong,
    String? ngayPhanCong,
  }) {
    final tenKhoa = nv.khoa.isNotEmpty ? nv.khoa : 'Chuyên khoa';
    final vaiTro = nv.vaiTro.isNotEmpty
        ? nv.vaiTro
        : (nv.role.isNotEmpty ? nv.role : 'Nhân viên');
    final tg = thoiGianKichHoat ?? nv.ngayTao ?? DateTime.now();

    final isDaPhanCong = daPhanCong ?? nv.daPhanCong;
    final int ttId = trangThaiId ?? (isDaPhanCong ? 16 : (nv.trangThaiId != 0 ? nv.trangThaiId : 15));
    final phongPc = phongPhanCong ?? nv.phongPhanCong;
    final ngayPc = ngayPhanCong ?? nv.ngayPhanCong;

    final String ttText = isDaPhanCong
        ? (phongPc != null && phongPc.isNotEmpty
            ? 'Đã phân công ($phongPc)'
            : 'Đã phân công lịch làm')
        : 'Chờ - Chờ nhận lịch làm';

    final String moTaTrangThai = isDaPhanCong
        ? (phongPc != null && phongPc.isNotEmpty
            ? 'Nhân sự đã được phân công trực tại $phongPc (Trạng thái 16).'
            : 'Nhân sự đã được phân công lịch làm việc thành công (Trạng thái 16).')
        : 'Nhân sự hiện đã sẵn sàng và đủ điều kiện để được phân công ca trực theo ngày trong mục Phân Công Trực.';

    return ThongBaoModel(
      id: 'tb_kich_hoat_${nv.maNv}',
      tieuDe: 'Tài khoản nhân sự đã được kích hoạt',
      noiDungNgan:
          'Nhân viên ${nv.hoTen} ($vaiTro - ${nv.maNv}) thuộc $tenKhoa đã được kích hoạt tài khoản thành công.',
      noiDungChiTiet:
          'Tài khoản nhân sự đã được kích hoạt thành công trên hệ thống:\n\n'
          '• Họ và tên: ${nv.hoTen}\n'
          '• Mã nhân sự: ${nv.maNv}\n'
          '• Chuyên khoa: $tenKhoa\n'
          '• Vai trò: $vaiTro\n'
          '• Số điện thoại: ${nv.soDienThoai.isNotEmpty ? nv.soDienThoai : "Chưa cập nhật"}\n'
          '• Email: ${nv.email.isNotEmpty ? nv.email : "Chưa cập nhật"}\n'
          '• Trạng thái nhân sự: Đang hoạt động\n'
          '• Trạng thái nhận việc: $ttText\n\n'
          '$moTaTrangThai',
      thoiGian: tg,
      loai: 'kich_hoat_tai_khoan',
      daDoc: daDoc,
      benhVienId: nv.benhVienId,
      maNhanVien: nv.maNv,
      tenNhanVien: nv.hoTen,
      khoa: tenKhoa,
      vaiTro: vaiTro,
      daPhanCong: isDaPhanCong,
      trangThaiId: ttId,
      phongPhanCong: phongPc,
      ngayPhanCong: ngayPc,
    );
  }

  /// Tạo thông báo từ Document Firestore (nếu có trong ThongBaoHeThong hoặc ThongBao)
  factory ThongBaoModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool daDoc = false,
  }) {
    final data = doc.data() ?? {};
    DateTime tg = DateTime.now();
    final rawTg = data['thoi_gian'] ?? data['ngay_tao'] ?? data['createdAt'];
    if (rawTg is Timestamp) {
      tg = rawTg.toDate();
    }

    final bool isDaPhanCong = (data['da_phan_cong'] == true) ||
        (data['trang_thai_id'] == 16) ||
        (data['trang_thai'] == 'đã phân công') ||
        (data['phong_phan_cong'] != null &&
            data['phong_phan_cong'].toString().trim().isNotEmpty);

    final int ttId = isDaPhanCong
        ? 16
        : (int.tryParse(data['trang_thai_id']?.toString() ?? '15') ?? 15);

    return ThongBaoModel(
      id: doc.id,
      tieuDe: (data['tieu_de'] ?? data['ten_loai'] ?? 'Thông báo').toString(),
      noiDungNgan: (data['noi_dung_ngan'] ?? data['mo_ta'] ?? '').toString(),
      noiDungChiTiet:
          (data['noi_dung_chi_tiet'] ?? data['noi_dung'] ?? data['mo_ta'] ?? '')
              .toString(),
      thoiGian: tg,
      loai: (data['loai'] ?? data['id_loai'] ?? 'he_thong').toString(),
      daDoc: (data['da_doc'] == true) || daDoc,
      benhVienId: data['benh_vien_id']?.toString(),
      maNhanVien: data['ma_nhan_vien']?.toString(),
      tenNhanVien: data['ten_nhan_vien']?.toString(),
      khoa: data['khoa']?.toString(),
      vaiTro: data['vai_tro']?.toString(),
      metadata: data,
      daPhanCong: isDaPhanCong,
      trangThaiId: ttId,
      phongPhanCong:
          data['phong_phan_cong']?.toString() ?? data['phong']?.toString(),
      ngayPhanCong:
          data['ngay_phan_cong']?.toString() ?? data['ngay']?.toString(),
    );
  }

  /// Định dạng thời gian hiển thị thân thiện (Vừa xong, hôm nay, ngày tháng...)
  String get thoiGianHienThi {
    final now = DateTime.now();
    final diff = now.difference(thoiGian);

    if (diff.inSeconds < 60) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24 && now.day == thoiGian.day) {
      final h = thoiGian.hour.toString().padLeft(2, '0');
      final m = thoiGian.minute.toString().padLeft(2, '0');
      return '$h:$m Hôm nay';
    } else {
      final d = thoiGian.day.toString().padLeft(2, '0');
      final m = thoiGian.month.toString().padLeft(2, '0');
      final y = thoiGian.year;
      final h = thoiGian.hour.toString().padLeft(2, '0');
      final min = thoiGian.minute.toString().padLeft(2, '0');
      return '$h:$min $d/$m/$y';
    }
  }
}
