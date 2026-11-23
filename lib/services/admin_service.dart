import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // 1. QUẢN LÝ BỆNH VIỆN / CƠ SỞ Y TẾ
  // ---------------------------------------------------------------------------

  /// Lấy danh sách tất cả bệnh viện (Realtime Stream)
  Stream<QuerySnapshot<Map<String, dynamic>>> getHospitalsStream({String? statusFilter}) {
    Query<Map<String, dynamic>> query = _db.collection('BenhVien');
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('trangThai', isEqualTo: statusFilter);
    }
    return query.orderBy('ngayTao', descending: true).snapshots();
  }

  /// Duyệt bệnh viện mới đăng ký
  Future<void> approveHospital(String hospitalId) async {
    await _db.collection('BenhVien').doc(hospitalId).update({
      'trangThai': 'DA_DUYET',
      'trang_thai_hop_tac_id': 10,
      'trang_thai': 'da_duyet',
      'da_duyet': true,
      'ngayDuyet': FieldValue.serverTimestamp(),
      'ngay_duyet': FieldValue.serverTimestamp(),
      'ngay_hop_tac': FieldValue.serverTimestamp(),
    });

    try {
      final ycDoc = await _db.collection('YeuCauHopTac').doc(hospitalId).get();
      if (ycDoc.exists) {
        await _db.collection('YeuCauHopTac').doc(hospitalId).update({
          'trang_thai_hop_tac_id': 10,
          'trang_thai': 'da_duyet',
          'da_duyet': true,
          'ngay_duyet': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  /// Từ chối hoặc Khóa bệnh viện vi phạm
  Future<void> updateHospitalStatus(String hospitalId, String status, {String? reason}) async {
    final bool isReject = status == 'TU_CHOI';
    final int statusId = isReject ? 4 : 8;

    await _db.collection('BenhVien').doc(hospitalId).update({
      'trangThai': status, // 'TU_CHOI', 'DA_KHOA', 'HOAT_DONG'
      'trang_thai_hop_tac_id': statusId,
      'da_duyet': false,
      if (reason != null) 'lyDoKhoa': reason,
      if (reason != null) 'ly_do_tu_choi': reason,
      'capNhatLaoCuoi': FieldValue.serverTimestamp(),
    });

    try {
      final ycDoc = await _db.collection('YeuCauHopTac').doc(hospitalId).get();
      if (ycDoc.exists) {
        await _db.collection('YeuCauHopTac').doc(hospitalId).update({
          'trang_thai_hop_tac_id': statusId,
          'trang_thai': isReject ? 'tu_choi' : 'khoa',
          'da_duyet': false,
          if (reason != null) 'ly_do_tu_choi': reason,
          'ngay_tu_choi': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  /// Thêm bệnh viện mới: Mặc định đưa vào CHỜ DUYỆT trước, khi duyệt xong mới sang Tổng BV
  Future<DocumentReference> addHospital(Map<String, dynamic> hospitalData) async {
    hospitalData['ngayTao'] = FieldValue.serverTimestamp();
    hospitalData['ngay_tao'] = FieldValue.serverTimestamp();
    hospitalData['trangThai'] = 'CHO_DUYET';
    hospitalData['trang_thai_hop_tac_id'] = 1;
    hospitalData['trang_thai'] = 'cho_duyet';
    hospitalData['da_duyet'] = false;
    return await _db.collection('BenhVien').add(hospitalData);
  }

  // ---------------------------------------------------------------------------
  // 2. QUẢN LÝ TÀI KHOẢN & PHÂN QUYỀN (NhanVien / BenhNhan)
  // ---------------------------------------------------------------------------

  /// Lấy danh sách nhân viên theo bệnh viện hoặc toàn hệ thống
  Stream<QuerySnapshot<Map<String, dynamic>>> getUsersStream({String? roleId}) {
    Query<Map<String, dynamic>> query = _db.collection('NhanVien');
    if (roleId != null && roleId.isNotEmpty) {
      query = query.where('vaiTroId', isEqualTo: roleId);
    }
    return query.snapshots();
  }

  /// Cấp vai trò hoặc cập nhật trạng thái tài khoản
  Future<void> updateUserRoleAndStatus({
    required String userId,
    required String roleId,
    required bool isActive,
  }) async {
    await _db.collection('NhanVien').doc(userId).update({
      'vaiTroId': roleId,
      'trangThaiHoatDong': isActive,
      'capNhatLaoCuoi': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // 3. QUẢN LÝ BÁO CÁO LỖI (BaoCaoLoi)
  // ---------------------------------------------------------------------------

  /// Lấy danh sách báo cáo lỗi từ người dùng (Realtime)
  Stream<QuerySnapshot<Map<String, dynamic>>> getBugReportsStream({String? status}) {
    Query<Map<String, dynamic>> query = _db.collection('BaoCaoLoi');
    if (status != null && status.isNotEmpty) {
      query = query.where('trangThaiXuly', isEqualTo: status);
    }
    return query.orderBy('ngayTao', descending: true).snapshots();
  }

  /// Cập nhật tiến độ xử lý báo cáo lỗi
  Future<void> updateBugReportStatus({
    required String reportId,
    required String status, // 'DANG_XU_LY', 'DA_GIAI_QUYET', 'TU_CHOI'
    String? adminNote,
  }) async {
    await _db.collection('BaoCaoLoi').doc(reportId).update({
      'trangThaiXuly': status,
      if (adminNote != null) 'ghiChuAdmin': adminNote,
      'ngayCapNhat': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // 4. THỐNG KÊ TỔNG QUAN HỆ THỐNG
  // ---------------------------------------------------------------------------

  /// Lấy các chỉ số tổng quan cho Dashboard Admin
  Future<Map<String, int>> getAdminDashboardStats() async {
    // Chỉ đếm bệnh viện đã duyệt hợp tác (ID: 10)
    final hospitals = await _db
        .collection('BenhVien')
        .where('trang_thai_hop_tac_id', isEqualTo: 10)
        .count()
        .get();
    final pendingHospitals = await _db
        .collection('BenhVien')
        .where('trang_thai_hop_tac_id', isEqualTo: 1)
        .count()
        .get();
    final patients = await _db.collection('BenhNhan').count().get();
    final openReports = await _db
        .collection('BaoCaoLoi')
        .where('trangThaiXuly', isEqualTo: 'CHO_XU_LY')
        .count()
        .get();

    return {
      'totalHospitals': hospitals.count ?? 0,
      'pendingHospitals': pendingHospitals.count ?? 0,
      'totalPatients': patients.count ?? 0,
      'openReports': openReports.count ?? 0,
    };
  }
}