import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'cskh_duyetdon_khoa_screen_c1.dart';
import 'letan_thietlap_thongtin_screen_c1.dart';
import 'letan_trangchu_screen_c1.dart';

/// MÀN HÌNH ĐĂNG NHẬP PHÂN HỆ C1 (LỄ TÂN & CHĂM SÓC KHÁCH HÀNG)
/// - Đăng nhập bằng Mã nhân viên được cấp (VD: LT_TM_01, CSKH_01) -> Tự động chuyển Màn hình 3 thiết lập
/// - Đăng nhập bằng Gmail (khi đã kích hoạt) -> Vào thẳng Bàn làm việc Lễ tân / CSKH
class LetanDangnhapScreenC1 extends StatefulWidget {
  const LetanDangnhapScreenC1({super.key});

  @override
  State<LetanDangnhapScreenC1> createState() => _LetanDangnhapScreenC1State();
}

class _LetanDangnhapScreenC1State extends State<LetanDangnhapScreenC1> {
  final _formKey = GlobalKey<FormState>();
  final _taiKhoanCtrl = TextEditingController(text: 'LT_TM_01');
  final _matKhauCtrl = TextEditingController(text: '123456');

  bool _anMatKhau = true;
  bool _dangXuLy = false;
  bool _ghiNhoDangNhap = true;

  @override
  void initState() {
    super.initState();
    _kiemTraPhienDangNhapTuDong();
  }

  /// Tự động đăng nhập nếu trước đó người dùng chọn Ghi nhớ tài khoản
  Future<void> _kiemTraPhienDangNhapTuDong() async {
    final phien = await FirebaseServiceC1.layPhienDangNhap();
    if (phien != null && mounted) {
      _taiKhoanCtrl.text = phien['taiKhoan'] ?? '';
      _matKhauCtrl.text = phien['matKhau'] ?? '';
      // Tự động kích hoạt đăng nhập
      _xuLyDangNhap(laTuDong: true);
    }
  }

  @override
  void dispose() {
    _taiKhoanCtrl.dispose();
    _matKhauCtrl.dispose();
    super.dispose();
  }

  Future<void> _xuLyDangNhap({bool laTuDong = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (!laTuDong) AppDesignSystemC1.hapticLight();
    setState(() => _dangXuLy = true);

    final input = _taiKhoanCtrl.text.trim();
    final pass = _matKhauCtrl.text.trim();

    try {
      // 1. Gọi service kiểm tra thông tin trên Firestore NhanVien
      final user = await FirebaseServiceC1.dangNhapNhanVien(
        taiKhoanHoacEmail: input,
        matKhau: pass,
      );

      // Lưu phiên nếu người dùng tích chọn Ghi nhớ
      if (_ghiNhoDangNhap) {
        await FirebaseServiceC1.luuPhienDangNhap(taiKhoan: input, matKhau: pass);
      } else {
        await FirebaseServiceC1.xoaPhienDangNhap();
      }

      if (!mounted) return;
      setState(() => _dangXuLy = false);

      final daKichHoat = user?['da_kich_hoat'] == true;
      final role = (user?['role'] ?? 'le_tan').toString();
      final maNhanVien = (user?['ma_tai_khoan'] ?? input).toString();

      // TRƯỜNG HỢP 1: Lần đầu đăng nhập bằng mã nhân viên chưa kích hoạt -> Sang Màn hình 3
      if (!daKichHoat) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tài khoản mới lần đầu đăng nhập! Vui lòng thiết lập thông tin.'),
            backgroundColor: Color(0xFF0284C7),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LetanThietlapThongtinScreenC1(
              maNhanVienMacDinh: maNhanVien,
            ),
          ),
        );
        return;
      }

      // Cập nhật thông tin profile hiện tại khớp hoàn toàn với tài khoản Firestore vừa đăng nhập
      final emailReal = (user?['email'] ?? (input.contains('@') ? input : '')).toString();
      final hoTenReal = (user?['ho_ten'] ?? 'Nhân Viên').toString();
      final chucVuReal = (user?['chuc_vu'] ?? (role == 'le_tan' ? 'Lễ tân tiếp đón' : 'Chăm sóc khách hàng')).toString();
      final khoaReal = (user?['khoa'] ?? (role == 'le_tan' ? 'Khoa Khám Bệnh' : 'Bộ Phận CSKH & Tiếp Nhận')).toString();
      final benhVienIdReal = (user?['benh_vien_id'] ?? '1').toString();

      DuLieuProfileMauC1.thongTinHienTai = DuLieuProfileMauC1.thongTinHienTai.copyWith(
        email: emailReal,
        hoTen: hoTenReal,
        maNhanVien: maNhanVien,
        chucVu: chucVuReal,
        khoa: khoaReal,
        benhVienId: benhVienIdReal,
      );

      // TRƯỜNG HỢP 2: Đã kích hoạt -> Vào bàn làm việc theo vai trò
      if (role == 'cham_soc_khach_hang' || role == 'cskh') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CskhDuyetdonKhoaScreenC1()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LeTanHomeScreenC1()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangXuLy = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppDesignSystemC1.isDarkMode,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo / Icon y tế
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppDesignSystemC1.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          size: 40,
                          color: AppDesignSystemC1.primary,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Tiêu đề
                      Text(
                        'ĐĂNG NHẬP NỘI BỘ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Phân hệ Lễ tân & Chăm sóc khách hàng',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Card chứa form
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ô nhập Mã nhân viên hoặc Gmail
                            const Text(
                              'Mã nhân viên hoặc Gmail',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _taiKhoanCtrl,
                              decoration: InputDecoration(
                                hintText: 'Nhập LT_TM_01 hoặc Gmail...',
                                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Vui lòng nhập mã hoặc Gmail';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Ô nhập Mật khẩu
                            const Text(
                              'Mật khẩu',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _matKhauCtrl,
                              obscureText: _anMatKhau,
                              decoration: InputDecoration(
                                hintText: 'Nhập mật khẩu...',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _anMatKhau ? Icons.visibility_off : Icons.visibility,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _anMatKhau = !_anMatKhau),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Vui lòng nhập mật khẩu';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Ghi nhớ đăng nhập
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _ghiNhoDangNhap,
                                    activeColor: AppDesignSystemC1.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                    onChanged: (val) => setState(() => _ghiNhoDangNhap = val ?? true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Ghi nhớ đăng nhập trên thiết bị',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Nút Đăng nhập
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _dangXuLy ? null : _xuLyDangNhap,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppDesignSystemC1.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _dangXuLy
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'ĐĂNG NHẬP',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Ghi chú hướng dẫn cho nhân viên
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lần đầu đăng nhập: Dùng Mã nhân viên được BV cấp (LT_TM_01 / pass: 123456)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E40AF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
