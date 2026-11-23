import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';
import '../../../models/letan_c1/letan_profile_model_c1.dart';
import '../../../services/letan_c1/letan_firebase_service_c1.dart';

/// Hàng thẻ thống kê nhanh số lượng đơn duyệt trong ngày của CSKH
class CskhStatsRowC1 extends StatelessWidget {
  final String tenKhoa;
  final DateTime ngayChon;

  const CskhStatsRowC1({
    super.key,
    required this.tenKhoa,
    required this.ngayChon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;

    return StreamBuilder<Map<String, int>>(
      stream: FirebaseServiceC1.streamThongKeHomNay(
        tenKhoa: tenKhoa,
        ngayChon: ngayChon,
        benhVienId: bvid,
        laCskh: true,
      ),
      builder: (context, snapshot) {
        final thongKe = snapshot.data ?? {
          'daTiepNhan': 0,
          'dangCho': 0,
          'daKham': 0,
          'tongSo': 0,
        };

        final dangCho = thongKe['dangCho'] ?? 0;
        final daDuyet = thongKe['daTiepNhan'] ?? 0;

        return Row(
          children: [
            Expanded(
              child: _buildItem(
                context: context,
                soLuong: '$dangCho',
                nhanDe: 'Cần duyệt',
                mauSo: const Color(0xFFD97706),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildItem(
                context: context,
                soLuong: '$dangCho',
                nhanDe: 'Được phép duyệt',
                mauSo: const Color(0xFF0284C7),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildItem(
                context: context,
                soLuong: '$daDuyet',
                nhanDe: 'Đã cấp STT',
                mauSo: const Color(0xFF10B981),
                isDark: isDark,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required String soLuong,
    required String nhanDe,
    required Color mauSo,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppDesignSystemC1.scale(context, 11)),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                soLuong,
                style: TextStyle(
                  color: mauSo,
                  fontSize: AppDesignSystemC1.scale(context, 20),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                nhanDe,
                maxLines: 1,
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                  fontSize: AppDesignSystemC1.scale(context, 11.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
