import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mock_data.dart';
import '../../../services/email_service.dart';
import '../../../services/firebase_admin_auth_service.dart';

// ===================================================
// KHO DỮ LIỆU DÙNG CHUNG — Đồng bộ Realtime với Firebase Firestore
// ===================================================
class ErrorReport {
  final String id;
  final String kind; // 'qr' hoặc 'booking'
  final String badge;
  final String title;
  final String sender;
  final String time;
  final String? desc;
  final bool isResolved;
  final String? adminResponse;
  final String? resolvedTime;

  const ErrorReport({
    required this.id,
    required this.kind,
    required this.badge,
    required this.title,
    required this.sender,
    required this.time,
    this.desc,
    this.isResolved = false,
    this.adminResponse,
    this.resolvedTime,
  });
}

class AdminStore extends ChangeNotifier {
  static final AdminStore instance = AdminStore._();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  QuerySnapshot<Map<String, dynamic>>? _hospitalsSnap;
  QuerySnapshot<Map<String, dynamic>>? _pendingSnap;
  StreamSubscription? _hospitalsSub;
  StreamSubscription? _pendingSub;
  StreamSubscription? _reportsSub;
  StreamSubscription? _patientsSub;

  bool isSyncing = false;
  bool isConnected = true;
  DateTime lastSync = DateTime.now();

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
  // Khởi tạo rỗng, CHỈ hiển thị khi có báo cáo lỗi thực tế từ Firebase
  List<ErrorReport> reports = [];
  List<ErrorReport> resolvedReports = [];
  List<AdminPatient> patients = [];
  List<Hospital> cancelledHospitals = [];

  int get totalBV => hospitals.length;
  int pendingTotal = 0;
  int errorTotal = 0;
  int get totalPatients => patients.length;

  String get totalBVText => totalBV.toString().padLeft(2, '0');
  String get pendingText => pendingTotal.toString().padLeft(2, '0');
  String get errorText => reports.length.toString().padLeft(2, '0');
  String get totalPatientsText => totalPatients.toString().padLeft(2, '0');

  static const List<List<Color>> _avatarPalette = [
    [Color(0xFFDBEAFE), Color(0xFF2563EB)], // Blue
    [Color(0xFFFFEDD5), Color(0xFFD97706)], // Orange
    [Color(0xFFDCFCE7), Color(0xFF16A34A)], // Green
    [Color(0xFFF3E8FF), Color(0xFF9333EA)], // Purple
    [Color(0xFFFEE2E2), Color(0xFFDC2626)], // Red
    [Color(0xFFE0E7FF), Color(0xFF4F46E5)], // Indigo
  ];

  AdminStore._() {
    _initFirebaseSync();
  }

  static String getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'BV';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    // Bỏ các tiền tố chung để lấy chữ cái đại diện rõ hơn
    final filtered = parts.where((p) {
      final l = p.toLowerCase();
      return !['bệnh', 'viện', 'bv', 'phòng', 'khám', 'pk', 'trung', 'tâm', 'tt'].contains(l);
    }).toList();

    if (filtered.length >= 2) {
      return (filtered[0][0] + filtered[1][0]).toUpperCase();
    } else if (filtered.length == 1) {
      return filtered[0].substring(0, filtered[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Kích hoạt đồng bộ tức thời từ Firebase
  Future<void> syncNow() async {
    isSyncing = true;
    notifyListeners();

    try {
      // 1. Tải BenhVien
      final bvSnap = await _firestore.collection('BenhVien').get();
      _hospitalsSnap = bvSnap;

      // 2. Tải YeuCauHopTac
      final ycSnap = await _firestore.collection('YeuCauHopTac').get();
      _pendingSnap = ycSnap;

      // Tính toán danh sách Tổng BV và Hồ sơ Chờ duyệt
      _recomputeData();

      // 3. Tải BaoCaoLoi
      final bcSnap = await _firestore.collection('BaoCaoLoi').get();
      _processReportsSnapshot(bcSnap);

      // 4. Tải BenhNhan
      final bnSnap = await _firestore.collection('BenhNhan').get();
      _processPatientsSnapshot(bnSnap);

      isConnected = true;
      lastSync = DateTime.now();
    } catch (e) {
      debugPrint('Lỗi syncNow: $e');
      isConnected = false;
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  /// TÍNH TOÁN LẠI TỔNG BV VÀ DANH SÁCH CHỜ DUYỆT
  /// Quy tắc:
  /// - Bệnh viện mới thêm trên Firebase mặc định CHỜ DUYỆT (trang_thai_hop_tac_id != 10 / chưa duyệt).
  /// - Chỉ khi được duyệt (trang_thai_hop_tac_id == 10 / 2 / da_duyet == true) thì mới hiển thị qua "Tổng BV".
  void _recomputeData() {
    final List<Hospital> approvedList = [];
    final List<Hospital> cancelledList = [];
    final List<Map<String, String>> viols = [];
    final Map<String, Map<String, String>> pendingMap = {};
    int idx = 0;

    // 1. DUYỆT QUA COLLECTION 'BenhVien'
    if (_hospitalsSnap != null) {
      for (final doc in _hospitalsSnap!.docs) {
        final data = doc.data();
        final name = data['ten_benh_vien']?.toString() ??
            data['name']?.toString() ??
            'Bệnh viện ${doc.id}';
        final type = data['co_so']?.toString() ??
            data['loai_hinh']?.toString() ??
            'Công lập';
        final rating =
            (data['diem_danh_gia_tb'] as num?)?.toDouble() ?? 4.5;
        final address = data['dia_chi']?.toString() ??
            'Đang cập nhật địa chỉ';
        final statusId = data['trang_thai_hop_tac_id'] as int?;
        final trangThaiStr = data['trang_thai']?.toString().toLowerCase();
        final trangThaiUpper = data['trangThai']?.toString().toUpperCase();
        final daDuyetBool = data['da_duyet'] == true;

        // Kiểm tra hủy hợp tác:
        // Khi hủy hợp tác, trang_thai_hop_tac_id chuyển về 1, nhưng có cờ huy_hop_tac hoặc is_unpartnered
        final bool isHuyHopTac = statusId == 9 ||
            trangThaiStr == 'huy_hop_tac' ||
            trangThaiUpper == 'HUY_HOP_TAC' ||
            data['is_unpartnered'] == true;

        // Bị từ chối
        final bool isRejected = statusId == 4 ||
            trangThaiStr == 'tu_choi' ||
            trangThaiUpper == 'TU_CHOI';

        // Trạng thái đã duyệt: 10 (đang hợp tác), 2 (đã xác nhận), 7 (hoạt động), hoặc cờ da_duyet / trangThai tương ứng
        // CHÚ Ý: Bệnh viện có statusId == 1 hoặc isHuyHopTac == true hoặc isRejected == true thì KHÔNG tính là đã duyệt
        final bool isApproved = !isHuyHopTac &&
            !isRejected &&
            statusId != 1 &&
            (statusId == 10 ||
                statusId == 2 ||
                statusId == 7 ||
                daDuyetBool ||
                trangThaiStr == 'da_duyet' ||
                trangThaiUpper == 'DA_DUYET' ||
                trangThaiUpper == 'HOAT_DONG');

        // Kiểm tra chặn đăng nhập
        final bool chanDangNhap = data['chan_dang_nhap'] == true ||
            data['is_blocked'] == true ||
            (statusId == 8 || statusId == 11) && (trangThaiStr == 'chan_dang_nhap' || trangThaiStr == 'khoa');
        final String? blockReason = data['ly_do_khoa']?.toString() ??
            data['ly_do_huy']?.toString() ??
            data['ly_do_chan']?.toString();

        if (isApproved && !isHuyHopTac && !isRejected) {
          // BỆNH VIỆN ĐÃ DUYỆT (Bao gồm cả đang hoạt động hoặc đang bị tạm chặn đăng nhập để quản lý)
          final depts = (data['ten_cac_khoa'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final doctorCount = depts != null && depts.isNotEmpty
              ? (depts.length * 8)
              : 35;
          final palette = _avatarPalette[idx % _avatarPalette.length];
          idx++;

          final hospital = Hospital(
            initials: getInitials(name),
            name: name,
            type: type,
            rating: rating,
            doctors: doctorCount,
            avatarBg: palette[0],
            avatarText: palette[1],
            address: address,
            code: doc.id,
            departments: depts,
            totalReviews: (data['tong_so_danh_gia'] as num?)?.toInt() ?? 0,
            phone: data['so_dien_thoai']?.toString(),
            email: data['email']?.toString(),
            status: statusId ?? 10,
            isBlocked: chanDangNhap,
            blockReason: blockReason,
          );
          approvedList.add(hospital);

          // Cơ sở đánh giá thấp hoặc vi phạm / bị chặn
          if (rating < 3.8 || chanDangNhap) {
            viols.add({
              'name': name,
              'match': name,
              'complaints': '${data['tong_so_danh_gia'] ?? 3} Khiếu nại/Đánh giá thấp',
              'location': '📍 $address · Mã: ${doc.id}',
              'reason': chanDangNhap
                  ? 'Lý do: Đang bị chặn đăng nhập (${blockReason ?? "Vi phạm quy định"}).'
                  : 'Lý do: Điểm đánh giá $rating★ dưới ngưỡng tiêu chuẩn.',
              'code': doc.id,
            });
          }
        } else if (isHuyHopTac) {
          // BỆNH VIỆN ĐÃ HỦY HỢP TÁC (LƯU TRỮ)
          final depts = (data['ten_cac_khoa'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final doctorCount = depts != null && depts.isNotEmpty
              ? (depts.length * 8)
              : 35;
          final palette = _avatarPalette[idx % _avatarPalette.length];
          idx++;

          final hospital = Hospital(
            initials: getInitials(name),
            name: name,
            type: type,
            rating: rating,
            doctors: doctorCount,
            avatarBg: palette[0],
            avatarText: palette[1],
            address: address,
            code: doc.id,
            departments: depts,
            totalReviews: (data['tong_so_danh_gia'] as num?)?.toInt() ?? 0,
            phone: data['so_dien_thoai']?.toString(),
            email: data['email']?.toString(),
            status: 9, // Trạng thái = 9 khi đã hủy hợp tác
            isBlocked: true,
            isUnpartnered: true,
            blockReason: blockReason ?? 'Đã ngừng hợp tác',
          );
          cancelledList.add(hospital);
        } else if (!chanDangNhap && !isHuyHopTac && !isRejected && statusId != 9) {
          // BỆNH VIỆN MỚI THÊM TRÊN FIREBASE / CHƯA DUYỆT
          // -> Cho vào "CHỜ DUYỆT" trước, KHÔNG hiển thị ở Tổng BV!
          final timeStr = data['ngay_tao']?.toString() ??
              data['thoi_gian_gui_str']?.toString() ??
              'Mới thêm trên hệ thống';
          final fileDoc = data['file_giay_phep_url']?.toString() ??
              data['file_url']?.toString() ??
              data['link_tai_lieu']?.toString() ??
              data['url_tai_lieu']?.toString() ??
              data['tai_lieu_dinh_kem']?.toString() ??
              data['hinh_anh_giay_phep']?.toString() ??
              data['file_giay_phep']?.toString() ??
              '';
          pendingMap[doc.id] = {
            'docId': doc.id,
            'name': name,
            'type': type.isEmpty ? 'Bệnh viện mới' : type,
            'code': data['so_giay_phep']?.toString() ?? doc.id,
            'tag': getInitials(name),
            'bs': '15 Bác sĩ',
            'time': 'Gửi: $timeStr',
            'docs': fileDoc.isNotEmpty ? fileDoc : 'Hồ sơ đăng ký hệ thống',
            'file_url': fileDoc,
            'location': address,
            'so_giay_phep': data['so_giay_phep']?.toString() ?? doc.id,
            'ma_so_thue': data['ma_so_thue']?.toString() ?? '',
            'email': data['email']?.toString() ?? '',
            'phone': data['so_dien_thoai']?.toString() ?? '',
            'mo_ta': data['mo_ta']?.toString() ?? '',
            'bhyt': data['bhyt']?.toString() ?? (data['co_bhyt'] == true ? 'Có hỗ trợ BHYT' : ''),
            'nguoi_dai_dien': data['nguoi_dai_dien']?.toString() ?? '',
            'hinh_anh': data['hinh_anh']?.toString() ?? '',
            'fromCollection': 'BenhVien',
          };
        }
      }
    }

    // 2. DUYỆT QUA COLLECTION 'YeuCauHopTac'
    if (_pendingSnap != null) {
      for (final doc in _pendingSnap!.docs) {
        final data = doc.data();
        final statusId = data['trang_thai_hop_tac_id'] as int? ?? 1;
        final daDuyet = data['da_duyet'] == true ||
            data['trang_thai'] == 'da_duyet' ||
            data['trangThai'] == 'DA_DUYET' ||
            statusId == 2 ||
            statusId == 10;
        final tuChoi = data['trang_thai'] == 'tu_choi' ||
            data['trangThai'] == 'TU_CHOI' ||
            statusId == 4;

        if (!daDuyet && !tuChoi) {
          final name = data['ten_benh_vien']?.toString() ?? 'Cơ sở Y tế mới';
          final type = data['loai_hinh']?.toString() ?? data['co_so']?.toString() ?? 'Bệnh viện Công lập';
          final code = data['so_giay_phep']?.toString() ??
              data['ma_ho_so']?.toString() ??
              doc.id;
          final timeStr = data['thoi_gian_gui_str']?.toString() ??
              data['ngay_gui_don']?.toString() ??
              'Mới gửi yêu cầu';
          final docFile = data['file_giay_phep_url']?.toString() ??
              data['file_url']?.toString() ??
              data['link_tai_lieu']?.toString() ??
              data['url_tai_lieu']?.toString() ??
              data['tai_lieu_dinh_kem']?.toString() ??
              data['hinh_anh_giay_phep']?.toString() ??
              data['file_giay_phep']?.toString() ??
              '';
          final location = data['dia_chi']?.toString() ??
              'Chưa cập nhật địa chỉ';

          if (pendingMap.containsKey(doc.id)) {
            final existing = pendingMap[doc.id]!;
            if (docFile.isNotEmpty) {
              existing['docs'] = docFile;
              existing['file_url'] = docFile;
            }
            existing['time'] = 'Gửi: $timeStr';
            if (data['so_giay_phep'] != null) existing['so_giay_phep'] = data['so_giay_phep'].toString();
            if (data['ma_so_thue'] != null) existing['ma_so_thue'] = data['ma_so_thue'].toString();
            if (data['email'] != null && existing['email']!.isEmpty) existing['email'] = data['email'].toString();
            if (data['so_dien_thoai'] != null && existing['phone']!.isEmpty) existing['phone'] = data['so_dien_thoai'].toString();
            if (data['mo_ta'] != null && existing['mo_ta']!.isEmpty) existing['mo_ta'] = data['mo_ta'].toString();
            if (data['nguoi_dai_dien'] != null && existing['nguoi_dai_dien']!.isEmpty) existing['nguoi_dai_dien'] = data['nguoi_dai_dien'].toString();
            if (data['co_bhyt'] != null && existing['bhyt']!.isEmpty) existing['bhyt'] = data['co_bhyt'] == true ? 'Có hỗ trợ BHYT' : 'Không hỗ trợ BHYT';
          } else {
            pendingMap[doc.id] = {
              'docId': doc.id,
              'name': name,
              'type': type,
              'code': code,
              'tag': getInitials(name),
              'bs': '15 Bác sĩ',
              'time': 'Gửi: $timeStr',
              'docs': docFile.isNotEmpty ? docFile : 'giay_phep_byt.pdf',
              'file_url': docFile,
              'location': location,
              'so_giay_phep': data['so_giay_phep']?.toString() ?? '',
              'ma_so_thue': data['ma_so_thue']?.toString() ?? '',
              'email': data['email']?.toString() ?? '',
              'phone': data['so_dien_thoai']?.toString() ?? '',
              'mo_ta': data['mo_ta']?.toString() ?? data['ghi_chu']?.toString() ?? '',
              'bhyt': data['bhyt']?.toString() ?? (data['co_bhyt'] == true ? 'Có hỗ trợ BHYT' : ''),
              'nguoi_dai_dien': data['nguoi_dai_dien']?.toString() ?? '',
              'hinh_anh': data['hinh_anh']?.toString() ?? '',
              'fromCollection': 'YeuCauHopTac',
            };
          }
        }
      }
    }

    if (_hospitalsSnap != null) {
      hospitals = approvedList;
      cancelledHospitals = cancelledList;
    }
    violations = viols;
    if (_pendingSnap != null || _hospitalsSnap != null) {
      pending = pendingMap.values.toList();
      pendingTotal = pending.length;
    }
    lastSync = DateTime.now();
    isConnected = true;
    notifyListeners();
  }

  void _processReportsSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final List<ErrorReport> reportList = [];
    final List<ErrorReport> resolvedList = [];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['trang_thai_xu_ly'] ??
              data['trang_thai'] ??
              data['trangThai'] ??
              data['status'])
          ?.toString()
          .toUpperCase() ??
          'CHO_XU_LY';

      final bool isResolved = status == 'DA_GIAI_QUYET' ||
          status == 'RESOLVED' ||
          status == 'DA_XU_LY' ||
          status == 'CLOSED';

      final rawKind = (data['loai'] ?? data['kind'] ?? data['type'] ?? '')
          .toString()
          .toLowerCase();
      final kind = rawKind.contains('booking') || rawKind.contains('lich')
          ? 'booking'
          : 'qr';
      final defaultBadge =
          kind == 'qr' ? 'Lỗi QR Check-in' : 'Lỗi Đặt Lịch';
      final badge = data['badge']?.toString() ??
          data['danh_muc']?.toString() ??
          data['loai_loi']?.toString() ??
          defaultBadge;
      final title = data['tieu_de']?.toString() ??
          data['title']?.toString() ??
          'Báo cáo sự cố từ Bệnh viện';

      final rawSender = data['nguoi_gui']?.toString() ??
          data['sender']?.toString() ??
          data['ten_benh_vien']?.toString() ??
          data['benh_vien']?.toString() ??
          'Bệnh viện báo lỗi';
      final senderStr = rawSender.startsWith('Người gửi:')
          ? rawSender
          : 'Người gửi: $rawSender';

      String timeStr = 'Gần đây';
      if (data['thoi_gian_hien_thi'] != null) {
        timeStr = data['thoi_gian_hien_thi'].toString();
      } else if (data['time'] != null) {
        timeStr = data['time'].toString();
      } else if (data['ngay_tao'] is Timestamp) {
        final dt = (data['ngay_tao'] as Timestamp).toDate();
        timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}/${dt.year}';
      } else if (data['ngay_tao'] != null) {
        timeStr = data['ngay_tao'].toString();
      }

      String? resolvedTimeStr;
      if (data['ngay_giai_quyet'] is Timestamp) {
        final dt = (data['ngay_giai_quyet'] as Timestamp).toDate();
        resolvedTimeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}/${dt.year}';
      } else if (data['ngay_giai_quyet'] != null) {
        resolvedTimeStr = data['ngay_giai_quyet'].toString();
      }

      final desc = data['noi_dung']?.toString() ??
          data['mo_ta']?.toString() ??
          data['desc']?.toString() ??
          data['content']?.toString();

      final adminResp = data['phan_hoi_admin']?.toString() ??
          data['phan_hoi']?.toString() ??
          data['admin_response']?.toString();

      final reportItem = ErrorReport(
        id: doc.id,
        kind: kind,
        badge: badge,
        title: title,
        sender: senderStr,
        time: timeStr,
        desc: desc != null && desc.isNotEmpty
            ? (desc.startsWith('Mô tả:') ? desc : 'Mô tả: $desc')
            : null,
        isResolved: isResolved,
        adminResponse: adminResp,
        resolvedTime: resolvedTimeStr,
      );

      if (isResolved) {
        resolvedList.add(reportItem);
      } else {
        reportList.add(reportItem);
      }
    }
    reports = reportList;
    resolvedReports = resolvedList;
    errorTotal = reportList.length;
    lastSync = DateTime.now();
    isConnected = true;
    notifyListeners();
  }

  void _processPatientsSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final List<AdminPatient> list = [];
    int idx = 0;
    debugPrint('Đang xử lý ${snapshot.docs.length} tài khoản BenhNhan từ Firestore...');
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
      final uid = data['uid']?.toString() ?? doc.id;
      final maBenhNhan = data['ma_benh_nhan']?.toString() ?? 'BN${doc.id.length >= 4 ? doc.id.substring(0, 4) : doc.id}';
      final hoTen = data['ho_ten']?.toString() ?? 'Bệnh nhân ${doc.id}';
      final email = data['email']?.toString();
      final phone = data['so_dien_thoai']?.toString();
      final address = data['dia_chi']?.toString();
      final gender = data['gioi_tinh']?.toString();
      final verified = data['da_xac_thuc_email'] == true;
      final rawStatus = data['trang_thai_id'];
      int statusId = 7;
      if (rawStatus is int) {
        statusId = rawStatus;
      } else if (rawStatus is String) {
        statusId = int.tryParse(rawStatus) ?? 7;
      }
      final trangThaiStr = data['trang_thai']?.toString().toLowerCase();
      final isBlocked = data['chan_dang_nhap'] == true ||
          data['is_blocked'] == true ||
          statusId == 8 || statusId == 11 ||
          trangThaiStr == 'khoa' ||
          trangThaiStr == 'chan_dang_nhap';
      final blockReason = data['ly_do_khoa']?.toString() ?? data['ly_do_chan']?.toString();

      DateTime? ngayTao;
      if (data['ngay_tao'] is Timestamp) {
        ngayTao = (data['ngay_tao'] as Timestamp).toDate();
      } else if (data['ngay_tao'] != null) {
        try {
          ngayTao = DateTime.parse(data['ngay_tao'].toString());
        } catch (_) {}
      }

      DateTime? ngaySinh;
      if (data['ngay_sinh'] is Timestamp) {
        ngaySinh = (data['ngay_sinh'] as Timestamp).toDate();
      } else if (data['ngay_sinh'] != null) {
        try {
          ngaySinh = DateTime.parse(data['ngay_sinh'].toString());
        } catch (_) {}
      }

      DateTime? ngayKhoa;
      if (data['ngay_khoa'] is Timestamp) {
        ngayKhoa = (data['ngay_khoa'] as Timestamp).toDate();
      } else if (data['ngay_khoa'] != null) {
        try {
          ngayKhoa = DateTime.parse(data['ngay_khoa'].toString());
        } catch (_) {}
      }

      DateTime? dangNhapCuoi;
      final rawLogin = data['dang_nhap_cuoi'] ?? data['last_login'] ?? data['lan_hoat_dong_cuoi'] ?? data['last_active'];
      if (rawLogin is Timestamp) {
        dangNhapCuoi = rawLogin.toDate();
      } else if (rawLogin != null) {
        try {
          dangNhapCuoi = DateTime.parse(rawLogin.toString());
        } catch (_) {}
      }

      DateTime? ngayOffline;
      final rawOff = data['ngay_offline'] ?? data['offline_at'] ?? data['thoi_gian_offline'];
      if (rawOff is Timestamp) {
        ngayOffline = rawOff.toDate();
      } else if (rawOff != null) {
        try {
          ngayOffline = DateTime.parse(rawOff.toString());
        } catch (_) {}
      }

      final palette = _avatarPalette[idx % _avatarPalette.length];
      idx++;

      list.add(AdminPatient(
        uid: uid,
        maBenhNhan: maBenhNhan,
        hoTen: hoTen,
        email: email,
        soDienThoai: phone,
        diaChi: address,
        gioiTinh: gender,
        ngaySinh: ngaySinh,
        ngayTao: ngayTao,
        daXacThucEmail: verified,
        trangThaiId: statusId,
        isBlocked: isBlocked,
        blockReason: blockReason,
        ngayKhoa: ngayKhoa,
        ngayOffline: ngayOffline,
        dangNhapCuoi: dangNhapCuoi,
        avatarBg: palette[0],
        avatarText: palette[1],
      ));
      } catch (err) {
        debugPrint('Lỗi phân tích bệnh nhân ${doc.id}: $err');
      }
    }
    patients = list;
    debugPrint('Đã cập nhật thành công ${patients.length} bệnh nhân vào bộ nhớ AdminStore');
    lastSync = DateTime.now();
    isConnected = true;
    notifyListeners();
  }

  void _initFirebaseSync() {
    try {
      // 1. Lắng nghe danh sách bệnh viện từ Firestore collection 'BenhVien'
      _hospitalsSub = _firestore.collection('BenhVien').snapshots().listen(
        (snapshot) {
          _hospitalsSnap = snapshot;
          _recomputeData();
        },
        onError: (e) {
          debugPrint('Lỗi realtime BenhVien: $e');
          isConnected = false;
          notifyListeners();
        },
      );

      // 2. Lắng nghe hồ sơ chờ duyệt từ 'YeuCauHopTac'
      _pendingSub = _firestore.collection('YeuCauHopTac').snapshots().listen(
        (snapshot) {
          _pendingSnap = snapshot;
          _recomputeData();
        },
        onError: (e) {
          debugPrint('Lỗi realtime YeuCauHopTac: $e');
          isConnected = false;
          notifyListeners();
        },
      );

      // 3. Lắng nghe báo cáo lỗi từ 'BaoCaoLoi'
      _reportsSub = _firestore.collection('BaoCaoLoi').snapshots().listen(
        (snapshot) {
          _processReportsSnapshot(snapshot);
        },
        onError: (e) {
          debugPrint('Lỗi realtime BaoCaoLoi: $e');
          isConnected = false;
          notifyListeners();
        },
      );

      // 4. Lắng nghe danh sách bệnh nhân từ 'BenhNhan'
      _patientsSub = _firestore.collection('BenhNhan').snapshots().listen(
        (snapshot) {
          _processPatientsSnapshot(snapshot);
        },
        onError: (e) {
          debugPrint('Lỗi realtime BenhNhan: $e');
          isConnected = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Không thể khởi tạo listener Firestore: $e');
      isConnected = false;
      notifyListeners();
    }
  }

  // ===================================================
  // CÁC HÀNH ĐỘNG CỦA ADMIN (Ghi dữ liệu lên Firebase)
  // ===================================================

  /// DUYỆT BỆNH VIỆN
  void approveHospital(Map<String, String> h) async {
    final docId = h['docId'] ?? h['code'] ?? '';
    if (docId.isEmpty) return;

    pending.removeWhere((e) => (e['docId'] == docId || e['code'] == h['code']));
    pendingTotal = pending.length;

    final palette = _avatarPalette[hospitals.length % _avatarPalette.length];
    final bsRaw = h['bs'] ?? '15';
    final doctors = int.tryParse(bsRaw.split(' ').first) ?? 15;

    final newHospital = Hospital(
      initials: h['tag'] ?? 'BV',
      name: h['name'] ?? 'Bệnh viện',
      type: h['type'] ?? 'Tư nhân',
      rating: 5.0,
      doctors: doctors,
      avatarBg: palette[0],
      avatarText: palette[1],
      address: h['location'] ?? 'Đang cập nhật địa chỉ',
      code: docId,
      status: 10,
    );
    if (!hospitals.any((e) => e.code == docId)) {
      hospitals.insert(0, newHospital);
    }
    violations.removeWhere((v) => v['match'] == h['name']);
    notifyListeners();

    // Ghi lên Firestore
    try {
      // 1. Cập nhật hoặc tạo mới trong BenhVien với trạng thái ĐÃ DUYỆT (10)
      await _firestore.collection('BenhVien').doc(docId).set({
        'ten_benh_vien': h['name'],
        'co_so': h['type'],
        'dia_chi': h['location'],
        'trang_thai_hop_tac_id': 10,
        'trang_thai': 'da_duyet',
        'trangThai': 'DA_DUYET',
        'da_duyet': true,
        'diem_danh_gia_tb': 5.0,
        'tong_so_danh_gia': 0,
        'ngay_duyet': FieldValue.serverTimestamp(),
        'ngay_hop_tac': FieldValue.serverTimestamp(),
        'da_xac_thuc_email': true,
        'role': 'benh_vien',
      }, SetOptions(merge: true));

      // 2. Cập nhật YeuCauHopTac nếu tồn tại
      try {
        final ycDoc = await _firestore.collection('YeuCauHopTac').doc(docId).get();
        if (ycDoc.exists) {
          await _firestore.collection('YeuCauHopTac').doc(docId).set({
            'trang_thai_hop_tac_id': 10,
            'trang_thai': 'da_duyet',
            'trangThai': 'DA_DUYET',
            'da_duyet': true,
            'ngay_duyet': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Lỗi ghi duyệt bệnh viện lên Firebase: $e');
    }
  }

  /// TỪ CHỐI DUYỆT BỆNH VIỆN
  void rejectHospital(Map<String, String> h, {String? reason}) async {
    final docId = h['docId'] ?? h['code'] ?? '';
    if (docId.isEmpty) return;

    pending.removeWhere((e) => (e['docId'] == docId || e['code'] == h['code']));
    pendingTotal = pending.length;
    violations.removeWhere((v) => v['match'] == h['name']);
    notifyListeners();

    try {
      // 1. Cập nhật BenhVien nếu có
      try {
        final bvDoc = await _firestore.collection('BenhVien').doc(docId).get();
        if (bvDoc.exists) {
          await _firestore.collection('BenhVien').doc(docId).set({
            'trang_thai_hop_tac_id': 4,
            'trang_thai': 'tu_choi',
            'trangThai': 'TU_CHOI',
            'da_duyet': false,
            'ly_do_tu_choi': reason ?? 'Hồ sơ chưa đạt tiêu chuẩn quy định.',
            'ngay_tu_choi': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (_) {}

      // 2. Cập nhật YeuCauHopTac nếu có
      try {
        final ycDoc = await _firestore.collection('YeuCauHopTac').doc(docId).get();
        if (ycDoc.exists) {
          await _firestore.collection('YeuCauHopTac').doc(docId).set({
            'trang_thai_hop_tac_id': 4,
            'trang_thai': 'tu_choi',
            'trangThai': 'TU_CHOI',
            'da_duyet': false,
            'ly_do_tu_choi': reason ?? 'Hồ sơ chưa đạt tiêu chuẩn quy định.',
            'ngay_tu_choi': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Lỗi từ chối bệnh viện trên Firebase: $e');
    }
  }

  /// XÓA CƠ SỞ VI PHẠM
  void deleteViolation(Map<String, String> v) async {
    violations.remove(v);
    final matched = pending.where((e) => e['name'] == v['match']).toList();
    for (final m in matched) {
      pending.remove(m);
      pendingTotal = (pendingTotal - 1).clamp(0, 999);
    }
    if (pending.isEmpty) pendingTotal = 0;
    notifyListeners();

    try {
      final code = v['code'];
      if (code != null && code.isNotEmpty) {
        await _firestore.collection('BenhVien').doc(code).update({
          'trang_thai_hop_tac_id': 8,
          'ly_do_khoa': v['reason'] ?? 'Vi phạm quy chuẩn BYT',
          'ngay_khoa': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Lỗi khóa cơ sở vi phạm trên Firebase: $e');
    }
  }

  /// HỦY HỢP TÁC VỚI BỆNH VIỆN
  Future<void> cancelHospitalPartnership(Hospital h, String reason) async {
    h.isUnpartnered = true;
    h.isBlocked = true;
    h.blockReason = reason;
    h.status = 1; // Chuyển trạng thái về 1 (Chờ duyệt / Hủy hợp tác)
    hospitals.remove(h);
    if (!cancelledHospitals.contains(h)) {
      cancelledHospitals.insert(0, h);
    }
    violations.removeWhere((v) => v['code'] == h.code || v['name'] == h.name);
    notifyListeners();

    try {
      final code = h.code;
      if (code != null && code.isNotEmpty) {
        // Cập nhật trạng thái trên Firebase BenhVien:
        // Chuyển trang_thai_hop_tac_id sang 9 (Hủy Hợp Tác)
        // và gắn cờ chan_dang_nhap, da_duyet = false để không thể đăng nhập
        await _firestore.collection('BenhVien').doc(code).update({
          'trang_thai_hop_tac_id': 9,
          'da_duyet': false,
          'trang_thai': 'huy_hop_tac',
          'trangThai': 'HUY_HOP_TAC',
          'chan_dang_nhap': true,
          'is_blocked': true,
          'is_unpartnered': true,
          'ly_do_huy': reason,
          'ngay_ngung_hop_tac': FieldValue.serverTimestamp(),
        });

        // Cập nhật đồng bộ trên YeuCauHopTac nếu có
        try {
          final ycDoc = await _firestore.collection('YeuCauHopTac').doc(code).get();
          if (ycDoc.exists) {
            await _firestore.collection('YeuCauHopTac').doc(code).update({
              'trang_thai_hop_tac_id': 9,
              'da_duyet': false,
              'trang_thai': 'huy_hop_tac',
              'trangThai': 'HUY_HOP_TAC',
              'chan_dang_nhap': true,
              'ly_do_huy': reason,
            });
          }
        } catch (_) {}

        // Chặn quyền đăng nhập trong collection NhanVien của bệnh viện này
        try {
          final nvDoc = await _firestore.collection('NhanVien').doc(code).get();
          if (nvDoc.exists) {
            await _firestore.collection('NhanVien').doc(code).update({
              'trangThaiHoatDong': false,
              'chan_dang_nhap': true,
              'trang_thai_hop_tac_id': 9,
            });
          }

          final staffQueries = [
            _firestore.collection('NhanVien').where('id_benh_vien', isEqualTo: code).get(),
            _firestore.collection('NhanVien').where('benh_vien_id', isEqualTo: code).get(),
            _firestore.collection('NhanVien').where('ma_benh_vien', isEqualTo: code).get(),
          ];
          final results = await Future.wait(staffQueries);
          for (final snap in results) {
            for (final doc in snap.docs) {
              await doc.reference.update({
                'trangThaiHoatDong': false,
                'chan_dang_nhap': true,
                'trang_thai_hop_tac_id': 9,
              });
            }
          }
        } catch (_) {}

        // Vô hiệu hóa tài khoản gốc trên Firebase Auth và thu hồi phiên đăng nhập
        try {
          await FirebaseAdminAuthService.instance.disableAndRevokeUser(
            uid: code,
            email: h.email,
          );
        } catch (e) {
          debugPrint('Lỗi vô hiệu hóa Firebase Auth cho bệnh viện: $e');
        }

        // Gửi thông báo hệ thống
        await _firestore.collection('ThongBaoHeThong').add({
          'tieu_de': 'Hủy hợp tác bệnh viện',
          'noi_dung': 'Quản trị viên đã hủy thỏa thuận hợp tác với bệnh viện: ${h.name} ($code). Lý do: $reason',
          'loai': 'huy_hop_tac_bv',
          'benh_vien_id': code,
          'da_doc': false,
          'thoi_gian_hien_thi': 'Vừa xong',
          'ngay_tao': FieldValue.serverTimestamp(),
        });

        // Gửi email thông báo ngừng hợp tác tới email đăng ký của bệnh viện
        if (h.email != null && h.email!.isNotEmpty) {
          await EmailService.instance.sendPartnershipCancelledEmail(
            toEmail: h.email!,
            hospitalName: h.name,
            reason: reason,
          );
        }
      }
    } catch (e) {
      debugPrint('Lỗi hủy hợp tác bệnh viện trên Firebase: $e');
    }
  }

  /// KHÔI PHỤC QUAN HỆ HỢP TÁC VỚI BỆNH VIỆN
  Future<void> restoreHospitalPartnership(Hospital h) async {
    h.isUnpartnered = false;
    h.isBlocked = false;
    h.blockReason = null;
    h.status = 10; // Trở lại trạng thái 10 (Hợp tác)
    cancelledHospitals.remove(h);
    if (!hospitals.contains(h)) {
      hospitals.insert(0, h);
    }
    notifyListeners();

    try {
      final code = h.code;
      if (code != null && code.isNotEmpty) {
        // Cập nhật trạng thái trên Firebase BenhVien: Chuyển lại về 10 (Hợp tác)
        await _firestore.collection('BenhVien').doc(code).update({
          'trang_thai_hop_tac_id': 10,
          'da_duyet': true,
          'trang_thai': 'da_duyet',
          'trangThai': 'DA_DUYET',
          'chan_dang_nhap': false,
          'is_blocked': false,
          'is_unpartnered': false,
          'ly_do_huy': FieldValue.delete(),
          'ly_do_khoa': FieldValue.delete(),
          'ngay_khoi_phuc_hop_tac': FieldValue.serverTimestamp(),
        });

        // Cập nhật lại YeuCauHopTac nếu có
        try {
          final ycDoc = await _firestore.collection('YeuCauHopTac').doc(code).get();
          if (ycDoc.exists) {
            await _firestore.collection('YeuCauHopTac').doc(code).update({
              'trang_thai_hop_tac_id': 10,
              'da_duyet': true,
              'trang_thai': 'da_duyet',
              'trangThai': 'DA_DUYET',
              'chan_dang_nhap': false,
              'ly_do_huy': FieldValue.delete(),
            });
          }
        } catch (_) {}

        // Mở khóa quyền đăng nhập tài khoản nhân viên / quản lý trong collection NhanVien
        try {
          final nvDoc = await _firestore.collection('NhanVien').doc(code).get();
          if (nvDoc.exists) {
            await _firestore.collection('NhanVien').doc(code).update({
              'trangThaiHoatDong': true,
              'chan_dang_nhap': false,
              'trang_thai_hop_tac_id': 10,
            });
          }

          final staffQueries = [
            _firestore.collection('NhanVien').where('id_benh_vien', isEqualTo: code).get(),
            _firestore.collection('NhanVien').where('benh_vien_id', isEqualTo: code).get(),
            _firestore.collection('NhanVien').where('ma_benh_vien', isEqualTo: code).get(),
          ];
          final results = await Future.wait(staffQueries);
          for (final snap in results) {
            for (final doc in snap.docs) {
              await doc.reference.update({
                'trangThaiHoatDong': true,
                'chan_dang_nhap': false,
                'trang_thai_hop_tac_id': 10,
              });
            }
          }
        } catch (_) {}

        // Mở khóa tài khoản gốc trên Firebase Auth
        try {
          await FirebaseAdminAuthService.instance.enableUser(
            uid: code,
            email: h.email,
          );
        } catch (e) {
          debugPrint('Lỗi mở khóa Firebase Auth cho bệnh viện: $e');
        }

        // Gửi thông báo hệ thống
        await _firestore.collection('ThongBaoHeThong').add({
          'tieu_de': 'Khôi phục hợp tác bệnh viện',
          'noi_dung': 'Quản trị viên đã khôi phục hợp tác với bệnh viện: ${h.name} ($code)',
          'loai': 'khoi_phuc_hop_tac_bv',
          'benh_vien_id': code,
          'da_doc': false,
          'thoi_gian_hien_thi': 'Vừa xong',
          'ngay_tao': FieldValue.serverTimestamp(),
        });

        // Gửi email thông báo khôi phục hợp tác
        if (h.email != null && h.email!.isNotEmpty) {
          await EmailService.instance.sendPartnershipRestoredEmail(
            toEmail: h.email!,
            hospitalName: h.name,
          );
        }
      }
    } catch (e) {
      debugPrint('Lỗi khôi phục hợp tác bệnh viện trên Firebase: $e');
    }
  }

  /// XÓA VĨNH VIỄN TÀI KHOẢN BỆNH VIỆN TRÊN FIREBASE (FIRESTORE & FIREBASE AUTHENTICATION)
  Future<void> deleteHospitalAccount(Hospital h) async {
    final email = h.email;
    final name = h.name;
    hospitals.remove(h);
    cancelledHospitals.remove(h);
    violations.removeWhere((v) => v['code'] == h.code || v['name'] == h.name);
    notifyListeners();

    try {
      final code = h.code;
      if (code != null && code.isNotEmpty) {
        String? finalEmail = email;
        String targetAuthUid = code;

        // 0. Đọc thông tin từ collection BenhVien trước khi xóa tài liệu
        try {
          final bvSnap = await _firestore.collection('BenhVien').doc(code).get();
          if (bvSnap.exists) {
            final data = bvSnap.data();
            if (data != null) {
              if (finalEmail == null || finalEmail.isEmpty) {
                finalEmail = data['email']?.toString();
              }
              final authUidInDoc = data['uid']?.toString() ??
                  data['auth_uid']?.toString() ??
                  data['tai_khoan_id']?.toString();
              if (authUidInDoc != null && authUidInDoc.isNotEmpty) {
                targetAuthUid = authUidInDoc;
              }
            }
          }
        } catch (e) {
          debugPrint('Lỗi đọc dữ liệu BenhVien trước khi xóa: $e');
        }

        // Kiểm tra trong YeuCauHopTac nếu vẫn chưa có email
        if (finalEmail == null || finalEmail.isEmpty) {
          try {
            final ycSnap = await _firestore.collection('YeuCauHopTac').doc(code).get();
            if (ycSnap.exists) {
              finalEmail = ycSnap.data()?['email']?.toString();
            }
          } catch (_) {}
        }

        // 1. XÓA VĨNH VIỄN TÀI KHOẢN KHỎI FIREBASE AUTHENTICATION (BẢNG USERS TRÊN CONSOLE)
        try {
          final deletedAuth = await FirebaseAdminAuthService.instance.deleteUser(
            uid: targetAuthUid,
            email: finalEmail,
          );
          if (deletedAuth) {
            debugPrint('✅ Đã xóa hoàn toàn tài khoản bệnh viện khỏi Firebase Auth: $targetAuthUid ($finalEmail)');
          } else {
            debugPrint('⚠️ Không thể xóa khỏi Firebase Auth hoặc tài khoản không tồn tại trên Auth');
          }
        } catch (e) {
          debugPrint('❌ Lỗi xóa tài khoản bệnh viện trên Firebase Auth: $e');
        }

        // 2. Xóa trong collection BenhVien
        await _firestore.collection('BenhVien').doc(code).delete();

        // 3. Xóa trong YeuCauHopTac
        try {
          await _firestore.collection('YeuCauHopTac').doc(code).delete();
        } catch (_) {}

        // 4. Xóa trong NhanVien
        try {
          await _firestore.collection('NhanVien').doc(code).delete();
        } catch (_) {}

        // 5. Ghi nhật ký thông báo hệ thống
        try {
          await _firestore.collection('ThongBaoHeThong').add({
            'tieu_de': 'Đã xóa vĩnh viễn bệnh viện',
            'noi_dung': 'Quản trị viên đã xóa hoàn toàn hồ sơ và tài khoản bệnh viện: $name ($code)',
            'loai': 'xoa_tai_khoan_bv',
            'da_doc': false,
            'thoi_gian_hien_thi': 'Vừa xong',
            'ngay_tao': FieldValue.serverTimestamp(),
          });
        } catch (_) {}

        // 6. Gửi email thông báo xóa tài khoản bệnh viện
        if (finalEmail != null && finalEmail.isNotEmpty) {
          await EmailService.instance.sendAccountDeletedEmail(
            toEmail: finalEmail,
            recipientName: name,
            isHospital: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Lỗi xóa vĩnh viễn bệnh viện trên Firebase: $e');
    }
  }

  /// XÓA HỢP TÁC VỚI BỆNH VIỆN
  void unpartnerHospital(Hospital h) async {
    cancelHospitalPartnership(h, 'Ngừng hợp tác theo yêu cầu của Quản trị viên');
  }

  /// SỬA THÔNG TIN BỆNH VIỆN
  void updateHospital(
    Hospital h, {
    String? name,
    String? type,
    String? address,
    int? doctors,
  }) async {
    if (name != null && name.isNotEmpty) h.name = name;
    if (type != null && type.isNotEmpty) h.type = type;
    if (address != null && address.isNotEmpty) h.address = address;
    if (doctors != null) h.doctors = doctors;
    notifyListeners();

    try {
      if (h.code != null && h.code!.isNotEmpty) {
        final Map<String, dynamic> updateData = {};
        if (name != null && name.isNotEmpty) updateData['ten_benh_vien'] = name;
        if (type != null && type.isNotEmpty) updateData['co_so'] = type;
        if (address != null && address.isNotEmpty) updateData['dia_chi'] = address;
        updateData['ngay_cap_nhat'] = FieldValue.serverTimestamp();

        await _firestore.collection('BenhVien').doc(h.code).update(updateData);
      }
    } catch (e) {
      debugPrint('Lỗi cập nhật bệnh viện trên Firebase: $e');
    }
  }

  /// XỬ LÝ XONG BÁO CÁO LỖI
  void resolveReport(String id) async {
    final report = reports.firstWhere(
      (r) => r.id == id,
      orElse: () => ErrorReport(
        id: id,
        kind: 'other',
        badge: 'Sự cố',
        title: 'Báo cáo sự cố',
        sender: 'Người dùng',
        time: 'Vừa xong',
      ),
    );
    resolveReportAndNotify(
      report,
      'Quản trị viên đã tiếp nhận và giải quyết thành công sự cố này.',
    );
  }

  /// XỬ LÝ SỰ CỐ VÀ GỬI THÔNG BÁO CHO NGƯỜI GỬI
  Future<void> resolveReportAndNotify(
    ErrorReport report,
    String responseMessage,
  ) async {
    final resolvedItem = ErrorReport(
      id: report.id,
      kind: report.kind,
      badge: report.badge,
      title: report.title,
      sender: report.sender,
      time: report.time,
      desc: report.desc,
      isResolved: true,
      adminResponse: responseMessage,
      resolvedTime: 'Vừa xong',
    );
    reports.removeWhere((r) => r.id == report.id);
    resolvedReports.removeWhere((r) => r.id == report.id);
    resolvedReports.insert(0, resolvedItem);
    errorTotal = reports.length;
    notifyListeners();

    try {
      // 1. Cập nhật BaoCaoLoi
      await _firestore.collection('BaoCaoLoi').doc(report.id).update({
        'trang_thai_xu_ly': 'DA_GIAI_QUYET',
        'trang_thai': 'da_giai_quyet',
        'trangThai': 'DA_GIAI_QUYET',
        'da_doc': true,
        'phan_hoi_admin': responseMessage,
        'ngay_giai_quyet': FieldValue.serverTimestamp(),
      });

      // 2. Gửi thông báo đến ThongBaoHeThong
      await _firestore.collection('ThongBaoHeThong').add({
        'tieu_de': 'Đã xử lý sự cố: ${report.title}',
        'noi_dung': 'Quản trị viên đã xử lý và phản hồi tới ${report.sender}: "$responseMessage"',
        'loai': 'su_co_da_sua',
        'bao_cao_loi_id': report.id,
        'nguoi_nhan': report.sender,
        'thoi_gian_hien_thi': 'Vừa xong',
        'da_doc': false,
        'ngay_tao': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Lỗi giải quyết báo cáo và gửi thông báo trên Firebase: $e');
    }
  }

  /// LỌC BÁO CÁO THEO LOẠI
  List<ErrorReport> filteredReports(int filter) {
    if (filter == 1) {
      return reports.where((r) => r.kind == 'booking').toList();
    }
    if (filter == 2) {
      return reports.where((r) => r.kind == 'qr').toList();
    }
    return List.of(reports);
  }

  /// LỌC LỊCH SỬ BÁO CÁO ĐÃ GIẢI QUYẾT
  List<ErrorReport> filteredResolvedReports(int filter) {
    if (filter == 1) {
      return resolvedReports.where((r) => r.kind == 'booking').toList();
    }
    if (filter == 2) {
      return resolvedReports.where((r) => r.kind == 'qr').toList();
    }
    return List.of(resolvedReports);
  }

  // ===================================================
  // QUẢN LÝ TÀI KHOẢN BỆNH NHÂN (FIREBASE)
  // ===================================================

  /// CHẶN ĐĂNG NHẬP / KHÓA TÀI KHOẢN BỆNH NHÂN
  Future<void> blockPatient(AdminPatient p, String reason) async {
    p.isBlocked = true;
    p.trangThaiId = 8;
    p.blockReason = reason;
    p.ngayKhoa = DateTime.now();
    notifyListeners();

    try {
      await _firestore.collection('BenhNhan').doc(p.uid).set({
        'chan_dang_nhap': true,
        'is_blocked': true,
        'trang_thai_id': 11,
        'trang_thai': 'khoa',
        'trangThai': 'DA_KHOA',
        'ly_do_khoa': reason,
        'ngay_khoa': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Gửi thông báo hệ thống
      await _firestore.collection('ThongBaoHeThong').add({
        'tieu_de': 'Khóa tài khoản bệnh nhân',
        'noi_dung': 'Quản trị viên đã khóa tài khoản bệnh nhân: ${p.hoTen} (${p.maBenhNhan}). Lý do: $reason',
        'loai': 'khoa_tai_khoan',
        'nguoi_nhan_uid': p.uid,
        'da_doc': false,
        'thoi_gian_hien_thi': 'Vừa xong',
        'ngay_tao': FieldValue.serverTimestamp(),
      });

      // Vô hiệu hóa tài khoản gốc trên Firebase Auth và thu hồi phiên đăng nhập
      try {
        await FirebaseAdminAuthService.instance.disableAndRevokeUser(
          uid: p.uid,
          email: p.email,
        );
      } catch (e) {
        debugPrint('Lỗi vô hiệu hóa Firebase Auth: ');
      }

      // Gửi email thông báo tới email đăng ký của bệnh nhân
      if (p.email != null && p.email!.isNotEmpty) {
        await EmailService.instance.sendAccountBlockedEmail(
          toEmail: p.email!,
          recipientName: p.hoTen,
          reason: reason,
          isHospital: false,
        );
      }
    } catch (e) {
      debugPrint('Lỗi chặn tài khoản bệnh nhân trên Firebase: $e');
      p.isBlocked = false;
      p.trangThaiId = 7;
      p.blockReason = null;
      notifyListeners();
      rethrow;
    }
  }

  /// MỞ KHÓA TÀI KHOẢN BỆNH NHÂN
  Future<void> unblockPatient(AdminPatient p) async {
    p.isBlocked = false;
    p.trangThaiId = 7;
    p.blockReason = null;
    notifyListeners();

    try {
      await _firestore.collection('BenhNhan').doc(p.uid).set({
        'chan_dang_nhap': false,
        'is_blocked': false,
        'trang_thai_id': 7,
        'trang_thai': 'hoat_dong',
        'trangThai': 'HOAT_DONG',
        'ly_do_khoa': FieldValue.delete(),
        'ngay_mo_khoa': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Gửi thông báo hệ thống
      await _firestore.collection('ThongBaoHeThong').add({
        'tieu_de': 'Mở khóa tài khoản bệnh nhân',
        'noi_dung': 'Quản trị viên đã kích hoạt lại tài khoản bệnh nhân: ${p.hoTen} (${p.maBenhNhan})',
        'loai': 'mo_khoa_tai_khoan',
        'nguoi_nhan_uid': p.uid,
        'da_doc': false,
        'thoi_gian_hien_thi': 'Vừa xong',
        'ngay_tao': FieldValue.serverTimestamp(),
      });

      // Mở khóa tài khoản gốc trên Firebase Auth
      try {
        await FirebaseAdminAuthService.instance.enableUser(
          uid: p.uid,
          email: p.email,
        );
      } catch (e) {
        debugPrint('Lỗi mở khóa Firebase Auth: ');
      }

      // Gửi email thông báo mở khóa tới bệnh nhân
      if (p.email != null && p.email!.isNotEmpty) {
        await EmailService.instance.sendAccountUnblockedEmail(
          toEmail: p.email!,
          recipientName: p.hoTen,
          isHospital: false,
        );
      }
    } catch (e) {
      debugPrint('Lỗi mở khóa tài khoản bệnh nhân trên Firebase: $e');
      p.isBlocked = true;
      p.trangThaiId = 8;
      notifyListeners();
      rethrow;
    }
  }

  /// XÓA VĨNH VIỄN TÀI KHOẢN BỆNH NHÂN (FIRESTORE & FIREBASE AUTHENTICATION)
  Future<void> deletePatientAccount(AdminPatient p) async {
    final email = p.email;
    final name = p.hoTen;
    patients.removeWhere((item) => item.uid == p.uid);
    notifyListeners();

    try {
      // 1. Xóa vĩnh viễn tài khoản trên Firebase Authentication (Users Table)
      try {
        await FirebaseAdminAuthService.instance.deleteUser(
          uid: p.uid,
          email: email,
        );
      } catch (e) {
        debugPrint('❌ Lỗi xóa tài khoản bệnh nhân trên Firebase Auth: $e');
      }

      // 2. Xóa hồ sơ trong Firestore collection BenhNhan
      await _firestore.collection('BenhNhan').doc(p.uid).delete();

      await _firestore.collection('ThongBaoHeThong').add({
        'tieu_de': 'Đã xóa tài khoản bệnh nhân',
        'noi_dung': 'Quản trị viên đã xóa hoàn toàn tài khoản bệnh nhân: ${p.hoTen} (${p.maBenhNhan})',
        'loai': 'xoa_tai_khoan',
        'da_doc': false,
        'thoi_gian_hien_thi': 'Vừa xong',
        'ngay_tao': FieldValue.serverTimestamp(),
      });

      // Gửi email thông báo xóa tài khoản tới bệnh nhân
      if (email != null && email.isNotEmpty) {
        await EmailService.instance.sendAccountDeletedEmail(
          toEmail: email,
          recipientName: name,
          isHospital: false,
        );
      }
    } catch (e) {
      debugPrint('Lỗi xóa tài khoản bệnh nhân trên Firebase: $e');
    }
  }

  /// LẤY LỊCH HẸN CỦA BỆNH NHÂN TỪ FIRESTORE
  Future<List<Map<String, dynamic>>> getPatientAppointments(String patientId) async {
    try {
      final snap = await _firestore
          .collection('LichHen')
          .where('benh_nhan_id', isEqualTo: patientId)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('Lỗi tải lịch hẹn bệnh nhân: $e');
      return [];
    }
  }

  /// THỐNG KÊ HOẠT ĐỘNG VÀ BIỂU ĐỒ TẦN SUẤT CỦA BỆNH NHÂN
  Future<Map<String, dynamic>> getPatientActivityStats(AdminPatient patient) async {
    final appointments = await getPatientAppointments(patient.uid);

    final now = DateTime.now();
    final joinDate = patient.ngayTao ?? now;
    final totalDaysJoined = (now.difference(joinDate).inDays).clamp(1, 3650);

    // Thời điểm bắt đầu offline
    final offlineStart = patient.effectiveOfflineTime;
    final offlineDuration = now.difference(offlineStart);

    String offlineDurationText = 'Đang trực tuyến';
    if (!patient.isActive) {
      if (offlineDuration.inDays > 30) {
        final months = (offlineDuration.inDays / 30).floor();
        final days = offlineDuration.inDays % 30;
        offlineDurationText = '$months tháng $days ngày';
      } else if (offlineDuration.inDays > 0) {
        final hours = offlineDuration.inHours % 24;
        offlineDurationText = '${offlineDuration.inDays} ngày $hours giờ';
      } else if (offlineDuration.inHours > 0) {
        final mins = offlineDuration.inMinutes % 60;
        offlineDurationText = '${offlineDuration.inHours} giờ $mins phút';
      } else {
        offlineDurationText = '${offlineDuration.inMinutes.clamp(1, 60)} phút';
      }
    } else if (patient.dangNhapCuoi != null) {
      final diff = now.difference(patient.dangNhapCuoi!);
      if (diff.inDays > 0) {
        offlineDurationText = '${diff.inDays} ngày trước';
      } else if (diff.inHours > 0) {
        offlineDurationText = '${diff.inHours} giờ trước';
      } else {
        offlineDurationText = 'Vừa online';
      }
    }

    // Tần suất hoạt động: số lịch hẹn / tháng & / tuần
    final totalAppointments = appointments.length;
    final freqPerMonth = totalDaysJoined >= 30
        ? (totalAppointments / (totalDaysJoined / 30.0))
        : (totalAppointments * (30.0 / totalDaysJoined));
    final freqPerWeek = totalDaysJoined >= 7
        ? (totalAppointments / (totalDaysJoined / 7.0))
        : (totalAppointments * (7.0 / totalDaysJoined));

    // Lọc lịch hoàn thành / hủy
    int completedCount = 0;
    int cancelledCount = 0;
    for (final app in appointments) {
      final status = (app['trang_thai'] ?? app['status'] ?? '').toString().toLowerCase();
      if (status.contains('huy') || status.contains('cancel')) {
        cancelledCount++;
      } else if (status.contains('kham') || status.contains('xong') || status.contains('complete')) {
        completedCount++;
      }
    }

    // --- BIỂU ĐỒ THEO NGÀY (7 ngày gần nhất) ---
    final List<Map<String, dynamic>> dailyChart = [];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      int count = 0;
      for (final app in appointments) {
        DateTime? appDate;
        if (app['ngay_kham'] is Timestamp) {
          appDate = (app['ngay_kham'] as Timestamp).toDate();
        } else if (app['ngay_tao'] is Timestamp) {
          appDate = (app['ngay_tao'] as Timestamp).toDate();
        } else if (app['ngay_kham'] != null) {
          try {
            appDate = DateTime.parse(app['ngay_kham'].toString());
          } catch (_) {}
        }
        if (appDate != null &&
            appDate.year == day.year &&
            appDate.month == day.month &&
            appDate.day == day.day) {
          count++;
        }
      }
      dailyChart.add({
        'label': '${day.day}/${day.month}',
        'count': count,
        'date': day,
      });
    }

    // --- BIỂU ĐỒ THEO THÁNG (12 tháng qua) ---
    final List<Map<String, dynamic>> monthlyChart = [];
    for (int i = 11; i >= 0; i--) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      int count = 0;
      for (final app in appointments) {
        DateTime? appDate;
        if (app['ngay_kham'] is Timestamp) {
          appDate = (app['ngay_kham'] as Timestamp).toDate();
        } else if (app['ngay_tao'] is Timestamp) {
          appDate = (app['ngay_tao'] as Timestamp).toDate();
        } else if (app['ngay_kham'] != null) {
          try {
            appDate = DateTime.parse(app['ngay_kham'].toString());
          } catch (_) {}
        }
        if (appDate != null &&
            appDate.year == targetMonth.year &&
            appDate.month == targetMonth.month) {
          count++;
        }
      }
      monthlyChart.add({
        'label': 'T${targetMonth.month}',
        'count': count,
        'year': targetMonth.year,
      });
    }

    // --- BIỂU ĐỒ THEO NĂM (Các năm từ khi tham gia đến nay) ---
    final List<Map<String, dynamic>> yearlyChart = [];
    final startYear = (patient.ngayTao?.year ?? now.year).clamp(2022, now.year);
    for (int y = startYear; y <= now.year; y++) {
      int count = 0;
      for (final app in appointments) {
        DateTime? appDate;
        if (app['ngay_kham'] is Timestamp) {
          appDate = (app['ngay_kham'] as Timestamp).toDate();
        } else if (app['ngay_tao'] is Timestamp) {
          appDate = (app['ngay_tao'] as Timestamp).toDate();
        } else if (app['ngay_kham'] != null) {
          try {
            appDate = DateTime.parse(app['ngay_kham'].toString());
          } catch (_) {}
        }
        if (appDate != null && appDate.year == y) {
          count++;
        }
      }
      yearlyChart.add({
        'label': '$y',
        'count': count,
      });
    }

    return {
      'totalAppointments': totalAppointments,
      'completedCount': completedCount,
      'cancelledCount': cancelledCount,
      'totalDaysJoined': totalDaysJoined,
      'offlineDurationText': offlineDurationText,
      'offlineStart': offlineStart,
      'freqPerMonth': freqPerMonth.toStringAsFixed(1),
      'freqPerWeek': freqPerWeek.toStringAsFixed(1),
      'dailyChart': dailyChart,
      'monthlyChart': monthlyChart,
      'yearlyChart': yearlyChart,
    };
  }

  /// THỐNG KÊ TẦN SUẤT HOẠT ĐỘNG CHUNG CỦA TẤT CẢ TÀI KHOẢN BỆNH NHÂN TRÊN HỆ THỐNG
  Future<Map<String, dynamic>> getGlobalActivityStats() async {
    List<Map<String, dynamic>> allAppointments = [];
    try {
      final snap = await _firestore.collection('LichHen').get();
      allAppointments = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('Lỗi tải lịch hẹn toàn hệ thống: $e');
    }

    final now = DateTime.now();
    final totalPatientsCount = patients.length;
    final activePatientsCount = patients.where((p) => p.isActive).length;
    final blockedPatientsCount = totalPatientsCount - activePatientsCount;

    int completedCount = 0;
    int cancelledCount = 0;
    for (final app in allAppointments) {
      final status = (app['trang_thai'] ?? app['status'] ?? '').toString().toLowerCase();
      if (status.contains('huy') || status.contains('cancel')) {
        cancelledCount++;
      } else if (status.contains('kham') || status.contains('xong') || status.contains('complete')) {
        completedCount++;
      }
    }

    // --- BIỂU ĐỒ HOẠT ĐỘNG CHUNG THEO NGÀY (7 ngày gần nhất) ---
    final List<Map<String, dynamic>> dailyChart = [];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      int count = 0;
      for (final app in allAppointments) {
        DateTime? appDate;
        if (app['ngay_kham'] is Timestamp) {
          appDate = (app['ngay_kham'] as Timestamp).toDate();
        } else if (app['ngay_tao'] is Timestamp) {
          appDate = (app['ngay_tao'] as Timestamp).toDate();
        } else if (app['ngay_kham'] != null) {
          try {
            appDate = DateTime.parse(app['ngay_kham'].toString());
          } catch (_) {}
        }
        if (appDate != null &&
            appDate.year == day.year &&
            appDate.month == day.month &&
            appDate.day == day.day) {
          count++;
        }
      }
      dailyChart.add({
        'label': '${day.day}/${day.month}',
        'count': count,
        'date': day,
      });
    }

    // --- BIỂU ĐỒ HOẠT ĐỘNG CHUNG THEO THÁNG (12 tháng qua) ---
    final List<Map<String, dynamic>> monthlyChart = [];
    for (int i = 11; i >= 0; i--) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      int count = 0;
      for (final app in allAppointments) {
        DateTime? appDate;
        if (app['ngay_kham'] is Timestamp) {
          appDate = (app['ngay_kham'] as Timestamp).toDate();
        } else if (app['ngay_tao'] is Timestamp) {
          appDate = (app['ngay_tao'] as Timestamp).toDate();
        } else if (app['ngay_kham'] != null) {
          try {
            appDate = DateTime.parse(app['ngay_kham'].toString());
          } catch (_) {}
        }
        if (appDate != null &&
            appDate.year == targetMonth.year &&
            appDate.month == targetMonth.month) {
          count++;
        }
      }
      monthlyChart.add({
        'label': 'T${targetMonth.month}',
        'count': count,
        'year': targetMonth.year,
      });
    }

    // --- BIỂU ĐỒ HOẠT ĐỘNG CHUNG THEO NĂM (từ 3 năm trước đến nay) ---
    final List<Map<String, dynamic>> yearlyChart = [];
    final currentYear = now.year;
    for (int y = currentYear - 3; y <= currentYear; y++) {
      int count = 0;
      for (final app in allAppointments) {
        DateTime? appDate;
        if (app['ngay_kham'] is Timestamp) {
          appDate = (app['ngay_kham'] as Timestamp).toDate();
        } else if (app['ngay_tao'] is Timestamp) {
          appDate = (app['ngay_tao'] as Timestamp).toDate();
        } else if (app['ngay_kham'] != null) {
          try {
            appDate = DateTime.parse(app['ngay_kham'].toString());
          } catch (_) {}
        }
        if (appDate != null && appDate.year == y) {
          count++;
        }
      }
      yearlyChart.add({
        'label': '$y',
        'count': count,
      });
    }

    final totalAppointments = allAppointments.length;
    final totalDailyCount = dailyChart.map((e) => e['count'] as int).fold(0, (a, b) => a + b);
    final totalMonthlyCount = monthlyChart.map((e) => e['count'] as int).fold(0, (a, b) => a + b);

    final avgPerDay = (totalDailyCount / 7.0).toStringAsFixed(1);
    final avgPerMonth = (totalMonthlyCount / 12.0).toStringAsFixed(1);
    final activePercent = totalPatientsCount > 0
        ? ((activePatientsCount / totalPatientsCount) * 100).toStringAsFixed(0)
        : '0';

    return {
      'totalAppointments': totalAppointments,
      'completedCount': completedCount,
      'cancelledCount': cancelledCount,
      'totalPatientsCount': totalPatientsCount,
      'activePatientsCount': activePatientsCount,
      'blockedPatientsCount': blockedPatientsCount,
      'activePercent': activePercent,
      'avgPerDay': avgPerDay,
      'avgPerMonth': avgPerMonth,
      'dailyChart': dailyChart,
      'monthlyChart': monthlyChart,
      'yearlyChart': yearlyChart,
    };
  }

  @override
  void dispose() {
    _hospitalsSub?.cancel();
    _pendingSub?.cancel();
    _reportsSub?.cancel();
    _patientsSub?.cancel();
    super.dispose();
  }
}
