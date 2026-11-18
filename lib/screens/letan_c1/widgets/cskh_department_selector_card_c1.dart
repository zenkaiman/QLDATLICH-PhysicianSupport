import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';

/// Card hiển thị Khoa làm việc cố định theo phân công của Bệnh viện
class CskhDepartmentSelectorCardC1 extends StatelessWidget {
  final String tenKhoaHienTai;
  final String label;
  final String badgeText;

  const CskhDepartmentSelectorCardC1({
    super.key,
    required this.tenKhoaHienTai,
    this.label = 'KHOA PHÂN CÔNG (CỐ ĐỊNH)',
    this.badgeText = 'Bệnh viện chỉ định',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Color(0xFF0284C7),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tenKhoaHienTai,
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  'Cố định',
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
