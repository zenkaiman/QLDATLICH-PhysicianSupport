import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import '../auth/login_screen.dart';
import 'letan_capnhat_profile_screen_c1.dart';
import 'letan_doimatkhau_screen_c1.dart';
import 'letan_quenmatkhau_screen_c1.dart';

class LetanProfileTabC1 extends StatefulWidget {
  final VoidCallback? onDangXuat;
  final String? tenKhoaHienTai;

  const LetanProfileTabC1({
    super.key,
    this.onDangXuat,
    this.tenKhoaHienTai,
  });

  @override
  State<LetanProfileTabC1> createState() => _LetanProfileTabC1State();
}

class _LetanProfileTabC1State extends State<LetanProfileTabC1> {
  late ThongTinLeTanC1 _thongTin;

  @override
  void initState() {
    super.initState();
    _thongTin = DuLieuProfileMauC1.thongTinHienTai;
    if (widget.tenKhoaHienTai != null && widget.tenKhoaHienTai!.isNotEmpty) {
      _thongTin = _thongTin.copyWith(khoa: widget.tenKhoaHienTai);
    }
    // 1. Tự động đọc dữ liệu nhân viên mới nhất trực tiếp từ Firestore NhanVien
    FirebaseServiceC1.layThongTinNhanVienTuFirestore(_thongTin.maNhanVien).then((data) {
      if (mounted && data != null) {
        setState(() {
          _thongTin = _thongTin.copyWith(
            maNhanVien: (data['ma_nhan_vien'] ?? data['ma_tai_khoan'] ?? _thongTin.maNhanVien).toString(),
            email: (data['email'] ?? _thongTin.email).toString(),
            hoTen: (data['ho_ten'] ?? _thongTin.hoTen).toString(),
            chucVu: (data['chuc_vu'] ?? _thongTin.chucVu).toString(),
            khoa: widget.tenKhoaHienTai ?? (data['khoa'] ?? _thongTin.khoa).toString(),
            tenBenhVien: (data['ten_benh_vien'] ?? data['tenBenhVien'] ?? _thongTin.tenBenhVien).toString(),
            benhVienId: (data['benh_vien_id'] ?? data['ma_benh_vien'] ?? _thongTin.benhVienId).toString(),
          );
          DuLieuProfileMauC1.thongTinHienTai = _thongTin;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant LetanProfileTabC1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tenKhoaHienTai != null && widget.tenKhoaHienTai != oldWidget.tenKhoaHienTai) {
      setState(() {
        _thongTin = _thongTin.copyWith(khoa: widget.tenKhoaHienTai);
        DuLieuProfileMauC1.thongTinHienTai = _thongTin;
      });
    }
  }

  // Điều hướng sang trang chỉnh sửa thông tin và reload lại khi có kết quả mới
  Future<void> _moTrangChinhSua() async {
    final ketQuaMoi = await Navigator.push<ThongTinLeTanC1>(
      context,
      MaterialPageRoute(
        builder: (_) => LetanCapnhatProfileScreenC1(thongTinHienTai: _thongTin),
      ),
    );

    if (ketQuaMoi != null) {
      setState(() {
        _thongTin = ketQuaMoi;
        DuLieuProfileMauC1.thongTinHienTai = ketQuaMoi;
      });
    }
  }

  // Điều hướng sang trang đổi mật khẩu
  void _moTrangDoiMatKhau() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LetanDoimatkhauScreenC1(email: _thongTin.email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          _buildHeaderProfile(),
          const SizedBox(height: 18),
          _buildCardThongTinCaNhan(),
          const SizedBox(height: 16),
          _buildCardTaiKhoanBaoMat(),
          const SizedBox(height: 16),
          _buildCardCaiDatGiaoDien(),
          const SizedBox(height: 20),
          _buildButtonDangXuat(),
        ],
      ),
    );
  }

  // Header Avatar lớn + Tên + Badge Khoa
  Widget _buildHeaderProfile() {
    final initials = _thongTin.hoTen.split(' ').map((e) => e[0]).take(2).join();
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar hình tròn nổi bật
          Stack(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF9500), Color(0xFFFFCC00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials.isNotEmpty ? initials : 'LT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _moTrangChinhSua,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? AppDesignSystemC1.darkSurface : Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tên lễ tân
          Text(
            _thongTin.hoTen,
            style: TextStyle(
              color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),

          // CHỨC VỤ LỚN NẰM NGAY DƯỚI TÊN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.6) : const Color(0xFFFFF5E6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: isDark ? 0.6 : 1.0)),
            ),
            child: Text(
              _thongTin.chucVu,
              style: const TextStyle(
                color: Color(0xFFFF9500),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Khối thông tin chi tiết: Tên, Mã NV, Thuộc khoa, Gmail
  Widget _buildCardThongTinCaNhan() {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thông tin nhân sự',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton.icon(
                onPressed: _moTrangChinhSua,
                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFFF9500)),
                label: const Text(
                  'Chỉnh sửa',
                  style: TextStyle(
                    color: Color(0xFFFF9500),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          Divider(height: 18, color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFF2F2F7)),
          _buildItemInfo(Icons.local_hospital_rounded, 'Bệnh viện', _thongTin.tenBenhVien),
          _buildItemInfo(Icons.person_outline, 'Họ và tên', _thongTin.hoTen),
          _buildItemInfo(Icons.badge_outlined, 'Mã nhân viên', _thongTin.maNhanVien),
          _buildItemInfo(Icons.local_hospital_outlined, 'Thuộc khoa', _thongTin.khoa),
          _buildItemInfo(Icons.alternate_email, 'Gmail tài khoản', _thongTin.email),
        ],
      ),
    );
  }

  // Khối Tài khoản & Đổi mật khẩu / Quên mật khẩu
  Widget _buildCardTaiKhoanBaoMat() {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bảo mật & Mật khẩu',
            style: TextStyle(
              color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // Nút sang trang Đổi mật khẩu
          InkWell(
            onTap: _moTrangDoiMatKhau,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_reset, color: Color(0xFFFF9500), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đổi mật khẩu',
                          style: TextStyle(
                            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Cập nhật mật khẩu bảo mật mới',
                          style: TextStyle(
                            color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93), size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Nút sang trang Quên mật khẩu
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LetanQuenmatkhauScreenC1(emailMacDinh: _thongTin.email),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_lock_outlined, color: Color(0xFF007AFF), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quên mật khẩu?',
                          style: TextStyle(
                            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Gửi mã xác thực qua Gmail (mô phỏng Firebase)',
                          style: TextStyle(
                            color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93), size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemInfo(IconData icon, String label, String value) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93), size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Khối Cài đặt Giao diện (Chế độ Sáng / Tối)
  Widget _buildCardCaiDatGiaoDien() {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final cardBg = isDark ? AppDesignSystemC1.darkSurface : Colors.white;
    final borderCol = isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA);
    final textCol = isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E);
    final subTextCol = isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Giao diện ứng dụng',
            style: TextStyle(
              color: textCol,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark ? Colors.amber : const Color(0xFF0284C7),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chế độ tối (Dark Mode)',
                        style: TextStyle(
                          color: textCol,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isDark ? 'Đang kích hoạt nền tối bảo vệ mắt' : 'Đang sử dụng nền sáng tiêu chuẩn',
                        style: TextStyle(color: subTextCol, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isDark,
                  activeThumbColor: AppDesignSystemC1.primary,
                  onChanged: (val) {
                    AppDesignSystemC1.batTatCheDoSangToi();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // Nút Đăng xuất
  Widget _buildButtonDangXuat() {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xác nhận đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ca làm việc lễ tân?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await FirebaseServiceC1.xoaPhienDangNhap();
                  if (ctx.mounted) Navigator.pop(ctx);
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30), foregroundColor: Colors.white),
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
            SizedBox(width: 8),
            Text(
              'Đăng Xuất Tài Khoản',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
