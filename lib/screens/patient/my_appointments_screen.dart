import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_routes.dart';
import '../../models/family_profile_model.dart';
import '../../models/lichhen_model.dart';
import '../../providers/lich_hen_provider.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../models/appointment_item.dart';

enum _Scope { all, mine, relatives }

/// Chỉnh độ trong suốt an toàn cho mọi phiên bản Flutter (thay withOpacity).
extension _ColorX on Color {
  Color o(double opacity) => withAlpha((opacity * 255).round().clamp(0, 255));
}

class MyAppointmentsScreen extends StatefulWidget {
  final String? benhNhanId;

  final List<MyAppointmentItem>? appointments;
  final int? historyCount;

  final ValueChanged<MyAppointmentItem>? onOpenDetail;
  final VoidCallback? onOpenHistory;
  final ValueChanged<int>? onNavTap;
  final bool showBottomNavBar;

  const MyAppointmentsScreen({
    super.key,
    this.benhNhanId,
    this.appointments,
    this.historyCount,
    this.onOpenDetail,
    this.onOpenHistory,
    this.onNavTap,
    this.showBottomNavBar = true,
  });

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  _Scope _scope = _Scope.all;

  String? get _patientId =>
      widget.benhNhanId ?? FirebaseAuth.instance.currentUser?.uid;

  bool _inScope(LichHenModel booking) {
    switch (_scope) {
      case _Scope.mine:
        return booking.profileKey == FamilyProfileModel.selfId;
      case _Scope.relatives:
        return booking.profileKey != FamilyProfileModel.selfId;
      case _Scope.all:
        return true;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.appointments == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  void _openHistory() {
    if (widget.onOpenHistory != null) {
      widget.onOpenHistory!();
    } else {
      Navigator.pushNamed(context, AppRoutes.notification, arguments: 0);
    }
  }

  Future<void> _load() async {
    final id = _patientId;
    if (id == null || id.isEmpty) return;
    await context.read<LichHenProvider>().loadMyBookings(id);
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Lịch hẹn trong Firestore -> dòng hiển thị.
  MyAppointmentItem _toItem(LichHenModel b) {
    final khoa = b.tenKhoa ?? 'Chuyên khoa';
    final hasHours = b.gioBatDau != null && b.gioKetThuc != null;
    final hours = hasHours ? '${b.gioBatDau} - ${b.gioKetThuc}' : '';
    final patientName =
        b.profileKey != FamilyProfileModel.selfId &&
            (b.tenNguoiKham ?? '').isNotEmpty
        ? '${b.tenNguoiKham} (${b.quanHe ?? 'Người thân'})'
        : null;
    final subtitleParts = [
      if (patientName != null) patientName,
      hasHours ? '$khoa • Giờ khám: $hours' : khoa,
    ];

    return MyAppointmentItem(
      id: b.id,
      hospitalName: b.tenBenhVien ?? 'Bệnh viện ${b.benhVienId}',
      subtitle: subtitleParts.join(' • '),
      status: statusFromTrangThaiId(b.trangThaiId),
      departmentName: khoa,
      dateLabel: _formatDate(b.ngayDat),
      timeLabel: hasHours ? hours : '—',
    );
  }

  Future<void> _openDetail(MyAppointmentItem item) async {
    if (widget.onOpenDetail != null) {
      widget.onOpenDetail!(item);
    } else {
      final result = await Navigator.pushNamed(
        context,
        AppRoutes.appointmentDetail,
        arguments: item,
      );
      if (result == true && mounted) {
        await _load();
      }
    }
  }

  /// Về trang chủ (tab đầu tiên) để đặt lịch khám.
  void _goBookNow() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.patientMain,
      (_) => false,
      arguments: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LichHenProvider>();
    final usePreview = widget.appointments != null;

    final items = usePreview
        ? widget.appointments!
        : provider.activeBookings.where(_inScope).map(_toItem).toList();
    final historyCount =
        widget.historyCount ??
        (usePreview ? 0 : provider.historyBookings.length);

    final loading = !usePreview && provider.isLoadingMyBookings;
    final error = usePreview ? null : provider.myBookingsError;
    final notLoggedIn =
        !usePreview && (_patientId == null || _patientId!.isEmpty);

    final pendingCount = items
        .where((e) => e.status == AppointmentStatus.pending)
        .length;

    // Nội dung danh sách
    final children = <Widget>[];
    if (notLoggedIn) {
      children.add(
        const _MessageState(
          icon: Icons.lock_outline_rounded,
          title: 'Bạn chưa đăng nhập',
          text: 'Vui lòng đăng nhập để xem lịch khám của bạn.',
        ),
      );
    } else if (loading && items.isEmpty) {
      children.addAll(const [
        _SkeletonCard(),
        SizedBox(height: 14),
        _SkeletonCard(),
        SizedBox(height: 14),
        _SkeletonCard(),
      ]);
    } else if (error != null && items.isEmpty) {
      children.add(
        _MessageState(
          icon: Icons.wifi_off_rounded,
          title: 'Không tải được lịch khám',
          text: error,
          color: Colors.red.shade400,
          onRetry: _load,
        ),
      );
    } else {
      if (!usePreview) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              children:
                  {
                    _Scope.all: 'Tất cả',
                    _Scope.mine: 'Của tôi',
                    _Scope.relatives: 'Người thân',
                  }.entries.map((entry) {
                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: _scope == entry.key,
                      onSelected: (_) => setState(() => _scope = entry.key),
                    );
                  }).toList(),
            ),
          ),
        );
      }

      if (items.isEmpty) {
        children.add(_EmptyState(onBookNow: _goBookNow));
      } else {
        children.add(
          _SectionTitle(title: 'Lịch sắp tới', badge: '${items.length}'),
        );
        children.add(const SizedBox(height: 12));
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          children.add(
            _FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _AppointmentCard(
                  item: item,
                  onTap: () => _openDetail(item),
                ),
              ),
            ),
          );
        }
      }
      children.add(const SizedBox(height: 6));
      children.add(
        _FadeSlideIn(
          index: items.length,
          child: _HistoryCard(count: historyCount, onTap: _openHistory),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _Header(
            upcoming: items.length,
            pending: pendingCount,
            history: historyCount,
            showStats: !notLoggedIn && !(loading && items.isEmpty),
          ),
          Expanded(
            // Kéo xuống để tải lại
            child: RefreshIndicator(
              color: _kPrimary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: children,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNavBar
          ? MedicalBottomNavBar(
              currentIndex: 1,
              onTap:
                  widget.onNavTap ??
                  (index) => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.patientMain,
                    (_) => false,
                    arguments: index,
                  ),
            )
          : null,
    );
  }
}

// ───────────────────────── MÀU RIÊNG CỦA MÀN HÌNH ─────────────────────────

const Color _kPrimary = Color(0xFF0B63CE);
const Color _kPrimaryDark = Color(0xFF084A9E);
const Color _kPrimarySoft = Color(0xFFE8F1FC);
const Color _kAmber = Color(0xFFD97706);
const Color _kAmberSoft = Color(0xFFFEF3C7);
const Color _kBg = Color(0xFFF3F7FB);
const Color _kBorder = Color(0xFFE3EAF2);
const Color _kText = Color(0xFF0B1F3A);
const Color _kGrey = Color(0xFF5B6B80);

// ───────────────────────── HIỆU ỨNG XUẤT HIỆN ─────────────────────────

/// Mờ dần + trượt nhẹ từ dưới lên; các thẻ phía sau xuất hiện trễ hơn một chút.
class _FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _FadeSlideIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delayStep = index > 6 ? 6 : index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delayStep * 80),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ───────────────────────── PHẦN ĐẦU: TIÊU ĐỀ + THỐNG KÊ ─────────────────────────

class _Header extends StatelessWidget {
  final int upcoming;
  final int pending;
  final int history;
  final bool showStats;

  const _Header({
    required this.upcoming,
    required this.pending,
    required this.history,
    required this.showStats,
  });

  @override
  Widget build(BuildContext context) {
    final confirmed = upcoming - pending;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPrimaryDark, _kPrimary, Color(0xFF1F8FE8)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.o(0.07),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.o(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.event_note_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lịch khám của tôi',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Theo dõi và quản lý các lịch hẹn',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xCCFFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (showStats) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _StatTile(
                          value: '$upcoming',
                          label: 'Sắp tới',
                          icon: Icons.event_available_rounded,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          value: '$pending',
                          label: 'Chờ xác nhận',
                          icon: Icons.hourglass_top_rounded,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          value: '${confirmed < 0 ? 0 : confirmed}',
                          label: 'Đã xác nhận',
                          icon: Icons.verified_rounded,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          value: '$history',
                          label: 'Đã khám',
                          icon: Icons.history_rounded,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.o(0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.o(0.18)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xDDFFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? badge;
  const _SectionTitle({required this.title, this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _kText,
            letterSpacing: -0.2,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: _kPrimarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ───────────────────────── THẺ LỊCH KHÁM ─────────────────────────

class _AppointmentCard extends StatelessWidget {
  final MyAppointmentItem item;
  final VoidCallback? onTap;
  const _AppointmentCard({required this.item, this.onTap});

  /// Tách "dd/MM/yyyy" thành [ngày, tháng]; không đúng định dạng thì trả về null.
  List<String>? _splitDate(String label) {
    final parts = label.split('/');
    if (parts.length < 2) return null;
    final day = parts[0].trim();
    final month = parts[1].trim();
    if (day.isEmpty || month.isEmpty) return null;
    return [day, month];
  }

  /// 6 ký tự cuối của mã lịch, in hoa (mã Firestore rất dài nên chỉ hiện gọn).
  String _shortId(String id) {
    final clean = id.replaceAll('#', '').trim();
    if (clean.isEmpty) return '—';
    return clean.length > 6
        ? clean.substring(clean.length - 6).toUpperCase()
        : clean.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isPending = item.status == AppointmentStatus.pending;
    final accent = isPending ? _kAmber : _kPrimary;
    final soft = isPending ? _kAmberSoft : _kPrimarySoft;
    final date = _splitDate(item.dateLabel);
    final hasTime = item.timeLabel.trim().isNotEmpty && item.timeLabel != '—';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.o(0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: _kBorder),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dải màu đầu thẻ theo trạng thái
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accent, accent.o(0.2)]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DateBadge(date: date, accent: accent, soft: soft),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.hospitalName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: _kText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              StatusChip(item.status),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Khối thông tin chi tiết
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.medical_services_outlined,
                            label: 'Chuyên khoa',
                            text: item.departmentName,
                            color: accent,
                          ),
                          if (hasTime) ...[
                            const SizedBox(height: 10),
                            _InfoRow(
                              icon: Icons.schedule_rounded,
                              label: 'Giờ khám',
                              text: item.timeLabel,
                              color: accent,
                            ),
                          ],
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Ngày khám',
                            text: item.dateLabel,
                            color: accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Chân thẻ: mã lịch + xem chi tiết
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Mã ${_shortId(item.id)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: _kGrey,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _kPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Xem chi tiết',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
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
    );
  }
}

/// Ô ngày kiểu tờ lịch: tháng nhỏ phía trên, số ngày lớn bên dưới.
class _DateBadge extends StatelessWidget {
  final List<String>? date; // [ngày, tháng]
  final Color accent;
  final Color soft;
  const _DateBadge({
    required this.date,
    required this.accent,
    required this.soft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: date == null
          ? Icon(Icons.event_rounded, size: 28, color: accent)
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  color: accent,
                  child: Text(
                    'Th ${date![1]}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      date![0],
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: _kText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Một dòng thông tin: biểu tượng, nhãn nhỏ và giá trị.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color color;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.o(0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 12.5, color: _kGrey)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── THẺ LỊCH SỬ ─────────────────────────

class _HistoryCard extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  const _HistoryCard({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _kPrimarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 26,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử khám bệnh',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      count > 0
                          ? '$count lần khám đã hoàn tất'
                          : 'Chưa có lần khám nào hoàn tất',
                      style: const TextStyle(fontSize: 12.5, color: _kGrey),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 26,
                color: _kPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── TRẠNG THÁI TRỐNG / LỖI / ĐANG TẢI ─────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onBookNow;
  const _EmptyState({required this.onBookNow});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 28, 12, 24),
      child: Column(
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kPrimary.o(0.06),
            ),
            child: Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kPrimarySoft,
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  size: 44,
                  color: _kPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Bạn chưa có lịch khám nào',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Chọn bệnh viện và khung giờ phù hợp,\nviệc đặt lịch chỉ mất vài phút.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: _kGrey),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onBookNow,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Đặt lịch khám',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thông báo giữa màn hình (chưa đăng nhập / lỗi), có nút "Thử lại" tuỳ chọn.
class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  final VoidCallback? onRetry;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.text,
    this.color = _kPrimary,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.o(0.10),
            ),
            child: Icon(icon, size: 42, color: color),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, height: 1.45, color: _kGrey),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── KHUNG XƯƠNG KHI ĐANG TẢI ─────────────────────────

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const _SkeletonBox({this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6EDF5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Thẻ giả nhấp nháy nhẹ khi đang tải danh sách.
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_ctrl),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _kBorder),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SkeletonBox(width: 56, height: 64, radius: 16),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(height: 16),
                      SizedBox(height: 10),
                      _SkeletonBox(width: 90, height: 20, radius: 20),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _SkeletonBox(height: 84, radius: 14),
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SkeletonBox(width: 80, height: 22),
                _SkeletonBox(width: 110, height: 36, radius: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
