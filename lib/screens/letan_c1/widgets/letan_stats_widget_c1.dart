import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';
import '../../../models/letan_c1/letan_profile_model_c1.dart';
import '../../../services/letan_c1/letan_firebase_service_c1.dart';

/// Khối thống kê lịch khám hôm nay của bàn Lễ tân
class LetanStatsWidgetC1 extends StatelessWidget {
  final String tenKhoaHienTai;
  final DateTime ngayChon;
  final VoidCallback onSelectDate;

  const LetanStatsWidgetC1({
    super.key,
    required this.tenKhoaHienTai,
    required this.ngayChon,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final String ngayHienThi =
        '${ngayChon.day.toString().padLeft(2, '0')}/${ngayChon.month.toString().padLeft(2, '0')}/${ngayChon.year}';
    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;

    return StreamBuilder<Map<String, int>>(
      stream: FirebaseServiceC1.streamThongKeHomNay(
        tenKhoa: tenKhoaHienTai,
        ngayChon: ngayChon,
        benhVienId: bvid,
      ),
      builder: (context, snapshot) {
        final thongKe = snapshot.data ?? {
          'daTiepNhan': 0,
          'dangCho': 0,
          'daKham': 0,
          'tongSo': 0,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Thống kê lịch khám',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            FirebaseServiceC1.laCheDoTong(tenKhoaHienTai) ? 'Toàn viện' : tenKhoaHienTai,
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onSelectDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF1E88E5)),
                        const SizedBox(width: 4),
                        Text(
                          ngayHienThi,
                          style: TextStyle(
                            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildItem(
                    soLuong: '${thongKe['daTiepNhan'] ?? 0}',
                    nhanDe: 'Đã tiếp nhận',
                    mauSo: const Color(0xFFFF9500),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildItem(
                    soLuong: '${thongKe['dangCho'] ?? 0}',
                    nhanDe: 'Đang chờ',
                    mauSo: const Color(0xFF007AFF),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildItem(
                    soLuong: '${thongKe['daKham'] ?? 0}',
                    nhanDe: 'Đã khám',
                    mauSo: const Color(0xFF34C759),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildItem({
    required String soLuong,
    required String nhanDe,
    required Color mauSo,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
      ),
      child: Column(
        children: [
          Text(
            soLuong,
            style: TextStyle(
              color: mauSo,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nhanDe,
            style: TextStyle(
              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
