import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';

class LetanQuenmatkhauScreenC1 extends StatefulWidget {
  final String emailMacDinh;

  const LetanQuenmatkhauScreenC1({
    super.key,
    this.emailMacDinh = '',
  });

  @override
  State<LetanQuenmatkhauScreenC1> createState() => _LetanQuenmatkhauScreenC1State();
}

class _LetanQuenmatkhauScreenC1State extends State<LetanQuenmatkhauScreenC1> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _dichDenController;
  final _otpController = TextEditingController();
  final _matKhauMoiController = TextEditingController();
  final _xacNhanMatKhauController = TextEditingController();

  int _buocHienTai = 1; // 1: Nhập Email/SĐT gửi OTP, 2: Nhập OTP & Đặt mật khẩu mới
  bool _anMatKhauMoi = true;
  bool _anXacNhan = true;
  bool _dangXuLy = false;

  @override
  void initState() {
    super.initState();
    _dichDenController = TextEditingController(text: widget.emailMacDinh.isNotEmpty ? widget.emailMacDinh : 'cuoc2004@gmail.com');
  }

  @override
  void dispose() {
    _dichDenController.dispose();
    _otpController.dispose();
    _matKhauMoiController.dispose();
    _xacNhanMatKhauController.dispose();
    super.dispose();
  }

  // Bước 1: Gửi mã OTP
  Future<void> _guiMaOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _dangXuLy = true);
    final target = _dichDenController.text.trim();
    final bool laEmail = target.contains('@');

    try {
      await FirebaseServiceC1.guiOtpQuenMatKhau(
        dichDen: target,
        laEmail: laEmail,
      );

      if (!mounted) return;
      setState(() {
        _dangXuLy = false;
        _buocHienTai = 2; // Chuyển sang bước 2: Nhập OTP trong app
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Đã gửi mã OTP đến $target! Mã thử nghiệm: 123456',
          ),
          backgroundColor: const Color(0xFF34C759),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangXuLy = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  // Bước 2: Xác thực OTP và đặt mật khẩu mới ngay trong app
  Future<void> _xacThucVaDoiMatKhau() async {
    if (!_formKey.currentState!.validate()) return;

    if (_matKhauMoiController.text != _xacNhanMatKhauController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu xác nhận không trùng khớp!'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _dangXuLy = true);
    final target = _dichDenController.text.trim();
    final otp = _otpController.text.trim();
    final passMoi = _matKhauMoiController.text.trim();

    try {
      await FirebaseServiceC1.xacThucOtpDatLaiMatKhau(
        dichDen: target,
        maOtpNhapVao: otp,
        matKhauMoi: passMoi,
      );

      if (!mounted) return;
      setState(() => _dangXuLy = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Đổi mật khẩu thành công! Bạn có thể đăng nhập ngay bằng mật khẩu mới.'),
          backgroundColor: Color(0xFF34C759),
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.pop(context); // Quay về màn hình đăng nhập
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangXuLy = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Scaffold(
      backgroundColor: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
            size: 20,
          ),
          onPressed: () {
            if (_buocHienTai == 2) {
              setState(() => _buocHienTai = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _buocHienTai == 1 ? 'Quên Mật Khẩu' : 'Nhập Mã OTP & Đổi Mật Khẩu',
          style: TextStyle(
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Khung minh họa icon
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFF5E6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _buocHienTai == 1 ? Icons.mark_email_unread_outlined : Icons.lock_reset_rounded,
                      color: const Color(0xFFFF9500),
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  _buocHienTai == 1 ? 'Khôi Phục Mật Khẩu' : 'Xác Nhận Mã OTP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _buocHienTai == 1
                      ? 'Nhập địa chỉ Gmail hoặc Số điện thoại để nhận mã OTP đổi mật khẩu trực tiếp trong app.'
                      : 'Nhập mã OTP đã gửi đến ${_dichDenController.text.trim()} và tạo mật khẩu mới.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // ==================== BƯỚC 1: NHẬP EMAIL / SĐT ====================
                if (_buocHienTai == 1) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gmail hoặc Số điện thoại (*)',
                          style: TextStyle(
                            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _dichDenController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập Gmail hoặc Số điện thoại';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Nhập Gmail hoặc SĐT nhận OTP...',
                            prefixIcon: const Icon(Icons.contact_mail_outlined, size: 20),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F2F7),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _dangXuLy ? null : _guiMaOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9500),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _dangXuLy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Nhận Mã OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],

                // ==================== BƯỚC 2: NHẬP OTP & ĐẶT MẬT KHẨU MỚI ====================
                if (_buocHienTai == 2) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ô 1: Nhập mã OTP (linh hoạt 4-6 số)
                        const Text(
                          'Mã OTP xác thực (*)',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 8,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 6),
                          validator: (val) => val == null || val.trim().length < 4 ? 'Vui lòng nhập mã OTP hợp lệ' : null,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Nhập mã OTP...',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F2F7),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Ô 2: Mật khẩu mới
                        const Text('Mật khẩu mới (*)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _matKhauMoiController,
                          obscureText: _anMatKhauMoi,
                          validator: (val) => val == null || val.length < 6 ? 'Mật khẩu phải từ 6 ký tự' : null,
                          decoration: InputDecoration(
                            hintText: 'Nhập mật khẩu mới...',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(_anMatKhauMoi ? Icons.visibility_off : Icons.visibility, size: 20),
                              onPressed: () => setState(() => _anMatKhauMoi = !_anMatKhauMoi),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F2F7),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Ô 3: Xác nhận mật khẩu mới
                        const Text('Xác nhận mật khẩu (*)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _xacNhanMatKhauController,
                          obscureText: _anXacNhan,
                          validator: (val) => val != _matKhauMoiController.text ? 'Mật khẩu không khớp' : null,
                          decoration: InputDecoration(
                            hintText: 'Nhập lại mật khẩu mới...',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(_anXacNhan ? Icons.visibility_off : Icons.visibility, size: 20),
                              onPressed: () => setState(() => _anXacNhan = !_anXacNhan),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F2F7),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nút Xác nhận đổi mật khẩu
                  ElevatedButton(
                    onPressed: _dangXuLy ? null : _xacThucVaDoiMatKhau,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9500),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _dangXuLy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Xác Nhận & Đổi Mật Khẩu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),

                  // Nút Gửi lại mã OTP
                  TextButton(
                    onPressed: _dangXuLy ? null : _guiMaOtp,
                    child: const Text('Chưa nhận được mã? Bấm gửi lại OTP', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600)),
                  ),
                ],

                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Quay Lại Đăng Nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
