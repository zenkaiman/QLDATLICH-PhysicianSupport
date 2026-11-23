import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';
import '../../../models/letan_c1/letan_qr_model_c1.dart';
import 'letan_qr_quick_view_bottom_sheet_c1.dart';

/// Thẻ hiển thị bệnh nhân trong danh sách chờ khám của Lễ tân
class LetanPatientCardC1 extends StatelessWidget {
  final Map<String, dynamic> item;

  const LetanPatientCardC1({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color badgeText;
    Color avatarBg;
    Color avatarText;

    final trangThai = item['trangThai'] ?? 'Đang chờ';
    if (trangThai == 'Tiếp theo') {
      badgeBg = const Color(0xFFE8F8EF);
      badgeText = const Color(0xFF34C759);
      avatarBg = const Color(0xFFE8F8EF);
      avatarText = const Color(0xFF34C759);
    } else if (trangThai == 'Đang chờ') {
      badgeBg = const Color(0xFFE8F4FD);
      badgeText = const Color(0xFF007AFF);
      avatarBg = const Color(0xFFE8F4FD);
      avatarText = const Color(0xFF007AFF);
    } else {
      badgeBg = const Color(0xFFF2F2F7);
      badgeText = const Color(0xFF8E8E93);
      avatarBg = const Color(0xFFF2F2F7);
      avatarText = const Color(0xFF8E8E93);
    }

    final isDark = AppDesignSystemC1.laCheDoToi;
    final cardBg = isDark ? AppDesignSystemC1.darkSurface : Colors.white;
    final borderCol = isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA);
    final textCol = isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E);
    final subTextCol = isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93);

    final hoTen = (item['hoTen'] ?? 'Bệnh nhân').toString();
    final initials = hoTen.trim().isNotEmpty
        ? hoTen.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'BN';

    return InkWell(
      onTap: () {
        AppDesignSystemC1.hapticLight();
        LetanQrQuickViewBottomSheetC1.show(
          context: context,
          ketQua: KetQuaQuetQrC1(
            thanhCong: true,
            thongBao: 'Hồ sơ tiếp nhận bệnh nhân',
            chiTietLoi: 'Đã tiếp nhận vào hàng chờ',
            soThuTu: int.tryParse(item['stt']?.toString() ?? '1') ?? 1,
            gioKhamDuKien: '${item['gioKham']} - Hôm nay',
            hoTen: hoTen.toUpperCase(),
            maBenhNhan: (item['maBenhNhan'] ?? '').toString(),
            namSinhGioiTinh: [
              item['namSinh']?.toString() ?? '',
              item['gioiTinh']?.toString() ?? ''
            ].where((s) => s.isNotEmpty).join(' - '),
            cccd: (item['cccd'] ?? '').toString(),
            bhyt: (item['bhyt'] ?? '').toString(),
            khoaKham: (item['tenKhoa'] ?? '').toString(),
            phongKham: (item['phongKham'] ?? '').toString(),
            bacSi: (item['bacSi'] ?? '').toString(),
          ),
          onQuetTiep: () {},
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDesignSystemC1.scale(context, 12),
          vertical: AppDesignSystemC1.scale(context, 10),
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          children: [
            Container(
              width: AppDesignSystemC1.scale(context, 40),
              height: AppDesignSystemC1.scale(context, 40),
              decoration: BoxDecoration(
                color: avatarBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  color: avatarText,
                  fontSize: AppDesignSystemC1.scale(context, 14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: AppDesignSystemC1.scale(context, 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hoTen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textCol,
                      fontSize: AppDesignSystemC1.scale(context, 15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (item['so_thu_tu'] != null && item['so_thu_tu'].toString().isNotEmpty)
                        ? '${item['gioKham']} • STT: ${item['so_thu_tu']} • ${item['tenKhoa']}'
                        : '${item['gioKham']} • ${item['tenKhoa']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subTextCol,
                      fontSize: AppDesignSystemC1.scale(context, 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trangThai,
                  style: TextStyle(
                    color: badgeText,
                    fontSize: AppDesignSystemC1.scale(context, 11.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
