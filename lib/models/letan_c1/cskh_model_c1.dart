import 'package:cloud_firestore/cloud_firestore.dart';

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
/// Tương thích 100% với schema Firestore Conversations/{conversationId}
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
    final String hoTenVal = (map['tenBenhNhan'] ?? map['hoTen'] ?? map['ho_ten'] ?? 'Bệnh nhân').toString();
    final parts = hoTenVal.trim().split(' ');
    final String initials = parts.isNotEmpty
        ? parts.where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase()
        : 'BN';

    // Format thời gian hiển thị
    String timeStr = 'Vừa xong';
    final rawTs = map['lastMessageAt'] ?? map['thoi_gian_cap_nhat'] ?? map['thoiGian'] ?? map['updatedAt'] ?? map['createdAt'];
    if (rawTs is Timestamp) {
      final dt = rawTs.toDate();
      timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (rawTs is String && rawTs.isNotEmpty) {
      timeStr = rawTs;
    }

    // Đếm số tin nhắn chưa đọc của CSKH (unreadCountSupport)
    final int unreadSupport = (map['unreadCountSupport'] as num?)?.toInt() ??
        (map['tinChuaDoc'] as num?)?.toInt() ??
        (map['tin_chua_doc'] as num?)?.toInt() ??
        0;

    // Xác định hội thoại có đang chờ phản hồi từ CSKH hay không
    // 1. unreadCountSupport > 0
    // 2. Hoặc status == 'open'
    // 3. Hoặc chưa có CSKH phụ trách (supportId rỗng)
    final String statusStr = (map['status'] ?? 'open').toString().toLowerCase();
    final String supportIdStr = (map['supportId'] ?? '').toString();
    final bool isWaiting = unreadSupport > 0 ||
        statusStr == 'open' ||
        supportIdStr.isEmpty;

    return HoiThoaiCskhModelC1(
      id: docId ?? (map['id'] ?? ''),
      benhNhanId: (map['benhNhanId'] ?? map['benh_nhan_id'] ?? '').toString(),
      hoTen: hoTenVal,
      vietTat: initials.isNotEmpty ? initials : 'BN',
      tinNhanCuoi: (map['lastMessage'] ?? map['tinNhanCuoi'] ?? map['tin_nhan_cuoi'] ?? '...').toString(),
      thoiGian: timeStr,
      khoa: (map['tenKhoa'] ?? map['khoa'] ?? map['tenBenhVien'] ?? 'CSKH Bệnh viện').toString(),
      tuoi: (map['tuoi'] as num?)?.toInt() ?? 0,
      maBhyt: (map['maBhyt'] ?? map['ma_bhyt'] ?? '').toString(),
      tinChuaDoc: unreadSupport > 0 ? unreadSupport : (isWaiting ? 1 : 0),
      dangChoPhanHoi: isWaiting,
    );
  }
}

/// Model từng tin nhắn chi tiết trong phòng chat
/// Tương thích 100% với schema Conversations/{conversationId}/Messages/{messageId}
class TinNhanCskhModelC1 {
  final String id;
  final String hoiThoaiId;
  final String noiDung;
  final String thoiGian;
  final bool laCskhGui; // true: CSKH gửi, false: Bệnh nhân gửi
  final String type; // text, image, system
  final String imageUrl;
  final bool isRead;

  const TinNhanCskhModelC1({
    required this.id,
    required this.hoiThoaiId,
    required this.noiDung,
    required this.thoiGian,
    required this.laCskhGui,
    this.type = 'text',
    this.imageUrl = '',
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hoiThoaiId': hoiThoaiId,
      'noiDung': noiDung,
      'thoiGian': thoiGian,
      'laCskhGui': laCskhGui,
      'type': type,
      'imageUrl': imageUrl,
      'isRead': isRead,
    };
  }

  factory TinNhanCskhModelC1.fromMap(Map<String, dynamic> map, [String? docId]) {
    String timeStr = 'Vừa xong';
    final rawTs = map['createdAt'] ?? map['thoi_gian'] ?? map['thoiGian'] ?? map['timestamp'];
    if (rawTs is Timestamp) {
      final dt = rawTs.toDate();
      timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (rawTs is String && rawTs.isNotEmpty) {
      timeStr = rawTs;
    }

    final String role = (map['senderRole'] ?? '').toString().toLowerCase();
    final bool isSupport = role == 'support' ||
        map['laCskhGui'] == true ||
        map['la_cskh'] == true ||
        map['la_cskh_gui'] == true;

    return TinNhanCskhModelC1(
      id: docId ?? (map['id'] ?? ''),
      hoiThoaiId: (map['conversationId'] ?? map['hoiThoaiId'] ?? '').toString(),
      noiDung: (map['content'] ?? map['noiDung'] ?? map['noi_dung'] ?? '').toString(),
      thoiGian: timeStr,
      laCskhGui: isSupport,
      type: (map['type'] ?? 'text').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      isRead: map['isRead'] == true,
    );
  }
}
