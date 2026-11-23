import 'package:flutter/material.dart';

// ============ MODEL BỆNH VIỆN ============
class Hospital {
  final String initials;
  String name;
  String type;
  final double rating;
  int doctors;
  final Color avatarBg;
  final Color avatarText;
  String? address;
  final String? code;
  final List<String>? departments;
  final int? totalReviews;
  final String? phone;
  final String? email;
  int? status;
  bool isBlocked;
  bool isUnpartnered;
  String? blockReason;

  Hospital({
    required this.initials,
    required this.name,
    required this.type,
    required this.rating,
    required this.doctors,
    required this.avatarBg,
    required this.avatarText,
    this.address,
    this.code,
    this.departments,
    this.totalReviews,
    this.phone,
    this.email,
    this.status,
    this.isBlocked = false,
    this.isUnpartnered = false,
    this.blockReason,
  });
}

// ============ MODEL BỆNH NHÂN CHO ADMIN ============
class AdminPatient {
  final String uid;
  String maBenhNhan;
  String hoTen;
  String? email;
  String? soDienThoai;
  String? diaChi;
  String? gioiTinh;
  DateTime? ngaySinh;
  DateTime? ngayTao;
  bool daXacThucEmail;
  int trangThaiId; // 7: Hoạt động, 8: Tạm khóa / chặn
  bool isBlocked;
  String? blockReason;
  DateTime? ngayKhoa;
  DateTime? ngayOffline;
  DateTime? dangNhapCuoi;
  final Color avatarBg;
  final Color avatarText;

  AdminPatient({
    required this.uid,
    required this.maBenhNhan,
    required this.hoTen,
    this.email,
    this.soDienThoai,
    this.diaChi,
    this.gioiTinh,
    this.ngaySinh,
    this.ngayTao,
    this.daXacThucEmail = false,
    this.trangThaiId = 7,
    this.isBlocked = false,
    this.blockReason,
    this.ngayKhoa,
    this.ngayOffline,
    this.dangNhapCuoi,
    required this.avatarBg,
    required this.avatarText,
  });

  String get initials {
    final clean = hoTen.trim();
    if (clean.isEmpty) return 'BN';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  bool get isActive => !isBlocked && trangThaiId != 8 && trangThaiId != 11;

  /// Thời điểm bắt đầu offline hoặc ngưng hoạt động
  DateTime get effectiveOfflineTime {
    if (!isActive) {
      return ngayKhoa ?? ngayOffline ?? ngayTao ?? DateTime.now();
    }
    return dangNhapCuoi ?? ngayOffline ?? ngayTao ?? DateTime.now();
  }
}

// ============ DỮ LIỆU GIẢ (sau này thay bằng API) ============
final List<Hospital> verifiedHospitals = [
  Hospital(
    initials: 'BM',
    name: 'Bệnh viện Bạch Mai',
    type: 'Công lập',
    rating: 4.9,
    doctors: 120,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: '78 Giải Phóng, Đống Đa, Hà Nội',
  ),
  Hospital(
    initials: 'TA',
    name: 'BV Đa Khoa Tâm Anh',
    type: 'Tư nhân',
    rating: 4.8,
    doctors: 85,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: '108 Hoàng Như Tiếp, Long Biên, Hà Nội',
  ),
  Hospital(
    initials: 'CR',
    name: 'Bệnh viện Chợ Rẫy',
    type: 'Công lập',
    rating: 4.9,
    doctors: 200,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '201B Nguyễn Chí Thanh, Q.5, TP.HCM',
  ),
  Hospital(
    initials: '108',
    name: 'Bệnh viện TWQĐ 108',
    type: 'Công lập',
    rating: 4.9,
    doctors: 180,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: 'Số 1 Trần Hưng Đạo, Hà Nội',
  ),
  Hospital(
    initials: 'K',
    name: 'Bệnh viện K',
    type: 'Công lập',
    rating: 4.7,
    doctors: 150,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: '43 Quán Sứ, Hà Nội',
  ),
  Hospital(
    initials: 'NT',
    name: 'Bệnh viện Nhi Trung ương',
    type: 'Công lập',
    rating: 4.8,
    doctors: 160,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: '18/879 La Thành, Hà Nội',
  ),
  Hospital(
    initials: 'PNT',
    name: 'Bệnh viện Phạm Ngọc Thạch',
    type: 'Công lập',
    rating: 4.6,
    doctors: 110,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '120 Hồng Bàng, Q.5, TP.HCM',
  ),
  Hospital(
    initials: 'YD',
    name: 'Bệnh viện ĐH Y Dược TP.HCM',
    type: 'Công lập',
    rating: 4.8,
    doctors: 140,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: '215 Hồng Bàng, Q.5, TP.HCM',
  ),
  Hospital(
    initials: 'VM',
    name: 'Bệnh viện Đa khoa Quốc tế Vinmec',
    type: 'Tư nhân',
    rating: 4.9,
    doctors: 130,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: '458 Minh Khai, Hà Nội',
  ),
  Hospital(
    initials: 'FV',
    name: 'Bệnh viện FV',
    type: 'Tư nhân',
    rating: 4.8,
    doctors: 95,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: '6 Nguyễn Lương Bằng, Q.7, TP.HCM',
  ),
  Hospital(
    initials: 'HM',
    name: 'Bệnh viện Hoàn Mỹ Sài Gòn',
    type: 'Tư nhân',
    rating: 4.7,
    doctors: 100,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '60-60A Phan Xích Long, Q.Phú Nhuận, TP.HCM',
  ),
  Hospital(
    initials: 'ML',
    name: 'Bệnh viện Đa khoa Medlatec',
    type: 'Tư nhân',
    rating: 4.6,
    doctors: 70,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: '42 Nghĩa Dũng, Hà Nội',
  ),
  Hospital(
    initials: 'TC',
    name: 'Bệnh viện Đa khoa Thu Cúc',
    type: 'Tư nhân',
    rating: 4.7,
    doctors: 80,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: '286 Thụy Khuê, Hà Nội',
  ),
  Hospital(
    initials: 'VP',
    name: 'Bệnh viện Việt Pháp Hà Nội',
    type: 'Tư nhân',
    rating: 4.8,
    doctors: 75,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: 'Số 1 Phương Mai, Hà Nội',
  ),
  Hospital(
    initials: 'CI',
    name: 'Bệnh viện Quốc tế City',
    type: 'Tư nhân',
    rating: 4.6,
    doctors: 65,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '3 Đường 17A, Bình Trị Đông, TP.HCM',
  ),
  Hospital(
    initials: 'E',
    name: 'Bệnh viện E',
    type: 'Công lập',
    rating: 4.6,
    doctors: 130,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: '89 Trần Cung, Hà Nội',
  ),
  Hospital(
    initials: 'TN',
    name: 'Bệnh viện Thống Nhất',
    type: 'Công lập',
    rating: 4.7,
    doctors: 120,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: 'Số 1 Lý Thường Kiệt, Tân Bình, TP.HCM',
  ),
  Hospital(
    initials: '175',
    name: 'Bệnh viện Quân y 175',
    type: 'Công lập',
    rating: 4.7,
    doctors: 150,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: '786 Nguyễn Kiệm, Gò Vấp, TP.HCM',
  ),
  Hospital(
    initials: '103',
    name: 'Bệnh viện Quân y 103',
    type: 'Công lập',
    rating: 4.6,
    doctors: 140,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '261 Phùng Hưng, Hà Đông, Hà Nội',
  ),
  Hospital(
    initials: 'PS',
    name: 'Bệnh viện Phụ sản Trung ương',
    type: 'Công lập',
    rating: 4.8,
    doctors: 110,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: '43 Tràng Thi, Hà Nội',
  ),
  Hospital(
    initials: 'TD',
    name: 'Bệnh viện Từ Dũ',
    type: 'Công lập',
    rating: 4.8,
    doctors: 130,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: '284 Cống Quỳnh, Q.1, TP.HCM',
  ),
  Hospital(
    initials: 'PH',
    name: 'Bệnh viện Phụ sản Hà Nội',
    type: 'Công lập',
    rating: 4.7,
    doctors: 90,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: '929 La Thành, Hà Nội',
  ),
  Hospital(
    initials: 'NĐ',
    name: 'Bệnh viện Nhi Đồng 1',
    type: 'Công lập',
    rating: 4.7,
    doctors: 120,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '341 Sư Vạn Hạnh, Q.10, TP.HCM',
  ),
  Hospital(
    initials: 'DL',
    name: 'Bệnh viện Da Liễu Trung ương',
    type: 'Công lập',
    rating: 4.6,
    doctors: 60,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: '15A Phương Mai, Hà Nội',
  ),
  Hospital(
    initials: 'MT',
    name: 'Bệnh viện Mắt Trung ương',
    type: 'Công lập',
    rating: 4.7,
    doctors: 70,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: '85 Bà Triệu, Hà Nội',
  ),
  Hospital(
    initials: 'MH',
    name: 'Bệnh viện Mắt TP.HCM',
    type: 'Công lập',
    rating: 4.6,
    doctors: 65,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: '280 Điện Biên Phủ, Q.3, TP.HCM',
  ),
  Hospital(
    initials: 'TM',
    name: 'Bệnh viện Tai Mũi Họng TW',
    type: 'Công lập',
    rating: 4.6,
    doctors: 55,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '78 Giải Phóng, Hà Nội',
  ),
  Hospital(
    initials: 'RH',
    name: 'Bệnh viện Răng Hàm Mặt TW',
    type: 'Công lập',
    rating: 4.7,
    doctors: 60,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: '40A Tràng Thi, Hà Nội',
  ),
  Hospital(
    initials: 'TH',
    name: 'Bệnh viện Tim Hà Nội',
    type: 'Công lập',
    rating: 4.8,
    doctors: 75,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: '92 Trần Hưng Đạo, Hà Nội',
  ),
  Hospital(
    initials: 'VT',
    name: 'Viện Tim TP.HCM',
    type: 'Công lập',
    rating: 4.7,
    doctors: 60,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: '4 Dương Quang Trung, Q.10, TP.HCM',
  ),
  Hospital(
    initials: 'UB',
    name: 'Bệnh viện Ung Bướu TP.HCM',
    type: 'Công lập',
    rating: 4.7,
    doctors: 130,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '3 Nơ Trang Long, Bình Thạnh, TP.HCM',
  ),
  Hospital(
    initials: 'BD',
    name: 'Bệnh viện Bình Dân',
    type: 'Công lập',
    rating: 4.7,
    doctors: 110,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: '371 Điện Biên Phủ, Q.3, TP.HCM',
  ),
  Hospital(
    initials: '115',
    name: 'Bệnh viện Nhân Dân 115',
    type: 'Công lập',
    rating: 4.7,
    doctors: 140,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: '520 Nguyễn Tri Phương, Q.10, TP.HCM',
  ),
  Hospital(
    initials: 'GĐ',
    name: 'Bệnh viện Nhân Dân Gia Định',
    type: 'Công lập',
    rating: 4.6,
    doctors: 130,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: 'Số 1 Nơ Trang Long, Bình Thạnh, TP.HCM',
  ),
  Hospital(
    initials: 'TV',
    name: 'Bệnh viện Trưng Vương',
    type: 'Công lập',
    rating: 4.5,
    doctors: 80,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '266 Lý Thường Kiệt, Q.10, TP.HCM',
  ),
  Hospital(
    initials: 'AB',
    name: 'Bệnh viện An Bình',
    type: 'Công lập',
    rating: 4.5,
    doctors: 75,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: '146 An Bình, Q.5, TP.HCM',
  ),
  Hospital(
    initials: 'XA',
    name: 'Bệnh viện Đa khoa Xuyên Á',
    type: 'Tư nhân',
    rating: 4.6,
    doctors: 90,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: '42 QL22, Củ Chi, TP.HCM',
  ),
  Hospital(
    initials: 'BC',
    name: 'Bệnh viện Quốc tế Becamex',
    type: 'Tư nhân',
    rating: 4.6,
    doctors: 70,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: 'Đại lộ Bình Dương, TP.Thủ Dầu Một',
  ),
  Hospital(
    initials: 'CA',
    name: 'Bệnh viện Columbia Asia',
    type: 'Tư nhân',
    rating: 4.7,
    doctors: 60,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '8 Alexandre de Rhodes, Q.1, TP.HCM',
  ),
  Hospital(
    initials: 'HD',
    name: 'Bệnh viện Hoàn Mỹ Đà Nẵng',
    type: 'Tư nhân',
    rating: 4.6,
    doctors: 75,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: '60 Nguyễn Văn Linh, Đà Nẵng',
  ),
  Hospital(
    initials: 'ĐN',
    name: 'Bệnh viện Đà Nẵng',
    type: 'Công lập',
    rating: 4.6,
    doctors: 150,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: '103 Quang Trung, Đà Nẵng',
  ),
  Hospital(
    initials: 'HU',
    name: 'Bệnh viện Trung ương Huế',
    type: 'Công lập',
    rating: 4.7,
    doctors: 160,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: '16 Lê Lợi, TP.Huế',
  ),
  Hospital(
    initials: 'VC',
    name: 'Bệnh viện Vinmec Central Park',
    type: 'Tư nhân',
    rating: 4.9,
    doctors: 120,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '208 Nguyễn Hữu Cảnh, Bình Thạnh, TP.HCM',
  ),
  Hospital(
    initials: 'AH',
    name: 'Bệnh viện Tâm Anh TP.HCM',
    type: 'Tư nhân',
    rating: 4.8,
    doctors: 90,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: '2B Phổ Quang, Tân Bình, TP.HCM',
  ),
  Hospital(
    initials: 'TT',
    name: 'Bệnh viện Đa khoa Tâm Trí',
    type: 'Tư nhân',
    rating: 4.5,
    doctors: 55,
    avatarBg: const Color(0xFFDBEAFE),
    avatarText: const Color(0xFF2563EB),
    address: '68A Phạm Văn Chiêu, Gò Vấp, TP.HCM',
  ),
  Hospital(
    initials: 'HP',
    name: 'Bệnh viện Quốc tế Hạnh Phúc',
    type: 'Tư nhân',
    rating: 4.7,
    doctors: 65,
    avatarBg: const Color(0xFFFFEDD5),
    avatarText: const Color(0xFFD97706),
    address: '18 Đại lộ Bình Dương, Thuận An',
  ),
  Hospital(
    initials: 'SG',
    name: 'Bệnh viện Đa khoa Sài Gòn',
    type: 'Tư nhân',
    rating: 4.5,
    doctors: 50,
    avatarBg: const Color(0xFFDCFCE7),
    avatarText: const Color(0xFF16A34A),
    address: '125 Lê Lợi, Q.1, TP.HCM',
  ),
  Hospital(
    initials: 'CT',
    name: 'Bệnh viện ĐH Y Dược Cần Thơ',
    type: 'Công lập',
    rating: 4.6,
    doctors: 100,
    avatarBg: const Color(0xFFF3E8FF),
    avatarText: const Color(0xFF9333EA),
    address: '179 Nguyễn Văn Cừ, Cần Thơ',
  ),
];

final List<Map<String, String>> pendingHospitals = [
  {
    'tag': 'HN',
    'name': 'BV Đa khoa Hồng Ngọc',
    'type': 'Tư nhân',
    'bs': '60 bác sĩ',
    'time': 'Gửi yêu cầu: 2 giờ trước',
    'code': 'BV-2026-0053'
  },
  {
    'tag': 'VD',
    'name': 'BV Việt Đức',
    'type': 'Công lập',
    'bs': '150 bác sĩ',
    'time': 'Gửi yêu cầu: 5 giờ trước',
    'code': 'BV-2026-0054'
  },
  {
    'tag': 'AK',
    'name': 'PK Đa khoa An Khang',
    'type': 'Tư nhân',
    'bs': '25 bác sĩ',
    'time': 'Gửi yêu cầu: 1 ngày trước',
    'code': 'PK-2026-0091'
  },
  {
    'tag': 'PĐ',
    'name': 'BV Đa khoa Phương Đông',
    'type': 'Tư nhân',
    'bs': '45 bác sĩ',
    'time': 'Gửi yêu cầu: 2 ngày trước',
    'code': 'BV-2026-0092'
  },
  {
    'tag': 'DN',
    'name': 'BV Đa khoa Đồng Nai',
    'type': 'Công lập',
    'bs': '120 bác sĩ',
    'time': 'Gửi yêu cầu: 3 ngày trước',
    'code': 'BV-2026-0093'
  },
];
