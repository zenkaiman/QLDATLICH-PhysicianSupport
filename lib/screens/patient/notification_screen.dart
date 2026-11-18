import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_routes.dart';
import '../../models/lichhen_model.dart';
import '../../models/notification_model.dart';
import '../../models/review_model.dart';
import '../../services/review_service.dart';
import '../../providers/lich_hen_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/app_snackbar.dart';

/// _C: bảng màu dùng riêng cho màn hình thông báo.
class _C {
  static const primary = Color(0xFF2196F3);
  static const primaryDark = Color(0xFF1976D2);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFE53935);
  static const closed = Color(0xFF475569);
  static const bg = Color(0xFFF5F7FA);
  static const textDark = Color(0xFF0F172A);
  static const textGrey = Color(0xFF64748B);
  static const border = Color(0xFFE8ECF3);
}

/// _formatTimeAgo: đổi một thời điểm thành chuỗi "x phút trước", "x giờ trước"...
String _formatTimeAgo(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.isNegative) return 'Vừa xong';

  final seconds = diff.inSeconds;
  if (seconds < 10) return 'Vừa xong';
  if (seconds < 60) return '$seconds giây trước';

  final minutes = diff.inMinutes;
  if (minutes < 60) return '$minutes phút trước';

  final hours = diff.inHours;
  if (hours < 24) {
    final restMinutes = minutes % 60;
    return restMinutes == 0
        ? '$hours giờ trước'
        : '$hours giờ $restMinutes phút trước';
  }

  final days = diff.inDays;
  if (days < 30) return '$days ngày trước';
  if (days < 365) return '${days ~/ 30} tháng trước';
  return '${days ~/ 365} năm trước';
}

/// _formatExact: định dạng giờ chính xác "HH:mm dd/MM/yyyy".
String _formatExact(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)} ${two(t.day)}/${two(t.month)}/${t.year}';
}

/// NotificationScreen: màn hình gồm hai tab Lịch cũ và Thông báo.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _initialTabIndex = 1;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadBookings();
        _initNotifications();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// _initNotifications: bắt đầu lắng nghe thông báo của người dùng đang đăng nhập.
  void _initNotifications() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      context.read<NotificationProvider>().listen(userId);
    }
  }

  /// _loadBookings: tải danh sách lịch hẹn của người dùng đang đăng nhập.
  Future<void> _loadBookings() async {
    final id = FirebaseAuth.instance.currentUser?.uid;
    if (id == null) return;
    await context.read<LichHenProvider>().loadMyBookings(id);
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final history = context.watch<LichHenProvider>().historyBookings;

    final topInset = MediaQuery.of(context).padding.top;
    const headerBody = 128.0;
    const tabsHeight = 60.0;
    const overlap = 30.0;
    final headerHeight = topInset + headerBody;

    final args = ModalRoute.of(context)?.settings.arguments;
    _initialTabIndex = (args is int) ? args : 1;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          Stack(
            children: [
              _Header(
                height: headerHeight,
                unreadCount: notificationProvider.unreadCount,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, headerHeight - overlap, 20, 0),
                child: SizedBox(
                  height: tabsHeight,
                  child: _SegmentedTabs(
                    controller: _tabController,
                    tabs: [
                      _TabInfo('Lịch cũ', history.length, false),
                      _TabInfo(
                        'Thông báo',
                        notificationProvider.unreadCount,
                        true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryTab(history),
                _buildNotificationsTab(notificationProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// _groupHistoryByMonth: gom lịch cũ theo tháng, tháng mới nhất lên đầu.
  List<MapEntry<String, List<LichHenModel>>> _groupHistoryByMonth(
    List<LichHenModel> list,
  ) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final sorted = [...list]
      ..sort((a, b) => (b.ngayDat ?? epoch).compareTo(a.ngayDat ?? epoch));

    final map = <String, List<LichHenModel>>{};
    for (final b in sorted) {
      final d = b.ngayDat;
      final key = d == null
          ? 'Chưa rõ ngày'
          : 'Tháng ${d.month.toString().padLeft(2, '0')}/${d.year}';
      map.putIfAbsent(key, () => []).add(b);
    }
    return map.entries.toList();
  }

  /// _buildHistoryTab: dựng tab Lịch cũ gồm trạng thái tải, lỗi, rỗng hoặc danh sách theo tháng.
  Widget _buildHistoryTab(List<LichHenModel> history) {
    final provider = context.watch<LichHenProvider>();
    final loading = provider.isLoadingMyBookings && history.isEmpty;
    final error = provider.myBookingsError;

    final children = <Widget>[];
    if (loading) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (error != null && history.isEmpty) {
      children.add(
        _EmptyState(
          icon: Icons.error_outline_rounded,
          color: _C.danger,
          title: 'Không tải được lịch cũ',
          subtitle: error,
          actionText: 'Thử lại',
          onAction: _loadBookings,
        ),
      );
    } else if (history.isEmpty) {
      children.add(
        const _EmptyState(
          icon: Icons.history_rounded,
          color: _C.primary,
          title: 'Chưa có lịch khám cũ',
          subtitle: 'Các lịch khám đã hoàn thành sẽ hiển thị ở đây.',
        ),
      );
    } else {
      final completed = history
          .where((b) => b.trangThaiId.toString() == '5')
          .length;
      final missed = history
          .where((b) => b.trangThaiId.toString() == '6')
          .length;

      children.add(
        _HistorySummary(
          total: history.length,
          completed: completed,
          missed: missed,
        ),
      );

      var index = 0;
      for (final group in _groupHistoryByMonth(history)) {
        children.add(_MonthLabel(text: group.key, count: group.value.length));
        for (final booking in group.value) {
          children.add(
            _FadeIn(
              index: index++,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryCard(
                  booking: booking,
                  onRebook: () =>
                      Navigator.pushNamed(context, AppRoutes.hospitalFilter),
                ),
              ),
            ),
          );
        }
      }
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: children,
      ),
    );
  }

  /// _buildNotificationsTab: dựng tab Thông báo gồm trạng thái tải, lỗi, rỗng hoặc danh sách theo ngày.
  Widget _buildNotificationsTab(NotificationProvider provider) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && provider.notifications.isEmpty) {
      return Center(
        child: _EmptyState(
          icon: Icons.error_outline_rounded,
          color: _C.danger,
          title: 'Không tải được thông báo',
          subtitle: provider.error!,
          actionText: 'Thử lại',
          onAction: provider.refresh,
        ),
      );
    }

    final unreadCount = provider.unreadCount;
    final notifications = provider.notifications;
    final groups = _groupNotifications(notifications);

    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông báo từ bệnh viện',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _C.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  unreadCount > 0
                      ? 'Bạn có $unreadCount thông báo chưa đọc'
                      : 'Bạn đã đọc hết thông báo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: unreadCount > 0 ? _C.primaryDark : _C.textGrey,
                  ),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: provider.markAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _C.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done_all_rounded, size: 16, color: _C.primary),
                    SizedBox(width: 5),
                    Text(
                      'Đọc tất cả',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _C.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 4),
    ];

    if (groups.isEmpty && !provider.isLoading) {
      children.add(
        const _EmptyState(
          icon: Icons.notifications_off_outlined,
          color: _C.primary,
          title: 'Chưa có thông báo',
          subtitle: 'Thông báo từ bệnh viện sẽ hiển thị ở đây.',
        ),
      );
    }

    var index = 0;
    for (final group in groups) {
      children.add(_SectionLabel(group.key));
      for (final n in group.value) {
        children.add(
          _FadeIn(
            index: index++,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _NotificationCard(
                notification: n,
                unread: n.status == NotificationStatus.unread,
                onTap: () => provider.markRead(n.id),
              ),
            ),
          ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: children,
      ),
    );
  }

  /// _groupNotifications: gom thông báo thành các nhóm Hôm nay, Hôm qua, Trước đó (mới nhất lên đầu).
  List<MapEntry<String, List<NotificationModel>>> _groupNotifications(
    List<NotificationModel> list,
  ) {
    final sorted = [...list]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<NotificationModel>>{
      'Hôm nay': [],
      'Hôm qua': [],
      'Trước đó': [],
    };

    for (final n in sorted) {
      final day = DateTime(
        n.createdAt.year,
        n.createdAt.month,
        n.createdAt.day,
      );
      final diff = today.difference(day).inDays;
      final key = diff <= 0 ? 'Hôm nay' : (diff == 1 ? 'Hôm qua' : 'Trước đó');
      groups[key]!.add(n);
    }
    return groups.entries.where((e) => e.value.isNotEmpty).toList();
  }
}

/// _Header: phần đầu trang có nền gradient, tiêu đề và chuông thông báo.
class _Header extends StatelessWidget {
  final double height;
  final int unreadCount;
  const _Header({required this.height, required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), _C.primaryDark, Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: _Bubble(size: 170, opacity: 0.10),
            ),
            Positioned(
              bottom: 10,
              left: -50,
              child: _Bubble(size: 120, opacity: 0.07),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trung tâm',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Thông báo',
                            style: TextStyle(
                              fontSize: 30,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            unreadCount > 0
                                ? '$unreadCount tin mới đang chờ bạn'
                                : 'Bạn đã xem hết tin mới',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _BellBadge(count: unreadCount),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// _Bubble: hình tròn mờ trang trí nền.
class _Bubble extends StatelessWidget {
  final double size;
  final double opacity;
  const _Bubble({required this.size, required this.opacity});
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

/// _BellBadge: biểu tượng chuông kèm số thông báo chưa đọc.
class _BellBadge extends StatelessWidget {
  final int count;
  const _BellBadge({required this.count});
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: const Icon(
            Icons.notifications_active_rounded,
            size: 26,
            color: Colors.white,
          ),
        ),
        if (count > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _C.danger,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// _TabInfo: thông tin một tab (nhãn, số đếm, có phải tab cảnh báo không).
class _TabInfo {
  final String label;
  final int count;
  final bool alert;
  const _TabInfo(this.label, this.count, this.alert);
}

/// _SegmentedTabs: thanh chuyển tab dạng viên thuốc có hiệu ứng trượt.
class _SegmentedTabs extends StatelessWidget {
  final TabController controller;
  final List<_TabInfo> tabs;
  const _SegmentedTabs({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final n = tabs.length;
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, _) {
        final value = controller.animation!.value;
        final active = value.round();
        return Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _C.primary.withOpacity(0.16),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment(-1 + 2 * value / (n - 1), 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_C.primary, _C.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _C.primary.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: List.generate(n, (i) {
                  final tab = tabs[i];
                  final isActive = i == active;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.animateTo(i),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: isActive ? Colors.white : _C.textGrey,
                              ),
                            ),
                            if (tab.count > 0) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.white.withOpacity(0.25)
                                      : (tab.alert
                                            ? _C.danger
                                            : const Color(0xFFEEF1F6)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${tab.count}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: isActive || tab.alert
                                        ? Colors.white
                                        : _C.textGrey,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// _SectionLabel: tiêu đề nhóm thông báo (Hôm nay, Hôm qua, Trước đó).
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 0, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: _C.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: _C.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// _FadeIn: hiệu ứng mờ dần và trượt lên khi một mục xuất hiện.
class _FadeIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _FadeIn({required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    final ms = 300 + (index > 6 ? 6 : index) * 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// _EmptyState: khung hiển thị khi không có dữ liệu hoặc gặp lỗi, có thể kèm nút hành động.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  const _EmptyState({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.08),
                ),
              ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.14),
                ),
                child: Icon(icon, size: 38, color: color),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _C.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: _C.textGrey,
            ),
          ),
          if (actionText != null) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

/// _InfoChip: nhãn nhỏ gồm biểu tượng và chữ (tên bệnh viện, chuyên khoa).
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _C.textGrey),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _C.textGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// _NotificationCard: thẻ một thông báo, bấm vào để đánh dấu đã đọc (thông báo hoàn thành sẽ mở hộp thoại đánh giá).
class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final bool unread;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.unread,
    required this.onTap,
  });

  /// _icon: biểu tượng theo loại thông báo.
  IconData get _icon {
    switch (notification.type) {
      case NotificationType.appointmentConfirmed:
        return Icons.task_alt_rounded;
      case NotificationType.appointmentCancelled:
        return Icons.not_interested_rounded;
      case NotificationType.appointmentReminder:
        return Icons.notifications_rounded;
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
        return _C.success;
      case NotificationType.appointmentCancelled:
        return _C.danger;
      case NotificationType.appointmentReminder:
        return _C.warning;
      case NotificationType.appointmentCompleted:
        return const Color(0xFF8B5CF6);
      case NotificationType.roomPaused:
        return _C.warning;
      case NotificationType.roomResumed:
        return _C.success;
      case NotificationType.roomClosed:
        return _C.closed;
      case NotificationType.system:
        return _C.textGrey;
    }
  }

  /// _typeLabel: nhãn theo loại thông báo.
  String get _typeLabel {
    switch (notification.type) {
      case NotificationType.appointmentConfirmed:
        return 'XÁC NHẬN LỊCH';
      case NotificationType.appointmentCancelled:
        return 'HỦY LỊCH';
      case NotificationType.appointmentReminder:
        return 'NHẮC LỊCH';
      case NotificationType.appointmentCompleted:
        return 'HOÀN THÀNH';
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

  /// _has: kiểm tra chuỗi có giá trị (không null và không rỗng).
  bool _has(String? v) => v != null && v.isNotEmpty;

  /// _handleTap: xử lý khi bấm vào thẻ.
  Future<void> _handleTap(BuildContext context) async {
    // Bước 1: các loại khác ngoài hoàn thành chỉ cần đánh dấu đã đọc.
    if (notification.type != NotificationType.appointmentCompleted) {
      onTap();
      return;
    }

    // Bước 2: kiểm tra lịch khám này đã được đánh giá chưa.
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final lichHenId = notification.lichHenId ?? notification.id;

    if (userId != null) {
      final alreadyReviewed = await ReviewService().hasReviewed(
        lichHenId,
        userId,
      );
      if (alreadyReviewed) {
        if (!context.mounted) return;
        context.showAppSnackBar(
          title: 'Đã đánh giá lịch khám',
          message: 'Bạn đã đánh giá lịch khám này rồi!',
          type: SnackBarType.warning,
        );
        onTap();
        return;
      }
    }

    // Bước 3: mở hộp thoại đánh giá rồi đánh dấu đã đọc.
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ReviewDialog(notification: notification),
    );
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final hospital = notification.hospitalName;
    final department = notification.departmentName;
    final date = notification.appointmentDate;
    final time = notification.appointmentTime;
    final queue = notification.queueNumber;

    final hasPlace = _has(hospital) || _has(department);
    final hasStats = _has(date) || _has(time) || _has(queue);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: unread ? color.withOpacity(0.38) : _C.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: unread
                ? color.withOpacity(0.16)
                : Colors.black.withOpacity(0.03),
            blurRadius: unread ? 22 : 8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Material(
          color: Colors.white,
          child: Ink(
            decoration: BoxDecoration(
              gradient: unread
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, color.withOpacity(0.08)],
                    )
                  : null,
            ),
            child: InkWell(
              onTap: () => _handleTap(context),
              child: Stack(
                children: [
                  Positioned(
                    top: -34,
                    right: -26,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(unread ? 0.07 : 0.035),
                      ),
                    ),
                  ),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: unread
                                  ? [color, color.withOpacity(0.45)]
                                  : [
                                      color.withOpacity(0.28),
                                      color.withOpacity(0.12),
                                    ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(color),
                                const SizedBox(height: 14),
                                Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.3,
                                    fontWeight: unread
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: _C.textDark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  notification.message,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.5,
                                    color: _C.textGrey,
                                  ),
                                ),
                                if (hasPlace) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (_has(hospital))
                                        _InfoChip(
                                          icon: Icons.local_hospital_rounded,
                                          text: hospital!,
                                        ),
                                      if (_has(department))
                                        _InfoChip(
                                          icon: Icons.medical_services_outlined,
                                          text: department!,
                                        ),
                                    ],
                                  ),
                                ],
                                if (hasStats) ...[
                                  const SizedBox(height: 12),
                                  _buildStats(color, date, time, queue),
                                ],
                              ],
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
        ),
      ),
    );
  }

  /// _buildHeader: dòng đầu thẻ gồm biểu tượng, nhãn loại, nhãn MỚI và thời gian.
  Widget _buildHeader(Color color) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: unread
                  ? [color, color.withOpacity(0.70)]
                  : [color.withOpacity(0.18), color.withOpacity(0.08)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: unread
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.38),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Icon(_icon, size: 25, color: unread ? Colors.white : color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _typeLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (unread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _C.danger,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _C.danger.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'MỚI',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: _C.textGrey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _TimeAgoText(
                      time: notification.createdAt,
                      suffix: _formatExact(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _C.textGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// _buildStats: bảng thông tin ngày, giờ, số thứ tự có vạch ngăn.
  Widget _buildStats(Color color, String? date, String? time, String? queue) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.10), color.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (_has(date))
              _StatTile(
                icon: Icons.calendar_today_rounded,
                label: 'NGÀY',
                value: date!,
                color: color,
              ),
            if (_has(date) && (_has(time) || _has(queue)))
              VerticalDivider(width: 1, color: color.withOpacity(0.22)),
            if (_has(time))
              _StatTile(
                icon: Icons.access_time_rounded,
                label: 'GIỜ',
                value: time!,
                color: color,
              ),
            if (_has(time) && _has(queue))
              VerticalDivider(width: 1, color: color.withOpacity(0.22)),
            if (_has(queue))
              _StatTile(
                icon: Icons.confirmation_number_outlined,
                label: 'STT',
                value: queue!,
                color: color,
              ),
          ],
        ),
      ),
    );
  }
}

/// _ReviewDialog: hộp thoại đánh giá trải nghiệm khám (số sao, gợi ý nhanh, nhận xét, ẩn danh).
class _ReviewDialog extends StatefulWidget {
  final NotificationModel notification;
  const _ReviewDialog({required this.notification});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 5;
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  bool _showError = false;

  final TextEditingController _commentController = TextEditingController();
  final ReviewService _reviewService = ReviewService();
  final Set<String> _selectedTags = {};

  static const _positiveTags = [
    'Bác sĩ tận tình',
    'Phục vụ nhanh',
    'Cơ sở sạch sẽ',
    'Nhân viên thân thiện',
    'Tư vấn dễ hiểu',
  ];
  static const _neutralTags = [
    'Dịch vụ ổn',
    'Thời gian chờ hơi lâu',
    'Cần cải thiện thêm',
  ];
  static const _negativeTags = [
    'Chờ đợi quá lâu',
    'Thủ tục rườm rà',
    'Thái độ chưa tốt',
    'Cơ sở chưa sạch sẽ',
  ];

  List<String> get _tags => _rating >= 4
      ? _positiveTags
      : (_rating == 3 ? _neutralTags : _negativeTags);

  String get _ratingLabel {
    switch (_rating) {
      case 1:
        return 'Rất không hài lòng';
      case 2:
        return 'Không hài lòng';
      case 3:
        return 'Bình thường';
      case 4:
        return 'Hài lòng';
      default:
        return 'Rất hài lòng';
    }
  }

  Color get _ratingColor {
    if (_rating >= 4) return _C.success;
    if (_rating == 3) return _C.warning;
    return _C.danger;
  }

  String get _hospitalName {
    final v = widget.notification.hospitalName;
    return (v == null || v.isEmpty) ? 'Bệnh viện' : v;
  }

  String get _departmentName {
    final v = widget.notification.departmentName;
    return (v == null || v.isEmpty) ? 'Chưa cập nhật' : v;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// _setRating: đổi số sao, bỏ chọn các gợi ý không còn phù hợp với mức sao mới.
  void _setRating(int value) {
    if (_isSubmitting) return;
    setState(() {
      if ((_rating >= 4) != (value >= 4) || (_rating == 3) != (value == 3)) {
        _selectedTags.clear();
      }
      _rating = value;
    });
  }

  /// _buildComment: ghép nội dung nhận xét từ các gợi ý đã chọn và phần người dùng tự viết.
  String _buildComment() {
    final parts = <String>[
      if (_selectedTags.isNotEmpty) _selectedTags.join(', '),
      if (_commentController.text.trim().isNotEmpty)
        _commentController.text.trim(),
    ];
    return parts.join('. ');
  }

  /// _submitReview: kiểm tra nhận xét, gửi đánh giá lên Firestore rồi hiện hộp thoại cảm ơn.
  Future<void> _submitReview() async {
    // Bước 1: kiểm tra có nhận xét hoặc gợi ý.
    final comment = _buildComment();
    if (comment.isEmpty) {
      setState(() => _showError = true);
      return;
    }

    setState(() {
      _showError = false;
      _isSubmitting = true;
    });

    final navigator = Navigator.of(context);

    try {
      // Bước 2: lấy người dùng đang đăng nhập và tên bệnh nhân.
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Bạn chưa đăng nhập');

      String patientName = 'Bệnh nhân';
      final userDoc = await FirebaseFirestore.instance
          .collection('BenhNhan')
          .doc(userId)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        patientName = userDoc.data()!['ho_ten']?.toString() ?? 'Bệnh nhân';
      }

      // Bước 3: dựng đánh giá từ thông tin thông báo.
      final bvId = widget.notification.benhVienId ?? 'unknown_bv';
      final kId = widget.notification.khoaId ?? 'unknown_khoa';
      final lhId = widget.notification.lichHenId ?? widget.notification.id;

      final review = ReviewModel(
        id: 'DG_${bvId}_${kId}_$lhId',
        benhNhanId: userId,
        benhVienId: bvId,
        khoaId: kId,
        lichHenId: lhId,
        diemDanhGia: _rating,
        nhanXet: comment,
        anDanh: _isAnonymous,
        ngayTao: DateTime.now(),
        ngayDanhGia: DateTime.now(),
        tenBenhVien: widget.notification.hospitalName ?? 'Bệnh viện',
        tenKhoa: widget.notification.departmentName ?? 'Chuyên khoa',
        tenBenhNhan: patientName,
      );

      // Bước 4: gửi đánh giá, đóng hộp thoại và hiện hộp thoại cảm ơn.
      await _reviewService.submitReview(review);

      if (!mounted) return;
      navigator.pop();
      _showSuccessDialog(navigator.context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      context.showAppSnackBar(
        title: 'Gửi đánh giá thất bại',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    }
  }

  /// _showSuccessDialog: hộp thoại cảm ơn sau khi gửi đánh giá thành công.
  void _showSuccessDialog(BuildContext hostContext) {
    final hospital = _hospitalName;
    showDialog(
      context: hostContext,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: Curves.elasticOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.success.withOpacity(0.08),
                      ),
                    ),
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.success.withOpacity(0.14),
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _C.success.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Gửi đánh giá thành công!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: _C.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cảm ơn bạn đã chia sẻ trải nghiệm tại\n$hospital.\nÝ kiến của bạn giúp nâng cao chất lượng chăm sóc sức khỏe.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: _C.textGrey,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Hoàn tất',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVisitCard(),
                      const SizedBox(height: 22),
                      _buildRatingSection(),
                      const SizedBox(height: 22),
                      _buildTagsSection(),
                      const SizedBox(height: 22),
                      _buildCommentSection(),
                      const SizedBox(height: 18),
                      _buildAnonymousTile(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// _buildHeader: đầu hộp thoại gồm nền gradient, biểu tượng, tiêu đề và nút đóng.
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.09),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đánh giá trải nghiệm khám',
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Ý kiến của bạn giúp nâng cao chất lượng chăm sóc sức khỏe',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Đóng',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// _buildVisitCard: thẻ thông tin lần khám gồm bệnh viện, chuyên khoa, ngày giờ (nếu có).
  Widget _buildVisitCard() {
    final date = widget.notification.appointmentDate;
    final time = widget.notification.appointmentTime;
    final hasDate = date != null && date.isNotEmpty;
    final hasTime = time != null && time.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.primary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          _visitRow(Icons.local_hospital_rounded, 'BỆNH VIỆN', _hospitalName),
          const SizedBox(height: 12),
          _visitRow(
            Icons.medical_services_rounded,
            'CHUYÊN KHOA',
            _departmentName,
          ),
          if (hasDate || hasTime) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasDate)
                  Expanded(
                    child: _visitRow(
                      Icons.calendar_today_rounded,
                      'NGÀY KHÁM',
                      date,
                    ),
                  ),
                if (hasTime)
                  Expanded(
                    child: _visitRow(
                      Icons.access_time_rounded,
                      'GIỜ KHÁM',
                      time,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// _visitRow: một dòng thông tin lần khám gồm biểu tượng, nhãn và giá trị.
  Widget _visitRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _C.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: _C.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: _C.textGrey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: _C.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// _buildRatingSection: hàng sao chọn điểm và nhãn mức độ hài lòng.
  Widget _buildRatingSection() {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Bạn cảm thấy dịch vụ thế nào?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _C.textDark,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < _rating;
            return GestureDetector(
              onTap: () => _setRating(i + 1),
              child: AnimatedScale(
                scale: filled ? 1.0 : 0.88,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 46,
                    color: filled
                        ? const Color(0xFFFFB300)
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(_rating),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _ratingColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _ratingLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _ratingColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// _buildTagsSection: các gợi ý nhanh theo mức sao.
  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _rating >= 4 ? 'Điều bạn hài lòng nhất' : 'Điều cần cải thiện',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _C.textDark,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags.map((tag) {
            final selected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: _isSubmitting
                  ? null
                  : () => setState(() {
                      selected
                          ? _selectedTags.remove(tag)
                          : _selectedTags.add(tag);
                      _showError = false;
                    }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? _C.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? _C.primary : _C.border,
                    width: 1.3,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : _C.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// _buildCommentSection: ô nhập nhận xét và thông báo lỗi nếu bỏ trống.
  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chia sẻ thêm về trải nghiệm',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _C.textDark,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _commentController,
          enabled: !_isSubmitting,
          maxLines: 4,
          maxLength: 300,
          onChanged: (_) {
            if (_showError) setState(() => _showError = false);
          },
          style: const TextStyle(fontSize: 14, height: 1.45),
          decoration: InputDecoration(
            hintText: 'Ví dụ: Bác sĩ khám rất kỹ, tư vấn tận tình...',
            hintStyle: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.all(14),
            counterStyle: const TextStyle(fontSize: 11, color: _C.textGrey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _showError ? _C.danger : _C.border,
                width: 1.3,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _showError ? _C.danger : _C.border,
                width: 1.3,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _C.primary, width: 1.6),
            ),
          ),
        ),
        if (_showError)
          const Padding(
            padding: EdgeInsets.only(top: 2, left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 15, color: _C.danger),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Vui lòng chọn gợi ý hoặc nhập nhận xét của bạn',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// _buildAnonymousTile: công tắc ẩn danh kèm giải thích.
  Widget _buildAnonymousTile() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: _isAnonymous
            ? _C.primary.withOpacity(0.07)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAnonymous ? _C.primary.withOpacity(0.35) : _C.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isAnonymous ? Icons.visibility_off_rounded : Icons.person_rounded,
            size: 22,
            color: _isAnonymous ? _C.primary : _C.textGrey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đánh giá ẩn danh',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _C.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isAnonymous
                      ? 'Tên của bạn sẽ không hiển thị'
                      : 'Tên của bạn sẽ hiển thị cùng đánh giá',
                  style: const TextStyle(fontSize: 12, color: _C.textGrey),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAnonymous,
            activeColor: _C.primary,
            onChanged: _isSubmitting
                ? null
                : (v) => setState(() => _isAnonymous = v),
          ),
        ],
      ),
    );
  }

  /// _buildFooter: chân hộp thoại gồm nút Để sau và Gửi đánh giá.
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.textGrey,
                side: const BorderSide(color: _C.border, width: 1.3),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Để sau',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitReview,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSubmitting ? 'Đang gửi...' : 'Gửi đánh giá',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _C.primary.withOpacity(0.6),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// _StatTile: ô thông tin gồm nhãn nhỏ và giá trị (ngày, giờ, số thứ tự).
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
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
              Icon(icon, size: 11, color: color.withOpacity(0.8)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: _C.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// _HistoryCard: thẻ một lịch khám cũ (hoàn thành hoặc vắng mặt) kèm nút đặt lại lịch.
class _HistoryCard extends StatelessWidget {
  final LichHenModel booking;
  final VoidCallback onRebook;

  const _HistoryCard({required this.booking, required this.onRebook});

  bool get _completed => booking.trangThaiId.toString() == '5';

  /// _shortId: lấy 6 ký tự cuối của mã lịch để hiển thị gọn.
  String get _shortId {
    final id = booking.id.replaceAll('#', '').trim();
    if (id.isEmpty) return '—';
    return (id.length > 6 ? id.substring(id.length - 6) : id).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final date = booking.ngayDat;
    final accent = _completed ? _C.success : _C.textGrey;
    final hospital = booking.tenBenhVien ?? 'Bệnh viện ${booking.benhVienId}';
    final department = booking.tenKhoa ?? 'Chuyên khoa';
    final hasHours = booking.gioBatDau != null && booking.gioKetThuc != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _C.primary.withOpacity(0.16),
                                  _C.primary.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _C.primary.withOpacity(0.18),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  date == null
                                      ? ''
                                      : weekdays[date.weekday - 1],
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: _C.primary,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  date == null ? '--' : '${date.day}',
                                  style: const TextStyle(
                                    fontSize: 23,
                                    height: 1.1,
                                    fontWeight: FontWeight.w900,
                                    color: _C.textDark,
                                  ),
                                ),
                                Text(
                                  date == null
                                      ? ''
                                      : 'Th${date.month}/${date.year % 100}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _C.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hospital,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    height: 1.25,
                                    fontWeight: FontWeight.w800,
                                    color: _C.textDark,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _completed
                                            ? Icons.check_circle_rounded
                                            : Icons.person_off_rounded,
                                        size: 14,
                                        color: accent,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _completed ? 'Hoàn thành' : 'Vắng mặt',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HistoryInfo(
                            icon: Icons.medical_services_outlined,
                            text: department,
                          ),
                          if (hasHours)
                            _HistoryInfo(
                              icon: Icons.access_time_rounded,
                              text:
                                  '${booking.gioBatDau} - ${booking.gioKetThuc}',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: _C.border),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Mã $_shortId',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: _C.textGrey,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: onRebook,
                            icon: const Icon(Icons.replay_rounded, size: 17),
                            label: const Text(
                              'Đặt lại lịch',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: _C.primary,
                              backgroundColor: _C.primary.withOpacity(0.08),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// _HistoryInfo: nhãn thông tin trong thẻ lịch cũ (chuyên khoa, khung giờ).
class _HistoryInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HistoryInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _C.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _C.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// _HistorySummary: thẻ tổng quan lịch sử gồm tổng lượt khám, số hoàn thành, số vắng mặt và thanh tỉ lệ.
class _HistorySummary extends StatelessWidget {
  final int total;
  final int completed;
  final int missed;

  const _HistorySummary({
    required this.total,
    required this.completed,
    required this.missed,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), _C.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử khám bệnh',
                      style: TextStyle(fontSize: 12.5, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total lượt khám',
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryStat(
                icon: Icons.check_circle_rounded,
                label: 'Hoàn thành',
                value: completed,
              ),
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: Colors.white.withOpacity(0.25),
              ),
              _SummaryStat(
                icon: Icons.person_off_rounded,
                label: 'Vắng mặt',
                value: missed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// _SummaryStat: một số liệu trong thẻ tổng quan lịch sử.
class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// _MonthLabel: tiêu đề nhóm tháng kèm số lượt khám trong tháng.
class _MonthLabel extends StatelessWidget {
  final String text;
  final int count;
  const _MonthLabel({required this.text, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 0, 12),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, size: 18, color: _C.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _C.textDark,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: _C.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: _C.border)),
        ],
      ),
    );
  }
}

/// _TimeAgoText: văn bản "x phút trước · giờ chính xác" tự cập nhật theo thời gian.
class _TimeAgoText extends StatefulWidget {
  final DateTime time;
  final String? suffix;
  final TextStyle style;

  const _TimeAgoText({required this.time, required this.style, this.suffix});

  @override
  State<_TimeAgoText> createState() => _TimeAgoTextState();
}

class _TimeAgoTextState extends State<_TimeAgoText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  /// _schedule: hẹn lần cập nhật kế tiếp theo "tuổi" của thông báo.
  void _schedule() {
    final age = DateTime.now().difference(widget.time);
    final wait = age.inSeconds < 60
        ? const Duration(seconds: 1)
        : (age.inMinutes < 60
              ? const Duration(seconds: 15)
              : const Duration(minutes: 1));

    _timer?.cancel();
    _timer = Timer(wait, () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void didUpdateWidget(covariant _TimeAgoText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.time != widget.time) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ago = _formatTimeAgo(widget.time);
    final text = widget.suffix == null ? ago : '$ago · ${widget.suffix}';
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}