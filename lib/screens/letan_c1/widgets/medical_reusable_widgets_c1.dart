import 'package:flutter/material.dart';
import '../../../models/letan_c1/letan_design_system_c1.dart';

/// THẺ CARD CHUẨN Y TẾ DÙNG CHUNG (MỤC 5)
class MedicalCardC1 extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;

  const MedicalCardC1({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.backgroundColor,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final cardBg = backgroundColor ?? (isDark ? AppDesignSystemC1.darkSurface : Colors.white);
    final borderCol = isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0);

    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderCol, width: 1),
        boxShadow: AppDesignSystemC1.cardShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: () {
          AppDesignSystemC1.hapticLight();
          onTap!();
        },
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return content;
  }
}

/// HUY HIỆU TRẠNG THÁI CHUẨN Y TẾ DÙNG CHUNG (MỤC 5)
class MedicalStatusBadgeC1 extends StatelessWidget {
  final String trangThai;
  final double fontSize;

  const MedicalStatusBadgeC1({
    super.key,
    required this.trangThai,
    this.fontSize = 11.5,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    Color bg;
    Color text;

    final tt = trangThai.trim();
    if (tt == 'Chờ duyệt') {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFD97706);
    } else if (tt == 'Đã duyệt' || tt == 'Tiếp theo' || tt == 'Đang chờ' || tt == 'Đã tiếp nhận') {
      bg = (tt == 'Tiếp theo' || tt == 'Đã duyệt') ? const Color(0xFFE8F8EF) : const Color(0xFFE8F4FD);
      text = (tt == 'Tiếp theo' || tt == 'Đã duyệt') ? const Color(0xFF34C759) : const Color(0xFF007AFF);
    } else if (tt == 'Đã khám') {
      bg = const Color(0xFFE8F8EF);
      text = const Color(0xFF34C759);
    } else if (tt == 'Không duyệt' || tt == 'Đã hủy' || tt == 'Vắng') {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFEF4444);
    } else {
      bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      text = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tt,
        style: TextStyle(
          color: text,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Ô TÌM KIẾM CHUẨN Y TẾ DÙNG CHUNG (MỤC 5)
class MedicalSearchBarC1 extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String hintText;

  const MedicalSearchBarC1({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
    this.hintText = 'Tìm kiếm bệnh nhân, số điện thoại...',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                    onClear?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
