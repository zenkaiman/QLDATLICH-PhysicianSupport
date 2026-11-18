class PhongKhamModel {
  final String id;
  final String hospitalId;
  final String khoaId;
  final String tenPhong;
  final String soPhong;
  final String gioMoCua;
  final String gioDongCua;
  final int thoiGianKham; // Tính bằng phút
  final int soBenhNhanToiDa;
  final String? nhanVienId;

  PhongKhamModel({
    required this.id,
    required this.hospitalId,
    required this.khoaId,
    required this.tenPhong,
    required this.soPhong,
    required this.gioMoCua,
    required this.gioDongCua,
    required this.thoiGianKham,
    required this.soBenhNhanToiDa,
    this.nhanVienId,
  });

  factory PhongKhamModel.fromMap(Map<String, dynamic> map, String docId) {
    return PhongKhamModel(
      id: docId,
      hospitalId: map['hospitalId'] ?? '',
      khoaId: map['khoaId'] ?? '',
      tenPhong: map['tenPhong'] ?? '',
      soPhong: map['so_phong'] ?? '',
      gioMoCua: map['gioMoCua'] ?? '',
      gioDongCua: map['gioDongCua'] ?? '',
      thoiGianKham: (map['thoiGianKham'] as num?)?.toInt() ?? 0,
      soBenhNhanToiDa: (map['soBenhNhanToiDa'] as num?)?.toInt() ?? 0,
      nhanVienId: map['nhanVienId'],
    );
  }
}