class LichHenItemC1 {
  final String id;
  final String ten;
  final String sdt;
  final String khoa;
  final String gioKham;
  final String trangThai; // "Tiếp theo", "Đang chờ", "Chưa đến", "Đã khám", "Vắng"
  final String avatarInitials;

  const LichHenItemC1({
    required this.id,
    required this.ten,
    required this.sdt,
    required this.khoa,
    required this.gioKham,
    required this.trangThai,
    required this.avatarInitials,
  });
}

class DuLieuMauLichHenC1 {
  static const String ngayHienTai = 'Thứ Hai, 21/09/2026';
  static const int tongSoLichHen = 28;

  static const List<LichHenItemC1> danhSachLichHen = [
    LichHenItemC1(
      id: 'LH01',
      ten: 'Nguyễn Văn An',
      sdt: '0901234567',
      khoa: 'Khoa Tim mạch',
      gioKham: '08:30 – 09:00',
      trangThai: 'Tiếp theo',
      avatarInitials: 'NA',
    ),
    LichHenItemC1(
      id: 'LH02',
      ten: 'Trần Thị Hoa',
      sdt: '0912345678',
      khoa: 'Khoa Nhi Tiêu Hóa',
      gioKham: '09:00 – 09:30',
      trangThai: 'Đang chờ',
      avatarInitials: 'TH',
    ),
    LichHenItemC1(
      id: 'LH03',
      ten: 'Lê Minh',
      sdt: '0987654321',
      khoa: 'Khoa Mắt Kỹ Thuật Cao',
      gioKham: '09:15 – 09:45',
      trangThai: 'Đang chờ',
      avatarInitials: 'LM',
    ),
    LichHenItemC1(
      id: 'LH04',
      ten: 'Phạm Thị Tuyết',
      sdt: '0933445566',
      khoa: 'Khoa Tim mạch',
      gioKham: '10:00 – 10:30',
      trangThai: 'Chưa đến',
      avatarInitials: 'PT',
    ),
    LichHenItemC1(
      id: 'LH05',
      ten: 'Hoàng Văn Đức',
      sdt: '0944556677',
      khoa: 'Khoa Nội Tổng Hợp',
      gioKham: '10:30 – 11:00',
      trangThai: 'Chưa đến',
      avatarInitials: 'HV',
    ),
    LichHenItemC1(
      id: 'LH06',
      ten: 'Ngô Thị Lan',
      sdt: '0955667788',
      khoa: 'Khoa Da Liễu',
      gioKham: '07:30 – 08:00',
      trangThai: 'Đã khám',
      avatarInitials: 'NT',
    ),
    LichHenItemC1(
      id: 'LH07',
      ten: 'Vũ Quốc Bảo',
      sdt: '0977889900',
      khoa: 'Khoa Tim mạch',
      gioKham: '08:00 – 08:30',
      trangThai: 'Vắng',
      avatarInitials: 'QB',
    ),
  ];
}
