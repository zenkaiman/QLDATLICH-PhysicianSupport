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
        final rating = (data['diem_danh_gia_tb'] as num?)?.toDouble() ?? 4.5;
        final address = data['dia_chi']?.toString() ?? 'Đang cập nhật địa chỉ';
        final statusId = data['trang_thai_hop_tac_id'] as int?;
        final trangThaiStr = data['trang_thai']?.toString().toLowerCase();
        final trangThaiUpper = data['trangThai']?.toString().toUpperCase();
        final daDuyetBool = data['da_duyet'] == true;

        final bool isHuyHopTac = statusId == 9 ||
            trangThaiStr == 'huy_hop_tac' ||
            trangThaiUpper == 'HUY_HOP_TAC' ||
            data['is_unpartnered'] == true;

        final bool isRejected = statusId == 4 ||
            trangThaiStr == 'tu_choi' ||
            trangThaiUpper == 'TU_CHOI';

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

        final bool chanDangNhap = data['chan_dang_nhap'] == true ||
            data['is_blocked'] == true ||
            (statusId == 8 || statusId == 11) &&
                (trangThaiStr == 'chan_dang_nhap' || trangThaiStr == 'khoa');
        final String? blockReason = data['ly_do_khoa']?.toString() ??
            data['ly_do_huy']?.toString() ??
            data['ly_do_chan']?.toString();

        if (isApproved && !isHuyHopTac && !isRejected) {
          final depts = (data['ten_cac_khoa'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final doctorCount =
              depts != null && depts.isNotEmpty ? (depts.length * 8) : 35;
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
          final depts = (data['ten_cac_khoa'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final doctorCount =
              depts != null && depts.isNotEmpty ? (depts.length * 8) : 35;
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
            status: 9,
            isBlocked: true,
            isUnpartnered: true,
            blockReason: blockReason ?? 'Đã ngừng hợp tác',
          );
          cancelledList.add(hospital);
        } else if (!chanDangNhap && !isHuyHopTac && !isRejected && statusId != 9) {
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
            'ma_co_so_byt': data['ma_co_so_byt']?.toString() ?? data['ma_byt']?.toString() ?? '',
            'co_so': data['co_so']?.toString() ?? '',
            'loai_hinh': data['loai_hinh']?.toString() ?? type,
            'dia_chi_map': data['dia_chi_map']?.toString() ?? '',
            'vi_do': data['vi_do']?.toString() ?? '',
            'kinh_do': data['kinh_do']?.toString() ?? '',
            'email': data['email']?.toString() ?? '',
            'phone': data['so_dien_thoai']?.toString() ?? '',
            'mo_ta': data['mo_ta']?.toString() ?? '',
            'bhyt': data['bhyt']?.toString() ?? (data['co_bhyt'] == true ? 'Có BHYT (Tiếp nhận KCB BHYT)' : ''),
            'co_bhyt': (data['co_bhyt'] == true).toString(),
            'nguoi_dai_dien': data['nguoi_dai_dien']?.toString() ?? '',
            'cccd_mat_truoc_base64': data['cccd_mat_truoc_base64']?.toString() ?? data['cccd_truoc_base64']?.toString() ?? '',
            'cccd_mat_truoc_url': data['cccd_mat_truoc_url']?.toString() ?? '',
            'cccd_mat_truoc_ten': data['cccd_mat_truoc_ten']?.toString() ?? '',
            'cccd_mat_sau_base64': data['cccd_mat_sau_base64']?.toString() ?? data['cccd_sau_base64']?.toString() ?? '',
            'cccd_mat_sau_url': data['cccd_mat_sau_url']?.toString() ?? '',
            'cccd_mat_sau_ten': data['cccd_mat_sau_ten']?.toString() ?? '',
            'has_cccd': (data['has_cccd'] == true || (data['cccd_mat_truoc_base64'] != null && data['cccd_mat_truoc_base64'].toString().isNotEmpty)).toString(),
            'file_giay_phep': data['file_giay_phep']?.toString() ?? '',
            'file_giay_phep_url': data['file_giay_phep_url']?.toString() ?? fileDoc,
            'dung_luong_file': data['dung_luong_file']?.toString() ?? '',
            'loai_file': data['loai_file']?.toString() ?? '',
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
          final location = data['dia_chi']?.toString() ?? 'Chưa cập nhật địa chỉ';
          final cccdTruoc = data['cccd_mat_truoc_base64']?.toString() ?? data['cccd_truoc_base64']?.toString() ?? '';
          final cccdSau = data['cccd_mat_sau_base64']?.toString() ?? data['cccd_sau_base64']?.toString() ?? '';
          final cccdTruocUrl = data['cccd_mat_truoc_url']?.toString() ?? '';
          final cccdSauUrl = data['cccd_mat_sau_url']?.toString() ?? '';

          if (pendingMap.containsKey(doc.id)) {
            final existing = pendingMap[doc.id]!;
            if (docFile.isNotEmpty) {
              existing['docs'] = docFile;
              existing['file_url'] = docFile;
              existing['file_giay_phep_url'] = docFile;
            }
            existing['time'] = 'Gửi: $timeStr';
            if (data['so_giay_phep'] != null) existing['so_giay_phep'] = data['so_giay_phep'].toString();
            if (data['ma_so_thue'] != null) existing['ma_so_thue'] = data['ma_so_thue'].toString();
            if (data['ma_co_so_byt'] != null) existing['ma_co_so_byt'] = data['ma_co_so_byt'].toString();
            if (data['co_so'] != null) existing['co_so'] = data['co_so'].toString();
            if (data['loai_hinh'] != null) existing['loai_hinh'] = data['loai_hinh'].toString();
            if (data['dia_chi_map'] != null) existing['dia_chi_map'] = data['dia_chi_map'].toString();
            if (data['vi_do'] != null) existing['vi_do'] = data['vi_do'].toString();
            if (data['kinh_do'] != null) existing['kinh_do'] = data['kinh_do'].toString();
            if (data['email'] != null && existing['email']!.isEmpty) existing['email'] = data['email'].toString();
            if (data['so_dien_thoai'] != null && existing['phone']!.isEmpty) existing['phone'] = data['so_dien_thoai'].toString();
            if (data['mo_ta'] != null && existing['mo_ta']!.isEmpty) existing['mo_ta'] = data['mo_ta'].toString();
            if (data['nguoi_dai_dien'] != null && existing['nguoi_dai_dien']!.isEmpty) existing['nguoi_dai_dien'] = data['nguoi_dai_dien'].toString();
            if (data['co_bhyt'] != null && existing['bhyt']!.isEmpty) existing['bhyt'] = data['co_bhyt'] == true ? 'Có BHYT (Tiếp nhận KCB BHYT)' : 'Không hỗ trợ BHYT';
            if (cccdTruoc.isNotEmpty) existing['cccd_mat_truoc_base64'] = cccdTruoc;
            if (cccdSau.isNotEmpty) existing['cccd_mat_sau_base64'] = cccdSau;
            if (cccdTruocUrl.isNotEmpty) existing['cccd_mat_truoc_url'] = cccdTruocUrl;
            if (cccdSauUrl.isNotEmpty) existing['cccd_mat_sau_url'] = cccdSauUrl;
            if (data['dung_luong_file'] != null) existing['dung_luong_file'] = data['dung_luong_file'].toString();
            if (data['loai_file'] != null) existing['loai_file'] = data['loai_file'].toString();
            if (data['file_giay_phep'] != null) existing['file_giay_phep'] = data['file_giay_phep'].toString();
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
              'ma_co_so_byt': data['ma_co_so_byt']?.toString() ?? data['ma_byt']?.toString() ?? '',
              'co_so': data['co_so']?.toString() ?? '',
              'loai_hinh': data['loai_hinh']?.toString() ?? type,
              'dia_chi_map': data['dia_chi_map']?.toString() ?? '',
              'vi_do': data['vi_do']?.toString() ?? '',
              'kinh_do': data['kinh_do']?.toString() ?? '',
              'email': data['email']?.toString() ?? '',
              'phone': data['so_dien_thoai']?.toString() ?? '',
              'mo_ta': data['mo_ta']?.toString() ?? data['ghi_chu']?.toString() ?? '',
              'bhyt': data['bhyt']?.toString() ?? (data['co_bhyt'] == true ? 'Có BHYT (Tiếp nhận KCB BHYT)' : (data['co_bhyt'] == false ? 'Không hỗ trợ BHYT' : '')),
              'co_bhyt': (data['co_bhyt'] == true).toString(),
              'nguoi_dai_dien': data['nguoi_dai_dien']?.toString() ?? '',
              'cccd_mat_truoc_base64': cccdTruoc,
              'cccd_mat_truoc_url': cccdTruocUrl,
              'cccd_mat_truoc_ten': data['cccd_mat_truoc_ten']?.toString() ?? '',
              'cccd_mat_sau_base64': cccdSau,
              'cccd_mat_sau_url': cccdSauUrl,
              'cccd_mat_sau_ten': data['cccd_mat_sau_ten']?.toString() ?? '',
              'has_cccd': (data['has_cccd'] == true || cccdTruoc.isNotEmpty || cccdTruocUrl.isNotEmpty).toString(),
              'file_giay_phep': data['file_giay_phep']?.toString() ?? '',
              'file_giay_phep_url': docFile,
              'dung_luong_file': data['dung_luong_file']?.toString() ?? '',
              'loai_file': data['loai_file']?.toString() ?? '',
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
      final defaultBadge = kind == 'qr' ? 'Lỗi QR Check-in' : 'Lỗi Đặt Lịch';
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

    try {
      final Map<String, dynamic> bvData = {
        'ten_benh_vien': h['name'],
        'co_so': (h['co_so'] != null && h['co_so']!.isNotEmpty) ? h['co_so'] : (h['type'] ?? 'Tư nhân'),
        'loai_hinh': (h['loai_hinh'] != null && h['loai_hinh']!.isNotEmpty) ? h['loai_hinh'] : (h['type'] ?? 'Bệnh viện Tư nhân'),
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
      };

      if (h['ma_co_so_byt'] != null && h['ma_co_so_byt']!.isNotEmpty) {
        bvData['ma_co_so_byt'] = h['ma_co_so_byt'];
      }
      if (h['ma_so_thue'] != null && h['ma_so_thue']!.isNotEmpty) {
        bvData['ma_so_thue'] = h['ma_so_thue'];
      }
      if (h['so_giay_phep'] != null && h['so_giay_phep']!.isNotEmpty) {
        bvData['so_giay_phep'] = h['so_giay_phep'];
      }
      if (h['dia_chi_map'] != null && h['dia_chi_map']!.isNotEmpty) {
        bvData['dia_chi_map'] = h['dia_chi_map'];
      }
      if (h['vi_do'] != null && h['vi_do']!.isNotEmpty) {
        bvData['vi_do'] = double.tryParse(h['vi_do']!) ?? h['vi_do'];
      }
      if (h['kinh_do'] != null && h['kinh_do']!.isNotEmpty) {
        bvData['kinh_do'] = double.tryParse(h['kinh_do']!) ?? h['kinh_do'];
      }
      if (h['bhyt'] != null && h['bhyt']!.isNotEmpty) {
        bvData['bhyt'] = h['bhyt'];
        bvData['co_bhyt'] = h['co_bhyt'] == 'true' || h['bhyt']!.toLowerCase().contains('có');
      }
      if (h['cccd_mat_truoc_base64'] != null && h['cccd_mat_truoc_base64']!.isNotEmpty) {
        bvData['cccd_mat_truoc_base64'] = h['cccd_mat_truoc_base64'];
      }
      if (h['cccd_mat_truoc_url'] != null && h['cccd_mat_truoc_url']!.isNotEmpty) {
        bvData['cccd_mat_truoc_url'] = h['cccd_mat_truoc_url'];
      }
      if (h['cccd_mat_truoc_ten'] != null && h['cccd_mat_truoc_ten']!.isNotEmpty) {
        bvData['cccd_mat_truoc_ten'] = h['cccd_mat_truoc_ten'];
      }
      if (h['cccd_mat_sau_base64'] != null && h['cccd_mat_sau_base64']!.isNotEmpty) {
        bvData['cccd_mat_sau_base64'] = h['cccd_mat_sau_base64'];
      }
      if (h['cccd_mat_sau_url'] != null && h['cccd_mat_sau_url']!.isNotEmpty) {
        bvData['cccd_mat_sau_url'] = h['cccd_mat_sau_url'];
      }
      if (h['cccd_mat_sau_ten'] != null && h['cccd_mat_sau_ten']!.isNotEmpty) {
        bvData['cccd_mat_sau_ten'] = h['cccd_mat_sau_ten'];
      }
      bvData['has_cccd'] = h['has_cccd'] == 'true' ||
          (h['cccd_mat_truoc_base64'] != null && h['cccd_mat_truoc_base64']!.isNotEmpty) ||
          (h['cccd_mat_truoc_url'] != null && h['cccd_mat_truoc_url']!.isNotEmpty);
      if (h['file_giay_phep'] != null && h['file_giay_phep']!.isNotEmpty) {
        bvData['file_giay_phep'] = h['file_giay_phep'];
      }
      if (h['file_giay_phep_url'] != null && h['file_giay_phep_url']!.isNotEmpty) {
        bvData['file_giay_phep_url'] = h['file_giay_phep_url'];
      }
      if (h['dung_luong_file'] != null && h['dung_luong_file']!.isNotEmpty) {
        bvData['dung_luong_file'] = h['dung_luong_file'];
      }
      if (h['loai_file'] != null && h['loai_file']!.isNotEmpty) {
        bvData['loai_file'] = h['loai_file'];
      }
      if (h['email'] != null && h['email']!.isNotEmpty) {
        bvData['email'] = h['email'];
      }
      if (h['phone'] != null && h['phone']!.isNotEmpty) {
        bvData['so_dien_thoai'] = h['phone'];
      }
      if (h['nguoi_dai_dien'] != null && h['nguoi_dai_dien']!.isNotEmpty) {
        bvData['nguoi_dai_dien'] = h['nguoi_dai_dien'];
      }
      if (h['mo_ta'] != null && h['mo_ta']!.isNotEmpty) {
        bvData['mo_ta'] = h['mo_ta'];
      }

      await _firestore.collection('BenhVien').doc(docId).set(bvData, SetOptions(merge: true));

      try {
        final ycDoc = await _firestore.collection('YeuCauHopTac').doc(docId).get();
        if (ycDoc.exists) {
          final Map<String, dynamic> ycData = {
            'trang_thai_hop_tac_id': 10,
            'trang_thai': 'da_duyet',
            'trangThai': 'DA_DUYET',
            'da_duyet': true,
            'ngay_duyet': FieldValue.serverTimestamp(),
          };
          await _firestore.collection('YeuCauHopTac').doc(docId).set(ycData, SetOptions(merge: true));
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
    h.status = 1;
    hospitals.remove(h);
    if (!cancelledHospitals.contains(h)) {
      cancelledHospitals.insert(0, h);
    }
    violations.removeWhere((v) => v['code'] == h.code || v['name'] == h.name);
    notifyListeners();

    try {
      final code = h.code;
      if (code != null && code.isNotEmpty) {
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

        await _syncHospitalAndStaffStatusInNhanVien(
          code: code,
          maBenhVien: h.code,
          hospitalName: h.name,
          isBlocked: true,
          reason: reason,
        );

        try {
          await FirebaseAdminAuthService.instance.disableAndRevokeUser(
            uid: code,
            email: h.email,
          );
        } catch (e) {
          debugPrint('Lỗi vô hiệu hóa Firebase Auth cho bệnh viện: $e');
        }

        await _firestore.collection('ThongBaoHeThong').add({
          'tieu_de': 'Hủy hợp tác bệnh viện',
          'noi_dung': 'Quản trị viên đã hủy thỏa thuận hợp tác với bệnh viện: ${h.name} ($code). Lý do: $reason',
          'loai': 'huy_hop_tac_bv',
          'benh_vien_id': code,
          'da_doc': false,
          'thoi_gian_hien_thi': 'Vừa xong',
          'ngay_tao': FieldValue.serverTimestamp(),
        });

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
    h.status = 10;
    cancelledHospitals.remove(h);
    if (!hospitals.contains(h)) {
      hospitals.insert(0, h);
    }
    notifyListeners();

    try {
      final code = h.code;
      if (code != null && code.isNotEmpty) {
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

        await _syncHospitalAndStaffStatusInNhanVien(
          code: code,
          maBenhVien: h.code,
          hospitalName: h.name,
          isBlocked: false,
        );

        try {
          await FirebaseAdminAuthService.instance.enableUser(
            uid: code,
            email: h.email,
          );
        } catch (e) {
          debugPrint('Lỗi mở khóa Firebase Auth cho bệnh viện: $e');
        }

        await _firestore.collection('ThongBaoHeThong').add({
          'tieu_de': 'Khôi phục hợp tác bệnh viện',
          'noi_dung': 'Quản trị viên đã khôi phục hợp tác với bệnh viện: ${h.name} ($code)',
          'loai': 'khoi_phuc_hop_tac_bv',
          'benh_vien_id': code,
          'da_doc': false,
          'thoi_gian_hien_thi': 'Vừa xong',
          'ngay_tao': FieldValue.serverTimestamp(),
        });

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

  /// ĐỒNG BỘ KHÓA HOẶC MỞ KHÓA TẤT CẢ TÀI KHOẢN NHÂN VIÊN TRONG 'NhanVien'
  Future<void> _syncHospitalAndStaffStatusInNhanVien({
    required String code,
    String? maBenhVien,
    String? hospitalName,
    required bool isBlocked,
    String? reason,
  }) async {
    final Set<String> targetDocIds = {};
    if (code.isNotEmpty) targetDocIds.add(code);
    if (maBenhVien != null && maBenhVien.isNotEmpty) targetDocIds.add(maBenhVien);

    try {
      for (final id in targetDocIds.toList()) {
        try {
          final nvDoc = await _firestore.collection('NhanVien').doc(id).get();
          if (nvDoc.exists) {
            targetDocIds.add(nvDoc.id);
            final mbv = nvDoc.data()?['ma_benh_vien']?.toString();
            if (mbv != null && mbv.isNotEmpty) targetDocIds.add(mbv);
          }
        } catch (_) {}
      }

      for (final key in targetDocIds.toList()) {
        try {
          final q1 = await _firestore.collection('NhanVien').where('ma_benh_vien', isEqualTo: key).get();
          for (final d in q1.docs) targetDocIds.add(d.id);
        } catch (_) {}
        try {
          final q2 = await _firestore.collection('NhanVien').where('benh_vien_id', isEqualTo: key).get();
          for (final d in q2.docs) targetDocIds.add(d.id);
        } catch (_) {}
        try {
          final q3 = await _firestore.collection('NhanVien').where('id_benh_vien', isEqualTo: key).get();
          for (final d in q3.docs) targetDocIds.add(d.id);
        } catch (_) {}
      }

      if (hospitalName != null && hospitalName.isNotEmpty) {
        try {
          final qName = await _firestore.collection('NhanVien').where('ten_benh_vien', isEqualTo: hospitalName).get();
          for (final d in qName.docs) targetDocIds.add(d.id);
        } catch (_) {}
      }

      for (final nvDocId in targetDocIds) {
        try {
          final nvDocRef = _firestore.collection('NhanVien').doc(nvDocId);

          await nvDocRef.set({
            'trangThaiHoatDong': !isBlocked,
            'chan_dang_nhap': isBlocked,
            'is_blocked': isBlocked,
            'trang_thai_hop_tac_id': isBlocked ? 9 : 10,
            if (isBlocked && reason != null) 'ly_do_huy': reason,
            if (!isBlocked) 'ly_do_huy': FieldValue.delete(),
          }, SetOptions(merge: true));

          final danhSachSnap = await nvDocRef.collection('danh_sach').get();
          for (final staffDoc in danhSachSnap.docs) {
            final sData = staffDoc.data();
            final sUid = sData['uid']?.toString() ?? sData['auth_uid']?.toString();
            final sEmail = sData['email']?.toString();

            await staffDoc.reference.update({
              'chan_dang_nhap': isBlocked,
              'trangThaiHoatDong': !isBlocked,
              'da_kich_hoat': !isBlocked,
              'trang_thai': isBlocked ? 'tam_khoa' : 'dang_hoat_dong',
              if (isBlocked && reason != null) 'ly_do_khoa': reason,
            });

            if (sUid != null || sEmail != null) {
              if (isBlocked) {
                await FirebaseAdminAuthService.instance.disableAndRevokeUser(
                  uid: sUid ?? '',
                  email: sEmail,
                );
              } else {
                await FirebaseAdminAuthService.instance.enableUser(
                  uid: sUid ?? '',
                  email: sEmail,
                );
              }
            }
          }
        } catch (e) {
          debugPrint('❌ [NhanVien Sync] Lỗi cập nhật NhanVien/$nvDocId: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ [NhanVien Sync] Lỗi: $e');
    }
  }

  /// XÓA HOÀN TOÀN BỆNH VIỆN VÀ TOÀN BỘ TÀI KHOẢN NHÂN VIÊN TRONG 'NhanVien'
  Future<void> _deleteHospitalAndStaffInNhanVien({
    required String code,
    String? maBenhVien,
    String? hospitalName,
    String? authUid,
  }) async {
    final Set<String> targetDocIds = {};
    if (code.isNotEmpty) targetDocIds.add(code);
    if (maBenhVien != null && maBenhVien.isNotEmpty) targetDocIds.add(maBenhVien);
    if (authUid != null && authUid.isNotEmpty) targetDocIds.add(authUid);

    try {
      for (final id in targetDocIds.toList()) {
        try {
          final nvDoc = await _firestore.collection('NhanVien').doc(id).get();
          if (nvDoc.exists) {
            targetDocIds.add(nvDoc.id);
            final data = nvDoc.data();
            final mbv = data?['ma_benh_vien']?.toString();
            if (mbv != null && mbv.isNotEmpty) targetDocIds.add(mbv);
          }
        } catch (_) {}
      }

      for (final key in targetDocIds.toList()) {
        try {
          final q1 = await _firestore.collection('NhanVien').where('ma_benh_vien', isEqualTo: key).get();
          for (final d in q1.docs) targetDocIds.add(d.id);
        } catch (_) {}
        try {
          final q2 = await _firestore.collection('NhanVien').where('benh_vien_id', isEqualTo: key).get();
          for (final d in q2.docs) targetDocIds.add(d.id);
        } catch (_) {}
        try {
          final q3 = await _firestore.collection('NhanVien').where('id_benh_vien', isEqualTo: key).get();
          for (final d in q3.docs) targetDocIds.add(d.id);
        } catch (_) {}
      }

      if (hospitalName != null && hospitalName.isNotEmpty) {
        try {
          final qName = await _firestore.collection('NhanVien').where('ten_benh_vien', isEqualTo: hospitalName).get();
          for (final d in qName.docs) targetDocIds.add(d.id);
        } catch (_) {}
      }

      debugPrint('🏥 [NhanVien Cleanup] Danh sách bệnh viện trong NhanVien cần xóa: $targetDocIds');

      for (final nvDocId in targetDocIds) {
        try {
          final nvDocRef = _firestore.collection('NhanVien').doc(nvDocId);

          final danhSachSnap = await nvDocRef.collection('danh_sach').get();
          debugPrint('👨‍⚕️ [NhanVien Cleanup] Tìm thấy ${danhSachSnap.docs.length} nhân viên trong NhanVien/$nvDocId/danh_sach');

          for (final staffDoc in danhSachSnap.docs) {
            final sData = staffDoc.data();
            final sUid = sData['uid']?.toString() ?? sData['auth_uid']?.toString();
            final sEmail = sData['email']?.toString();

            if (sUid != null || sEmail != null) {
              try {
                await FirebaseAdminAuthService.instance.deleteUser(
                  uid: sUid ?? '',
                  email: sEmail,
                );
                debugPrint('✅ [NhanVien Cleanup] Đã xóa Auth nhân viên: $sUid ($sEmail)');
              } catch (e) {
                debugPrint('❌ [NhanVien Cleanup] Lỗi xóa Auth nhân viên: $e');
              }
            }
            await staffDoc.reference.delete();
          }

          await nvDocRef.delete();
          debugPrint('✅ [NhanVien Cleanup] Đã xóa hoàn toàn document NhanVien/$nvDocId');
        } catch (e) {
          debugPrint('❌ [NhanVien Cleanup] Lỗi khi xử lý NhanVien/$nvDocId: $e');
        }
      }

      for (final key in targetDocIds) {
        try {
          final group1 = await _firestore.collectionGroup('danh_sach').where('ma_benh_vien', isEqualTo: key).get();
          for (final d in group1.docs) {
            final sData = d.data();
            final sUid = sData['uid']?.toString() ?? sData['auth_uid']?.toString();
            final sEmail = sData['email']?.toString();
            if (sUid != null || sEmail != null) {
              try { await FirebaseAdminAuthService.instance.deleteUser(uid: sUid ?? '', email: sEmail); } catch (_) {}
            }
            await d.reference.delete();
          }
        } catch (_) {}

        try {
          final group2 = await _firestore.collectionGroup('danh_sach').where('benh_vien_id', isEqualTo: key).get();
          for (final d in group2.docs) {
            final sData = d.data();
            final sUid = sData['uid']?.toString() ?? sData['auth_uid']?.toString();
            final sEmail = sData['email']?.toString();
            if (sUid != null || sEmail != null) {
              try { await FirebaseAdminAuthService.instance.deleteUser(uid: sUid ?? '', email: sEmail); } catch (_) {}
            }
            await d.reference.delete();
          }
        } catch (_) {}
      }

      for (final key in targetDocIds) {
        try {
          final qStaff = await _firestore.collection('NhanVien').where('ma_benh_vien', isEqualTo: key).get();
          for (final doc in qStaff.docs) {
            final sData = doc.data();
            final sUid = sData['uid']?.toString() ?? sData['auth_uid']?.toString();
            final sEmail = sData['email']?.toString();
            if (sUid != null || sEmail != null) {
              try { await FirebaseAdminAuthService.instance.deleteUser(uid: sUid ?? '', email: sEmail); } catch (_) {}
            }
            await doc.reference.delete();
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ [NhanVien Cleanup] Lỗi dọn dẹp NhanVien: $e');
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
        String? maBenhVien = code;

        try {
          final bvSnap = await _firestore.collection('BenhVien').doc(code).get();
          if (bvSnap.exists) {
            final data = bvSnap.data();
            if (data != null) {
              maBenhVien = data['ma_benh_vien']?.toString() ??
                  data['code']?.toString() ??
                  data['id']?.toString() ??
                  maBenhVien;
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

        if (finalEmail == null || finalEmail.isEmpty) {
          try {
            final ycSnap = await _firestore.collection('YeuCauHopTac').doc(code).get();
            if (ycSnap.exists) {
              finalEmail = ycSnap.data()?['email']?.toString();
              final mbv = ycSnap.data()?['ma_benh_vien']?.toString();
              if (mbv != null && mbv.isNotEmpty) maBenhVien = mbv;
            }
          } catch (_) {}
        }

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

        await _deleteHospitalAndStaffInNhanVien(
          code: code,
          maBenhVien: maBenhVien,
          hospitalName: name,
          authUid: targetAuthUid,
        );

        await _firestore.collection('BenhVien').doc(code).delete();
        if (maBenhVien != null && maBenhVien != code) {
          try { await _firestore.collection('BenhVien').doc(maBenhVien).delete(); } catch (_) {}
        }

        try { await _firestore.collection('YeuCauHopTac').doc(code).delete(); } catch (_) {}
        if (maBenhVien != null && maBenhVien != code) {
          try { await _firestore.collection('YeuCauHopTac').doc(maBenhVien).delete(); } catch (_) {}
        }

        final relatedCollections = ['PhongKham', 'Khoa', 'PhanCong'];
        for (final colName in relatedCollections) {
          for (final key in {code, maBenhVien, targetAuthUid}.whereType<String>().where((s) => s.isNotEmpty)) {
            try {
              final snap1 = await _firestore.collection(colName).where('benh_vien_id', isEqualTo: key).get();
              for (final d in snap1.docs) await d.reference.delete();
            } catch (_) {}
            try {
              final snap2 = await _firestore.collection(colName).where('ma_benh_vien', isEqualTo: key).get();
              for (final d in snap2.docs) await d.reference.delete();
            } catch (_) {}
            try {
              final snap3 = await _firestore.collection(colName).where('id_benh_vien', isEqualTo: key).get();
              for (final d in snap3.docs) await d.reference.delete();
            } catch (_) {}
          }
        }

        try {
          await _firestore.collection('ThongBaoHeThong').add({
            'tieu_de': 'Đã xóa vĩnh viễn bệnh viện và nhân viên',
            'noi_dung': 'Quản trị viên đã xóa hoàn toàn hồ sơ và tài khoản bệnh viện cùng toàn bộ nhân viên: $name ($code)',
            'loai': 'xoa_tai_khoan_bv',
            'da_doc': false,
            'thoi_gian_hien_thi': 'Vừa xong',
            'ngay_tao': FieldValue.serverTimestamp(),
          });
        } catch (_) {}

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
  void updateHospital(Hospital h, {String? name, String? type, String? address, int? doctors}) async {
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
    resolveReportAndNotify(report, 'Quản trị viên đã tiếp nhận và giải quyết thành công sự cố này.');
  }

  /// XỬ LÝ SỰ CỐ VÀ GỬI THÔNG BÁO CHO NGƯỜI GỬI
  Future<void> resolveReportAndNotify(ErrorReport report, String responseMessage) async {
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
      await _firestore.collection('BaoCaoLoi').doc(report.id).update({
        'trang_thai_xu_ly': 'DA_GIAI_QUYET',
        'trang_thai': 'da_giai_quyet',
        'trangThai': 'DA_GIAI_QUYET',
        'da_doc': true,
        'phan_hoi_admin': responseMessage,
        'ngay_giai_quyet': FieldValue.serverTimestamp(),
      });

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
    if (filter == 1) return reports.where((r) => r.kind == 'booking').toList();
    if (filter == 2) return reports.where((r) => r.kind == 'qr').toList();
    return List.of(reports);
  }

  /// LỌC LỊCH SỬ BÁO CÁO ĐÃ GIẢI QUYẾT
  List<ErrorReport> filteredResolvedReports(int filter) {
    if (filter == 1) return resolvedReports.where((r) => r.kind == 'booking').toList();
    if (filter == 2) return resolvedReports.where((r) => r.kind == 'qr').toList();
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

      await _firestore.collection('ThongBaoHeThong').add({
        'tieu_de': 'Khóa tài khoản bệnh nhân',
        'noi_dung': 'Quản trị viên đã khóa tài khoản bệnh nhân: ${p.hoTen} (${p.maBenhNhan}). Lý do: $reason',
        'loai': 'khoa_tai_khoan',
        'nguoi_nhan_uid': p.uid,
        'da_doc': false,
        'thoi_gian_hien_thi': 'Vừa xong',
        'ngay_tao': FieldValue.serverTimestamp(),
      });

      try {
        await FirebaseAdminAuthService.instance.disableAndRevokeUser(
          uid: p.uid,
          email: p.email,
        );
      } catch (e) {
        debugPrint('Lỗi vô hiệu hóa Firebase Auth: $e');
      }

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

      await _firestore.collection('ThongBaoHeThong').add({
        'tieu_de': 'Mở khóa tài khoản bệnh nhân',
        'noi_dung': 'Quản trị viên đã kích hoạt lại tài khoản bệnh nhân: ${p.hoTen} (${p.maBenhNhan})',
        'loai': 'mo_khoa_tai_khoan',
        'nguoi_nhan_uid': p.uid,
        'da_doc': false,
        'thoi_gian_hien_thi': 'Vừa xong',
        'ngay_tao': FieldValue.serverTimestamp(),
      });

      try {
        await FirebaseAdminAuthService.instance.enableUser(
          uid: p.uid,
          email: p.email,
        );
      } catch (e) {
        debugPrint('Lỗi mở khóa Firebase Auth: $e');
      }

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
      try {
        await FirebaseAdminAuthService.instance.deleteUser(
          uid: p.uid,
          email: email,
        );
      } catch (e) {
        debugPrint('❌ Lỗi xóa tài khoản bệnh nhân trên Firebase Auth: $e');
      }

      await _firestore.collection('BenhNhan').doc(p.uid).delete();

      await _firestore.collection('ThongBaoHeThong').add({
        'tieu_de': 'Đã xóa tài khoản bệnh nhân',
        'noi_dung': 'Quản trị viên đã xóa hoàn toàn tài khoản bệnh nhân: ${p.hoTen} (${p.maBenhNhan})',
        'loai': 'xoa_tai_khoan',
        'da_doc': false,
        'thoi_gian_hien_thi': 'Vừa xong',
        'ngay_tao': FieldValue.serverTimestamp(),
      });

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

    final offlineStart = patient.effectiveOfflineTime; // Note: Ensure effectiveOfflineTime is defined in AdminPatient model
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

    final totalAppointments = appointments.length;
    final freqPerMonth = totalDaysJoined >= 30
        ? (totalAppointments / (totalDaysJoined / 30.0))
        : (totalAppointments * (30.0 / totalDaysJoined));
    final freqPerWeek = totalDaysJoined >= 7
        ? (totalAppointments / (totalDaysJoined / 7.0))
        : (totalAppointments * (7.0 / totalDaysJoined));

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
          try { appDate = DateTime.parse(app['ngay_kham'].toString()); } catch (_) {}
        }
        if (appDate != null && appDate.year == day.year && appDate.month == day.month && appDate.day == day.day) {
          count++;
        }
      }
      dailyChart.add({'label': '${day.day}/${day.month}', 'count': count, 'date': day});
    }

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
          try { appDate = DateTime.parse(app['ngay_kham'].toString()); } catch (_) {}
        }
        if (appDate != null && appDate.year == targetMonth.year && appDate.month == targetMonth.month) {
          count++;
        }
      }
      monthlyChart.add({'label': 'T${targetMonth.month}', 'count': count, 'year': targetMonth.year});
    }

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
          try { appDate = DateTime.parse(app['ngay_kham'].toString()); } catch (_) {}
        }
        if (appDate != null && appDate.year == y) {
          count++;
        }
      }
      yearlyChart.add({'label': '$y', 'count': count});
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
          try { appDate = DateTime.parse(app['ngay_kham'].toString()); } catch (_) {}
        }
        if (appDate != null && appDate.year == day.year && appDate.month == day.month && appDate.day == day.day) {
          count++;
        }
      }
      dailyChart.add({'label': '${day.day}/${day.month}', 'count': count, 'date': day});
    }

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
          try { appDate = DateTime.parse(app['ngay_kham'].toString()); } catch (_) {}
        }
        if (appDate != null && appDate.year == targetMonth.year && appDate.month == targetMonth.month) {
          count++;
        }
      }
      monthlyChart.add({'label': 'T${targetMonth.month}', 'count': count, 'year': targetMonth.year});
    }

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
          try { appDate = DateTime.parse(app['ngay_kham'].toString()); } catch (_) {}
        }
        if (appDate != null && appDate.year == y) {
          count++;
        }
      }
      yearlyChart.add({'label': '$y', 'count': count});
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