/// Model thông tin đơn khám bệnh (chuẩn bị sẵn toMap & fromMap cho Firebase Firestore)
class DonKhamKhoaModelC1 {
  final String id;
  final int stt;
  final String maDon;
  final String hoTen;
  final String tenKhoa;
  final String phongKham;
  final String caKham;
  final String khungGio;
  final String gioiTinh;
  final int tuoi;
  String trangThai; // 'cho_duyet', 'da_duyet', 'tu_choi'
  String? lyDoTuChoi;

  DonKhamKhoaModelC1({
    required this.id,
    required this.stt,
    required this.maDon,
    required this.hoTen,
    required this.tenKhoa,
    required this.phongKham,
    required this.caKham,
    required this.khungGio,
    required this.gioiTinh,
    required this.tuoi,
    this.trangThai = 'cho_duyet',
    this.lyDoTuChoi,
  });

  bool get laDaDuyet => trangThai == 'da_duyet';
  bool get laTuChoi => trangThai == 'tu_choi';
  bool get laChoDuyet => trangThai == 'cho_duyet';

  // Chuyển sang Map để sau này ghi lên Firestore: collection('don_kham').doc(id).set(map)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stt': stt,
      'maDon': maDon,
      'hoTen': hoTen,
      'tenKhoa': tenKhoa,
      'phongKham': phongKham,
      'caKham': caKham,
      'khungGio': khungGio,
      'gioiTinh': gioiTinh,
      'tuoi': tuoi,
      'trangThai': trangThai,
      'lyDoTuChoi': lyDoTuChoi,
    };
  }

  // Khởi tạo từ Map khi đọc từ Firestore: DonKhamKhoaModelC1.fromMap(doc.data())
  factory DonKhamKhoaModelC1.fromMap(Map<String, dynamic> map, [String? docId]) {
    return DonKhamKhoaModelC1(
      id: docId ?? (map['id'] ?? ''),
      stt: (map['stt'] as num?)?.toInt() ?? 0,
      maDon: map['maDon'] ?? '',
      hoTen: map['hoTen'] ?? '',
      tenKhoa: map['tenKhoa'] ?? '',
      phongKham: map['phongKham'] ?? '',
      caKham: map['caKham'] ?? '',
      khungGio: map['khungGio'] ?? '',
      gioiTinh: map['gioiTinh'] ?? '',
      tuoi: (map['tuoi'] as num?)?.toInt() ?? 0,
      trangThai: map['trangThai'] ?? 'cho_duyet',
      lyDoTuChoi: map['lyDoTuChoi'],
    );
  }
}

/// Model khoa khám tổng quan
class KhoaKhamModelC1 {
  final String id;
  final String tenKhoa;
  final String moTaPhong;
  final int tongDonCho;
  final int chiTieuNgay;
  final bool laDayDon;

  const KhoaKhamModelC1({
    required this.id,
    required this.tenKhoa,
    required this.moTaPhong,
    required this.tongDonCho,
    required this.chiTieuNgay,
    this.laDayDon = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenKhoa': tenKhoa,
      'moTaPhong': moTaPhong,
      'tongDonCho': tongDonCho,
      'chiTieuNgay': chiTieuNgay,
      'laDayDon': laDayDon,
    };
  }

  factory KhoaKhamModelC1.fromMap(Map<String, dynamic> map, [String? docId]) {
    return KhoaKhamModelC1(
      id: docId ?? (map['id'] ?? ''),
      tenKhoa: map['tenKhoa'] ?? '',
      moTaPhong: map['moTaPhong'] ?? '',
      tongDonCho: (map['tongDonCho'] as num?)?.toInt() ?? 0,
      chiTieuNgay: (map['chiTieuNgay'] as num?)?.toInt() ?? 0,
      laDayDon: map['laDayDon'] ?? false,
    );
  }
}

/// Model cuộc hội thoại hỗ trợ bệnh nhân (Chat CSKH)
class HoiThoaiCskhModelC1 {
  final String id;
  final String benhNhanId;
  final String hoTen;
  final String vietTat;
  final String tinNhanCuoi;
  final String thoiGian;
  final String khoa;
  final int tuoi;
  final String maBhyt;
  final int tinChuaDoc;
  final bool dangChoPhanHoi;

  const HoiThoaiCskhModelC1({
    required this.id,
    required this.benhNhanId,
    required this.hoTen,
    required this.vietTat,
    required this.tinNhanCuoi,
    required this.thoiGian,
    required this.khoa,
    required this.tuoi,
    required this.maBhyt,
    this.tinChuaDoc = 0,
    this.dangChoPhanHoi = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'benhNhanId': benhNhanId,
      'hoTen': hoTen,
      'vietTat': vietTat,
      'tinNhanCuoi': tinNhanCuoi,
      'thoiGian': thoiGian,
      'khoa': khoa,
      'tuoi': tuoi,
      'maBhyt': maBhyt,
      'tinChuaDoc': tinChuaDoc,
      'dangChoPhanHoi': dangChoPhanHoi,
    };
  }

  factory HoiThoaiCskhModelC1.fromMap(Map<String, dynamic> map, [String? docId]) {
    return HoiThoaiCskhModelC1(
      id: docId ?? (map['id'] ?? ''),
      benhNhanId: map['benhNhanId'] ?? '',
      hoTen: map['hoTen'] ?? '',
      vietTat: map['vietTat'] ?? '',
      tinNhanCuoi: map['tinNhanCuoi'] ?? '',
      thoiGian: map['thoiGian'] ?? '',
      khoa: map['khoa'] ?? '',
      tuoi: (map['tuoi'] as num?)?.toInt() ?? 0,
      maBhyt: map['maBhyt'] ?? '',
      tinChuaDoc: (map['tinChuaDoc'] as num?)?.toInt() ?? 0,
      dangChoPhanHoi: map['dangChoPhanHoi'] ?? false,
    );
  }
}

/// Model từng tin nhắn chi tiết trong phòng chat
class TinNhanCskhModelC1 {
  final String id;
  final String hoiThoaiId;
  final String noiDung;
  final String thoiGian;
  final bool laCskhGui; // true: CSKH gửi, false: Bệnh nhân gửi

  const TinNhanCskhModelC1({
    required this.id,
    required this.hoiThoaiId,
    required this.noiDung,
    required this.thoiGian,
    required this.laCskhGui,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hoiThoaiId': hoiThoaiId,
      'noiDung': noiDung,
      'thoiGian': thoiGian,
      'laCskhGui': laCskhGui,
    };
  }

  factory TinNhanCskhModelC1.fromMap(Map<String, dynamic> map, [String? docId]) {
    return TinNhanCskhModelC1(
      id: docId ?? (map['id'] ?? ''),
      hoiThoaiId: map['hoiThoaiId'] ?? '',
      noiDung: map['noiDung'] ?? '',
      thoiGian: map['thoiGian'] ?? '',
      laCskhGui: map['laCskhGui'] ?? false,
    );
  }
}
