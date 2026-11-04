import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';

/// Thanh Navigation Bar 4 nút chuẩn của CSKH: Trang chủ, Duyệt đơn, CSKH, Profile
class CskhBottomNavC1 extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const CskhBottomNavC1({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        AppDesignSystemC1.hapticLight();
        onTabSelected(index);
      },
      backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
      indicatorColor: isDark
          ? const Color(0xFF0284C7).withValues(alpha: 0.3)
          : const Color(0xFFE0F2FE),
      elevation: 2,
      height: 65,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, color: AppDesignSystemC1.textSecondary),
          selectedIcon: Icon(Icons.home, color: Color(0xFF0284C7)),
          label: 'Trang chủ',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_turned_in_outlined, color: AppDesignSystemC1.textSecondary),
          selectedIcon: Icon(Icons.assignment_turned_in, color: Color(0xFF0284C7)),
          label: 'Duyệt đơn',
        ),
        NavigationDestination(
          icon: Icon(Icons.support_agent_outlined, color: AppDesignSystemC1.textSecondary),
          selectedIcon: Icon(Icons.support_agent, color: Color(0xFF0284C7)),
          label: 'CSKH',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline, color: AppDesignSystemC1.textSecondary),
          selectedIcon: Icon(Icons.person, color: Color(0xFF0284C7)),
          label: 'Profile',
        ),
      ],
    );
  }
}
