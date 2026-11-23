import 'package:flutter/material.dart';

// =========================================================================
// HỆ THỐNG MÀU SẮC & GIAO DIỆN QUẢN TRỊ VIÊN HIỆN ĐẠI (STRIPE & LINEAR STYLE)
// =========================================================================

// --- Màu nền & Bề mặt ---
const kBg = Color(0xFFF8FAFC);          // Nền Slate-50 sạch sẽ, dịu mắt
const kSurface = Color(0xFFFFFFFF);     // Màu bề mặt Card trắng tinh
const kSurfaceSubtle = Color(0xFFF1F5F9);// Slate-100 cho ô nhập liệu, pill
const kBorder = Color(0xFFE2E8F0);      // Viền card thanh mảnh 1px (Slate-200)
const kBorderSubtle = Color(0xFFF1F5F9);// Viền rất nhạt (Slate-100)

// --- Màu Thương hiệu / Chủ đạo (Royal Sapphire Blue) ---
const kPrimary = Color(0xFF2563EB);     // Xanh công nghệ hiện đại (Blue-600)
const kPrimaryLight = Color(0xFFEFF6FF);// Xanh pastel nhạt (Blue-50)
const kPrimaryHover = Color(0xFF1D4ED8);// Blue-700
const kPrimaryDark = Color(0xFF1E40AF); // Blue-800

// --- Màu Trạng thái (Semantic Colors) ---
const kGreen = Color(0xFF059669);       // Xanh Emerald duyệt / online / thành công
const kGreenBg = Color(0xFFD1FAE5);     // Emerald-100
const kGreenLight = Color(0xFFECFDF5);  // Emerald-50
const kGreenBorder = Color(0xFFA7F3D0); // Emerald-200

const kRed = Color(0xFFDC2626);         // Đỏ Rose cảnh báo / xóa / từ chối
const kRedBg = Color(0xFFFEE2E2);       // Rose-100
const kRedLight = Color(0xFFFEF2F2);    // Rose-50
const kRedBorder = Color(0xFFFECACA);   // Rose-200

const kOrange = Color(0xFFEA580C);      // Cam cảnh báo / cần xử lý
const kAmber = Color(0xFFD97706);       // Vàng hổ phách chờ duyệt
const kOrangeBg = Color(0xFFFFEDD5);    // Orange-100
const kAmberLight = Color(0xFFFFFBEB);  // Amber-50
const kYellowBg = Color(0xFFFEF3C7);    // Amber-100
const kAmberBorder = Color(0xFFFDE68A); // Amber-200

const kPurple = Color(0xFF7C3AED);      // Tím phân tích / thống kê
const kPurpleLight = Color(0xFFF5F3FF); // Purple-50
const kTeal = Color(0xFF0D9488);        // Xanh Teal bệnh nhân
const kTealLight = Color(0xFFCCFBF1);   // Teal-50

// --- Thang màu xám chữ (Typography Palette) ---
const kSlate900 = Color(0xFF0F172A);    // Chữ tiêu đề chính (Slate-900)
const kSlate800 = Color(0xFF1E293B);    // Chữ tiêu đề phụ
const kSlate700 = Color(0xFF334155);    // Nội dung chính
const kSlate600 = Color(0xFF475569);    // Chữ phụ
const kSlate500 = Color(0xFF64748B);    // Chữ chú thích / nhãn phụ
const kSlate400 = Color(0xFF94A3B8);    // Placeholder / icon mờ
const kSlate300 = Color(0xFFCBD5E1);    // Phân cách
const kSlate200 = Color(0xFFE2E8F0);    // Đường kẻ viền
const kSlate100 = Color(0xFFF1F5F9);    // Nền nút bấm mờ

// ============ HIỆU ỨNG ĐỔ BÓNG CAO CẤP (LAYERED AMBIENT SHADOWS) ============
const kCardShadow = [
  BoxShadow(
    color: Color(0x060F172A),
    blurRadius: 16,
    offset: Offset(0, 4),
  ),
  BoxShadow(
    color: Color(0x040F172A),
    blurRadius: 4,
    offset: Offset(0, 1),
  ),
];

const kElevatedShadow = [
  BoxShadow(
    color: Color(0x0C0F172A),
    blurRadius: 24,
    offset: Offset(0, 8),
  ),
  BoxShadow(
    color: Color(0x040F172A),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];

const kFloatingShadow = [
  BoxShadow(
    color: Color(0x100F172A),
    blurRadius: 32,
    offset: Offset(0, 12),
  ),
];

// ============ THEME TỔNG THỂ TOÀN ỨNG DỤNG ============
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      primary: kPrimary,
      surface: kSurface,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kSlate900,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: kSlate900,
        letterSpacing: -0.3,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFF1F5F9),
      thickness: 1,
      space: 1,
    ),
  );
}
