import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_routes.dart';
import '../../models/family_profile_model.dart'; // [MỚI]
import '../../models/lichhen_model.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_profile_provider.dart'; // [MỚI]
import '../../providers/lich_hen_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/appointment_item.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/family_widgets.dart'; // [MỚI]

// ───────────────────────── THEME & COLORS ─────────────────────────
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

// ───────────────────────── HOME SCREEN ─────────────────────────
class HomeScreen extends StatefulWidget {
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
      if (mounted) {
        _loadProfiles(); // [MỚI] (đã gồm _loadUser)
        _loadBookings();
        _loadNotifications();
      }
    });
  }

  Future<void> _loadUser() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null && FirebaseAuth.instance.currentUser != null) {
      await auth.fetchCurrentUser();
    }
  }

  // [MỚI] Nạp user trước, rồi nạp danh sách hồ sơ (cần PatientModel để đồng bộ hồ sơ chính chủ)
  Future<void> _loadProfiles() async {
    await _loadUser();
    if (!mounted) return;
    await context.read<FamilyProfileProvider>().load(
      context.read<AuthProvider>().user,
    );
  }

  Future<void> _loadBookings() async {
    final id = FirebaseAuth.instance.currentUser?.uid;
    if (id != null) {
      await context.read<LichHenProvider>().loadMyBookings(id);
    }
  }

  // Bắt đầu lắng nghe thông báo từ Firestore
  Future<void> _loadNotifications() async {
    final id = FirebaseAuth.instance.currentUser?.uid;
    if (id != null) {
      context.read<NotificationProvider>().listen(id);
    }
  }

  LichHenModel? _findUpcoming(List<LichHenModel> bookings) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    const showStatuses = {'1', '2'};

    // 1. Lọc ra các lịch hẹn trong tương lai (từ hôm nay trở đi) và có trạng thái hợp lệ
    final upcoming = bookings.where((b) {
      final d = b.ngayDat;
      return showStatuses.contains(b.trangThaiId.toString()) &&
          d != null &&
          !d.isBefore(startOfDay);
    }).toList();

    if (upcoming.isEmpty) return null;

    // 2. Sắp xếp: ưu tiên lịch ĐÃ XÁC NHẬN (2) trước, sau đó mới tới ngày, giờ
    upcoming.sort((a, b) {
      // Ưu tiên 1: trạng thái đã xác nhận ('2') đứng trước chờ duyệt ('1')
      final aConfirmed = a.trangThaiId.toString() == '2' ? 0 : 1;
      final bConfirmed = b.trangThaiId.toString() == '2' ? 0 : 1;
      if (aConfirmed != bConfirmed) return aConfirmed.compareTo(bConfirmed);

      // Ưu tiên 2: ngày khám gần nhất
      final dateCompare = a.ngayDat!.compareTo(b.ngayDat!);
      if (dateCompare != 0) return dateCompare;

      // Ưu tiên 3: giờ bắt đầu sớm hơn
      final timeA = _parseTimeToMinutes(a.gioBatDau);
      final timeB = _parseTimeToMinutes(b.gioBatDau);
      return timeA.compareTo(timeB);
    });

    // 3. Trả về phần tử đầu tiên (chính là lịch gần nhất)
    return upcoming.first;
  }

  // ✅ HÀM HỖ TRỢ: Chuyển đổi chuỗi giờ "07:30" thành tổng số phút để so sánh chính xác
  int _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty)
      return 9999; // Nếu không có giờ, đẩy xuống cuối
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      return (hours * 60) + minutes;
    }
    return 9999; // Nếu định dạng giờ lạ, đẩy xuống cuối
  }

  MyAppointmentItem _convertToAppointmentItem(LichHenModel model) {
    final dateStr = model.ngayDat != null
        ? '${model.ngayDat!.day.toString().padLeft(2, '0')}/'
              '${model.ngayDat!.month.toString().padLeft(2, '0')}/'
              '${model.ngayDat!.year}'
        : '—';

    final timeStr = (model.gioBatDau != null && model.gioKetThuc != null)
        ? '${model.gioBatDau} - ${model.gioKetThuc}'
        : (model.gioDuKien.isNotEmpty ? model.gioDuKien : 'Đang cập nhật');

    return MyAppointmentItem(
      id: model.id,
      hospitalName: model.tenBenhVien ?? 'Bệnh viện',
      subtitle: '${model.tenKhoa ?? 'Chuyên khoa'} · $timeStr',
      status: statusFromTrangThaiId(model.trangThaiId),
      departmentName: model.tenKhoa ?? 'Chuyên khoa',
      dateLabel: dateStr,
      timeLabel: timeStr,
    );
  }

  // ── Điều hướng ──
  void _openBooking() => Navigator.pushNamed(context, AppRoutes.hospitalFilter);

  void _openAppointmentDetail(MyAppointmentItem appointment) {
    Navigator.pushNamed(
      context,
      AppRoutes.appointmentDetail,
      arguments: appointment,
    );
  }

  void _openQr() {
    // [SỬA] Chỉ lấy lịch của hồ sơ đang chọn
    final activeBookings = context.read<LichHenProvider>().activeBookingsOf(
      context.read<FamilyProfileProvider>().currentId,
    );
    final upcomingBooking = _findUpcoming(activeBookings);

    if (upcomingBooking != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.qrTicket,
        arguments: upcomingBooking,
      );
    } else {
      context.showAppSnackBar(
        title: 'Chưa có lịch khám',
        message: 'Hồ sơ này chưa có lịch khám sắp tới để xuất trình mã QR.',
        type: SnackBarType.warning,
      );
    }
  }

  void _openMyAppointments() {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(1);
    } else {
      Navigator.pushNamed(context, AppRoutes.myAppointments);
    }
  }

  void _openNotifications() {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(3);
    } else {
      Navigator.pushNamed(context, AppRoutes.patientMain, arguments: 3);
    }
  }

  void _openProfile() {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(4);
    } else {
      Navigator.pushNamed(context, AppRoutes.editProfile);
    }
  }

  void _openAppointmentTracking() {
    Navigator.pushNamed(context, AppRoutes.appointmentTracking);
  }

  // [MỚI]
  void _openFamilyProfiles() {
    Navigator.pushNamed(context, AppRoutes.familyProfiles);
  }

  Future<void> _copyHotline() async {
    await Clipboard.setData(const ClipboardData(text: '19006868'));
    if (!mounted) return;
    context.showAppSnackBar(
      message: 'Đã sao chép số hotline 1900 6868',
      type: SnackBarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hoTen = auth.user?.hoTen;
    final userName = (hoTen != null && hoTen.trim().isNotEmpty)
        ? hoTen
        : (FirebaseAuth.instance.currentUser?.displayName ?? 'Bệnh nhân');

    // [MỚI] Hồ sơ đang xem
    final family = context.watch<FamilyProfileProvider>();
    final currentProfile = family.current;

    // [SỬA] Lọc lịch sắp tới theo hồ sơ đang chọn
    final upcomingLichHen = _findUpcoming(
      context.watch<LichHenProvider>().activeBookingsOf(currentProfile?.id),
    );
    final upcomingItem = upcomingLichHen != null
        ? _convertToAppointmentItem(upcomingLichHen)
        : null;

    final notificationProvider = context.watch<NotificationProvider>();
    final unreadCount = notificationProvider.unreadCount;
    final recentNotices = notificationProvider.notifications.take(3).toList();

    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: RefreshIndicator(
        color: AppTheme.primary,
        edgeOffset: topInset,
        onRefresh: () async {
          await auth.fetchCurrentUser();
          await context.read<FamilyProfileProvider>().load(
            auth.user,
            force: true,
          ); // [MỚI]
          await _loadBookings();
          await notificationProvider.refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Khu vực đầu trang: nền gradient + lời chào + tìm kiếm + lịch sắp tới ──
              Stack(
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
                          // [MỚI]
                          profileLabel: currentProfile == null
                              ? null
                              : (currentProfile.isSelf
                                    ? 'Tôi'
                                    : '${currentProfile.quanHe} - ${currentProfile.hoTen}'),
                          onSwitchTap: () => showProfileSwitcherSheet(context),
                        ),
                        const SizedBox(height: 18),
                        _SearchBar(onTap: _openBooking),
                        const SizedBox(height: 22),
                        upcomingLichHen == null
                            ? _EmptyUpcomingCard(onBook: _openBooking)
                            : _UpcomingCard(
                                appointment: upcomingLichHen,
                                onTap: () {
                                  if (upcomingItem != null) {
                                    _openAppointmentDetail(upcomingItem);
                                  }
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Dịch vụ nhanh (lưới 3 cột x 2 hàng) ──
                    const _SectionTitle(title: 'Dịch vụ nhanh'),
                    const SizedBox(height: 14),
                    IntrinsicHeight(
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ServiceItem(
                            icon: Icons.add_circle_rounded,
                            label: 'Đặt lịch\nkhám',
                            color: AppTheme.primary,
                            onTap: _openBooking,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ServiceItem(
                            icon: Icons.event_note_rounded,
                            label: 'Lịch khám\ncủa tôi',
                            color: const Color(0xFF8B5CF6),
                            onTap: _openMyAppointments,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ServiceItem(
                            icon: Icons.monitor_heart_rounded,
                            label: 'Theo dõi\ntrực tiếp',
                            color: const Color(0xFF0EA5E9),
                            onTap: _openAppointmentTracking,
                          ),
                        ),
                      ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ServiceItem(
                            icon: Icons.qr_code_2_rounded,
                            label: 'Mã QR\ncủa tôi',
                            color: AppTheme.success,
                            onTap: _openQr,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ServiceItem(
                            icon: Icons.groups_rounded,
                            label: 'Quản lý\nngười thân',
                            color: const Color(0xFFEC4899),
                            onTap: _openFamilyProfiles,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ServiceItem(
                            icon: Icons.assignment_ind_rounded,
                            label: 'Hồ sơ\ncá nhân',
                            color: const Color(0xFFF59E0B),
                            onTap: _openProfile,
                          ),
                        ),
                      ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Mẹo sức khỏe ──
                    const _HealthTipCard(),
                    const SizedBox(height: 28),

                    // ── Thông báo gần đây ──
                    _SectionTitle(
                      title: 'Thông báo gần đây',
                      actionText: 'Xem tất cả',
                      onAction: _openNotifications,
                      badge: unreadCount,
                    ),
                    const SizedBox(height: 14),

                    if (notificationProvider.isLoading && recentNotices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (recentNotices.isEmpty)
                      const _EmptyNotices()
                    else
                      ...recentNotices.map(
                        (notice) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _HomeNoticeTile(
                            notification: notice,
                            unread: notice.status == NotificationStatus.unread,
                            onTap: () {
                              notificationProvider.markRead(notice.id);
                              _openNotifications();
                            },
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
    );
  }
}

// ───────────────────────── ĐẦU TRANG ─────────────────────────

// Nền gradient xanh + họa tiết chữ thập y tế phía sau lời chào.
class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), AppTheme.primaryDark, Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        child: Stack(
          children: [
            Positioned(top: -60, right: -50, child: _Bubble(210, 0.09)),
            Positioned(bottom: 20, left: -70, child: _Bubble(170, 0.06)),
            Positioned(
              top: 120,
              right: 70,
              child: Icon(
                Icons.add_rounded,
                size: 30,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            Positioned(
              top: 190,
              left: 36,
              child: Icon(
                Icons.add_rounded,
                size: 22,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String userName;
  final int unreadCount;
  final VoidCallback onBellTap;
  final VoidCallback onAvatarTap;
  final String? profileLabel; // [MỚI]
  final VoidCallback onSwitchTap; // [MỚI]

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
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 3,
              ),
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
              // [MỚI] Nút đổi hồ sơ đang xem
              if (profileLabel != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onSwitchTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.swap_horiz_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
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
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        _BellButton(count: unreadCount, onTap: onBellTap),
      ],
    );
  }
}

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

// Thanh tìm kiếm giả: bấm vào mở màn hình tìm bệnh viện.
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
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
              const Icon(
                Icons.search_rounded,
                color: AppTheme.primary,
                size: 24,
              ),
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

// ───────────────────────── LỊCH KHÁM SẮP TỚI ─────────────────────────

class _UpcomingCard extends StatelessWidget {
  final LichHenModel appointment;
  final VoidCallback onTap;

  const _UpcomingCard({required this.appointment, required this.onTap});

  IconData _statusIcon(AppointmentStatus status) {
    if (status == AppointmentStatus.approved) {
      return Icons.check_circle_rounded;
    }
    if (status == AppointmentStatus.cancelled) return Icons.cancel_rounded;
    return Icons.schedule_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final date = a.ngayDat;
    final hospital = a.tenBenhVien;
    final status = statusFromTrangThaiId(a.trangThaiId);

    final timeText = (a.gioBatDau != null && a.gioKetThuc != null)
        ? '${a.gioBatDau}–${a.gioKetThuc}'
        : (a.gioDuKien.isNotEmpty ? a.gioDuKien : 'Đang cập nhật');
    final queueText = a.soThuTu > 0 ? '#${a.soThuTu}' : 'Chờ cấp';

    // [MỚI] Lịch đặt hộ: hiện tên người đi khám
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
                Positioned(top: -40, right: -30, child: _Bubble(140, 0.10)),
                Positioned(bottom: -60, left: -30, child: _Bubble(160, 0.07)),
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

                      // Khoa + bệnh viện
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
                                if (hospital != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.local_hospital_rounded,
                                        size: 14,
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          hospital,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white.withOpacity(
                                              0.88,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                // [MỚI]
                                if (isForRelative) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        size: 14,
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'Khám cho: ${a.tenNguoiKham}'
                                          '${(a.quanHe ?? '').isNotEmpty ? ' (${a.quanHe})' : ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white.withOpacity(
                                              0.95,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
                          border: Border.all(
                            color: Colors.white.withOpacity(0.20),
                          ),
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

  Widget _vDivider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(vertical: 4),
    color: Colors.white.withOpacity(0.25),
  );
}

// Một ô trong bảng thông tin của thẻ lịch sắp tới.
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
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.07),
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.13),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 36,
                  color: AppTheme.primary,
                ),
              ),
            ],
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
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppTheme.textGrey,
            ),
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

// ───────────────────────── DỊCH VỤ NHANH ─────────────────────────

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

// Ô dịch vụ nhỏ: biểu tượng tròn nền nhạt + nhãn 2 dòng.
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

// ───────────────────────── MẸO SỨC KHỎE ─────────────────────────

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
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 25,
            ),
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

// ───────────────────────── THÔNG BÁO ─────────────────────────

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

/// _HomeNoticeTile: thẻ thông báo gọn hiển thị ở trang chủ.
class _HomeNoticeTile extends StatelessWidget {
  final NotificationModel notification;
  final bool unread;
  final VoidCallback? onTap;

  const _HomeNoticeTile({
    required this.notification,
    this.unread = false,
    this.onTap,
  });

  /// _icon: biểu tượng theo loại thông báo.
  IconData get _icon {
    switch (notification.type) {
      case NotificationType.appointmentConfirmed:
        return Icons.task_alt_rounded;
      case NotificationType.appointmentCancelled:
        return Icons.not_interested_rounded;
      case NotificationType.appointmentReminder:
        return Icons.alarm_rounded;
      case NotificationType.appointmentCompleted:
        return Icons.workspace_premium_rounded;
      case NotificationType.roomPaused:
        return Icons.pause_circle_rounded;
      case NotificationType.roomResumed:
        return Icons.play_circle_rounded;
      case NotificationType.roomClosed:
        return Icons.lock_rounded;
      case NotificationType.system:
        return Icons.notifications_active_rounded;
    }
  }

  /// _color: màu theo loại thông báo.
  Color get _color {
    switch (notification.type) {
      case NotificationType.appointmentConfirmed:
        return AppTheme.primary;
      case NotificationType.appointmentReminder:
        return AppTheme.warning;
      case NotificationType.appointmentCompleted:
        return AppTheme.success;
      case NotificationType.appointmentCancelled:
        return AppTheme.danger;
      case NotificationType.roomPaused:
        return AppTheme.warning;
      case NotificationType.roomResumed:
        return AppTheme.success;
      case NotificationType.roomClosed:
        return const Color(0xFF475569);
      case NotificationType.system:
        return const Color(0xFF8B5CF6);
    }
  }

  /// _typeLabel: nhãn theo loại thông báo.
  String get _typeLabel {
    switch (notification.type) {
      case NotificationType.appointmentConfirmed:
        return 'XÁC NHẬN LỊCH';
      case NotificationType.appointmentReminder:
        return 'NHẮC LỊCH';
      case NotificationType.appointmentCompleted:
        return 'HOÀN THÀNH';
      case NotificationType.appointmentCancelled:
        return 'HỦY LỊCH';
      case NotificationType.roomPaused:
        return 'PHÒNG TẠM DỪNG';
      case NotificationType.roomResumed:
        return 'TIẾP TỤC KHÁM';
      case NotificationType.roomClosed:
        return 'PHÒNG ĐÓNG CỬA';
      case NotificationType.system:
        return 'HỆ THỐNG';
    }
  }

  /// _timeAgo: đổi thời điểm tạo thông báo thành chuỗi "x phút trước", "x giờ trước"...
  String get _timeAgo {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${diff.inDays ~/ 7} tuần trước';
  }

  /// _has: kiểm tra chuỗi có giá trị (không null và không rỗng).
  bool _has(String? v) => v != null && v.isNotEmpty;

  /// _chip: nhãn nhỏ gồm biểu tượng và chữ (bệnh viện, số thứ tự).
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
    final color = _color;
    final hospital = notification.hospitalName;
    final queue = notification.queueNumber;
    final hasChips = _has(hospital) || _has(queue);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unread ? color.withOpacity(0.32) : AppTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: unread
                ? color.withOpacity(0.12)
                : Colors.black.withOpacity(0.03),
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
                                    : [
                                        color.withOpacity(0.18),
                                        color.withOpacity(0.07),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              _icon,
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
                                        _typeLabel,
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
                                    fontWeight: unread
                                        ? FontWeight.w800
                                        : FontWeight.w700,
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
                                if (hasChips) ...[
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

// ───────────────────────── HELPER WIDGETS & FUNCTIONS ─────────────────────────

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

String _formatDateShort(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String _countdownLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(today).inDays;
  if (days <= 0) return 'Hôm nay';
  if (days == 1) return 'Ngày mai';
  return 'Còn $days ngày';
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'Chào buổi sáng';
  if (hour < 14) return 'Chào buổi trưa';
  if (hour < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
}