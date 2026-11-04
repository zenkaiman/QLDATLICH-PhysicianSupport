import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';

/// Thẻ hiển thị thông tin từng đơn đặt lịch khám trong danh sách duyệt đơn
class CskhAppointmentCardC1 extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const CskhAppointmentCardC1({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final rawTrangThai = (item['rawTrangThai'] ?? '').toString();
    final bool laDaDuyet = rawTrangThai == 'da_duyet' || item['trangThai'] == 'Đã duyệt';
    final bool laTuChoi = rawTrangThai == 'tu_choi' || item['trangThai'] == 'Không duyệt';

    Color cardBg;
    Color borderCard;
    Widget badgeTrangThai;

    if (laDaDuyet) {
      cardBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5);
      borderCard = const Color(0xFF10B981);
      badgeTrangThai = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '✓ Đã duyệt',
          style: TextStyle(color: Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
    } else if (laTuChoi) {
      cardBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2);
      borderCard = const Color(0xFFEF4444);
      badgeTrangThai = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '✕ Không duyệt',
          style: TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
    } else {
      cardBg = isDark ? AppDesignSystemC1.darkSurface : Colors.white;
      borderCard = isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0);
      badgeTrangThai = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Chờ duyệt',
          style: TextStyle(
            color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCard),
      ),
      child: Row(
        children: [
          Row(
            children: [
              InkWell(
                onTap: onApprove,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: laDaDuyet
                        ? const Color(0xFF10B981)
                        : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFECFDF5)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Center(
                    child: Text(
                      '✓',
                      style: TextStyle(
                        color: laDaDuyet ? Colors.white : const Color(0xFF059669),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: onReject,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: laTuChoi
                        ? const Color(0xFFEF4444)
                        : (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEF2F2)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Center(
                    child: Text(
                      '✕',
                      style: TextStyle(
                        color: laTuChoi ? Colors.white : const Color(0xFFDC2626),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STT ${item['stt'] ?? '1'}: ${item['hoTen'] ?? 'Bệnh nhân'}',
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['gioKham'] ?? ''} • ${item['gioiTinh'] ?? ''}, ${item['namSinh'] ?? ''} • ${item['tenKhoa'] ?? ''}',
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                    fontSize: 11.5,
                  ),
                ),
                if (item['lyDoTuChoi'] != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Lý do: ${item['lyDoTuChoi']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          badgeTrangThai,
        ],
      ),
    );
  }
}
