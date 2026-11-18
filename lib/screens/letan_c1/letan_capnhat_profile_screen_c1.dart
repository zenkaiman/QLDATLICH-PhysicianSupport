import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';

class LetanCapnhatProfileScreenC1 extends StatefulWidget {
  final ThongTinLeTanC1 thongTinHienTai;

  const LetanCapnhatProfileScreenC1({
    super.key,
    required this.thongTinHienTai,
  });

  @override
  State<LetanCapnhatProfileScreenC1> createState() => _LetanCapnhatProfileScreenC1State();
}

class _LetanCapnhatProfileScreenC1State extends State<LetanCapnhatProfileScreenC1> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _hoTenController;
  late TextEditingController _emailMoiController;
  late TextEditingController _matKhauXacNhanController;

  bool _anMatKhauXacNhan = true;
  bool _dangXuLy = false;

  @override
  void initState() {
    super.initState();
    _hoTenController = TextEditingController(text: widget.thongTinHienTai.hoTen);
    _emailMoiController = TextEditingController(text: widget.thongTinHienTai.email);
    _matKhauXacNhanController = TextEditingController();
  }

  @override
  void dispose() {
    _hoTenController.dispose();
    _emailMoiController.dispose();
    _matKhauXacNhanController.dispose();
    super.dispose();
  }

  Future<void> _luuThayDoi() async {
    if (!_formKey.currentState!.validate()) return;

    final emailMoi = _emailMoiController.text.trim();
    final bool coDoiEmail = emailMoi.toLowerCase() != widget.thongTinHienTai.email.trim().toLowerCase();
    final passXacNhan = _matKhauXacNhanController.text.trim();

    if (coDoiEmail && passXacNhan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mật khẩu xác nhận để đổi Gmail!'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _dangXuLy = true);
    final maNv = widget.thongTinHienTai.maNhanVien.trim();
    final hoTenMoi = _hoTenController.text.trim();

    try {
      // 1. Nếu có đổi Gmail -> Xác nhận mật khẩu và đổi Gmail trên Firestore
      if (coDoiEmail) {
        await FirebaseServiceC1.doiEmailNhanVien(
          maNhanVien: maNv,
          emailMoi: emailMoi,
          matKhauXacNhan: passXacNhan,
        );
      }

      // 2. Cập nhật thông tin Họ tên trên Firestore (Cố định chức vụ và khoa theo Bệnh viện phân công)
      final bool isCskh = widget.thongTinHienTai.chucVu.toLowerCase().contains('cskh') ||
          widget.thongTinHienTai.chucVu.toLowerCase().contains('chăm sóc');
      await FirebaseServiceC1.capNhatThongTinNhanVien(
        maNhanVien: maNv,
        hoTen: hoTenMoi,
        chucVu: widget.thongTinHienTai.chucVu,
        role: isCskh ? 'cham_soc_khach_hang' : 'le_tan',
        vaiTroId: isCskh ? 6 : 5,
        khoa: widget.thongTinHienTai.khoa,
        benhVienId: widget.thongTinHienTai.benhVienId,
      );

      // Tự động dọn dẹp Document cấp 1 nếu có
      await FirebaseServiceC1.donDepDocumentNhanVienCap1(maNv);

      final thongTinMoi = widget.thongTinHienTai.copyWith(
        hoTen: hoTenMoi,
        email: emailMoi,
      );

      // Cập nhật bộ nhớ cục bộ
      DuLieuProfileMauC1.thongTinHienTai = thongTinMoi;

      if (!mounted) return;
      setState(() => _dangXuLy = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Cập nhật thông tin thành công trên Firebase!'),
          backgroundColor: Color(0xFF34C759),
        ),
      );

      // Trả về thông tin mới cho trang Profile reload lại
      Navigator.pop(context, thongTinMoi);
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
          'Chỉnh Sửa Thông Tin',
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
                // Khối thông tin cố định do Bệnh viện phân công
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
                      // 1. Mã nhân viên cố định
                      _buildRowThongTinCoDinh(
                        icon: Icons.badge_outlined,
                        label: 'Mã nhân viên (Cố định bởi Bệnh viện)',
                        val: widget.thongTinHienTai.maNhanVien,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),

                      // 2. Chức vụ / Vai trò cố định
                      _buildRowThongTinCoDinh(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Chức vụ / Vai trò (Cố định bởi Bệnh viện)',
                        val: widget.thongTinHienTai.chucVu,
                        subLabel: 'Vai trò phân quyền cố định, không thể tự thay đổi để xem hay duyệt phân hệ khác',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),

                      // 3. Chuyên khoa cố định
                      _buildRowThongTinCoDinh(
                        icon: Icons.local_hospital_outlined,
                        label: 'Thuộc chuyên khoa (Cố định bởi Bệnh viện)',
                        val: widget.thongTinHienTai.khoa,
                        subLabel: 'Bạn chỉ có quyền xem và duyệt đơn của khoa này (hoặc do Bệnh viện phân công lại)',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Khối thông tin được phép chỉnh sửa
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
                        'Thông tin cá nhân được phép sửa',
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Họ và tên
                      _buildTextField(
                        label: 'Họ và tên nhân viên (*)',
                        controller: _hoTenController,
                        icon: Icons.person_outline,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // Gmail đăng nhập
                      _buildTextField(
                        label: 'Địa chỉ Gmail đăng nhập (*)',
                        controller: _emailMoiController,
                        icon: Icons.email_outlined,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Vui lòng nhập Gmail';
                          if (!val.contains('@')) return 'Email không hợp lệ';
                          return null;
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),

                      // Ô nhập Mật khẩu xác nhận khi đổi Gmail
                      TextFormField(
                        controller: _matKhauXacNhanController,
                        obscureText: _anMatKhauXacNhan,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu xác nhận (chỉ cần khi đổi Gmail)',
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                          ),
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _anMatKhauXacNhan ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _anMatKhauXacNhan = !_anMatKhauXacNhan),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Nút Lưu thay đổi
                ElevatedButton(
                  onPressed: _dangXuLy ? null : _luuThayDoi,
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
                          'Lưu Thay Đổi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(height: 12),

                // Nút Hủy bỏ
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

  Widget _buildRowThongTinCoDinh({
    required IconData icon,
    required String label,
    required String val,
    String? subLabel,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFF9500), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 10, color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B)),
                          const SizedBox(width: 2),
                          Text(
                            'Khóa',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  val,
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
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
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93), size: 20),
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
