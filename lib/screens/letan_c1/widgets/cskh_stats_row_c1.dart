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
        final tongSo = thongKe['tongSo'] ?? 0;

        return Row(
          children: [
            Expanded(
              child: _buildItem(
                soLuong: '$dangCho',
                nhanDe: 'Đang chờ',
                mauSo: const Color(0xFFD97706),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildItem(
                soLuong: '$daDuyet',
                nhanDe: 'Đã duyệt',
                mauSo: const Color(0xFF10B981),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildItem(
                soLuong: '$tongSo',
                nhanDe: 'Tổng đơn',
                mauSo: const Color(0xFF0284C7),
                isDark: isDark,
              ),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Text(
            soLuong,
            style: TextStyle(
              color: mauSo,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            nhanDe,
            style: TextStyle(
              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
