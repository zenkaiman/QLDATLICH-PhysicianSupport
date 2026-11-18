/// Model dữ liệu phòng khám phục vụ phân công trực
class PhongItemPhanCong {
  final String id;
  final String tenPhong;
  final String gioMoCua;
  final String gioDongCua;
  final int soBenhNhanToiDa;
  final String thoiGianKham;

  const PhongItemPhanCong({
    required this.id,
    required this.tenPhong,
    required this.gioMoCua,
    required this.gioDongCua,
    required this.soBenhNhanToiDa,
    required this.thoiGianKham,
  });

  String get thoiGianVaDiaDiem {
    final gio = (gioMoCua.isNotEmpty && gioDongCua.isNotEmpty)
        ? '$gioMoCua - $gioDongCua'
        : '07:30 - 17:00';
    return '$gio · Tối đa $soBenhNhanToiDa BN/ca';
  }
}

/// Model dữ liệu phân công trực 1 ca / 1 vai trò trong ngày
class PhanCongItemModel {
  final String id;
  final String ngay;
  final String benhVienId;
  final String khoaId;
  final String tenKhoa;
  final String prefixKhoa;
  final String phongId;
  final String tenPhong;
  final String vaiTroCode;
  final String maNhanVien;
  final String tenNhanVien;
  final String vaiTro;
  final int trangThaiId;
  final String trangThai;

  const PhanCongItemModel({
    required this.id,
    required this.ngay,
    required this.benhVienId,
    required this.khoaId,
    required this.tenKhoa,
    required this.prefixKhoa,
    required this.phongId,
    required this.tenPhong,
    required this.vaiTroCode,
    required this.maNhanVien,
    required this.tenNhanVien,
    required this.vaiTro,
    this.trangThaiId = 16,
    this.trangThai = 'đã phân công',
  });

  factory PhanCongItemModel.fromMap(String docId, Map<String, dynamic> map) {
    return PhanCongItemModel(
      id: docId,
      ngay: (map['ngay'] ?? '').toString(),
      benhVienId: (map['benh_vien_id'] ?? '').toString(),
      khoaId: (map['khoa_id'] ?? '').toString(),
      tenKhoa: (map['ten_khoa'] ?? '').toString(),
      prefixKhoa: (map['prefix_khoa'] ?? '').toString(),
      phongId: (map['phong_id'] ?? map['ten_phong'] ?? '').toString(),
      tenPhong: (map['ten_phong'] ?? map['phong_id'] ?? '').toString(),
      vaiTroCode: (map['vai_tro_code'] ?? '').toString(),
      maNhanVien:
          (map['nhan_vien_id'] ?? map['ma_nhan_vien'] ?? '').toString(),
      tenNhanVien: (map['ten_nhan_vien'] ?? '').toString(),
      vaiTro: (map['vai_tro'] ?? '').toString(),
      trangThaiId: (map['trang_thai_id'] is int)
          ? map['trang_thai_id'] as int
          : 16,
      trangThai: (map['trang_thai'] ?? 'đã phân công').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ngay': ngay,
      'benh_vien_id': benhVienId,
      'khoa_id': khoaId,
      'ten_khoa': tenKhoa,
      'prefix_khoa': prefixKhoa,
      'phong_id': phongId,
      'ten_phong': tenPhong,
      'vai_tro_code': vaiTroCode,
      'nhan_vien_id': maNhanVien,
      'ma_nhan_vien': maNhanVien,
      'ten_nhan_vien': tenNhanVien,
      'vai_tro': vaiTro,
      'trang_thai_id': trangThaiId,
      'trang_thai': trangThai,
    };
  }
}
