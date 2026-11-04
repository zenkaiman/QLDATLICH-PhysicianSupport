// Model du lieu cho Le tan C1
class BenhNhanChoKhamC1 {
  final String id;
  final String ten;
  final String khoa;
  final String gioKham;
  final String trangThai; // "Tiếp theo", "Đang chờ", "Chưa đến"
  final String avatarInitials;

  const BenhNhanChoKhamC1({
    required this.id,
    required this.ten,
    required this.khoa,
    required this.gioKham,
    required this.trangThai,
    required this.avatarInitials,
  });
}

class ThongKeLeTanC1 {
  final int daTiepNhan;
  final int dangCho;
  final int daKham;

  const ThongKeLeTanC1({
    required this.daTiepNhan,
    required this.dangCho,
    required this.daKham,
  });
}

class ThongBaoLeTanC1 {
  final String id;
  final String tieuDe;
  final String noiDungNgan;
  final String noiDungChiTiet;
  final String thoiGian;
  final String loai; // 'khan_cap', 'lich_hen', 'he_thong', 'nhan_su'
  final bool daDoc;

  const ThongBaoLeTanC1({
    required this.id,
    required this.tieuDe,
    required this.noiDungNgan,
    required this.noiDungChiTiet,
    required this.thoiGian,
    required this.loai,
    this.daDoc = false,
  });
}
