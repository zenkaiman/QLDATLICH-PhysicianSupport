import 'package:flutter/material.dart';
import '../../../models/letan_c1/letan_design_system_c1.dart';
import '../../../models/letan_c1/letan_qr_model_c1.dart';

/// MODAL BOTTOM SHEET XEM NHANH THÔNG TIN QR (PHƯƠNG ÁN 1 + 3)
/// - Chế độ Read-only (Chỉ xem)
/// - Trực quan, nổi bật Số Thứ Tự (STT) và Trạng thái
/// - Nút "Đã xem • Quét tiếp mã khác" đóng sheet và tiếp tục camera ngay lập tức
class LetanQrQuickViewBottomSheetC1 extends StatelessWidget {
  final KetQuaQuetQrC1 ketQua;
  final VoidCallback onQuetTiep;

  const LetanQrQuickViewBottomSheetC1({
    super.key,
    required this.ketQua,
    required this.onQuetTiep,
  });

  static Future<void> show({
    required BuildContext context,
    required KetQuaQuetQrC1 ketQua,
    required VoidCallback onQuetTiep,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LetanQrQuickViewBottomSheetC1(
        ketQua: ketQua,
        onQuetTiep: onQuetTiep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final cardBg = isDark ? AppDesignSystemC1.darkSurface : Colors.white;
    final textCol = isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A);

    // Xác định màu sắc theo trạng thái ngày khám
    Color statusBg;
    Color statusText;
    Color statusBorder;
    IconData statusIcon;

    switch (ketQua.trangThaiNgayKham) {
      case TrangThaiNgayKhamC1.dungNgay:
        statusBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5);
        statusText = const Color(0xFF10B981);
        statusBorder = isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0);
        statusIcon = Icons.check_circle_rounded;
        break;
      case TrangThaiNgayKhamC1.chuaToiNgay:
        statusBg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFFFBEB);
        statusText = const Color(0xFFF59E0B);
        statusBorder = isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A);
        statusIcon = Icons.schedule_rounded;
        break;
      case TrangThaiNgayKhamC1.daQuaHan:
      case TrangThaiNgayKhamC1.khongXacDinh:
        statusBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEF2F2);
        statusText = const Color(0xFFEF4444);
        statusBorder = isDark ? const Color(0xFFB91C1C) : const Color(0xFFFECACA);
        statusIcon = Icons.cancel_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thanh kéo (Drag handle)
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Tiêu đề + STT
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KẾT QUẢ ĐỐI SOÁT VÉ KHÁM',
                      style: TextStyle(
                        color: AppDesignSystemC1.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ketQua.hoTen ?? 'BỆNH NHÂN',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Huy hiệu Số Thứ Tự (STT) lớn
              if (ketQua.soThuTu != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppDesignSystemC1.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'STT',
                        style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        ketQua.soThuTu.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Banner Trạng thái đối soát
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusBorder),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusText, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ketQua.thongBao,
                        style: TextStyle(
                          color: statusText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (ketQua.chiTietLoi.isNotEmpty)
                        Text(
                          ketQua.chiTietLoi,
                          style: TextStyle(
                            color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Khối thông tin chi tiết (Read-only)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                _buildInfoRow('Mã lịch hẹn:', ketQua.maLichHen ?? '---', isDark, isHighlight: true),
                const Divider(height: 12, thickness: 0.6),
                _buildInfoRow('Ngày khám:', ketQua.ngayKham ?? 'Hôm nay', isDark),
                const Divider(height: 12, thickness: 0.6),
                _buildInfoRow('Giờ khám:', ketQua.gioKhamDuKien ?? 'Trong ngày', isDark),
                const Divider(height: 12, thickness: 0.6),
                _buildInfoRow('Chuyên khoa:', ketQua.khoaKham ?? 'Khoa Khám Bệnh', isDark),
                const Divider(height: 12, thickness: 0.6),
                _buildInfoRow('Phòng khám:', ketQua.phongKham ?? 'Tiếp nhận', isDark),
                if (ketQua.cccd != null && ketQua.cccd!.isNotEmpty) ...[
                  const Divider(height: 12, thickness: 0.6),
                  _buildInfoRow('CCCD/Định danh:', ketQua.cccd!, isDark),
                ],
                if (ketQua.bhyt != null && ketQua.bhyt!.isNotEmpty) ...[
                  const Divider(height: 12, thickness: 0.6),
                  _buildInfoRow('BHYT:', ketQua.bhyt!, isDark),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Nút bấm: "ĐÃ XEM • TIẾP TỤC QUÉT"
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                AppDesignSystemC1.hapticLight();
                Navigator.pop(context);
                onQuetTiep();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignSystemC1.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text(
                'Đã xem • Tiếp tục quét mã khác',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isHighlight
                  ? AppDesignSystemC1.primary
                  : (isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A)),
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
