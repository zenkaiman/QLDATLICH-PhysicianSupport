import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';

/// Model đại diện cho một chuyên khoa khám bệnh
class KhoaKhamModelC1 {
  final String tenKhoa;
  final String moTaPhong;
  final String soLuongDon; // Ví dụ: "25/25 Đơn", "20 Đơn"
  final IconData icon;
  final bool laKhoaDangChon;
  final bool laDayDon; // Nếu đầy đơn hiển thị badge đỏ

  const KhoaKhamModelC1({
    required this.tenKhoa,
    required this.moTaPhong,
    required this.soLuongDon,
    required this.icon,
    this.laKhoaDangChon = false,
    this.laDayDon = false,
  });
}

/// Thẻ hiển thị chuyên khoa khám bệnh dạng danh sách/lưới
class CskhDepartmentCardC1 extends StatelessWidget {
  final KhoaKhamModelC1 khoa;
  final VoidCallback onTap;

  const CskhDepartmentCardC1({
    super.key,
    required this.khoa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final bool isHighlighted = khoa.laKhoaDangChon;

    final Color bgCard = isDark
        ? (isHighlighted ? const Color(0xFF0C2444) : AppDesignSystemC1.darkSurface)
        : (isHighlighted ? const Color(0xFFF0F9FF) : Colors.white);

    final Color borderCard = isHighlighted
        ? const Color(0xFF0284C7)
        : (isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderCard,
          width: isHighlighted ? 1.5 : 1.0,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? (isDark ? const Color(0xFF075985).withValues(alpha: 0.5) : const Color(0xFFE0F2FE))
                        : (isDark ? const Color(0xFF451A03).withValues(alpha: 0.5) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    khoa.icon,
                    size: 23,
                    color: isHighlighted ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        khoa.tenKhoa,
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        khoa.moTaPhong,
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadgeDon(khoa, isDark),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isHighlighted
                      ? const Color(0xFF0284C7)
                      : (isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeDon(KhoaKhamModelC1 khoa, bool isDark) {
    if (khoa.laDayDon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.7) : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.5 : 0.3),
          ),
        ),
        child: Text(
          khoa.soLuongDon,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.5 : 0.3),
        ),
      ),
      child: Text(
        khoa.soLuongDon,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFD97706),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      ),
    );
  }
}
