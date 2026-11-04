import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'letan_quenmatkhau_screen_c1.dart';

class LetanDoimatkhauScreenC1 extends StatefulWidget {
  final String email;

  const LetanDoimatkhauScreenC1({
    super.key,
    required this.email,
  });

  @override
  State<LetanDoimatkhauScreenC1> createState() => _LetanDoimatkhauScreenC1State();
}

class _LetanDoimatkhauScreenC1State extends State<LetanDoimatkhauScreenC1> {
  final _formKey = GlobalKey<FormState>();
  final _matKhauHienTaiController = TextEditingController();
  final _matKhauMoiController = TextEditingController();
  final _xacNhanMatKhauController = TextEditingController();

  bool _anMatKhauCu = true;
  bool _anMatKhauMoi = true;
  bool _anXacNhan = true;
  bool _dangXuLy = false;

  @override
  void dispose() {
    _matKhauHienTaiController.dispose();
    _matKhauMoiController.dispose();
    _xacNhanMatKhauController.dispose();
    super.dispose();
  }

  Future<void> _luuMatKhau() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _dangXuLy = true);
    final maNv = DuLieuProfileMauC1.thongTinHienTai.maNhanVien;
    final passCu = _matKhauHienTaiController.text.trim();
    final passMoi = _matKhauMoiController.text.trim();

    try {
      await FirebaseServiceC1.doiMatKhauNhanVien(
        maNhanVien: maNv,
        matKhauHienTai: passCu,
        matKhauMoi: passMoi,
      );

      if (!mounted) return;
      setState(() => _dangXuLy = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Đổi mật khẩu thành công trên Firebase!'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
      Navigator.pop(context);
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Đổi Mật Khẩu',
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
                // Thẻ thông tin tài khoản Gmail đăng nhập
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFF5E6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lock_outline, color: Color(0xFFFF9500), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tài khoản đăng nhập',
                              style: TextStyle(
                                color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.email,
                              style: TextStyle(
                                color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Form nhập mật khẩu
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        label: 'Mật khẩu hiện tại',
                        controller: _matKhauHienTaiController,
                        obscureText: _anMatKhauCu,
                        onToggleVisibility: () => setState(() => _anMatKhauCu = !_anMatKhauCu),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Vui lòng nhập mật khẩu hiện tại';
                          }
                          return null;
                        },
                        isDark: isDark,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LetanQuenmatkhauScreenC1(emailMacDinh: widget.email),
                              ),
                            );
                          },
                          child: const Text(
                            'Quên mật khẩu?',
                            style: TextStyle(
                              color: Color(0xFFFF9500),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        label: 'Mật khẩu mới',
                        controller: _matKhauMoiController,
                        obscureText: _anMatKhauMoi,
                        onToggleVisibility: () => setState(() => _anMatKhauMoi = !_anMatKhauMoi),
                        validator: (val) {
                          if (val == null || val.length < 6) {
                            return 'Mật khẩu mới phải có ít nhất 6 ký tự';
                          }
                          return null;
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Xác nhận mật khẩu mới',
                        controller: _xacNhanMatKhauController,
                        obscureText: _anXacNhan,
                        onToggleVisibility: () => setState(() => _anXacNhan = !_anXacNhan),
                        validator: (val) {
                          if (val != _matKhauMoiController.text) {
                            return 'Mật khẩu xác nhận không khớp';
                          }
                          return null;
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Nút Xác nhận thay đổi
                ElevatedButton(
                  onPressed: _dangXuLy ? null : _luuMatKhau,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9500),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _dangXuLy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Xác Nhận Thay Đổi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(height: 12),

                // Nút Hủy
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                    minimumSize: const Size(double.infinity, 52),
                    side: BorderSide(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Hủy Bỏ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
          ),
          decoration: InputDecoration(
            hintText: 'Nhập $label...',
            hintStyle: TextStyle(
              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
              fontSize: 13,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                size: 20,
              ),
              onPressed: onToggleVisibility,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F2F7),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: isDark ? const BorderSide(color: AppDesignSystemC1.darkBorder) : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: isDark ? const BorderSide(color: AppDesignSystemC1.darkBorder) : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF9500), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
