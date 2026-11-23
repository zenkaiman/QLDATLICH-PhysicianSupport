import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';

/// Modal BottomSheet hiển thị danh sách 10 ngày gần nhất để xem Lịch sử duyệt đơn
/// Kèm mục cuối cùng cho phép chọn ngày bất kỳ từ DatePicker
class CskhLichSuNgayBottomSheetC1 {
  static void show({
    required BuildContext context,
    required String tenKhoa,
    required Function(DateTime ngayChon) onSelectDate,
  }) {
    AppDesignSystemC1.hapticLight();
    final isDark = AppDesignSystemC1.laCheDoToi;
    final now = DateTime.now();

    // Tạo danh sách 10 ngày gần nhất từ hôm nay trở về trước
    final List<DateTime> danhSach10Ngay = List.generate(10, (index) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: index));
    });

    String layThuTiengViet(int weekday) {
      switch (weekday) {
        case DateTime.monday:
          return 'Thứ Hai';
        case DateTime.tuesday:
          return 'Thứ Ba';
        case DateTime.wednesday:
          return 'Thứ Tư';
        case DateTime.thursday:
          return 'Thứ Năm';
        case DateTime.friday:
          return 'Thứ Sáu';
        case DateTime.saturday:
          return 'Thứ Bảy';
        case DateTime.sunday:
          return 'Chủ Nhật';
        default:
          return '';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
          ),
          padding: const EdgeInsets.only(top: 14, bottom: 20),
          decoration: BoxDecoration(
            color: isDark ? AppDesignSystemC1.darkBackground : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh kéo xám
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header tiêu đề
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: Color(0xFFD97706),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lịch Sử Duyệt Đơn',
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tenKhoa.isNotEmpty ? 'Khoa: $tenKhoa • 10 ngày gần nhất' : '10 ngày gần nhất',
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),

              // Danh sách 10 ngày gần nhất + mục chọn ngày khác
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: danhSach10Ngay.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    // Mục cuối cùng: Chọn ngày khác
                    if (index == danhSach10Ngay.length) {
                      return InkWell(
                        onTap: () async {
                          Navigator.pop(ctx);
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: DateTime(2020),
                            lastDate: now,
                            helpText: 'CHỌN NGÀY XEM LỊCH SỬ',
                            cancelText: 'HỦY',
                            confirmText: 'XEM ĐƠN',
                          );
                          if (picked != null) {
                            onSelectDate(picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0C2444) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.calendar_month_rounded, color: Color(0xFF0284C7), size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Chọn ngày khác...',
                                  style: TextStyle(
                                    color: Color(0xFF0284C7),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0284C7), size: 14),
                            ],
                          ),
                        ),
                      );
                    }

                    final ngay = danhSach10Ngay[index];
                    final String ngayFormat =
                        '${ngay.day.toString().padLeft(2, '0')}/${ngay.month.toString().padLeft(2, '0')}/${ngay.year}';
                    final bool laHomNay = index == 0;
                    final bool laHomQua = index == 1;

                    String nhanNgay = '';
                    if (laHomNay) {
                      nhanNgay = 'Hôm nay';
                    } else if (laHomQua) {
                      nhanNgay = 'Hôm qua';
                    } else {
                      nhanNgay = layThuTiengViet(ngay.weekday);
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelectDate(ngay);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_note_rounded,
                              size: 18,
                              color: laHomNay ? const Color(0xFF10B981) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '$nhanNgay • $ngayFormat',
                                style: TextStyle(
                                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                                  fontSize: 13.5,
                                  fontWeight: laHomNay ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (laHomNay)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Hiện tại',
                                  style: TextStyle(
                                    color: Color(0xFF059669),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
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
  }
}
