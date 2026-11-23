import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../config/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../config/staff_session.dart';
import '../letan_c1/cskh_duyetdon_khoa_screen_c1.dart';
import '../letan_c1/letan_trangchu_screen_c1.dart';
import '../../support_doctor/department_room_picker.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _primary = Color(0xFF1E78E0);

  static const _roleLeTan = {'receptionist', 'le_tan'};
  static const _roleCskh = {'customerSupport', 'cskh', 'cham_soc_khach_hang'};
  static const _roleBacSi = {'doctorAssistant', 'ho_tro_bac_si', 'bac_si'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// _bootstrap: khôi phục phiên đăng nhập đã lưu rồi chuyển thẳng tới màn hình đúng vai trò; không có thì về đăng nhập.
  Future<void> _bootstrap() async {
    String destination = 'login';
    try {
      destination = await context.read<AuthProvider>().restoreSession();
    } catch (_) {
      destination = 'login';
    }
    if (!mounted) return;

    switch (destination) {
      case 'admin':
        _goNamed(AppRoutes.adminDashboard);
        return;
      case 'hospital':
        _goNamed(AppRoutes.hospitalDashboard);
        return;
      case 'patient':
        _goNamed(AppRoutes.patientMain, arguments: 0);
        return;
    }

    final openedStaff = await _tryRestoreStaff();
    if (openedStaff || !mounted) return;
    _goNamed(AppRoutes.login);
  }

  /// _goNamed: chuyển sang route chỉ định và xóa toàn bộ stack điều hướng.
  void _goNamed(String route, {Object? arguments}) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (r) => false,
      arguments: arguments,
    );
  }

  /// _tryRestoreStaff: nếu có mã nhân viên đã lưu thì nạp hồ sơ và mở màn hình nhân viên tương ứng.
  /// Trả về false nếu không có phiên nhân viên hợp lệ.
  Future<bool> _tryRestoreStaff() async {
    final code = await StaffSession.read();
    if (code == null || code.isEmpty) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('NhanVien')
          .doc(code)
          .get();
      final data = doc.data();
      if (!doc.exists || data == null || data['da_kich_hoat'] != true) {
        await StaffSession.clear();
        return false;
      }

      final role = (data['role'] ?? 'receptionist').toString();
      final isLeTan = _roleLeTan.contains(role);

      final Widget? screen = isLeTan
          ? const LeTanHomeScreenC1()
          : _roleCskh.contains(role)
          ? const CskhDuyetdonKhoaScreenC1()
          : _roleBacSi.contains(role)
          ? const ClinicRoomPickerScreen()
          : null;

      if (screen == null) {
        await StaffSession.clear();
        return false;
      }

      DuLieuProfileMauC1.thongTinHienTai = DuLieuProfileMauC1.thongTinHienTai
          .copyWith(
            maNhanVien: code,
            hoTen: (data['ho_ten'] ?? 'Nhân viên').toString(),
            chucVu:
                (data['chuc_vu'] ??
                        (isLeTan ? 'Lễ tân tiếp đón' : 'Chăm sóc khách hàng'))
                    .toString(),
            khoa: (data['khoa'] ?? 'Khoa Khám Bệnh').toString(),
            email: (data['email'] ?? '').toString(),
          );

      if (!mounted) return true;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => screen),
        (r) => false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: Center(child: CircularProgressIndicator(color: _primary)),
    );
  }
}
