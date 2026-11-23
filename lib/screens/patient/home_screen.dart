import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_routes.dart';
import '../../models/appointment_item.dart';
import '../../models/family_profile_model.dart';
import '../../models/lichhen_model.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_profile_provider.dart';
import '../../providers/lich_hen_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/family_widgets.dart';

/// AppTheme: bảng màu dùng chung cho màn Trang chủ.
class AppTheme {
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFFDBEAFE);
  static const Color bg = Color(0xFFF4F7FB);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textGrey = Color(0xFF64748B);
  static const Color border = Color(0xFFE6EBF2);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
}

/// HomeScreen: tab Trang chủ. Hiển thị lời chào, hồ sơ đang xem, ô tìm bệnh viện,
/// lịch khám sắp tới, các dịch vụ nhanh, mẹo sức khỏe và thông báo gần đây.
class HomeScreen extends StatefulWidget {
  /// Chuyển tab của PatientMainScreen; null thì mở màn hình riêng bằng route.
  final ValueChanged<int>? onSelectTab;

  const HomeScreen({super.key, this.onSelectTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadProfiles();
      _loadBookings();
      _loadNotifications();
    });
  }

  // ───────────── Tải dữ liệu ─────────────

  /// _loadUser: nếu đã đăng nhập mà chưa có thông tin user thì tải từ server.
  Future<void> _loadUser() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null && FirebaseAuth.instance.currentUser != null) {
      await auth.fetchCurrentUser();
    }
  }

  /// _loadProfiles: tải thông tin user rồi danh sách hồ sơ (chính chủ + người thân).
  Future<void> _loadProfiles() async {
    await _loadUser();
    if (!mounted) return;
    await context.read<FamilyProfileProvider>().load(
      context.read<AuthProvider>().user,
    );
  }

  /// _loadBookings: tải danh sách lịch hẹn của người dùng.
  Future<void> _loadBookings() async {
    final id = FirebaseAuth.instance.currentUser?.uid;
    if (id != null) await context.read<LichHenProvider>().loadMyBookings(id);
  }

  /// _loadNotifications: bắt đầu lắng nghe thông báo realtime từ Firestore.
  void _loadNotifications() {
    final id = FirebaseAuth.instance.currentUser?.uid;
    if (id != null) context.read<NotificationProvider>().listen(id);
  }

  // ───────────── Lịch sắp tới ─────────────

  /// _findUpcoming: chọn lịch sắp tới để hiển thị. Chỉ lấy lịch chờ duyệt/đã xác nhận
  /// từ hôm nay trở đi; ưu tiên đã xác nhận, rồi ngày gần nhất, rồi giờ sớm nhất.
  LichHenModel? _findUpcoming(List<LichHenModel> bookings) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    const showStatuses = {'1', '2'};

    final upcoming = bookings.where((b) {
      final d = b.ngayDat;
      return showStatuses.contains(b.trangThaiId.toString()) &&
          d != null &&
          !d.isBefore(startOfDay);
    }).toList();
    if (upcoming.isEmpty) return null;

    upcoming.sort((a, b) {
      final aConfirmed = a.trangThaiId.toString() == '2' ? 0 : 1;
      final bConfirmed = b.trangThaiId.toString() == '2' ? 0 : 1;
      if (aConfirmed != bConfirmed) return aConfirmed.compareTo(bConfirmed);

      final byDate = a.ngayDat!.compareTo(b.ngayDat!);
      if (byDate != 0) return byDate;

      return _parseTimeToMinutes(a.gioBatDau)
          .compareTo(_parseTimeToMinutes(b.gioBatDau));
    });
    return upcoming.first;
  }

  /// _parseTimeToMinutes: "HH:mm" -> số phút trong ngày; thiếu hoặc sai định dạng thì trả 9999 (xếp cuối).
  int _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 9999;
    final parts = timeStr.split(':');
    if (parts.length != 2) return 9999;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  /// _convertToAppointmentItem: đổi LichHenModel sang MyAppointmentItem để mở màn chi tiết.
  MyAppointmentItem _convertToAppointmentItem(LichHenModel model) {
    final d = model.ngayDat;
    final dateStr = d != null
        ? '${d.day.toString().padLeft(2, '0')}/'
              '${d.month.toString().padLeft(2, '0')}/${d.year}'
        : '—';
    final timeStr = (model.gioBatDau != null && model.gioKetThuc != null)
        ? '${model.gioBatDau} - ${model.gioKetThuc}'
        : (model.gioDuKien.isNotEmpty ? model.gioDuKien : 'Đang cập nhật');
    final khoa = model.tenKhoa ?? 'Chuyên khoa';

    return MyAppointmentItem(
      id: model.id,
      hospitalName: model.tenBenhVien ?? 'Bệnh viện',
      subtitle: '$khoa · $timeStr',
      status: statusFromTrangThaiId(model.trangThaiId),
      departmentName: khoa,
      dateLabel: dateStr,
      timeLabel: timeStr,
    );
  }

  // ───────────── Điều hướng & thao tác ─────────────

  void _openBooking() => Navigator.pushNamed(context, AppRoutes.hospitalFilter);

  void _openAppointmentDetail(MyAppointmentItem appointment) {
    Navigator.pushNamed(
      context,
      AppRoutes.appointmentDetail,
      arguments: appointment,
    );
  }

  /// _openQr: mở vé QR của lịch sắp tới (của hồ sơ đang xem); chưa có lịch thì báo.
  void _openQr() {
    final bookings = context.read<LichHenProvider>().activeBookingsOf(
      context.read<FamilyProfileProvider>().currentId,
    );
    final upcoming = _findUpcoming(bookings);

    if (upcoming == null) {
      context.showAppSnackBar(
        title: 'Chưa có lịch khám',
        message: 'Hồ sơ này chưa có lịch khám sắp tới để xuất trình mã QR.',
        type: SnackBarType.warning,
      );
      return;
    }
    Navigator.pushNamed(context, AppRoutes.qrTicket, arguments: upcoming);
  }

  /// _openTab: chuyển sang tab [index] của PatientMainScreen, hoặc mở màn hình riêng ([fallback]).
  void _openTab(int index, VoidCallback fallback) {
    final onSelectTab = widget.onSelectTab;
    if (onSelectTab != null) {
      onSelectTab(index);
    } else {
      fallback();
    }
  }

  void _openMyAppointments() => _openTab(
    1,
    () => Navigator.pushNamed(context, AppRoutes.myAppointments),
  );

  void _openNotifications() => _openTab(
    3,
    () => Navigator.pushNamed(context, AppRoutes.patientMain, arguments: 3),
  );

  void _openProfile() =>
      _openTab(4, () => Navigator.pushNamed(context, AppRoutes.editProfile));

  void _openAppointmentTracking() =>
      Navigator.pushNamed(context, AppRoutes.appointmentTracking);

  void _openFamilyProfiles() =>
      Navigator.pushNamed(context, AppRoutes.familyProfiles);

  /// _onRefresh: kéo để làm mới user, hồ sơ, lịch hẹn và thông báo.
  Future<void> _onRefresh(
    AuthProvider auth,
    NotificationProvider notifications,
  ) async {
    await auth.fetchCurrentUser();
    if (!mounted) return;
    await context.read<FamilyProfileProvider>().load(auth.user, force: true);
    await _loadBookings();
    await notifications.refresh();
  }

  // ───────────── Giao diện ─────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hoTen = auth.user?.hoTen;
    final userName = (hoTen != null && hoTen.trim().isNotEmpty)
        ? hoTen
        : (FirebaseAuth.instance.currentUser?.displayName ?? 'Bệnh nhân');

    final currentProfile = context.watch<FamilyProfileProvider>().current;
    final upcoming = _findUpcoming(
      context.watch<LichHenProvider>().activeBookingsOf(currentProfile?.id),
    );
    final notifications = context.watch<NotificationProvider>();
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: RefreshIndicator(
        color: AppTheme.primary,
        edgeOffset: topInset,
        onRefresh: () => _onRefresh(auth, notifications),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(
                topInset: topInset,
                userName: userName,
                unreadCount: notifications.unreadCount,
                profile: currentProfile,
                upcoming: upcoming,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(title: 'Dịch vụ nhanh'),
                    const SizedBox(height: 14),
                    _buildQuickServices(),
                    const SizedBox(height: 28),
                    const _HealthTipCard(),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'Thông báo gần đây',
                      actionText: 'Xem tất cả',
                      onAction: _openNotifications,
                      badge: notifications.unreadCount,
                    ),
                    const SizedBox(height: 14),
                    ..._buildRecentNotices(notifications),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// _buildHero: nền gradient chứa lời chào, ô tìm kiếm và thẻ lịch sắp tới (hoặc thẻ trống).
  Widget _buildHero({
    required double topInset,
    required String userName,
    required int unreadCount,
    required FamilyProfileModel? profile,
    required LichHenModel? upcoming,
  }) {
    final profileLabel = profile == null
        ? null
        : (profile.isSelf ? 'Tôi' : '${profile.quanHe} - ${profile.hoTen}');

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topInset + 262,
          child: const _HeroBackground(),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeHeader(
                userName: userName,
                unreadCount: unreadCount,
                onBellTap: _openNotifications,
                onAvatarTap: _openProfile,
                profileLabel: profileLabel,
                onSwitchTap: () => showProfileSwitcherSheet(context),
              ),
              const SizedBox(height: 18),
              _SearchBar(onTap: _openBooking),
              const SizedBox(height: 22),
              upcoming == null
                  ? _EmptyUpcomingCard(onBook: _openBooking)
                  : _UpcomingCard(
                      appointment: upcoming,
                      onTap: () => _openAppointmentDetail(
                        _convertToAppointmentItem(upcoming),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  /// _buildQuickServices: lưới 2 hàng x 3 ô dịch vụ nhanh.
  Widget _buildQuickServices() {
    final services = <_ServiceItem>[
      _ServiceItem(
        icon: Icons.add_circle_rounded,
        label: 'Đặt lịch\nkhám',
        color: AppTheme.primary,
        onTap: _openBooking,
      ),
      _ServiceItem(
        icon: Icons.event_note_rounded,
        label: 'Lịch khám\ncủa tôi',
        color: const Color(0xFF8B5CF6),
        onTap: _openMyAppointments,
      ),
      _ServiceItem(
        icon: Icons.monitor_heart_rounded,
        label: 'Theo dõi\ntrực tiếp',
        color: const Color(0xFF0EA5E9),
        onTap: _openAppointmentTracking,
      ),
      _ServiceItem(
        icon: Icons.qr_code_2_rounded,
        label: 'Mã QR\ncủa tôi',
        color: AppTheme.success,
        onTap: _openQr,
      ),
      _ServiceItem(
        icon: Icons.groups_rounded,
        label: 'Quản lý\nngười thân',
        color: const Color(0xFFEC4899),
        onTap: _openFamilyProfiles,
      ),
      _ServiceItem(
        icon: Icons.assignment_ind_rounded,
        label: 'Hồ sơ\ncá nhân',
        color: AppTheme.warning,
        onTap: _openProfile,
      ),
    ];

    Widget row(List<_ServiceItem> items) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: items[i]),
          ],
        ],
      ),
    );

    return Column(
      children: [
        row(services.sublist(0, 3)),
        const SizedBox(height: 12),
        row(services.sublist(3)),
      ],
    );
  }

  /// _buildRecentNotices: tối đa 3 thông báo mới nhất (hoặc vòng xoay / khung trống).
  List<Widget> _buildRecentNotices(NotificationProvider provider) {
    final recent = provider.notifications.take(3).toList();

    if (provider.isLoading && recent.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (recent.isEmpty) return const [_EmptyNotices()];

    return [
      for (final notice in recent)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _HomeNoticeTile(
            notification: notice,
            unread: notice.status == NotificationStatus.unread,
            onTap: () {
              provider.markRead(notice.id);
              _openNotifications();
            },
          ),
        ),
    ];
  }
}

// ═════════════ Widget con ═════════════

/// _HeroBackground: nền gradient xanh bo cong kèm vòng tròn mờ và chữ thập y tế phía sau lời chào.
class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(bottom: Radius.circular(36));

    Widget cross(double top, double? left, double? right, double size) =>
        Positioned(
          top: top,
          left: left,
          right: right,
          child: Icon(
            Icons.add_rounded,
            size: size,
            color: Colors.white.withOpacity(0.10),
          ),
        );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), AppTheme.primaryDark, Color(0xFF3B82F6)],
        ),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned(top: -60, right: -50, child: _Bubble(210, 0.09)),
            const Positioned(bottom: 20, left: -70, child: _Bubble(170, 0.06)),
            cross(120, null, 70, 30),
            cross(190, 36, null, 22),
          ],
        ),
      ),
    );
  }
}

/// _HomeHeader: hàng đầu gồm avatar (mở hồ sơ), lời chào theo giờ, tên, nhãn đổi hồ sơ đang xem
/// và nút chuông thông báo.
class _HomeHeader extends StatelessWidget {
  final String userName;
  final int unreadCount;
  final VoidCallback onBellTap;
  final VoidCallback onAvatarTap;
  final String? profileLabel;
  final VoidCallback onSwitchTap;

  const _HomeHeader({
    required this.userName,
    required this.unreadCount,
    required this.onBellTap,
    required this.onAvatarTap,
    required this.onSwitchTap,
    this.profileLabel,
  });

  @override
  Widget build(BuildContext context) {
    final words = userName.trim().split(RegExp(r'\s+'));
    final initial = words.isNotEmpty && words.last.isNotEmpty
        ? words.last[0].toUpperCase()
        : '?';

    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFDBEAFE)],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()} 👋',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              if (profileLabel != null) ...[
                const SizedBox(height: 6),
                _buildSwitchChip(),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        _BellButton(count: unreadCount, onTap: onBellTap),
      ],
    );
  }

  /// _buildSwitchChip: nhãn "Đang xem: ..." bấm để đổi hồ sơ.
  Widget _buildSwitchChip() {
    return GestureDetector(
      onTap: onSwitchTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'Đang xem: $profileLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

/// _BellButton: nút chuông có số thông báo chưa đọc (99+ nếu quá 99).
class _BellButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _BellButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// _SearchBar: thanh tìm kiếm giả; bấm vào mở màn tìm bệnh viện.
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppTheme.primary, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tìm bệnh viện, chuyên khoa...',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 19,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// _UpcomingCard: thẻ lịch khám sắp tới gồm đếm ngược, khoa, bệnh viện, người khám (nếu là
/// người thân), bảng ngày / giờ / số thứ tự, trạng thái và nút xem chi tiết.
class _UpcomingCard extends StatelessWidget {
  final LichHenModel appointment;
  final VoidCallback onTap;

  const _UpcomingCard({required this.appointment, required this.onTap});

  IconData _statusIcon(AppointmentStatus status) {
    if (status == AppointmentStatus.approved) return Icons.check_circle_rounded;
    if (status == AppointmentStatus.cancelled) return Icons.cancel_rounded;
    return Icons.schedule_rounded;
  }

  Widget _vDivider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(vertical: 4),
    color: Colors.white.withOpacity(0.25),
  );

  /// _iconLine: dòng nhỏ gồm icon và chữ (bệnh viện, người khám).
  Widget _iconLine(IconData icon, String text, {double alpha = 0.88, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.85)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: Colors.white.withOpacity(alpha),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final date = a.ngayDat;
    final status = statusFromTrangThaiId(a.trangThaiId);
    final timeText = (a.gioBatDau != null && a.gioKetThuc != null)
        ? '${a.gioBatDau}–${a.gioKetThuc}'
        : (a.gioDuKien.isNotEmpty ? a.gioDuKien : 'Đang cập nhật');
    final queueText = a.soThuTu > 0 ? '#${a.soThuTu}' : 'Chờ cấp';
    final isForRelative =
        a.profileKey != FamilyProfileModel.selfId &&
        (a.tenNguoiKham ?? '').isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withOpacity(0.35),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                const Positioned(top: -40, right: -30, child: _Bubble(140, 0.10)),
                const Positioned(bottom: -60, left: -30, child: _Bubble(160, 0.07)),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nhãn + đếm ngược
                      Row(
                        children: [
                          const _GlassChip(
                            icon: Icons.event_available_rounded,
                            text: 'Lịch khám sắp tới',
                            small: true,
                          ),
                          const Spacer(),
                          if (date != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _countdownLabel(date),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Khoa + bệnh viện + người khám
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.medical_services_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.tenKhoa ?? 'Khoa chưa cập nhật',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    height: 1.2,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                if (a.tenBenhVien != null)
                                  _iconLine(
                                    Icons.local_hospital_rounded,
                                    a.tenBenhVien!,
                                  ),
                                if (isForRelative)
                                  _iconLine(
                                    Icons.person_rounded,
                                    'Khám cho: ${a.tenNguoiKham}'
                                    '${(a.quanHe ?? '').isNotEmpty ? ' (${a.quanHe})' : ''}',
                                    alpha: 0.95,
                                    bold: true,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Bảng thông tin: Ngày | Giờ | STT
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.20)),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              _InfoCell(
                                icon: Icons.calendar_today_rounded,
                                label: 'NGÀY',
                                value: date != null
                                    ? _formatDateShort(date)
                                    : '--/--',
                              ),
                              _vDivider(),
                              _InfoCell(
                                icon: Icons.access_time_rounded,
                                label: 'GIỜ KHÁM',
                                value: timeText,
                              ),
                              _vDivider(),
                              _InfoCell(
                                icon: Icons.confirmation_number_rounded,
                                label: 'SỐ THỨ TỰ',
                                value: queueText,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Trạng thái + xem chi tiết
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: status.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: status.borderColor,
                                width: 1.3,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _statusIcon(status),
                                  size: 15,
                                  color: status.foreground,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  status.label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: status.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Xem chi tiết',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// _InfoCell: một ô trong bảng thông tin của thẻ lịch sắp tới (nhãn nhỏ + giá trị).
class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11, color: Colors.white.withOpacity(0.75)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// _EmptyUpcomingCard: thẻ hiển thị khi chưa có lịch sắp tới, kèm nút "Đặt lịch khám ngay".
class _EmptyUpcomingCard extends StatelessWidget {
  final VoidCallback onBook;

  const _EmptyUpcomingCard({required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.14),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const _RingIcon(
            icon: Icons.calendar_month_rounded,
            outer: 96,
            inner: 70,
            iconSize: 36,
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có lịch khám sắp tới',
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Đặt lịch khám ngay để được chăm sóc sức khỏe\nvà nhận số thứ tự sớm nhất.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textGrey),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onBook,
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text(
                'Đặt lịch khám ngay',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// _RingIcon: icon trong hai vòng tròn đồng tâm mờ (dùng cho khung trống).
class _RingIcon extends StatelessWidget {
  final IconData icon;
  final double outer;
  final double inner;
  final double iconSize;

  const _RingIcon({
    required this.icon,
    required this.outer,
    required this.inner,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: outer,
          height: outer,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withOpacity(0.07),
          ),
        ),
        Container(
          width: inner,
          height: inner,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withOpacity(0.13),
          ),
          child: Icon(icon, size: iconSize, color: AppTheme.primary),
        ),
      ],
    );
  }
}

/// _SectionTitle: tiêu đề mục có thanh màu, badge số (nếu có) và nút hành động bên phải.
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final int badge;

  const _SectionTitle({
    required this.title,
    this.actionText,
    this.onAction,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppTheme.textDark,
          ),
        ),
        if (badge > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.danger,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge > 9 ? '9+' : '$badge',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              children: [
                Text(
                  actionText!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// _ServiceItem: ô dịch vụ nhỏ gồm biểu tượng nền nhạt và nhãn 2 dòng.
class _ServiceItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ServiceItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.22), color.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 25, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// _HealthTipCard: thẻ "Mẹo sức khỏe hôm nay", mẹo đổi theo ngày trong năm.
class _HealthTipCard extends StatelessWidget {
  const _HealthTipCard();

  static const _tips = [
    'Uống đủ nước mỗi ngày giúp cơ thể thải độc và luôn khỏe mạnh.',
    'Ngủ đủ 7–8 giờ mỗi đêm giúp tim mạch và hệ miễn dịch hoạt động tốt hơn.',
    'Đến sớm 15 phút để hoàn tất thủ tục trước giờ khám.',
    'Mang theo CCCD và thẻ BHYT khi đi khám để được hưởng quyền lợi.',
    'Vận động nhẹ 30 phút mỗi ngày giúp tăng cường sức khỏe và tinh thần.',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final tip = _tips[dayOfYear % _tips.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6FBF3), Color(0xFFEFF8FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.success.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF34D399), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.success.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MẸO SỨC KHỎE HÔM NAY',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFF047857),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// _EmptyNotices: khung hiển thị khi chưa có thông báo nào.
class _EmptyNotices extends StatelessWidget {
  const _EmptyNotices();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withOpacity(0.10),
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 28,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chưa có thông báo nào',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Thông báo từ bệnh viện sẽ hiển thị ở đây.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }
}

/// _HomeNoticeTile: thẻ thông báo gọn ở trang chủ (loại, tiêu đề, nội dung, bệnh viện, số thứ tự).
class _HomeNoticeTile extends StatelessWidget {
  final NotificationModel notification;
  final bool unread;
  final VoidCallback? onTap;

  const _HomeNoticeTile({
    required this.notification,
    this.unread = false,
    this.onTap,
  });

  /// _style: icon, màu và nhãn tương ứng với loại thông báo.
  ({IconData icon, Color color, String label}) get _style {
    switch (notification.type) {
      case NotificationType.appointmentConfirmed:
        return (
          icon: Icons.task_alt_rounded,
          color: AppTheme.primary,
          label: 'XÁC NHẬN LỊCH',
        );
      case NotificationType.appointmentCancelled:
        return (
          icon: Icons.not_interested_rounded,
          color: AppTheme.danger,
          label: 'HỦY LỊCH',
        );
      case NotificationType.appointmentReminder:
        return (
          icon: Icons.alarm_rounded,
          color: AppTheme.warning,
          label: 'NHẮC LỊCH',
        );
      case NotificationType.appointmentCompleted:
        return (
          icon: Icons.workspace_premium_rounded,
          color: AppTheme.success,
          label: 'HOÀN THÀNH',
        );
      case NotificationType.roomPaused:
        return (
          icon: Icons.pause_circle_rounded,
          color: AppTheme.warning,
          label: 'PHÒNG TẠM DỪNG',
        );
      case NotificationType.roomResumed:
        return (
          icon: Icons.play_circle_rounded,
          color: AppTheme.success,
          label: 'TIẾP TỤC KHÁM',
        );
      case NotificationType.roomClosed:
        return (
          icon: Icons.lock_rounded,
          color: const Color(0xFF475569),
          label: 'PHÒNG ĐÓNG CỬA',
        );
      case NotificationType.system:
        return (
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFF8B5CF6),
          label: 'HỆ THỐNG',
        );
    }
  }

  /// _timeAgo: "Vừa xong", "x phút trước", "x giờ trước", "Hôm qua", ...
  String get _timeAgo {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${diff.inDays ~/ 7} tuần trước';
  }

  bool _has(String? v) => v != null && v.isNotEmpty;

  /// _chip: nhãn nhỏ gồm icon và chữ (bệnh viện, số thứ tự).
  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textGrey),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final color = style.color;
    final hospital = notification.hospitalName;
    final queue = notification.queueNumber;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unread ? color.withOpacity(0.32) : AppTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: unread ? color.withOpacity(0.12) : Colors.black.withOpacity(0.03),
            blurRadius: unread ? 16 : 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Material(
          color: unread
              ? Color.alphaBlend(color.withOpacity(0.05), AppTheme.surface)
              : AppTheme.surface,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    color: unread ? color : color.withOpacity(0.22),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: unread
                                    ? [color, color.withOpacity(0.72)]
                                    : [color.withOpacity(0.18), color.withOpacity(0.07)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              style.icon,
                              size: 24,
                              color: unread ? Colors.white : color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        style.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (unread)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: const BoxDecoration(
                                          color: AppTheme.danger,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Text(
                                      _timeAgo,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.25,
                                    fontWeight:
                                        unread ? FontWeight.w800 : FontWeight.w700,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: AppTheme.textGrey,
                                  ),
                                ),
                                if (_has(hospital) || _has(queue)) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (_has(hospital))
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 170,
                                          ),
                                          child: _chip(
                                            Icons.local_hospital_rounded,
                                            hospital!,
                                          ),
                                        ),
                                      if (_has(queue))
                                        _chip(
                                          Icons.confirmation_number_outlined,
                                          'STT $queue',
                                        ),
                                    ],
                                  ),
                                ],
                              ],
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
        ),
      ),
    );
  }
}

/// _GlassChip: nhãn bo tròn nền trắng mờ (kiểu kính) gồm icon và chữ.
class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool small;

  const _GlassChip({
    required this.icon,
    required this.text,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: small ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(small ? 0.20 : 0.18),
        borderRadius: BorderRadius.circular(small ? 20 : 12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 15 : 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: small ? 12 : 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// _Bubble: hình tròn trắng mờ trang trí nền.
class _Bubble extends StatelessWidget {
  final double size;
  final double opacity;

  const _Bubble(this.size, this.opacity);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

// ═════════════ Hàm tiện ích ═════════════

/// _formatDateShort: DateTime -> "dd/MM".
String _formatDateShort(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// _countdownLabel: "Hôm nay", "Ngày mai" hoặc "Còn n ngày" tính từ hôm nay đến [date].
String _countdownLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(date.year, date.month, date.day).difference(today).inDays;
  if (days <= 0) return 'Hôm nay';
  if (days == 1) return 'Ngày mai';
  return 'Còn $days ngày';
}

/// _greeting: lời chào theo giờ trong ngày.
String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'Chào buổi sáng';
  if (hour < 14) return 'Chào buổi trưa';
  if (hour < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
}