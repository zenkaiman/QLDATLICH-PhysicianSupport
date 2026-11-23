import 'package:flutter/material.dart';

/// Thanh điều hướng dưới cùng cho giao diện Bệnh viện (4 tabs: Trang chủ, Khoa khám, Nhân sự, Cài đặt).
class HospitalBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool daXacThuc;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<String> onBlockedTabTap;

  const HospitalBottomNav({
    super.key,
    required this.currentIndex,
    required this.daXacThuc,
    required this.onTabSelected,
    required this.onBlockedTabTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Trang chủ',
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.grid_view_rounded,
            activeIcon: Icons.grid_view_rounded,
            label: 'Khoa khám',
            onTapBlocked: daXacThuc
                ? null
                : () => onBlockedTabTap('Khoa khám'),
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Nhân sự',
            onTapBlocked: daXacThuc
                ? null
                : () => onBlockedTabTap('Nhân sự'),
          ),
          _buildNavItem(
            index: 3,
            icon: Icons.assignment_ind_outlined,
            activeIcon: Icons.assignment_ind_rounded,
            label: 'Phân công',
            onTapBlocked: daXacThuc
                ? null
                : () => onBlockedTabTap('Phân công'),
          ),
          _buildNavItem(
            index: 4,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Cài đặt',
            onTapBlocked: daXacThuc
                ? null
                : () => onBlockedTabTap('Cài đặt'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    VoidCallback? onTapBlocked,
  }) {
    final isSelected = currentIndex == index;
    final color =
        isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8);

    return Expanded(
      child: InkWell(
        onTap: () {
          if (onTapBlocked != null) {
            onTapBlocked();
            return;
          }
          onTabSelected(index);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? activeIcon : icon, color: color, size: 21),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
