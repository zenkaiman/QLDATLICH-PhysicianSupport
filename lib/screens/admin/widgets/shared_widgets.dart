import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/admin_store.dart';

// =========================================================================
// CÁC THÀNH PHẦN GIAO DIỆN DÙNG CHUNG CAO CẤP (SHARED ADMIN DESIGN SYSTEM)
// =========================================================================

// ============ AVATAR CHỮ / VIẾT TẮT ============
class AvatarBox extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final double size;

  const AvatarBox({
    super.key,
    required this.text,
    required this.bg,
    required this.fg,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: fg.withValues(alpha: 0.15), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: fg,
          fontSize: size * 0.32,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ============ NÚT BACK TRÒN HIỆN ĐẠI ============
class BackCircle extends StatelessWidget {
  final VoidCallback? onTap;
  const BackCircle({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: kBorder),
          boxShadow: kCardShadow,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: kSlate800),
      ),
    );
  }
}

// ============ NÚT CHUÔNG THÔNG BÁO VỚI BADGE ============
class BellButton extends StatelessWidget {
  final int count;
  const BellButton({super.key, this.count = 0});

  @override
  Widget build(BuildContext context) {
    final effectiveCount = count > 0 ? count : AdminStore.instance.reports.length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
            boxShadow: kCardShadow,
          ),
          child: const Icon(Icons.notifications_outlined, color: kSlate800, size: 22),
        ),
        if (effectiveCount > 0)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: kRed,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                effectiveCount > 9 ? '9+' : '$effectiveCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============ BADGE LIVE FIREBASE (Realtime pulsing) ============
class LiveSyncBadge extends StatefulWidget {
  const LiveSyncBadge({super.key});

  @override
  State<LiveSyncBadge> createState() => _LiveSyncBadgeState();
}

class _LiveSyncBadgeState extends State<LiveSyncBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kGreenLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _opacity,
            builder: (_, __) => Opacity(
              opacity: _opacity.value,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: kGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Firebase Live',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: kGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ============ BADGE REALTIME HOẠT ĐỘNG (TƯƠNG TÁC + ANIMATION) ============
class HeroRealtimeBadge extends StatefulWidget {
  const HeroRealtimeBadge({super.key});

  @override
  State<HeroRealtimeBadge> createState() => _HeroRealtimeBadgeState();
}

class _HeroRealtimeBadgeState extends State<HeroRealtimeBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    AdminStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    AdminStore.instance.removeListener(_onStoreChanged);
    _rotationController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (AdminStore.instance.isSyncing) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
        _rotationController.reset();
      }
    }
    if (mounted) setState(() {});
  }

  void _handleManualSync() async {
    _rotationController.repeat();
    await AdminStore.instance.syncNow();
    _rotationController.stop();
    _rotationController.reset();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Đã cập nhật Realtime! (${AdminStore.instance.totalBV} BV, ${AdminStore.instance.pendingTotal} chờ duyệt)',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AdminStore.instance;

    return InkWell(
      onTap: _handleManualSync,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _rotationController,
              child: const Icon(
                Icons.sync_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF4ADE80),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              store.isSyncing ? 'Đang đồng bộ...' : 'Realtime Live',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ BADGE NHÃN (APP BADGE) ============
class AppBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.text,
    required this.color,
    required this.bg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ THANH ĐIỀU HƯỚNG DƯỚI CAO CẤP (MODERN ADMIN BOTTOM BAR) ============
class AdminBottomBar extends StatelessWidget {
  final int current;
  final Function(int) onTap;

  const AdminBottomBar({
    super.key,
    required this.current,
    required this.onTap,
  });

  Widget _buildItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    int badgeCount = 0,
    bool isDanger = false,
  }) {
    final bool active = index == current;
    final Color itemColor = isDanger
        ? kRed
        : (active ? kPrimary : kSlate400);

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: active ? 16 : 6,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: active ? (isDanger ? kRedLight : kPrimaryLight) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: badgeCount > 0
                    ? Badge(
                        backgroundColor: kRed,
                        label: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        child: Icon(
                          active ? activeIcon : icon,
                          size: 22,
                          color: itemColor,
                        ),
                      )
                    : Icon(
                        active ? activeIcon : icon,
                        size: 22,
                        color: itemColor,
                      ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: itemColor,
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
    final store = AdminStore.instance;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
        boxShadow: [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _buildItem(
                index: 0,
                label: 'Trang chủ',
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
              ),
              _buildItem(
                index: 1,
                label: 'Bệnh viện',
                icon: Icons.local_hospital_outlined,
                activeIcon: Icons.local_hospital_rounded,
              ),
              _buildItem(
                index: 2,
                label: 'Bệnh nhân',
                icon: Icons.people_alt_outlined,
                activeIcon: Icons.people_alt_rounded,
              ),
              _buildItem(
                index: 3,
                label: 'Xử lý',
                icon: Icons.assignment_turned_in_outlined,
                activeIcon: Icons.assignment_turned_in_rounded,
                badgeCount: store.pendingTotal + store.reports.length,
              ),
              _buildItem(
                index: 4,
                label: 'Đăng xuất',
                icon: Icons.logout_rounded,
                activeIcon: Icons.logout_rounded,
                isDanger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ Ô TÌM KIẾM HIỆN ĐẠI (MODERN SEARCH BOX) ============
class SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final VoidCallback? onClear;

  const SearchBox({
    super.key,
    required this.hint,
    this.onChanged,
    this.controller,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: kSlate400),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: kSlate900, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: kSlate400, fontWeight: FontWeight.w500),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller != null && controller!.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.cancel_rounded, size: 18, color: kSlate400),
            ),
        ],
      ),
    );
  }
}

// ============ TRẠNG THÁI TRỐNG HIỆN ĐẠI (EMPTY STATE) ============
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: kSlate400),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kSlate900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kSlate500, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
