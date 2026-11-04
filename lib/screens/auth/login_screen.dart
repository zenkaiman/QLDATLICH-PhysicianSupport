import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import '../../config/app_routes.dart';
import '../../database_seeder.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseAuthException;
import '../../config/app_session.dart';
import '../../providers/auth_provider.dart';
import '../letan_c1/cskh_duyetdon_khoa_screen_c1.dart';
import '../letan_c1/letan_thietlap_thongtin_screen_c1.dart';
import '../letan_c1/letan_trangchu_screen_c1.dart';
import '../../support_doctor/clinic_firestore_service.dart';
import '../../support_doctor/department_room_picker.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _primary = Color(0xFF1E78E0);
  static const _danger = Color(0xFFE53935);
  static const _grey = Color(0xFF64748B);

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  int _selectedRoleIndex = 0; // 0: Bệnh nhân, 1: Bệnh viện, 2: Admin

  bool _obscure = true;

  final List<Map<String, dynamic>> _roles = [
    {'name': 'Bệnh nhân', 'icon': Icons.person_outline, 'code': 'benh_nhan'},
    {'name': 'Bệnh viện', 'icon': Icons.local_hospital, 'code': 'benh_vien'},
    {'name': 'Admin', 'icon': Icons.admin_panel_settings, 'code': 'admin'},
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ email và mật khẩu')),
      );
      return;
    }

    try {
      final auth = context.read<AuthProvider>();
      final selectedRoleCode = _roles[_selectedRoleIndex]['code'] as String;

      // ✅ 1. ƯU TIÊN KIỂM TRA ĐĂNG NHẬP NHÂN VIÊN Y TẾ (DÙ NHẬP MÃ HAY GMAIL, DÙ CHỌN TAB NÀO)
      if (selectedRoleCode != 'admin') {
        Map<String, dynamic>? nhanVienData;
        try {
          nhanVienData = await FirebaseServiceC1.dangNhapNhanVien(
            taiKhoanHoacEmail: email,
            matKhau: password,
          );
        } catch (e) {
          // Nếu nhập mã nhân viên (không có @) mà sai hoặc không tìm thấy -> Ném lỗi trực tiếp ra UI
          if (!email.contains('@')) {
            rethrow;
          }
          // Nếu nhập email nhưng sai mật khẩu nhân viên -> Ném lỗi ra UI
          final errStr = e.toString();
          if (errStr.contains('Mật khẩu không chính xác') ||
              errStr.contains('Mật khẩu cấp ban đầu không chính xác')) {
            rethrow;
          }
          // Email không phải nhân viên -> Để trôi xuống luồng xác thực Bệnh nhân / Bệnh viện bên dưới
        }

        if (nhanVienData != null) {
          final role = (nhanVienData['role'] ?? nhanVienData['vai_tro'] ?? '').toString();
          final bool daKichHoat = (nhanVienData['da_kich_hoat'] == true) ||
              (nhanVienData['trang_thai'] == 'dang_hoat_dong');
          final maNvThucTe = (nhanVienData['ma_nhan_vien'] ??
                  nhanVienData['ma_tai_khoan'] ??
                  email)
              .toString();
          // Xác định đúng bệnh viện: ưu tiên dữ liệu document → đường dẫn
          // NhanVien/{bvId}/danh_sach/{ma} → chính mã nhân viên
          // (VD: BV508_BS_DL_02 → BV508)
          final duongDanNv = (nhanVienData['docPath'] ?? '').toString();
          var bvId = (nhanVienData['ma_benh_vien'] ??
                  nhanVienData['benh_vien_id'] ??
                  nhanVienData['benhVienId'] ??
                  '')
              .toString()
              .trim();
          if (bvId.isEmpty) {
            bvId = FirebaseServiceC1.benhVienIdTuDuongDan(duongDanNv);
          }
          if (bvId.isEmpty) {
            bvId = FirebaseServiceC1.benhVienIdTuMaNhanVien(maNvThucTe);
          }
          final tenBv = (nhanVienData['ten_benh_vien'] ?? 'Bệnh viện Quân y 17')
              .toString();

          // Cập nhật thông tin profile nhân viên hiện tại
          DuLieuProfileMauC1.thongTinHienTai =
              DuLieuProfileMauC1.thongTinHienTai.copyWith(
            maNhanVien: maNvThucTe,
            hoTen: (nhanVienData['ho_ten'] ?? 'Nhân viên').toString(),
            chucVu: (nhanVienData['chuc_vu'] ??
                    (role.contains('cskh') ||
                            role.contains('customer') ||
                            role.contains('cham_soc')
                        ? 'Chăm sóc khách hàng'
                        : 'Lễ tân tiếp đón'))
                .toString(),
            khoa: (nhanVienData['khoa'] ??
                    (role.contains('cskh') ||
                            role.contains('customer') ||
                            role.contains('cham_soc')
                        ? 'Bộ Phận CSKH & Tiếp Nhận'
                        : 'Khoa Khám Bệnh'))
                .toString(),
            email: (nhanVienData['email'] ?? email).toString(),
            benhVienId: bvId,
            tenBenhVien: tenBv,
          );

          // Ghi nhớ bệnh viện của phiên đăng nhập để mọi truy vấn
          // (lịch hẹn, thông báo bệnh nhân, nhân viên…) dùng đúng bệnh viện.
          if (bvId.isNotEmpty) AppSession.benhVienId = bvId;

          // Tự động ghi nhớ phiên đăng nhập
          await FirebaseServiceC1.luuPhienDangNhap(
              taiKhoan: email, matKhau: password);

          if (!mounted) return;

          // Nếu chưa kích hoạt -> Màn hình thiết lập thông tin ban đầu
          if (!daKichHoat) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LetanThietlapThongtinScreenC1(
                  maNhanVienMacDinh: maNvThucTe,
                ),
              ),
            );
            return;
          }

          // Đã kích hoạt -> Điều hướng chính xác theo vai trò
          // (so khớp linh hoạt: customerSupport / cskh / cham_soc_khach_hang,
          //  bac_si / BS_DL / doctor, le_tan / receptionist…)
          final roleLower = role.trim().toLowerCase();
          final laCskh = roleLower.contains('cskh') ||
              roleLower.contains('customer') ||
              roleLower.contains('cham_soc') ||
              roleLower.contains('chamsoc');
          final laBacSi = roleLower.contains('bac_si') ||
              roleLower.contains('bacsi') ||
              roleLower.contains('doctor') ||
              roleLower.contains('bs');
          final laLeTan = roleLower.contains('le_tan') ||
              roleLower.contains('letan') ||
              roleLower.contains('reception');

          if (laCskh) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => const CskhDuyetdonKhoaScreenC1()),
            );
            return;
          } else if (laBacSi) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => FirestoreClinicRoomPickerScreen(
                  hospitalId: bvId.isNotEmpty ? bvId : 'BV001',
                  hospitalName: tenBv.isNotEmpty
                      ? tenBv
                      : DuLieuProfileMauC1.thongTinHienTai.tenBenhVien,
                ),
              ),
            );
            return;
          } else if (laLeTan) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LeTanHomeScreenC1()),
            );
            return;
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LeTanHomeScreenC1()),
            );
            return;
          }
        }
      }

      // ✅ 2. NẾU KHÔNG PHẢI NHÂN VIÊN Y TẾ -> ĐĂNG NHẬP THEO VAI TRÒ CHỌN TRÊN GIAO DIỆN (BN / BV / ADMIN)
      await auth.login(email: email, password: password);

      if (!mounted) return;

      // ✅ 2.3. Nếu chọn Bệnh viện
      if (selectedRoleCode == 'benh_vien') {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.hospitalDashboard, (route) => false);
        return;
      }

      // ✅ 2.4. Nếu chọn Admin
      if (selectedRoleCode == 'admin') {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.adminDashboard, (route) => false);
        return;
      }

      // ✅ 2.5. Nếu chọn Bệnh nhân
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.patientHome, (route) => false);
      return;

    } catch (e) {
      if (!mounted) return;
      String errorMessage = _loginErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: _danger),
      );
    }
  }

  String _loginErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
        case 'user-not-found':
          return 'Email không đúng hoặc chưa được đăng ký.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Mật khẩu không đúng.';
        case 'user-disabled':
          return 'Tài khoản này đã bị vô hiệu hóa.';
        case 'too-many-requests':
          return 'Bạn thử đăng nhập quá nhiều lần. Vui lòng thử lại sau.';
      }
    }
    return error.toString().replaceAll('Exception: ', '');
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    // ✅ Lấy trạng thái loading từ Provider để đồng bộ UI
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Logo & Title
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 50),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'MEDICONNECT',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hệ thống Y tế & Đặt lịch khám thông minh\nhàng đầu Việt Nam',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: _grey, height: 1.4),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Role Selection Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: List.generate(_roles.length, (index) {
                    final isSelected = index == _selectedRoleIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRoleIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? _primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _roles[index]['icon'] as IconData,
                                size: 18,
                                color: isSelected ? Colors.white : _grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _roles[index]['name'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.white : _grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // Google Login Button (Placeholder)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chức năng đang phát triển')),
                    );
                  },
                  icon: const Icon(Icons.g_mobiledata, color: _primary, size: 24),
                  label: const Text(
                    'Đăng nhập với Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Or divider
              Row(
                children: [
                  Expanded(child: Divider(color: _grey.withOpacity(0.3))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('hoặc đăng nhập bằng tài khoản nội bộ', style: TextStyle(fontSize: 13, color: _grey)),
                  ),
                  Expanded(child: Divider(color: _grey.withOpacity(0.3))),
                ],
              ),
              const SizedBox(height: 24),

              // Email Input
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined, color: _grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: _border(const Color(0xFFE2E8F0)),
                  enabledBorder: _border(const Color(0xFFE2E8F0)),
                  focusedBorder: _border(_primary),
                ),
              ),
              const SizedBox(height: 16),

              // Password Input
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline, color: _grey),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: _grey),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: _border(const Color(0xFFE2E8F0)),
                  enabledBorder: _border(const Color(0xFFE2E8F0)),
                  focusedBorder: _border(_primary),
                ),
              ),
              
              // ✅ Quên mật khẩu
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng liên hệ quản trị viên hoặc sử dụng tính năng quên mật khẩu trong hồ sơ.')),
                    );
                  },
                  child: const Text(
                    'Quên mật khẩu?',
                    style: TextStyle(fontSize: 14, color: _primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Đăng nhập',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Register Link
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                child: const Text(
                  'Đăng ký tài khoản mới',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _danger),
                ),
              ),
              const SizedBox(height: 24),

              // Support Hotline
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, color: _danger, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Hotline hỗ trợ 24/7: 1900 6868',
                      style: TextStyle(color: _danger, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}