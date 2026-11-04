import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';
import '../../../services/letan_c1/letan_firebase_service_c1.dart';
import '../cskh_danhsach_don_khoa_screen_c1.dart';

/// Modal BottomSheet hiển thị danh sách Thông báo hệ thống cho Lễ tân & CSKH
class CskhThongBaoBottomSheetC1 {
  static void show(
    BuildContext context, {
    String vaiTro = 'cskh',
    String tieuDe = 'Thông Báo',
  }) {
    AppDesignSystemC1.hapticLight();
    final isDark = AppDesignSystemC1.laCheDoToi;
    String tabLocHienTai = 'tat_ca';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseServiceC1.streamThongBaoRealtime(vaiTro: vaiTro),
              builder: (context, snapshot) {
                final dsThongBaoRaw = snapshot.data ?? [];
                final soLuongChuaDoc = dsThongBaoRaw.where((e) => e['da_doc'] != true).length;
                final danhSachHienThi = tabLocHienTai == 'chua_doc'
                    ? dsThongBaoRaw.where((e) => e['da_doc'] != true).toList()
                    : dsThongBaoRaw;

                return Container(
                  height: MediaQuery.of(context).size.height * 0.72,
                  decoration: BoxDecoration(
                    color: isDark ? AppDesignSystemC1.darkBackground : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_active_rounded,
                                    color: Color(0xFF0284C7),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tieuDe,
                                      style: TextStyle(
                                        color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '$soLuongChuaDoc thông báo chưa đọc',
                                      style: TextStyle(
                                        color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                                ),
                                onPressed: () => Navigator.pop(modalCtx),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Tabs lọc: Tất cả / Chưa đọc
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    AppDesignSystemC1.hapticLight();
                                    setModalState(() => tabLocHienTai = 'tat_ca');
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: tabLocHienTai == 'tat_ca'
                                          ? (isDark ? const Color(0xFF0C2444) : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Tất cả (${dsThongBaoRaw.length})',
                                      style: TextStyle(
                                        color: tabLocHienTai == 'tat_ca'
                                            ? const Color(0xFF0284C7)
                                            : (isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B)),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    AppDesignSystemC1.hapticLight();
                                    setModalState(() => tabLocHienTai = 'chua_doc');
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: tabLocHienTai == 'chua_doc'
                                          ? (isDark ? const Color(0xFF0C2444) : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Chưa đọc ($soLuongChuaDoc)',
                                      style: TextStyle(
                                        color: tabLocHienTai == 'chua_doc'
                                            ? const Color(0xFFFF3B30)
                                            : (isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B)),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: danhSachHienThi.isEmpty
                            ? Center(
                                child: Text(
                                  'Không có thông báo nào',
                                  style: TextStyle(
                                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: danhSachHienThi.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = danhSachHienThi[index];
                                  final tieuDeItem = (item['tieu_de'] ?? item['tieuDe'] ?? 'Thông báo').toString();
                                  final noiDung = (item['noi_dung'] ?? item['noiDung'] ?? '').toString();
                                  final thoiGian =
                                      (item['thoi_gian_hien_thi'] ?? item['thoiGian'] ?? 'Vừa xong').toString();
                                  final daDoc = item['da_doc'] == true;

                                  return InkWell(
                                    onTap: () {
                                      if (item['id'] != null) {
                                        FirebaseServiceC1.danhDauDaDocThongBao(item['id'].toString());
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  tieuDeItem,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppDesignSystemC1.darkTextPrimary
                                                        : const Color(0xFF0F172A),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              if (!daDoc)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF0284C7),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            noiDung,
                                            style: TextStyle(
                                              color: isDark
                                                  ? AppDesignSystemC1.darkTextSecondary
                                                  : const Color(0xFF64748B),
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            thoiGian,
                                            style: TextStyle(
                                              color: isDark
                                                  ? AppDesignSystemC1.darkTextSecondary
                                                  : const Color(0xFF94A3B8),
                                              fontSize: 11,
                                            ),
                                          ),
                                          if ((item['loai'] ?? '').toString() == 'lich_hen') ...[
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.pop(modalCtx);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => CskhDanhsachDonKhoaScreenC1(
                                                        tenKhoa: (item['ten_khoa'] ?? 'Khoa Tim Mạch').toString(),
                                                      ),
                                                    ),
                                                  );
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Duyệt đơn ngay',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF0284C7),
                                                        ),
                                                      ),
                                                      SizedBox(width: 4),
                                                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF0284C7)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
