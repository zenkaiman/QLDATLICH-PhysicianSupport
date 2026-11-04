import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';
import '../letan_timkiem_screen_c1.dart';

/// Dãy chức năng thao tác nhanh cuộn ngang của Lễ tân
class LetanQuickActionsC1 extends StatelessWidget {
  final VoidCallback onOpenQr;
  final VoidCallback onOpenLichHen;
  final VoidCallback onOpenBaoCaoLoi;
  final VoidCallback onOpenProfile;

  const LetanQuickActionsC1({
    super.key,
    required this.onOpenQr,
    required this.onOpenLichHen,
    required this.onOpenBaoCaoLoi,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chức năng nhanh',
              style: TextStyle(
                color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Vuốt ngang ➔',
              style: TextStyle(
                color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              // 1. Tìm bệnh nhân
              _buildItem(
                context: context,
                tieuDe: 'Tìm bệnh nhân',
                moTa: 'Theo tên / SĐT',
                iconData: Icons.search,
                mauIcon: const Color(0xFF007AFF),
                mauNenIcon: isDark ? const Color(0xFF0C2444) : const Color(0xFFE8F4FD),
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LetanTimkiemScreenC1()),
                  );
                },
              ),
              const SizedBox(width: 10),

              // 2. Lịch hẹn hôm nay
              _buildItem(
                context: context,
                tieuDe: 'Lịch hẹn hôm nay',
                moTa: 'Tra cứu & Lọc',
                iconData: Icons.calendar_today,
                mauIcon: const Color(0xFFFF9500),
                mauNenIcon: isDark ? const Color(0xFF332005) : const Color(0xFFFFF5E6),
                isDark: isDark,
                onTap: onOpenLichHen,
              ),
              const SizedBox(width: 10),

              // 3. Quét mã QR
              _buildItem(
                context: context,
                tieuDe: 'Quét mã QR',
                moTa: 'Tiếp đón tại quầy',
                iconData: Icons.qr_code_scanner,
                mauIcon: const Color(0xFF10B981),
                mauNenIcon: isDark ? const Color(0xFF052A1C) : const Color(0xFFECFDF5),
                isDark: isDark,
                onTap: onOpenQr,
              ),
              const SizedBox(width: 10),

              // 4. Báo cáo sự cố
              _buildItem(
                context: context,
                tieuDe: 'Báo cáo sự cố',
                moTa: 'Gửi lỗi hệ thống',
                iconData: Icons.warning_amber_rounded,
                mauIcon: const Color(0xFFFF3B30),
                mauNenIcon: isDark ? const Color(0xFF33100D) : const Color(0xFFFEE2E2),
                isDark: isDark,
                onTap: onOpenBaoCaoLoi,
              ),
              const SizedBox(width: 10),

              // 5. Hồ sơ cá nhân
              _buildItem(
                context: context,
                tieuDe: 'Hồ sơ lễ tân',
                moTa: 'Đổi mật khẩu / Khoa',
                iconData: Icons.person_outline,
                mauIcon: const Color(0xFF8B5CF6),
                mauNenIcon: isDark ? const Color(0xFF23143E) : const Color(0xFFF3E8FF),
                isDark: isDark,
                onTap: onOpenProfile,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required String tieuDe,
    required String moTa,
    required IconData iconData,
    required Color mauIcon,
    required Color mauNenIcon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        AppDesignSystemC1.hapticLight();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 165,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: mauNenIcon,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(iconData, color: mauIcon, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tieuDe,
                    style: TextStyle(
                      color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    moTa,
                    style: TextStyle(
                      color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
