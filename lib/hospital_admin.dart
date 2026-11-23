import 'package:flutter/material.dart';

// ===================================================
// FILE GỐC: core/theme.dart
// ===================================================
// ============ MÀU DÙNG CHUNG ============
const kBg = Color(0xFFF3F4F8);
const kPrimary = Color(0xFF2E7CF6);
const kGreen = Color(0xFF16A34A);
const kGreenBg = Color(0xFFDCFCE7);
const kGreenLight = Color(0xFFEFFDF3);
const kRed = Color(0xFFEF4444);
const kRedBg = Color(0xFFFEF2F2);
const kOrange = Color(0xFFF59E0B);
const kAmber = Color(0xFFD97706);
const kOrangeBg = Color(0xFFFFF7ED);
const kYellowBg = Color(0xFFFFFBEB);

// ============ THEME CHUNG ============
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
  );
}

// ===================================================
// FILE GỐC: data/mock_data.dart
// ===================================================
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
  });
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

// ===================================================
// KHO DỮ LIỆU DÙNG CHUNG — mọi thao tác duyệt / từ chối /
// xóa / sửa / xử lý lỗi đều đổi dữ liệu thật tại đây
// ===================================================
class ErrorReport {
  final String id;
  final String kind; // 'qr' hoặc 'booking'
  final String badge;
  final String title;
  final String sender;
  final String time;
  final String? desc;
  const ErrorReport({
    required this.id,
    required this.kind,
    required this.badge,
    required this.title,
    required this.sender,
    required this.time,
    this.desc,
  });
}

class AdminStore extends ChangeNotifier {
  AdminStore._();
  static final AdminStore instance = AdminStore._();

  List<Hospital> hospitals = List.of(verifiedHospitals);
  List<Map<String, String>> pending =
      pendingHospitals.map((e) => Map<String, String>.of(e)).toList();
  List<Map<String, String>> violations = [
    {
      'name': 'Phòng khám Đa Khoa An Khang',
      'match': 'PK Đa khoa An Khang',
      'complaints': '3 Khiếu nại',
      'location': '📍 Cầu Giấy, Hà Nội · Mã: PK-4912',
      'reason':
          'Lý do: Giấy phép hoạt động hết hạn, chưa hoàn tất kiểm định BYT.',
    },
  ];
  List<ErrorReport> reports = [
    ErrorReport(
      id: 'qr1',
      kind: 'qr',
      badge: 'Lỗi Check-in QR',
      title: 'Quét QR không auto điền form tiếp nhận',
      sender: 'Người gửi: BV Tâm Anh (Quầy lễ tân)',
      time: '10 phút trước',
      desc:
          'Mô tả: Camera quét mở của bệnh nhận Nguyễn Văn A báo mã hợp lệ nhưng không tự load thông tin khám.',
    ),
    ErrorReport(
      id: 'bk1',
      kind: 'booking',
      badge: 'Lỗi Đặt Lịch',
      title: 'Trùng ca khám buổi sáng',
      sender: 'Người gửi: Bệnh nhân Trần Mai Lan',
      time: '1 giờ trước',
    ),
  ];

  int get totalBV => hospitals.length;
  int pendingTotal = 5;
  int errorTotal = 12;

  String get totalBVText => totalBV.toString().padLeft(2, '0');
  String get pendingText => pendingTotal.toString().padLeft(2, '0');
  String get errorText => reports.length.toString().padLeft(2, '0');

  static const List<List<Color>> _avatarPalette = [
    [Color(0xFFDBEAFE), Color(0xFF2563EB)],
    [Color(0xFFFFEDD5), Color(0xFFD97706)],
    [Color(0xFFDCFCE7), Color(0xFF16A34A)],
    [Color(0xFFF3E8FF), Color(0xFF9333EA)],
  ];

  // DUYỆT: chuyển từ chờ duyệt sang đã xác nhận
  void approveHospital(Map<String, String> h) {
    pending.removeWhere((e) => e['code'] == h['code']);
    pendingTotal = (pendingTotal - 1).clamp(0, 999);
    if (pending.isEmpty) pendingTotal = 0;
    final palette = _avatarPalette[hospitals.length % _avatarPalette.length];
    final bsRaw = h['bs'] ?? '0';
    final doctors = int.tryParse(bsRaw.split(' ').first) ?? 0;
    hospitals.add(Hospital(
      initials: h['tag'] ?? 'BV',
      name: h['name'] ?? 'Bệnh viện',
      type: h['type'] ?? 'Tư nhân',
      rating: 5.0,
      doctors: doctors,
      avatarBg: palette[0],
      avatarText: palette[1],
      address: 'Đang cập nhật địa chỉ',
      code: h['code'],
    ));
    violations.removeWhere((v) => v['match'] == h['name']);
    notifyListeners();
  }

  // TỪ CHỐI: xóa khỏi danh sách chờ
  void rejectHospital(Map<String, String> h) {
    pending.removeWhere((e) => e['code'] == h['code']);
    pendingTotal = (pendingTotal - 1).clamp(0, 999);
    if (pending.isEmpty) pendingTotal = 0;
    violations.removeWhere((v) => v['match'] == h['name']);
    notifyListeners();
  }

  // XÓA cơ sở vi phạm
  void deleteViolation(Map<String, String> v) {
    violations.remove(v);
    final matched =
        pending.where((e) => e['name'] == v['match']).toList();
    for (final m in matched) {
      pending.remove(m);
      pendingTotal = (pendingTotal - 1).clamp(0, 999);
    }
    if (pending.isEmpty) pendingTotal = 0;
    notifyListeners();
  }

  // XÓA HỢP TÁC với bệnh viện đã xác nhận
  void unpartnerHospital(Hospital h) {
    hospitals.remove(h);
    notifyListeners();
  }

  // SỬA thông tin bệnh viện
  void updateHospital(Hospital h,
      {String? name, String? type, String? address, int? doctors}) {
    if (name != null && name.isNotEmpty) h.name = name;
    if (type != null && type.isNotEmpty) h.type = type;
    if (address != null && address.isNotEmpty) h.address = address;
    if (doctors != null) h.doctors = doctors;
    notifyListeners();
  }

  // XỬ LÝ xong một báo cáo lỗi
  void resolveReport(String id) {
    reports.removeWhere((r) => r.id == id);
    errorTotal = (errorTotal - 1).clamp(0, 999);
    if (reports.isEmpty) errorTotal = 0;
    notifyListeners();
  }

  // Lọc báo cáo theo chip: 0 = tất cả, 1 = đặt lịch, 2 = QR
  List<ErrorReport> filteredReports(int filter) {
    if (filter == 1) {
      return reports.where((r) => r.kind == 'booking').toList();
    }
    if (filter == 2) return reports.where((r) => r.kind == 'qr').toList();
    return List.of(reports);
  }
}

// ===================================================
// FILE GỐC: widgets/shared_widgets.dart
// ===================================================
// ============ AVATAR CHỮ (BM / TA / HN...) ============
class AvatarBox extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final double size;
  const AvatarBox({
    super.key,
    required this.text,
    required this.bg,
    required this.fg,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.w800, color: fg, fontSize: 14)),
    );
  }
}

// ============ NÚT BACK TRÒN ============
class BackCircle extends StatelessWidget {
  const BackCircle({super.key});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Icon(Icons.chevron_left, size: 24),
      ),
    );
  }
}

// ============ NÚT CHUÔNG CAM ============
class BellButton extends StatelessWidget {
  const BellButton({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          color: const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.notifications, color: kOrange, size: 22),
    );
  }
}

// ============ BADGE NHỎ (Lỗi QR / Lỗi đặt lịch...) ============
class AppBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  const AppBadge(
      {super.key, required this.text, required this.color, required this.bg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// ============ THANH ĐIỀU HƯỚNG DƯỚI ============
class AdminBottomBar extends StatelessWidget {
  final int current;
  final Function(int) onTap;
  const AdminBottomBar(
      {super.key, required this.current, required this.onTap});

  Widget item(int i, String label, IconData icon) {
    final bool isLogout = i == 1;
    final bool active = i == current;
    final Color color =
        isLogout ? kRed : (active ? kPrimary : Colors.grey);
    return Expanded(
      child: InkWell(
        onTap: () => onTap(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            item(0, 'Trang chủ', Icons.home_filled),
            item(1, 'Đăng xuất', Icons.logout),
          ],
        ),
      ),
    );
  }
}

// ============ Ô TÌM KIẾM DÙNG CHUNG ============
class SearchBox extends StatelessWidget {
  final String hint;
  const SearchBox({super.key, required this.hint});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          border: InputBorder.none,
          icon: const Icon(Icons.search, size: 20, color: Colors.grey),
        ),
      ),
    );
  }
}

// ===================================================
// FILE GỐC: screens/main_shell.dart
// ===================================================
// Khung chính: Trang chủ + nút Đăng xuất
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  void _onTap(int i) {
    if (i == 1) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Đăng xuất?'),
          content: const Text(
              'Bạn có chắc muốn đăng xuất khỏi tài khoản Admin?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kRed, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã đăng xuất (demo)')));
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const HomeScreen(),
      bottomNavigationBar: AdminBottomBar(current: index, onTap: _onTap),
    );
  }
}

// ===================================================
// FILE GỐC: screens/home_screen.dart
// ===================================================
// ================= MÀN 1: TRANG CHỦ =================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    AdminStore.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AdminStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _confirmDelete({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    required String doneMessage,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy bỏ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kRed,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(doneMessage)));
            },
            child: const Text('Xác nhận Xóa'),
          ),
        ],
      ),
    );
  }

  Widget lowRatedRow(Hospital h) {
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => HospitalDetailScreen(hospital: h))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            AvatarBox(
                text: h.initials,
                bg: h.avatarBg,
                fg: h.avatarText,
                size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('${h.type} · ${h.doctors} bác sĩ',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('★ ${h.rating}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: kAmber,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            InkWell(
              onTap: () => _confirmDelete(
                title: 'Xác nhận xóa bệnh viện?',
                message:
                    '${h.name} sẽ bị gỡ khỏi hệ thống cùng toàn bộ lịch đặt khám.',
                onConfirm: () =>
                    AdminStore.instance.unpartnerHospital(h),
                doneMessage:
                    'Đã xóa ${h.name} khỏi hệ thống',
              ),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: kRedBg,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_outline,
                    size: 20, color: kRed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget violationMiniCard(Map<String, String> v) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kRedBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(v['name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kRed,
                        fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(v['complaints'] ?? '',
                    style: const TextStyle(
                        fontSize: 11,
                        color: kRed,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(v['location'] ?? '',
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _confirmDelete(
                title: 'Xác nhận xóa bệnh viện?',
                message:
                    'Toàn bộ tài khoản và danh sách đặt lịch của ${v['name']} sẽ bị hủy ngay lập tức.',
                onConfirm: () =>
                    AdminStore.instance.deleteViolation(v),
                doneMessage:
                    'Đã xóa ${v['name']} khỏi hệ thống',
              ),
              child: const Text('Xóa cơ sở này',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget statCard(
      String num, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Text(num,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget hospitalCard(BuildContext context, Hospital h) {
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => HospitalDetailScreen(hospital: h))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            AvatarBox(text: h.initials, bg: h.avatarBg, fg: h.avatarText),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('${h.type} · ★ ${h.rating} · ${h.doctors} bác sĩ',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, size: 13, color: kGreen),
                      SizedBox(width: 4),
                      Text('Đã xác nhận',
                          style: TextStyle(
                              fontSize: 12,
                              color: kGreen,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chào mừng admin',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    SizedBox(height: 2),
                    Text('Quản trị viên Admin 👋',
                        style: TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w800)),
                  ],
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ErrorReportsScreen())),
                  child: const BellButton(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                statCard(AdminStore.instance.totalBVText, 'Tổng BV',
                    kPrimary, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AllHospitalsScreen()));
                }),
                const SizedBox(width: 12),
                statCard(AdminStore.instance.pendingText, 'Chờ duyệt',
                    Colors.black87, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PendingApprovalScreen()));
                }),
                const SizedBox(width: 12),
                statCard(AdminStore.instance.errorText, 'Báo lỗi', kRed,
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ErrorReportsScreen()));
                }),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('Listview các bệnh viện',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AllHospitalsScreen())),
                  child: const Text('Nhấn vào xem chi tiết',
                      style: TextStyle(
                          fontSize: 12,
                          color: kPrimary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...AdminStore.instance.hospitals.take(4).map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: hospitalCard(context, h),
                )),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PendingApprovalScreen())),
                child: const Text('Duyệt bệnh viện',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                    width: 90,
                    height: 22,
                    decoration: BoxDecoration(
                        color: kGreenBg,
                        borderRadius: BorderRadius.circular(6))),
                const SizedBox(width: 12),
                Container(
                    width: 110,
                    height: 22,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF3D6),
                        borderRadius: BorderRadius.circular(6))),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('⚠️ Bệnh viện đánh giá thấp',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AllHospitalsScreen(
                                  initialSort: 1))),
                  child: const Text('Xem tất cả',
                      style: TextStyle(
                          fontSize: 12,
                          color: kPrimary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final lowest =
                  ([...AdminStore.instance.hospitals]
                        ..sort((a, b) =>
                            a.rating.compareTo(b.rating)))
                      .take(5)
                      .toList();
              return Column(
                children:
                    lowest.map((h) => lowRatedRow(h)).toList(),
              );
            }),
            if (AdminStore.instance.violations.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                  '🚨 Cơ sở vi phạm (${AdminStore.instance.violations.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const SizedBox(height: 10),
              ...AdminStore.instance.violations
                  .map(violationMiniCard),
            ],
          ],
        ),
      ),
    );
  }
}

// ===================================================
// FILE GỐC: screens/hospital_detail_screen.dart
// ===================================================
// ================= MÀN 2: CHI TIẾT BỆNH VIỆN =================
class HospitalDetailScreen extends StatefulWidget {
  final Hospital hospital;
  const HospitalDetailScreen({super.key, required this.hospital});
  @override
  State<HospitalDetailScreen> createState() => _HospitalDetailScreenState();
}

class _HospitalDetailScreenState extends State<HospitalDetailScreen> {
  @override
  void initState() {
    super.initState();
    AdminStore.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AdminStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  Widget deptRow(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Text('♥  $text',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hospital = widget.hospital;
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BackCircle(),
                  const SizedBox(width: 12),
                  const Text('Chi tiết bệnh viện',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: kGreenBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Hoạt động',
                        style: TextStyle(
                            fontSize: 12,
                            color: kGreen,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                EditHospitalScreen(hospital: hospital))),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.edit,
                          size: 18, color: kPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    AvatarBox(
                        text: hospital.initials,
                        bg: hospital.avatarBg,
                        fg: hospital.avatarText),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hospital.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                              '${hospital.type} · ★ ${hospital.rating} · Xác thực uy tín',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                              hospital.address ??
                                  '78 Giải Phóng, Đống Đa, Hà Nội',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('DANH SÁCH KHOA TRỰC THUỘC',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey)),
              const SizedBox(height: 10),
              deptRow('Khoa Tim Mạch · 18 BS'),
              deptRow('Khoa Nhi Tiêu Hóa · 24 BS'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: const BorderSide(color: kPrimary, width: 1.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ReviewScreen(hospital: hospital))),
                  child: const Text('Xem đánh giá bệnh viện',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kRed,
                    side: const BorderSide(color: kRed, width: 1.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final messenger =
                        ScaffoldMessenger.of(context);
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16)),
                        title:
                            const Text('Xóa bệnh viện?'),
                        content: Text(
                            '${hospital.name} sẽ bị gỡ khỏi hệ thống cùng toàn bộ lịch đặt khám.'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(context),
                              child:
                                  const Text('Hủy bỏ')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: kRed,
                                foregroundColor:
                                    Colors.white),
                            onPressed: () {
                              AdminStore.instance
                                  .unpartnerHospital(
                                      hospital);
                              Navigator.pop(context);
                              Navigator.pop(context);
                              messenger.showSnackBar(SnackBar(
                                  content: Text(
                                      'Đã xóa ${hospital.name} khỏi hệ thống')));
                            },
                            child:
                                const Text('Xác nhận Xóa'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Xóa bệnh viện',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================
// FILE GỐC: screens/review_screen.dart
// ===================================================
// ================= MÀN 3: ĐÁNH GIÁ BỆNH VIỆN =================
class ReviewScreen extends StatelessWidget {
  final Hospital hospital;
  const ReviewScreen({super.key, required this.hospital});

  Widget reviewCard(String name, String content, String date, String dept) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              const Text('★★★★★',
                  style: TextStyle(color: kOrange, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text('$date · $dept',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  BackCircle(),
                  SizedBox(width: 12),
                  Text('Đánh giá bệnh viện',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    AvatarBox(
                        text: hospital.initials,
                        bg: hospital.avatarBg,
                        fg: hospital.avatarText,
                        size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hospital.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('★★★★★ 4.9 (1.248 đánh giá)',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: kAmber,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: kGreenLight,
                    borderRadius: BorderRadius.circular(14)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tổng quan đánh giá',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    SizedBox(height: 6),
                    Text('Chất lượng khám: 4.9 · Thái độ NV: 4.8',
                        style: TextStyle(fontSize: 12)),
                    SizedBox(height: 2),
                    Text('Cơ sở vật chất: 4.7 · Thời gian chờ: 4.6',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Đánh giá gần đây',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
              reviewCard(
                  'Nguyễn Văn A',
                  'Bác sĩ tận tâm, khám nhanh, giải thích rõ ràng. Rất hài lòng!',
                  '18/09/2026',
                  'Khoa Tim mạch'),
              reviewCard(
                  'Trần Thị Bích',
                  'Chờ hơi lâu nhưng bác sĩ khám kỹ, kết quả chính xác.',
                  '17/09/2026',
                  'Khoa Nội'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kRed,
                          side: const BorderSide(color: kRed, width: 1.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final messenger =
                              ScaffoldMessenger.of(context);
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16)),
                              title:
                                  const Text('Xóa hợp tác?'),
                              content: Text(
                                  'Ngừng hợp tác với ${hospital.name}? Bệnh viện sẽ bị gỡ khỏi hệ thống.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context),
                                    child: const Text('Hủy')),
                                ElevatedButton(
                                  style:
                                      ElevatedButton.styleFrom(
                                          backgroundColor: kRed,
                                          foregroundColor:
                                              Colors.white),
                                  onPressed: () {
                                    AdminStore.instance
                                        .unpartnerHospital(hospital);
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                    messenger.showSnackBar(SnackBar(
                                        content: Text(
                                            'Đã xóa hợp tác với ${hospital.name}')));
                                  },
                                  child:
                                      const Text('Xóa hợp tác'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('Xóa hợp tác',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Tiếp tục hợp tác ✓')));
                        },
                        child: const Text('Tiếp tục hợp tác',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.grey,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {},
                  child: const Text('Xem tất cả đánh giá'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================
// FILE GỐC: screens/pending_approval_screen.dart
// ===================================================
// ================= MÀN 6: BỆNH VIỆN CHỜ DUYỆT =================
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});
  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  @override
  void initState() {
    super.initState();
    AdminStore.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AdminStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  Widget pendingCard(BuildContext context, Map<String, String> h) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarBox(
                  text: h['tag']!,
                  bg: const Color(0xFFDBEAFE),
                  fg: kPrimary,
                  size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h['name']!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('${h['type']} · ${h['bs']}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: kOrangeBg, borderRadius: BorderRadius.circular(20)),
            child: const Text('⏳ Chờ duyệt',
                style: TextStyle(
                    fontSize: 11,
                    color: kAmber,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Text(h['time']!,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ApproveConfirmScreen(hospital: h))),
                    child: const Text('✓ Duyệt',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kRed,
                      side: const BorderSide(color: kRed, width: 1.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RejectScreen(hospital: h))),
                    child: const Text('✕ Từ chối',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BackCircle(),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bệnh viện chờ duyệt',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17)),
                      Text(
                          '${AdminStore.instance.pendingTotal} bệnh viện đang chờ xác nhận',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: kOrangeBg,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                    'Chờ duyệt · ${AdminStore.instance.pendingText}',
                    style: TextStyle(
                        fontSize: 12,
                        color: kAmber,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              if (AdminStore.instance.pending.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: const Column(
                    children: [
                      Text('🎉',
                          style: TextStyle(fontSize: 40)),
                      SizedBox(height: 8),
                      Text('Đã xử lý hết!',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Không còn bệnh viện chờ duyệt.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              else
                ...AdminStore.instance.pending
                    .map((h) => pendingCard(context, h)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================
// FILE GỐC: screens/error_reports_screen.dart
// ===================================================
// ================= MÀN 7: XEM CÁC BÁO CÁO LỖI =================
class ErrorReportsScreen extends StatefulWidget {
  const ErrorReportsScreen({super.key});
  @override
  State<ErrorReportsScreen> createState() => _ErrorReportsScreenState();
}

class _ErrorReportsScreenState extends State<ErrorReportsScreen> {
  int filter = 0;

  @override
  void initState() {
    super.initState();
    AdminStore.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AdminStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  Widget chip(String label, int i) {
    final bool active = filter == i;
    return GestureDetector(
      onTap: () => setState(() => filter = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFDBEAFE) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? kPrimary : const Color(0xFFE5E7EB)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? kPrimary : Colors.grey)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BackCircle(),
                  const SizedBox(width: 12),
                  const Text('Xem các báo cáo lỗi',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: kOrangeBg,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        '${AdminStore.instance.errorTotal} Lỗi',
                        style: TextStyle(
                            fontSize: 12,
                            color: kAmber,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  chip('Tất cả', 0),
                  const SizedBox(width: 8),
                  chip('Lỗi đặt lịch', 1),
                  const SizedBox(width: 8),
                  chip('Lỗi QR', 2),
                ],
              ),
              const SizedBox(height: 14),
              Builder(builder: (context) {
                final list =
                    AdminStore.instance.filteredReports(filter);
                if (list.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Column(
                      children: [
                        Text('🎉',
                            style: TextStyle(fontSize: 40)),
                        SizedBox(height: 8),
                        Text('Không có báo cáo nào',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Tất cả sự cố đã được xử lý.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return Column(
                  children: list.map((r) {
                    final bool isQR = r.kind == 'qr';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppBadge(
                                text: r.badge,
                                color: isQR ? kRed : kAmber,
                                bg: isQR
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFFEF3C7),
                              ),
                              const Spacer(),
                              Text(r.time,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(r.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(r.sender,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey)),
                          if (r.desc != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFF8FAFC),
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: Text(r.desc!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87)),
                            ),
                          ],
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFFE8EEF7),
                                foregroundColor:
                                    Colors.black87,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            10)),
                              ),
                              onPressed: () {
                                AdminStore.instance
                                    .resolveReport(r.id);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Đã xử lý báo cáo ✓')));
                              },
                              child: const Text(
                                  'Xử lý sự cố ngay',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.w700,
                                      fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================
// FILE GỐC: screens/approve_confirm_screen.dart
// ===================================================
// ================= MÀN 8: XÁC NHẬN DUYỆT =================
class ApproveConfirmScreen extends StatelessWidget {
  final Map<String, String> hospital;
  const ApproveConfirmScreen({super.key, required this.hospital});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Row(
                children: [
                  BackCircle(),
                  SizedBox(width: 12),
                  Text('Xác nhận duyệt',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                          color: kGreenBg, shape: BoxShape.circle),
                      child:
                          const Icon(Icons.check, color: kGreen, size: 44),
                    ),
                    const SizedBox(height: 14),
                    const Text('Xác nhận duyệt bệnh viện?',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 8),
                    const Text(
                        'Bệnh viện sẽ được thêm vào hệ thống\nvà cấp tài khoản để bắt đầu hoạt động.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          AvatarBox(
                              text: hospital['tag']!,
                              bg: const Color(0xFFDBEAFE),
                              fg: kPrimary,
                              size: 46),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(hospital['name']!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                Text(
                                    '${hospital['type']} · ${hospital['bs']}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey)),
                                Text('Mã số: ${hospital['code']}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(
                              color: Color(0xFFE5E7EB)),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy',
                            style:
                                TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          AdminStore.instance
                              .approveHospital(hospital);
                          Navigator.pop(context);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Đã duyệt ${hospital['name']} ✓'),
                                  backgroundColor: kGreen));
                        },
                        child: const Text('✓ Xác nhận duyệt',
                            style:
                                TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================
// FILE GỐC: screens/reject_screen.dart
// ===================================================
// ================= MÀN 9: TỪ CHỐI DUYỆT =================
class RejectScreen extends StatefulWidget {
  final Map<String, String> hospital;
  const RejectScreen({super.key, required this.hospital});
  @override
  State<RejectScreen> createState() => _RejectScreenState();
}

class _RejectScreenState extends State<RejectScreen> {
  int selected = 0;
  final reasons = [
    'Thiếu giấy phép hoạt động',
    'Thông tin chưa đầy đủ',
    'Không đạt tiêu chuẩn',
    'Trùng bệnh viện đã có',
  ];
  final ctrl = TextEditingController(
      text:
          'Giấy phép hoạt động đã hết hạn từ 01/2026. Vui lòng bổ sung giấy phép mới trước khi gửi lại yêu cầu.');

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  BackCircle(),
                  SizedBox(width: 12),
                  Text('Từ chối duyệt',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    AvatarBox(
                        text: widget.hospital['tag']!,
                        bg: const Color(0xFFDBEAFE),
                        fg: kPrimary,
                        size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.hospital['name']!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          Text(
                              '${widget.hospital['type']} · ${widget.hospital['bs']}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                                color: kOrangeBg,
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('⏳ Chờ duyệt',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: kAmber,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xFFFEE2E2),
                      child: Text('!',
                          style: TextStyle(
                              color: kRed,
                              fontWeight: FontWeight.w900,
                              fontSize: 24)),
                    ),
                    SizedBox(height: 10),
                    Text('Vui lòng chọn lý do từ chối',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Lý do sẽ được gửi đến bệnh viện',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(reasons.length, (i) {
                  final bool active = i == selected;
                  return GestureDetector(
                    onTap: () => setState(() => selected = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? kRedBg : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active
                                ? kRed
                                : const Color(0xFFE5E7EB)),
                      ),
                      child: Text(reasons[i],
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active ? kRed : Colors.black87)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Text('GHI CHÚ CHI TIẾT (TÙY CHỌN)',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kRed, width: 1.2),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: ctrl,
                      maxLines: 3,
                      maxLength: 300,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Text('98/300',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '⚠ Bệnh viện sẽ nhận được lý do này và có thể gửi lại yêu cầu sau khi khắc phục.',
                style: TextStyle(fontSize: 11, color: kRed),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(
                              color: Color(0xFFE5E7EB)),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy',
                            style:
                                TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          AdminStore.instance.rejectHospital(
                              widget.hospital);
                          Navigator.pop(context);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Đã từ chối ${widget.hospital['name']}'),
                                  backgroundColor: kRed));
                        },
                        child: const Text('✕ Gửi từ chối',
                            style:
                                TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================
// MÀN 10: TẤT CẢ BỆNH VIỆN (mở từ thẻ "Tổng BV")
// ===================================================
class AllHospitalsScreen extends StatefulWidget {
  final int initialSort; // 0 = mặc định, 1 = thấp→cao, 2 = cao→thấp
  const AllHospitalsScreen({super.key, this.initialSort = 0});
  @override
  State<AllHospitalsScreen> createState() => _AllHospitalsScreenState();
}

class _AllHospitalsScreenState extends State<AllHospitalsScreen> {
  String query = '';
  late int sort;

  @override
  void initState() {
    super.initState();
    sort = widget.initialSort;
    AdminStore.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AdminStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  Widget sortChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFDBEAFE) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  active ? kPrimary : const Color(0xFFE5E7EB)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? kPrimary : Colors.grey)),
      ),
    );
  }

  Widget verifiedCard(BuildContext context, Hospital h) {
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => HospitalDetailScreen(hospital: h))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            AvatarBox(text: h.initials, bg: h.avatarBg, fg: h.avatarText),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('${h.type} · ★ ${h.rating} · ${h.doctors} bác sĩ',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, size: 13, color: kGreen),
                      SizedBox(width: 4),
                      Text('Đã xác nhận',
                          style: TextStyle(
                              fontSize: 12,
                              color: kGreen,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget pendingRow(BuildContext context, Map<String, String> h) {
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PendingApprovalScreen())),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            AvatarBox(
                text: h['tag']!,
                bg: const Color(0xFFDBEAFE),
                fg: kPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h['name']!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('${h['type']} · ${h['bs']}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: kOrangeBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('⏳ Chờ duyệt',
                        style: TextStyle(
                            fontSize: 11,
                            color: kAmber,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AdminStore.instance;
    final q = query.trim().toLowerCase();
    final verified = store.hospitals.where((h) {
      if (q.isEmpty) return true;
      return h.name.toLowerCase().contains(q) ||
          h.initials.toLowerCase().contains(q) ||
          (h.code ?? '').toLowerCase().contains(q);
    }).toList();
    final pend = store.pending.where((h) {
      if (q.isEmpty) return true;
      return (h['name'] ?? '').toLowerCase().contains(q) ||
          (h['tag'] ?? '').toLowerCase().contains(q) ||
          (h['code'] ?? '').toLowerCase().contains(q);
    }).toList();
    if (sort == 1) {
      verified.sort((a, b) => a.rating.compareTo(b.rating));
    } else if (sort == 2) {
      verified.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BackCircle(),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tất cả bệnh viện',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17)),
                      Text('${store.totalBV} cơ sở trong hệ thống',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    hintText: 'Tìm tên hoặc mã bệnh viện...',
                    hintStyle:
                        TextStyle(fontSize: 13, color: Colors.grey),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search,
                        size: 20, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  sortChip('A-Z', sort == 0,
                      () => setState(() => sort = 0)),
                  const SizedBox(width: 8),
                  sortChip('★ Thấp → Cao', sort == 1,
                      () => setState(() => sort = 1)),
                  const SizedBox(width: 8),
                  sortChip('★ Cao → Thấp', sort == 2,
                      () => setState(() => sort = 2)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      if (verified.isEmpty && pend.isEmpty)
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(16)),
                          child: const Column(
                            children: [
                              Text('🔍',
                                  style:
                                      TextStyle(fontSize: 40)),
                              SizedBox(height: 8),
                              Text('Không tìm thấy',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.w800,
                                      fontSize: 16)),
                              SizedBox(height: 4),
                              Text(
                                  'Thử từ khóa khác nhé.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey)),
                            ],
                          ),
                        )
                      else ...[
                        if (verified.isNotEmpty) ...[
                          Text(
                              'Đã xác nhận (${verified.length})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          const SizedBox(height: 10),
                          ...verified.map((h) =>
                              verifiedCard(context, h)),
                          const SizedBox(height: 6),
                        ],
                        if (pend.isNotEmpty) ...[
                          Row(
                            children: [
                              Text(
                                  'Chờ duyệt (${pend.length})',
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w800,
                                      fontSize: 15)),
                              const Spacer(),
                              GestureDetector(
                                onTap: () =>
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const PendingApprovalScreen())),
                                child: const Text(
                                    'Xem tất cả',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: kPrimary,
                                        fontWeight:
                                            FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...pend.map((h) =>
                              pendingRow(context, h)),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================
// MÀN 11: SỬA THÔNG TIN BỆNH VIỆN
// ===================================================
class EditHospitalScreen extends StatefulWidget {
  final Hospital hospital;
  const EditHospitalScreen({super.key, required this.hospital});
  @override
  State<EditHospitalScreen> createState() => _EditHospitalScreenState();
}

class _EditHospitalScreenState extends State<EditHospitalScreen> {
  late final TextEditingController nameCtrl;
  late final TextEditingController addrCtrl;
  late final TextEditingController doctorsCtrl;
  late String type;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.hospital.name);
    addrCtrl = TextEditingController(text: widget.hospital.address ?? '');
    doctorsCtrl =
        TextEditingController(text: widget.hospital.doctors.toString());
    type = widget.hospital.type;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addrCtrl.dispose();
    doctorsCtrl.dispose();
    super.dispose();
  }

  Widget field(String label, TextEditingController ctrl,
      {TextInputType keyboard = TextInputType.text, int lines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: keyboard,
            maxLines: lines,
            style: const TextStyle(fontSize: 14),
            decoration:
                const InputDecoration(border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  BackCircle(),
                  SizedBox(width: 12),
                  Text('Sửa thông tin bệnh viện',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    AvatarBox(
                        text: widget.hospital.initials,
                        bg: widget.hospital.avatarBg,
                        fg: widget.hospital.avatarText,
                        size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(widget.hospital.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          Text(
                              '${widget.hospital.type} · ★ ${widget.hospital.rating}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              field('TÊN BỆNH VIỆN', nameCtrl),
              const SizedBox(height: 12),
              const Text('LOẠI HÌNH',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButton<String>(
                  value: type,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                        value: 'Công lập',
                        child: Text('Công lập')),
                    DropdownMenuItem(
                        value: 'Tư nhân',
                        child: Text('Tư nhân')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => type = v);
                  },
                ),
              ),
              const SizedBox(height: 12),
              field('ĐỊA CHỈ', addrCtrl, lines: 2),
              const SizedBox(height: 12),
              field('SỐ BÁC SĨ', doctorsCtrl,
                  keyboard: TextInputType.number),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(
                              color: Color(0xFFE5E7EB)),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy',
                            style: TextStyle(
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final doctors = int.tryParse(
                                  doctorsCtrl.text.trim()) ??
                              widget.hospital.doctors;
                          AdminStore.instance.updateHospital(
                            widget.hospital,
                            name: nameCtrl.text.trim(),
                            type: type,
                            address: addrCtrl.text.trim(),
                            doctors: doctors,
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content: Text(
                                      'Đã lưu thay đổi ✓')));
                        },
                        child: const Text('Lưu thay đổi',
                            style: TextStyle(
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
