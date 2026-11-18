import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/patient_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_profile_provider.dart';
import '../../providers/lich_hen_provider.dart';
import '../../config/app_routes.dart';
import '../../utils/app_snackbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Bảng màu
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1E40AF);
  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textGrey = Color(0xFF64748B);
  static const Color _hint = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE6EBF2);
  static const Color _warning = Color(0xFFF59E0B);

  // Màu cho nút / hộp thoại đăng xuất
  static const Color _danger = Color(0xFFDC2626);
  static const Color _dangerBg = Color(0xFFFEF2F2);
  static const Color _dangerBorder = Color(0xFFFECACA);

  // Giấy tờ nhạy cảm: mặc định che bớt, bấm biểu tượng mắt để xem.
  bool _showCccd = false;
  bool _showBhyt = false;

  // Đang đăng xuất (khóa nút, hiện vòng xoay)
  bool _loggingOut = false;

  // ───────────────────────── Đọc dữ liệu từ model ─────────────────────────

  String _str(dynamic v) => (v ?? '').toString().trim();

  // CCCD / BHYT là 2 field mới của model (cccd, soBhyt). Chưa có thì trả về rỗng.
  String _cccdOf(PatientModel? p) {
    try {
      return _str((p as dynamic)?.cccd);
    } catch (_) {
      return '';
    }
  }

  String _bhytOf(PatientModel? p) {
    try {
      return _str((p as dynamic)?.soBhyt);
    } catch (_) {
      return '';
    }
  }

  // Tỉ lệ hoàn thiện hồ sơ (8 mục).
  double _completion(PatientModel? p) {
    final filled = [
      _str(p?.hoTen),
      _str(p?.gioiTinh),
      p?.ngaySinh == null ? '' : 'x',
      _str(p?.soDienThoai),
      _cccdOf(p),
      _bhytOf(p),
      _str(p?.diaChi),
      _str(p?.email),
    ].where((e) => e.isNotEmpty).length;
    return filled / 8;
  }

  // ───────────────────────── Định dạng hiển thị ─────────────────────────

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'BN';
    if (words.length == 1) {
      final w = words[0];
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  String _formatBirthday(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final age =
        now.year -
        d.year -
        ((now.month < d.month || (now.month == d.month && now.day < d.day))
            ? 1
            : 0);
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year} ($age tuổi)';
  }

  String _formatPhone(String v) {
    if (v.length == 10) {
      return '${v.substring(0, 4)} ${v.substring(4, 7)} ${v.substring(7)}';
    }
    return v;
  }

  // Che giữa dãy số, giữ 3 ký tự đầu và cuối.
  String _mask(String v) {
    if (v.length <= 6) return '•' * v.length;
    return '${v.substring(0, 3)}${'•' * (v.length - 6)}${v.substring(v.length - 3)}';
  }

  Future<void> _copyId(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    context.showAppSnackBar(
      message: 'Đã sao chép mã bệnh nhân',
      type: SnackBarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  void _openEdit() => Navigator.pushNamed(context, AppRoutes.editProfile);

  // ───────────────────────── Đăng xuất ─────────────────────────

  Future<bool> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: _danger.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _danger,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đăng xuất khỏi tài khoản?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bạn sẽ cần đăng nhập lại để đặt lịch và theo dõi lịch khám.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: _textGrey,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textDark,
                          side: const BorderSide(color: _border, width: 1.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _danger,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Đăng xuất',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    final confirmed = await _confirmLogout();
    if (!confirmed || !mounted) return;

    // Lấy trước khi await để không dùng context sau khoảng async.
    final auth = context.read<AuthProvider>();
    final family = context.read<FamilyProfileProvider>();
    final lichHen = context.read<LichHenProvider>();
    final navigator = Navigator.of(context);

    setState(() => _loggingOut = true);
    try {
      await auth.logout();
      family.clear();
      lichHen.clearMyBookings();
      // Xóa toàn bộ stack, quay về màn hình đăng nhập.
      navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      context.showAppSnackBar(
        message: 'Đăng xuất thất bại, vui lòng thử lại',
        type: SnackBarType.error,
      );
    }
  }

  // ───────────────────────── Giao diện ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final p = auth.user;
          final cccd = _cccdOf(p);
          final bhyt = _bhytOf(p);
          final phone = _str(p?.soDienThoai);

          return RefreshIndicator(
            onRefresh: () async {
              await auth.fetchCurrentUser();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(p),
                const SizedBox(height: 58),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // ── Thông tin cá nhân ──
                      _SectionCard(
                        title: 'Thông tin cá nhân',
                        icon: Icons.badge_rounded,
                        color: _primary,
                        children: [
                          _InfoRow(
                            icon: Icons.wc_rounded,
                            label: 'Giới tính',
                            value: _str(p?.gioiTinh),
                            color: const Color(0xFF3B82F6),
                          ),
                          _InfoRow(
                            icon: Icons.cake_rounded,
                            label: 'Ngày sinh',
                            value: _formatBirthday(p?.ngaySinh),
                            color: const Color(0xFF10B981),
                            isLast: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Giấy tờ & bảo hiểm ──
                      _SectionCard(
                        title: 'Giấy tờ & bảo hiểm',
                        icon: Icons.verified_user_rounded,
                        color: const Color(0xFFF59E0B),
                        children: [
                          _InfoRow(
                            icon: Icons.credit_card_rounded,
                            label: 'CCCD / CMND',
                            value: cccd.isEmpty
                                ? ''
                                : (_showCccd ? cccd : _mask(cccd)),
                            color: const Color(0xFFF59E0B),
                            onToggleVisible: cccd.isEmpty
                                ? null
                                : () => setState(() => _showCccd = !_showCccd),
                            visible: _showCccd,
                          ),
                          _InfoRow(
                            icon: Icons.health_and_safety_rounded,
                            label: 'Số thẻ BHYT',
                            value: bhyt.isEmpty
                                ? ''
                                : (_showBhyt ? bhyt : _mask(bhyt)),
                            color: const Color(0xFFEF4444),
                            onToggleVisible: bhyt.isEmpty
                                ? null
                                : () => setState(() => _showBhyt = !_showBhyt),
                            visible: _showBhyt,
                            isLast: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Liên hệ ──
                      _SectionCard(
                        title: 'Thông tin liên hệ',
                        icon: Icons.contact_phone_rounded,
                        color: const Color(0xFF8B5CF6),
                        children: [
                          _InfoRow(
                            icon: Icons.phone_rounded,
                            label: 'Số điện thoại',
                            value: _formatPhone(phone),
                            color: const Color(0xFF8B5CF6),
                          ),
                          _InfoRow(
                            icon: Icons.email_rounded,
                            label: 'Email',
                            value: _str(p?.email),
                            color: const Color(0xFF0EA5E9),
                          ),
                          _InfoRow(
                            icon: Icons.location_on_rounded,
                            label: 'Địa chỉ',
                            value: _str(p?.diaChi),
                            color: const Color(0xFFEC4899),
                            multiline: true,
                            isLast: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // import: family_profile_provider, lich_hen_provider
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.familyProfiles,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: _primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(
                                    Icons.groups_rounded,
                                    color: _primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Text(
                                    'Quản lý người thân',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _textDark,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: _hint,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Nút hành động ──
                      _buildActions(),
                      const SizedBox(height: 18),

                      // Cam kết bảo mật
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_rounded, size: 14, color: _hint),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Thông tin của bạn được bảo mật theo quy định của pháp luật',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: _hint),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Đầu trang: nền gradient, họa tiết chữ thập y tế, avatar, tên, mã bệnh nhân,
  // thẻ mức độ hoàn thiện hồ sơ nổi đè lên mép dưới.
  Widget _buildHeader(PatientModel? p) {
    final name = _str(p?.hoTen);
    final id = _str(p?.uid);
    final completion = _completion(p);
    final percent = (completion * 100).round();
    final canPop = Navigator.of(context).canPop();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D47A1), _primaryDark, Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(36),
            ),
            child: Stack(
              children: [
                // Họa tiết trang trí: vòng tròn mờ + chữ thập y tế
                Positioned(top: -50, right: -40, child: _bubble(190, 0.09)),
                Positioned(bottom: 30, left: -60, child: _bubble(150, 0.06)),
                Positioned(
                  top: 70,
                  left: 26,
                  child: Icon(
                    Icons.add_rounded,
                    size: 34,
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),
                Positioned(
                  top: 150,
                  right: 34,
                  child: Icon(
                    Icons.add_rounded,
                    size: 24,
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
                    child: Column(
                      children: [
                        // Thanh tiêu đề
                        Row(
                          children: [
                            if (canPop)
                              _roundButton(
                                Icons.arrow_back_ios_new_rounded,
                                () => Navigator.pop(context),
                              )
                            else
                              const SizedBox(width: 40),
                            const Expanded(
                              child: Text(
                                'Hồ sơ cá nhân',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            _roundButton(Icons.edit_rounded, _openEdit),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Avatar
                        Stack(
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.white, Color(0xFFDBEAFE)],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.55),
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _initials(name),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: _primary,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: _openEdit,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Text(
                          name.isEmpty ? 'Chưa cập nhật họ tên' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Mã bệnh nhân (bấm để sao chép)
                        if (id.isNotEmpty)
                          GestureDetector(
                            onTap: () => _copyId(id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.badge_outlined,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Mã BN: $id',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Thẻ mức độ hoàn thiện hồ sơ nổi đè mép dưới
        Positioned(
          left: 20,
          right: 20,
          bottom: -42,
          child: Material(
            color: Colors.white,
            elevation: 0,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: percent < 100 ? _openEdit : null,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.16),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: CircularProgressIndicator(
                              value: completion,
                              strokeWidth: 5,
                              backgroundColor: _primary.withOpacity(0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                percent == 100
                                    ? const Color(0xFF10B981)
                                    : _primary,
                              ),
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            percent == 100
                                ? 'Hồ sơ đã hoàn thiện'
                                : 'Hoàn thiện hồ sơ của bạn',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            percent == 100
                                ? 'Bạn có thể đặt lịch khám nhanh chóng'
                                : 'Bổ sung thông tin để đặt lịch và xác nhận nhanh hơn',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: _textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (percent < 100)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: _primary,
                        size: 24,
                      )
                    else
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF10B981),
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _openEdit,
            icon: const Icon(Icons.edit_note_rounded, size: 24),
            label: const Text(
              'Cập nhật thông tin cá nhân',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Nút đăng xuất: tông đỏ nhạt, đặt tách riêng cuối cụm nút
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: _danger,
                    ),
                  )
                : const Icon(Icons.logout_rounded, size: 22),
            label: Text(
              _loggingOut ? 'Đang đăng xuất...' : 'Đăng xuất',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _danger,
              disabledForegroundColor: _danger.withOpacity(0.7),
              backgroundColor: _dangerBg,
              side: const BorderSide(color: _dangerBorder, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Thành phần con ─────────────────────────

// Thẻ nhóm thông tin: tiêu đề có icon + danh sách dòng thông tin.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EBF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

// Một dòng thông tin. Giá trị rỗng thì hiện "Chưa cập nhật".
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool multiline;
  final bool isLast;
  final bool visible;
  final VoidCallback? onToggleVisible;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.multiline = false,
    this.isLast = false,
    this.visible = false,
    this.onToggleVisible,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF0F3F8))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.18), color.withOpacity(0.07)],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  empty ? 'Chưa cập nhật' : value,
                  maxLines: multiline ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: empty ? FontWeight.w500 : FontWeight.w700,
                    fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                    color: empty
                        ? const Color(0xFFB0BAC9)
                        : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          if (onToggleVisible != null)
            IconButton(
              onPressed: onToggleVisible,
              visualDensity: VisualDensity.compact,
              tooltip: visible ? 'Ẩn' : 'Hiện',
              icon: Icon(
                visible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: const Color(0xFF64748B),
              ),
            )
          else if (empty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Bổ sung',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
