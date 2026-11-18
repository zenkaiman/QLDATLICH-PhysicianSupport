import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _NavItemData {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const _NavItemData(this.activeIcon, this.inactiveIcon, this.label);
}

/// MedicalBottomNavBar: thanh điều hướng dưới cùng, nổi, nền trắng, ô chọn trượt mượt.
class MedicalBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int notificationCount;
  final int chatCount;
  final int? highlightIndex;
  final bool showLabels;

  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1E40AF);
  static const Color _activeBg = Color(0xFFEFF6FF);
  static const Color _inactive = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE6EBF2);
  static const Color _badge = Color(0xFFEF4444);

  static const double _barHeight = 70;
  static const double _barRadius = 26;

  static const List<_NavItemData> _items = [
    _NavItemData(Icons.home_rounded, Icons.home_outlined, 'Trang chủ'),
    _NavItemData(
      Icons.calendar_month_rounded,
      Icons.calendar_month_outlined,
      'Lịch khám',
    ),
    _NavItemData(
      Icons.chat_rounded,
      Icons.chat_bubble_outline_rounded,
      'Hỗ trợ',
    ),
    _NavItemData(
      Icons.notifications_rounded,
      Icons.notifications_none_rounded,
      'Thông báo',
    ),
    _NavItemData(Icons.person_rounded, Icons.person_outline_rounded, 'Cá nhân'),
  ];

  const MedicalBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.notificationCount = 0,
    this.chatCount = 0,
    this.highlightIndex,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final count = _items.length;
    final index = currentIndex < 0
        ? 0
        : (currentIndex >= count ? count - 1 : currentIndex);
    final hidePill = highlightIndex != null && index == highlightIndex;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: _barHeight,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_barRadius),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                alignment: Alignment(-1 + 2 * index / (count - 1), 0),
                child: AnimatedOpacity(
                  opacity: hidePill ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: FractionallySizedBox(
                    widthFactor: 1 / count,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _activeBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _primary.withOpacity(0.14),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 18,
                            height: 3.5,
                            decoration: const BoxDecoration(
                              color: _primary,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: List.generate(
                  count,
                  (i) => Expanded(child: _buildItem(i, index)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// _buildItem: dựng một mục điều hướng gồm biểu tượng, nhãn và huy hiệu.
  Widget _buildItem(int i, int activeIndex) {
    final item = _items[i];
    final isActive = i == activeIndex;
    final isHighlight = highlightIndex != null && i == highlightIndex;
    final badge = i == 2 ? chatCount : (i == 3 ? notificationCount : 0);

    final Widget icon = isHighlight
        ? _HighlightButton(icon: item.activeIcon, active: isActive)
        : AnimatedScale(
            scale: isActive ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: Icon(
              isActive ? item.activeIcon : item.inactiveIcon,
              size: 25,
              color: isActive ? _primary : _inactive,
            ),
          );

    return Semantics(
      button: true,
      selected: isActive,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap(i);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                icon,
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -5,
                    child: _Badge(count: badge),
                  ),
              ],
            ),
            if (showLabels) ...[
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive ? _primaryDark : _inactive,
                  letterSpacing: 0.1,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// _HighlightButton: nút nổi bật nền gradient cho mục đặc biệt.
class _HighlightButton extends StatelessWidget {
  final IconData icon;
  final bool active;

  const _HighlightButton({required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 25, color: Colors.white),
      ),
    );
  }
}

/// _Badge: huy hiệu số đỏ có viền trắng cho thông báo chưa đọc.
class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MedicalBottomNavBar._badge,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: MedicalBottomNavBar._badge.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          fontSize: 10,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}