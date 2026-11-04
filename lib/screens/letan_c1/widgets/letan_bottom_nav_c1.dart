import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';

/// Thanh Navigation Bar 4 nút của Bàn Tiếp Đón Lễ Tân
class LetanBottomNavC1 extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const LetanBottomNavC1({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                iconData: Icons.home,
                label: 'Trang chủ',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 1,
                iconData: Icons.qr_code_scanner,
                label: 'Quét QR',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 2,
                iconData: Icons.calendar_today,
                label: 'Lịch hẹn',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 3,
                iconData: Icons.person_outline,
                label: 'Tài khoản',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData iconData,
    required String label,
    required bool isDark,
  }) {
    final isSelected = currentIndex == index;
    final Color activeColor = const Color(0xFF007AFF);
    final Color inactiveColor = isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93);

    return InkWell(
      onTap: () {
        AppDesignSystemC1.hapticLight();
        onTabSelected(index);
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
