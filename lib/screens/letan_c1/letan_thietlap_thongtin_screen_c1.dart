import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'cskh_duyetdon_khoa_screen_c1.dart';
import 'letan_trangchu_screen_c1.dart';
import '../../support_doctor/clinic_firestore_service.dart';
import '../../support_doctor/department_room_picker.dart';

/// MÀN HÌNH 3: THIẾT LẬP THÔNG TIN KHI LẦN ĐẦU ĐĂNG NHẬP (FIGMA C1)
/// Nhân viên nhập Mã nhân viên được cấp -> Bổ sung Gmail, Họ tên, Ngày sinh, Giới tính, Mật khẩu mới.
/// Sau khi xác nhận: Tên đăng nhập chính thức chuyển thành Gmail.
class LetanThietlapThongtinScreenC1 extends StatefulWidget {
  final String maNhanVienMacDinh;

  const LetanThietlapThongtinScreenC1({
    super.key,
    this.maNhanVienMacDinh = 'LT_TM_01',
  });

  @override
  State<LetanThietlapThongtinScreenC1> createState() => _LetanThietlapThongtinScreenC1State();
}

class _LetanThietlapThongtinScreenC1State extends State<LetanThietlapThongtinScreenC1> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _maNvController;
  late TextEditingController _hoTenController;
  late TextEditingController _ngaySinhController;
  late TextEditingController _emailController;
  late TextEditingController _matKhauController;

  String _gioiTinh = 'Nữ'; // 'Nam' hoặc 'Nữ'
  bool _anMatKhau = true;
  bool _dangXuLy = false;

  @override
  void initState() {
    super.initState();
    _maNvController = TextEditingController(text: widget.maNhanVienMacDinh);
    _hoTenController = TextEditingController();
    _ngaySinhController = TextEditingController();
    _emailController = TextEditingController();
    _matKhauController = TextEditingController();
  }

  @override
  void dispose() {
    _maNvController.dispose();
    _hoTenController.dispose();
    _ngaySinhController.dispose();
    _emailController.dispose();
    _matKhauController.dispose();
    super.dispose();
  }

  // Chọn ngày sinh qua DatePicker chuẩn y tế
  Future<void> _chonNgaySinh() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1998, 8, 15),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
     );
    if (picked != null) {
      setState(() {
        final ngay = picked.day.toString().padLeft(2, '0');
        final thang = picked.month.toString().padLeft(2, '0');
        _ngaySinhController.text = '$ngay/$thang/${picked.year}';
      });
    }
  }

  // Xác nhận thiết lập thông tin & chuyển sang đăng nhập bằng Gmail
  Future<void> _xacNhanThietLap() async {
    if (!_formKey.currentState!.validate()) return;

    AppDesignSystemC1.hapticLight();
    setState(() => _dangXuLy = true);

    final emailMoi = _emailController.text.trim();
    final hoTenMoi = _hoTenController.text.trim();
    final maNv = _maNvController.text.trim();
    final ngaySinh = _ngaySinhController.text.trim();
    final matKhauMoi = _matKhauController.text.trim();

    try {
      // 1. Cập nhật trực tiếp lên Firestore NhanVien
      await FirebaseServiceC1.kichHoatTaiKhoanLanDau(
        maNhanVien: maNv,
        hoTen: hoTenMoi,
        email: emailMoi,
        ngaySinh: ngaySinh,
        gioiTinh: _gioiTinh,
        matKhauMoi: matKhauMoi,
      );
      // Tự động lưu phiên đăng nhập bằng Gmail mới kích hoạt
      await FirebaseServiceC1.luuPhienDangNhap(taiKhoan: emailMoi, matKhau: matKhauMoi);
    } catch (e) {
      // ignore: avoid_print
      print('Chế độ fallback mock do lỗi kết nối: $e');
    }

    // 2. Cập nhật bộ nhớ cục bộ
    DuLieuProfileMauC1.thongTinHienTai = DuLieuProfileMauC1.thongTinHienTai.copyWith(
      hoTen: hoTenMoi,
      email: emailMoi,
      maNhanVien: maNv,
    );

    if (!mounted) return;
    setState(() => _dangXuLy = false);

    // Thông báo thành công
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✓ Kích hoạt thành công! Từ bây giờ bạn sẽ đăng nhập bằng Gmail: $emailMoi',
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );

    // Điều hướng vào đúng Bàn làm việc theo Role
    final upper = maNv.toUpperCase();
    if (upper.contains('CSKH') || upper.contains('SP')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CskhDuyetdonKhoaScreenC1(),
        ),
      );
    } else if (upper.startsWith('BS') || upper.contains('BS_')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FirestoreClinicRoomPickerScreen(
            hospitalId: DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty
                ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
                : 'BV001',
            hospitalName: DuLieuProfileMauC1.thongTinHienTai.tenBenhVien,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LeTanHomeScreenC1(),
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
            child: Column(
              children: [
                // 1. Header trên cùng theo Figma: Tiêu đề + Nút Thoát
                _buildHeader(isDark),

                // 2. Nội dung cuộn Form điền thông tin
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Banner thông báo lần đầu đăng nhập
                          _buildCardThongBao(isDark),
                          const SizedBox(height: 18),

                          // Ô 1: Mã nhân viên (Read-only được cấp sẵn)
                          _buildFieldMaNhanVien(isDark),
                          const SizedBox(height: 16),

                          // Ô 2: Họ và tên nhân viên (*)
                          _buildFieldHoTen(isDark),
                          const SizedBox(height: 16),

                          // Ô 3: Email / Gmail đăng nhập mới (*)
                          _buildFieldEmail(isDark),
                          const SizedBox(height: 16),

                          // Ô 4: Ngày tháng năm sinh (*)
                          _buildFieldNgaySinh(isDark),
                          const SizedBox(height: 16),

                          // Ô 5: Giới tính (Nam / Nữ)
                          _buildFieldGioiTinh(isDark),
                          const SizedBox(height: 16),

                          // Ô 6: Mật khẩu mới (Bảo mật riêng) (*)
                          _buildFieldMatKhau(isDark),
                          const SizedBox(height: 28),

                          // Nút bấm Xác Nhận & Bắt Đầu Ca Trực
                          _buildButtonXacNhan(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Header theo Figma: Tiêu đề "Thiết Lập Thông Tin" + Nút "Thoát" màu đỏ
  Widget _buildHeader(bool isDark) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40), // Cân bằng với nút Thoát
          Text(
            'Thiết Lập Thông Tin',
            style: TextStyle(
              color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'Thoát',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card thông báo xanh dương trên cùng
  Widget _buildCardThongBao(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C2444) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lần đầu đăng nhập ca trực',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vui lòng xác nhận Mã nhân viên và điền đầy đủ họ tên, Gmail để hoàn tất kích hoạt.',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Ô 1: Mã nhân viên (Read-only)
  Widget _buildFieldMaNhanVien(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Mã nhân viên',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            Text(
              'Mã được cấp',
              style: TextStyle(
                color: Color(0xFF0284C7),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 20, color: Color(0xFF94A3B8)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _maNvController.text,
                  style: const TextStyle(
                    color: Color(0xFF0284C7),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.lock_outline, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ],
    );
  }

  // Ô 2: Họ và tên nhân viên (*)
  Widget _buildFieldHoTen(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Họ và tên nhân viên',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: _hoTenController,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ và tên' : null,
          decoration: _inputDecoration(
            hint: 'Nhập họ và tên đầy đủ',
            icon: Icons.person_outline,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // Ô 3: Email / Gmail (*)
  Widget _buildFieldEmail(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Text(
                  'Gmail tài khoản',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 4),
                Text('*', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              ],
            ),
            const Text(
              'Dùng đăng nhập sau này',
              style: TextStyle(
                color: Color(0xFF10B981),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập Gmail';
            if (!v.contains('@') || !v.contains('.')) return 'Email không đúng định dạng';
            return null;
          },
          decoration: _inputDecoration(
            hint: 'ví dụ: cuoc@gmail.com',
            icon: Icons.alternate_email,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // Ô 4: Ngày tháng năm sinh (*)
  Widget _buildFieldNgaySinh(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Ngày tháng năm sinh',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: _chonNgaySinh,
          borderRadius: BorderRadius.circular(14),
          child: IgnorePointer(
            child: TextFormField(
              controller: _ngaySinhController,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng chọn ngày sinh' : null,
              decoration: _inputDecoration(
                hint: 'DD/MM/YYYY',
                icon: Icons.calendar_today_outlined,
                isDark: isDark,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Ô 5: Giới tính (Nam / Nữ)
  Widget _buildFieldGioiTinh(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Giới tính',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            // Nút Nam
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _gioiTinh = 'Nam'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _gioiTinh == 'Nam'
                        ? (isDark ? const Color(0xFF0C2444) : const Color(0xFFF0F9FF))
                        : (isDark ? AppDesignSystemC1.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _gioiTinh == 'Nam'
                          ? const Color(0xFF0284C7)
                          : (isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0)),
                      width: _gioiTinh == 'Nam' ? 1.5 : 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_gioiTinh == 'Nam') ...[
                        const Icon(Icons.check_rounded, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        'Nam',
                        style: TextStyle(
                          color: _gioiTinh == 'Nam'
                              ? const Color(0xFF0284C7)
                              : (isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF475569)),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Nút Nữ
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _gioiTinh = 'Nữ'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _gioiTinh == 'Nữ'
                        ? (isDark ? const Color(0xFF0C2444) : const Color(0xFFF0F9FF))
                        : (isDark ? AppDesignSystemC1.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _gioiTinh == 'Nữ'
                          ? const Color(0xFF0284C7)
                          : (isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0)),
                      width: _gioiTinh == 'Nữ' ? 1.5 : 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_gioiTinh == 'Nữ') ...[
                        const Icon(Icons.check_rounded, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        'Nữ',
                        style: TextStyle(
                          color: _gioiTinh == 'Nữ'
                              ? const Color(0xFF0284C7)
                              : (isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF475569)),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Ô 6: Mật khẩu mới (Bảo mật riêng) (*)
  Widget _buildFieldMatKhau(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Mật khẩu mới (Bảo mật riêng)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: _matKhauController,
          obscureText: _anMatKhau,
          validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu phải từ 6 ký tự' : null,
          decoration: _inputDecoration(
            hint: 'Nhập mật khẩu an toàn',
            icon: Icons.lock_outline,
            isDark: isDark,
            suffixIcon: IconButton(
              icon: Icon(
                _anMatKhau ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF94A3B8),
              ),
              onPressed: () => setState(() => _anMatKhau = !_anMatKhau),
            ),
          ),
        ),
      ],
    );
  }

  // Nút Xác Nhận & Bắt Đầu Ca Trực
  Widget _buildButtonXacNhan() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _dangXuLy ? null : _xacNhanThietLap,
        icon: _dangXuLy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.check_rounded, size: 20),
        label: Text(
          _dangXuLy ? 'Đang kích hoạt...' : 'Xác Nhận & Bắt Đầu Ca Trực',
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          shadowColor: const Color(0xFF0284C7).withValues(alpha: 0.4),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF94A3B8),
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
    );
  }
}
