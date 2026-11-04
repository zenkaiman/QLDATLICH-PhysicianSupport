import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// HỆ THỐNG DESIGN SYSTEM CHUẨN Y TẾ HIỆN ĐẠI (MATERIAL 3) CHO C1
class AppDesignSystemC1 {
  // 1. BỘ MÀU CHÍNH (XANH DƯƠNG Y TẾ TIN CẬY & SẠCH SẼ)
  static const Color primary = Color(0xFF0284C7); // Sky Blue 600
  static const Color primaryDark = Color(0xFF0369A1); // Sky Blue 700
  static const Color primaryLight = Color(0xFFE0F2FE); // Sky Blue 100
  static const Color primaryContainer = Color(0xFFBAE6FD);

  // MÀU NỀN & MÀU PHỤ TRỢ (CHẾ ĐỘ SÁNG)
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textTertiary = Color(0xFF94A3B8); // Slate 400

  // MÀU PHỤ TRỢ (CHẾ ĐỘ TỐI - DARK MODE CHUẨN OLED / SLATE SANG TRỌNG)
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900 đen tuyền hiện đại
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800 thẻ card nổi bật
  static const Color darkCardSub = Color(0xFF334155); // Slate 700 ô con bên trong card
  static const Color darkBorder = Color(0xFF334155); // Slate 700 viền mềm mại
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50 chữ trắng sáng
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400 chữ phụ dịu mắt

  // QUẢN LÝ CHẾ ĐỘ SÁNG / TỐI (LIGHT / DARK THEME NOTIFIER)
  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);
  static bool get laCheDoToi => isDarkMode.value;

  static void batTatCheDoSangToi() {
    isDarkMode.value = !isDarkMode.value;
    hapticLight();
  }

  // GETTERS TRẢ VỀ MÀU LINH HOẠT THEO CHẾ ĐỘ SÁNG / TỐI
  static Color get mauNen => isDarkMode.value ? darkBackground : background;
  static Color get mauThe => isDarkMode.value ? darkSurface : surface;
  static Color get mauThePhu => isDarkMode.value ? darkCardSub : const Color(0xFFF1F5F9);
  static Color get mauVien => isDarkMode.value ? darkBorder : border;
  static Color get mauChuChinh => isDarkMode.value ? darkTextPrimary : textPrimary;
  static Color get mauChuPhu => isDarkMode.value ? darkTextSecondary : textSecondary;
  static Color get mauHeaderAppBar => isDarkMode.value ? darkSurface : Colors.white;

  // 2. MÀU TRẠNG THÁI CHUẨN Y TẾ ĐỒNG NHẤT
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF3B82F6); // Blue 500
  static const Color infoBg = Color(0xFFEFF6FF);

  // 3. HỆ THỐNG BO GÓC (BORDER RADIUS 16 - 20px)
  static const double radiusSmall = 10.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusFull = 999.0;

  static BorderRadius get borderRadSmall => BorderRadius.circular(radiusSmall);
  static BorderRadius get borderRadMedium => BorderRadius.circular(radiusMedium);
  static BorderRadius get borderRadLarge => BorderRadius.circular(radiusLarge);

  // 4. SHADOW CHIỀU SÂU NHẸ (SUBTLE DEPTH)
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  // 5. PHẢN HỒI RUNG NHẸ (HAPTIC FEEDBACK)
  static void hapticLight() {
    HapticFeedback.lightImpact();
  }

  static void hapticSuccess() {
    HapticFeedback.mediumImpact();
  }

  static void hapticError() {
    HapticFeedback.heavyImpact();
  }

  // 6. SNACKBAR ĐẸP THEO CHUẨN M3 VỚI ICON & MÀU TRẠNG THÁI
  static void showCustomSnackBar(
    BuildContext context, {
    required String message,
    bool isSuccess = true,
    IconData? icon,
  }) {
    hapticLight();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: isSuccess ? successBg : errorBg,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadMedium,
          side: BorderSide(color: isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
        ),
        content: Row(
          children: [
            Icon(
              icon ?? (isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded),
              color: isSuccess ? success : error,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 2500),
      ),
    );
  }

  // 7. ROUTE TRANSITION ĐẸP (FADE + SLIDE 250ms)
  static Route<T> pageRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.04, 0.0);
        const end = Offset.zero;
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: curve, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}
