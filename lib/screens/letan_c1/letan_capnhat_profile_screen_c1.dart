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
  late TextEditingController _maNhanVienController;
  late TextEditingController _emailMoiController;
  late TextEditingController _matKhauXacNhanController;
  late String _khoaDuocChon;

  // 3 Role nhân viên cố định theo cơ sở dữ liệu
  static const List<Map<String, dynamic>> danhSach3Roles = [
    {'role': 'le_tan', 'vai_tro_id': 5, 'ten': 'Lễ tân tiếp đón'},
    {'role': 'cham_soc_khach_hang', 'vai_tro_id': 6, 'ten': 'Chăm sóc khách hàng'},
    {'role': 'ho_tro_bac_si', 'vai_tro_id': 4, 'ten': 'Hỗ trợ bác sĩ'},
  ];

  late String _roleDuocChon;
  late String _tenChucVuDuocChon;
  bool _anMatKhauXacNhan = true;
  bool _dangXuLy = false;

  @override
  void initState() {
    super.initState();
    _hoTenController = TextEditingController(text: widget.thongTinHienTai.hoTen);
    _maNhanVienController = TextEditingController(text: widget.thongTinHienTai.maNhanVien);
    _emailMoiController = TextEditingController(text: widget.thongTinHienTai.email);
    _matKhauXacNhanController = TextEditingController();
    _khoaDuocChon = widget.thongTinHienTai.khoa;

    // Tìm role tương ứng hoặc mặc định là le_tan
    final roleHienTai = danhSach3Roles.firstWhere(
      (r) => widget.thongTinHienTai.chucVu.toLowerCase().contains(r['ten'].toString().toLowerCase()),
      orElse: () => danhSach3Roles[0],
    );
    _roleDuocChon = roleHienTai['role'];
    _tenChucVuDuocChon = roleHienTai['ten'];

    // Tự động tải khoa thật từ Firebase Firestore /Khoa/BO85AxXqDMSB68hnYjzhYfPIxHC2/danh_sach
    FirebaseServiceC1.layDanhSachTenKhoa().then((danhSachFirebase) {
      if (mounted && danhSachFirebase.isNotEmpty) {
        setState(() {
          // Nếu khoa hiện tại vẫn là mock 'Khoa Tim Mạch' hoặc chưa khớp Firebase thì lấy ngay khoa thật đầu tiên trên Firebase (ví dụ: 'KHOA TIM')
          final bool coTrongFirebase = danhSachFirebase.any(
            (k) => k.trim().toLowerCase() == _khoaDuocChon.trim().toLowerCase(),
          );
          if (!coTrongFirebase) {
            _khoaDuocChon = danhSachFirebase.first;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _hoTenController.dispose();
    _maNhanVienController.dispose();
    _emailMoiController.dispose();
    _matKhauXacNhanController.dispose();
    super.dispose();
  }

  void _moModalChonKhoa() {
    final isDark = AppDesignSystemC1.laCheDoToi;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.local_hospital_rounded, color: Color(0xFFFF9500), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Chọn Khoa Tiếp Nhận',
                      style: TextStyle(
                        color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Chọn khoa chuyên môn bạn đang trực ca tiếp nhận',
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirebaseServiceC1.streamDanhSachKhoa(),
                    builder: (context, snapshot) {
                      List<String> danhSachKhoa;
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        danhSachKhoa = snapshot.data!
                            .map((e) => (e['tenKhoa'] ?? '').toString())
                            .where((t) => t.isNotEmpty)
                            .toList();
                      } else {
                        danhSachKhoa = DuLieuProfileMauC1.danhSachKhoaCoSan;
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: danhSachKhoa.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final khoa = danhSachKhoa[index];
                          final bool isSelected = khoa.trim().toLowerCase() == _khoaDuocChon.trim().toLowerCase();

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _khoaDuocChon = khoa;
                              });
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFF5E6) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFFF9500) : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFFF9500) : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.medical_services_outlined,
                                      size: 18,
                                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      khoa,
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xFFFF9500) : const Color(0xFF1C1C1E),
                                        fontSize: 14.5,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFFFF9500), size: 22)
                                  else
                                    const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1), size: 22),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
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
    final maNv = _maNhanVienController.text.trim();
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

      // 2. Cập nhật thông tin Họ tên, Chức vụ (1 trong 3 role), Khoa trên Firestore
      final roleObj = danhSach3Roles.firstWhere((r) => r['role'] == _roleDuocChon);
      await FirebaseServiceC1.capNhatThongTinNhanVien(
        maNhanVien: maNv,
        hoTen: hoTenMoi,
        chucVu: _tenChucVuDuocChon,
        role: _roleDuocChon,
        vaiTroId: roleObj['vai_tro_id'] as int,
        khoa: _khoaDuocChon,
        benhVienId: widget.thongTinHienTai.benhVienId,
      );
      // Tự động dọn dẹp Document cấp 1 nếu có
      await FirebaseServiceC1.donDepDocumentNhanVienCap1(maNv);

      final thongTinMoi = widget.thongTinHienTai.copyWith(
        hoTen: hoTenMoi,
        chucVu: _tenChucVuDuocChon,
        maNhanVien: maNv,
        khoa: _khoaDuocChon,
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
          onPressed: () => Navigator.pop(context), // Hủy bỏ
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

                // Form chỉnh sửa thông tin
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
                      // 1. Mã nhân viên cố định (Read-only)
                      _buildRowThongTinCoDinh(
                        icon: Icons.badge_outlined,
                        label: 'Mã nhân viên (Cố định bởi Bệnh viện)',
                        val: widget.thongTinHienTai.maNhanVien,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // 2. Họ và tên
                      _buildTextField(
                        label: 'Họ và tên nhân viên',
                        controller: _hoTenController,
                        icon: Icons.person_outline,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // 3. Chọn Chức vụ trong 3 role nhân viên (Dropdown Selector)
                      Text(
                        'Chức vụ / Vai trò nhân viên (*)',
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.35)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _roleDuocChon,
                            dropdownColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                            items: danhSach3Roles.map((r) {
                              return DropdownMenuItem<String>(
                                value: r['role'] as String,
                                child: Row(
                                  children: [
                                    const Icon(Icons.workspace_premium_outlined, color: Color(0xFFFF9500), size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      r['ten'] as String,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final selected = danhSach3Roles.firstWhere((r) => r['role'] == val);
                                setState(() {
                                  _roleDuocChon = val;
                                  _tenChucVuDuocChon = selected['ten'] as String;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Cho phép Đổi Gmail
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
                      const SizedBox(height: 16),

                      // 5. Selector chọn Khoa có sẵn của bệnh viện dạng BottomSheet hiện đại
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thuộc khoa tiếp nhận',
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _moModalChonKhoa,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.35), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFF5E6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.local_hospital_rounded, color: Color(0xFFFF9500), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Khoa đang công tác',
                                          style: TextStyle(
                                            color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          _khoaDuocChon,
                                          style: TextStyle(
                                            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE8F4FD),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      children: [
                                        Text(
                                          'Thay đổi',
                                          style: TextStyle(
                                            color: Color(0xFF007AFF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(Icons.keyboard_arrow_right, color: Color(0xFF007AFF), size: 16),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

                // Nút Hủy bỏ (về lại trang Profile, không đổi gì)
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
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                val,
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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
