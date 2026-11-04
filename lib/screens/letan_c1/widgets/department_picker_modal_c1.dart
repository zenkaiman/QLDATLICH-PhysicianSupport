import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';
import '../../../models/letan_c1/letan_profile_model_c1.dart';
import '../../../services/letan_c1/letan_firebase_service_c1.dart';

/// Modal BottomSheet dùng chung để chọn Chuyên khoa cho cả Lễ tân và CSKH
class DepartmentPickerModalC1 {
  static void show({
    required BuildContext context,
    required String tenKhoaHienTai,
    required void Function(String tenKhoa, String? khoaId) onKhoaSelected,
    String tieuDe = 'Chọn Khoa Duyệt Đơn',
    String moTaPhu = 'Khoa được lấy tự động từ bệnh viện bạn đang làm việc',
    bool hoTroTong = true,
  }) {
    AppDesignSystemC1.hapticLight();
    final isDark = AppDesignSystemC1.laCheDoToi;
    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.apartment_rounded, color: Color(0xFF0284C7), size: 22),
                          const SizedBox(width: 10),
                          Text(
                            tieuDe,
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Bệnh Viện',
                          style: TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    moTaPhu,
                    style: TextStyle(
                      color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: FirebaseServiceC1.streamDanhSachKhoa(bvid),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(strokeWidth: 2),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Đang tải danh sách khoa từ Firebase...',
                                    style: TextStyle(
                                      color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final danhSachKhoa = [
                          if (hoTroTong)
                            {
                              'id': 'ALL',
                              'tenKhoa': 'Tất cả các khoa (Tổng)',
                              'moTaPhong': 'Toàn viện • Duyệt đơn tất cả các khoa',
                              'laTong': true,
                            },
                          ...snapshot.data!,
                        ];

                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: danhSachKhoa.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = danhSachKhoa[index];
                            final tenKhoa = (item['tenKhoa'] ?? 'Khoa Khám').toString();
                            final moTa = (item['moTaPhong'] ?? '').toString();
                            final laTong = item['laTong'] == true;
                            final isSelected = laTong
                                ? FirebaseServiceC1.laCheDoTong(tenKhoaHienTai)
                                : FirebaseServiceC1.laCungKhoa(tenKhoa, tenKhoaHienTai);

                            return InkWell(
                              onTap: () {
                                onKhoaSelected(
                                  tenKhoa,
                                  laTong ? null : item['id']?.toString(),
                                );
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã chọn khoa: $tenKhoa'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF0C2444) : const Color(0xFFF0F9FF))
                                      : (isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0284C7)
                                        : (isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF0284C7)
                                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        laTong ? Icons.dashboard_rounded : Icons.local_hospital_rounded,
                                        size: 20,
                                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tenKhoa,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? const Color(0xFF0284C7)
                                                  : (isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1E293B)),
                                              fontSize: 14.5,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                            ),
                                          ),
                                          if (moTa.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              moTa,
                                              style: TextStyle(
                                                color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF0284C7), size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
