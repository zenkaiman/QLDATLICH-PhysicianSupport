import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';
import '../../../models/letan_c1/letan_qr_model_c1.dart';
import '../letan_ketqua_qr_screen_c1.dart';

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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LetanKetquaQrScreenC1(
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
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: avatarBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  color: avatarText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hoTen,
                    style: TextStyle(
                      color: textCol,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['gioKham']} • STT: ${item['stt']} • ${item['tenKhoa']}',
                    style: TextStyle(
                      color: subTextCol,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trangThai,
                style: TextStyle(
                  color: badgeText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
