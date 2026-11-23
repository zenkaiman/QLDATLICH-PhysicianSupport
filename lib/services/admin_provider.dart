import 'package:flutter/material.dart';
import 'admin_service.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, int> _stats = {
    'totalHospitals': 0,
    'pendingHospitals': 0,
    'totalPatients': 0,
    'openReports': 0,
  };
  Map<String, int> get stats => _stats;

  /// Tải thông số thống kê Admin
  Future<void> fetchDashboardStats() async {
    _isLoading = true;
    notifyListeners();
    try {
      _stats = await _adminService.getAdminDashboardStats();
    } catch (e) {
      debugPrint('Lỗi tải thống kê Admin: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Duyệt bệnh viện
  Future<bool> approveHospital(String hospitalId) async {
    try {
      await _adminService.approveHospital(hospitalId);
      await fetchDashboardStats();
      return true;
    } catch (e) {
      debugPrint('Lỗi duyệt bệnh viện: $e');
      return false;
    }
  }

  /// Khóa bệnh viện
  Future<bool> lockHospital(String hospitalId, String reason) async {
    try {
      await _adminService.updateHospitalStatus(hospitalId, 'DA_KHOA', reason: reason);
      await fetchDashboardStats();
      return true;
    } catch (e) {
      debugPrint('Lỗi khóa bệnh viện: $e');
      return false;
    }
  }

  /// Cập nhật báo cáo lỗi
  Future<bool> resolveBugReport(String reportId, String note) async {
    try {
      await _adminService.updateBugReportStatus(
        reportId: reportId,
        status: 'DA_GIAI_QUYET',
        adminNote: note,
      );
      await fetchDashboardStats();
      return true;
    } catch (e) {
      debugPrint('Lỗi cập nhật báo cáo: $e');
      return false;
    }
  }
}