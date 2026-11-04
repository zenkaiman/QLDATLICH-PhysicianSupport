class ThongTinLeTanC1 {
  final String hoTen;
  final String chucVu; // Chức vụ lớn nằm ngay dưới tên (ví dụ: "Nhân Viên Lễ Tân Tiếp Đón")
  final String maNhanVien;
  final String khoa;
  final String email;
  final String avatarUrl;
  final String benhVienId;
  final String tenBenhVien;

  const ThongTinLeTanC1({
    required this.hoTen,
    required this.chucVu,
    required this.maNhanVien,
    required this.khoa,
    required this.email,
    this.avatarUrl = '',
    this.benhVienId = 'BV502',
    this.tenBenhVien = 'Bệnh viện Đa khoa Quốc tế',
  });

  ThongTinLeTanC1 copyWith({
    String? hoTen,
    String? chucVu,
    String? maNhanVien,
    String? khoa,
    String? email,
    String? avatarUrl,
    String? benhVienId,
    String? tenBenhVien,
  }) {
    return ThongTinLeTanC1(
      hoTen: hoTen ?? this.hoTen,
      chucVu: chucVu ?? this.chucVu,
      maNhanVien: maNhanVien ?? this.maNhanVien,
      khoa: khoa ?? this.khoa,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      benhVienId: benhVienId ?? this.benhVienId,
      tenBenhVien: tenBenhVien ?? this.tenBenhVien,
    );
  }
}

class DuLieuProfileMauC1 {
  static const List<String> danhSachKhoaCoSan = [
    'Khoa Tim Mạch',
    'Khoa Nhi Tiêu Hóa',
    'Khoa Mắt Kỹ Thuật Cao',
    'Khoa Da Liễu',
    'Khoa Nội Tổng Hợp',
    'Khoa Tai Mũi Họng',
    'Khoa Răng Hàm Mặt',
    'Khoa Cấp Cứu',
  ];

  static ThongTinLeTanC1 thongTinHienTai = const ThongTinLeTanC1(
    hoTen: 'Đinh Hoàng Cước',
    chucVu: 'NHÂN VIÊN LỄ TÂN TIẾP ĐÓN',
    maNhanVien: 'LT_TM_01',
    khoa: 'Khoa Tim Mạch',
    email: 'cuoc@gmail.com',
  );
}
