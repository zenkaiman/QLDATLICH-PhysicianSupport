import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';
import '../../../models/letan_c1/letan_profile_model_c1.dart';
import '../../../services/letan_c1/letan_firebase_service_c1.dart';
import '../cskh_danhsach_don_khoa_screen_c1.dart';
import 'cskh_department_selector_card_c1.dart';

/// Tab duyệt đơn theo phòng khám của khoa đang chọn
class CskhTabDuyetPhongC1 extends StatelessWidget {
  final String tenKhoaHienTai;
  final String? khoaIdHienTai;
  final DateTime ngayChon;
  final VoidCallback onSelectKhoa;
  final VoidCallback onSelectDate;
  final void Function(Map<String, dynamic> phong, String tenKhoa) onSelectPhong;

  const CskhTabDuyetPhongC1({
    super.key,
    required this.tenKhoaHienTai,
    required this.khoaIdHienTai,
    required this.ngayChon,
    required this.onSelectKhoa,
    required this.onSelectDate,
    required this.onSelectPhong,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Selector chọn Khoa làm việc ở trên cùng
          CskhDepartmentSelectorCardC1(
            tenKhoaHienTai: tenKhoaHienTai,
            onChangeDepartment: onSelectKhoa,
            label: 'KHOA ĐANG CHỌN',
            badgeText: 'Đang làm việc',
          ),
          const SizedBox(height: 14),

          // 2. Thanh chọn Ngày duyệt đơn
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NGÀY DUYỆT ĐƠN',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF475569),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              InkWell(
                onTap: onSelectDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Text(
                        '${ngayChon.day.toString().padLeft(2, '0')}/${ngayChon.month.toString().padLeft(2, '0')}/${ngayChon.year}',
                        style: const TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF0284C7)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Tiêu đề danh sách phòng khám & Nút vào duyệt toàn viện
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DANH SÁCH PHÒNG KHÁM',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF475569),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CskhDanhsachDonKhoaScreenC1(
                        tenKhoa: tenKhoaHienTai,
                        phongKham: 'Toàn khoa',
                        caKham: 'Tất cả các ca',
                        tongDon: 0,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Duyệt toàn bộ khoa',
                    style: TextStyle(
                      color: Color(0xFF0284C7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Danh sách các phòng khám dạng lưới / thẻ
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirebaseServiceC1.streamDanhSachKhoa(bvid),
            builder: (context, snapKhoa) {
              final dsKhoa = snapKhoa.data ?? [];
              Map<String, dynamic>? khoaDoc;
              for (var k in dsKhoa) {
                if (FirebaseServiceC1.laCungKhoa(k['tenKhoa']?.toString(), tenKhoaHienTai)) {
                  khoaDoc = k;
                  break;
                }
              }

              final khoaId = khoaIdHienTai ?? khoaDoc?['id']?.toString() ?? 'KHOA_MAC_DINH';
              final int soPhongKhoa = (khoaDoc?['soPhong'] as num?)?.toInt() ?? 1;
              final String phongDau = khoaDoc?['phongDau']?.toString() ?? '101';

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseServiceC1.streamDanhSachPhongTheoKhoa(
                  benhVienId: bvid,
                  khoaId: khoaId,
                  tenKhoa: tenKhoaHienTai,
                  soPhongMacDinh: soPhongKhoa,
                  phongDau: phongDau,
                ),
                builder: (context, snapPhong) {
                  final dsPhong = snapPhong.data ?? [];

                  if (snapPhong.connectionState == ConnectionState.waiting && !snapPhong.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }

                  if (dsPhong.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 40,
                            color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Khoa "$tenKhoaHienTai" chưa có phòng khám nào.',
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dsPhong.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final phong = dsPhong[index];
                      final tenPhong = (phong['tenPhong'] ?? phong['soPhong'] ?? 'Phòng').toString();
                      final soPhong = (phong['soPhong'] ?? '').toString();
                      final trangThai = (phong['trangThai'] ?? 'san_sang').toString();
                      final bool isSanSang = trangThai == 'san_sang' || trangThai == 'dang_kham';

                      return InkWell(
                        onTap: () => onSelectPhong(phong, tenKhoaHienTai),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.door_sliding_outlined,
                                    color: Color(0xFF0284C7),
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          tenPhong,
                                          style: TextStyle(
                                            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (soPhong.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'P.$soPhong',
                                              style: TextStyle(
                                                color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSanSang
                                          ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                                          : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isSanSang ? 'Sẵn sàng' : 'Tạm đóng',
                                      style: TextStyle(
                                        color: isSanSang ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'Duyệt đơn',
                                        style: TextStyle(
                                          color: Color(0xFF0284C7),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 11,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
