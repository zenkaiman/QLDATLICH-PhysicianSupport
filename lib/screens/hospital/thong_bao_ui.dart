import 'package:flutter/material.dart';

import '../../models/thong_bao_model.dart';

/// Card hiển thị từng mục thông báo trong danh sách
class ThongBaoItemWidget extends StatelessWidget {
  final ThongBaoModel thongBao;
  final VoidCallback onTap;

  const ThongBaoItemWidget({
    super.key,
    required this.thongBao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !thongBao.daDoc;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
          width: isUnread ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon loại thông báo
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isUnread
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    thongBao.loai == 'kich_hoat_tai_khoan'
                        ? Icons.verified_user_rounded
                        : Icons.notifications_active_rounded,
                    color: isUnread
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF64748B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Nội dung thông báo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề + Chấm chưa đọc
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              thongBao.tieuDe,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isUnread
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Nội dung vắn tắt
                      Text(
                        thongBao.noiDungNgan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isUnread
                              ? const Color(0xFF1E293B)
                              : const Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Huy hiệu trạng thái & thời gian
                      Row(
                        children: [
                          // Tag trạng thái: Chờ (15) hoặc Đã phân công (16)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: thongBao.daPhanCong
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: thongBao.daPhanCong
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFFCD34D),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (thongBao.daPhanCong) ...[
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 10,
                                    color: Color(0xFF16A34A),
                                  ),
                                  const SizedBox(width: 2.5),
                                ],
                                Text(
                                  thongBao.daPhanCong ? 'Đã phân công' : 'Chờ',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: thongBao.daPhanCong
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Thời gian
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              thongBao.thoiGianHienThi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Nhãn Xem chi tiết
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Chi tiết',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isUnread
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF2563EB),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 15,
                                color: isUnread
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF2563EB),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog hiển thị chi tiết thông báo kích hoạt nhân sự
class DialogChiTietThongBao extends StatelessWidget {
  final ThongBaoModel thongBao;
  final VoidCallback? onDenPhanCong;

  const DialogChiTietThongBao({
    super.key,
    required this.thongBao,
    this.onDenPhanCong,
  });

  Widget _buildRow(String label, String value, {Widget? badge}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                badge ??
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header icon + title + close
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông báo kích hoạt',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          thongBao.daPhanCong
                              ? 'Nhân sự đã được phân công lịch làm'
                              : 'Tài khoản nhân sự sẵn sàng',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Thông tin chi tiết nhân sự
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildRow(
                      'Họ và tên:',
                      thongBao.tenNhanVien ?? 'Chưa cập nhật',
                    ),
                    _buildRow('Mã nhân sự:', thongBao.maNhanVien ?? 'N/A'),
                    _buildRow(
                      'Chuyên khoa:',
                      thongBao.khoa ?? 'Chưa phân khoa',
                    ),
                    _buildRow('Vai trò:', thongBao.vaiTro ?? 'Nhân viên'),
                    _buildRow(
                      'Trạng thái:',
                      '',
                      badge: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: thongBao.daPhanCong
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: thongBao.daPhanCong
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFFCD34D),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  thongBao.daPhanCong
                                      ? Icons.check_circle_rounded
                                      : Icons.hourglass_top_rounded,
                                  size: 13,
                                  color: thongBao.daPhanCong
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFB45309),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  thongBao.daPhanCong
                                      ? 'Đã phân công'
                                      : 'Chờ nhận lịch làm',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: thongBao.daPhanCong
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (thongBao.daPhanCong &&
                        thongBao.phongPhanCong != null &&
                        thongBao.phongPhanCong!.trim().isNotEmpty) ...[
                      _buildRow('Phòng trực:', thongBao.phongPhanCong!),
                    ],
                    if (thongBao.daPhanCong &&
                        thongBao.ngayPhanCong != null &&
                        thongBao.ngayPhanCong!.trim().isNotEmpty) ...[
                      _buildRow('Ngày trực:', thongBao.ngayPhanCong!),
                    ],
                    _buildRow('Thời gian:', thongBao.thoiGianHienThi),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Hướng dẫn
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: thongBao.daPhanCong
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: thongBao.daPhanCong
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      thongBao.daPhanCong
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      size: 18,
                      color: thongBao.daPhanCong
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        thongBao.daPhanCong
                            ? (thongBao.phongPhanCong != null &&
                                      thongBao.phongPhanCong!.trim().isNotEmpty
                                  ? 'Nhân sự đã được phân công trực tại ${thongBao.phongPhanCong} ( Đã phân công).'
                                  : 'Nhân sự đã được phân công lịch làm việc Đã phân công).')
                            : 'Nhân sự đã kích hoạt và đang ở trạng thái Chờ . Bạn có thể phân công trực cho nhân sự ngay bây giờ.',
                        style: TextStyle(
                          fontSize: 12,
                          color: thongBao.daPhanCong
                              ? const Color(0xFF166534)
                              : const Color(0xFF1E40AF),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nút điều hướng & đóng
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Đóng',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  if (onDenPhanCong != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDenPhanCong!();
                        },
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 17,
                        ),
                        label: Text(
                          thongBao.daPhanCong
                              ? 'Xem Phân Công Trực'
                              : 'Đến Phân Công Trực',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: thongBao.daPhanCong
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Giao diện khi không có thông báo
class ThongBaoEmptyState extends StatelessWidget {
  final bool filterChuaDoc;

  const ThongBaoEmptyState({super.key, this.filterChuaDoc = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 36,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              filterChuaDoc
                  ? 'Không có thông báo chưa đọc'
                  : 'Chưa có thông báo nào',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              filterChuaDoc
                  ? 'Bạn đã đọc tất cả thông báo tài khoản nhân sự kích hoạt.'
                  : 'Khi tài khoản nhân sự được kích hoạt trên hệ thống, thông báo sẽ hiển thị tại đây.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thanh bộ lọc và nút đánh dấu tất cả đã đọc
class ThongBaoFilterBar extends StatelessWidget {
  final int selectedTab; // 0: Tất cả, 1: Chưa đọc
  final int tongSo;
  final int soChuaDoc;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onDanhDauTatCa;

  const ThongBaoFilterBar({
    super.key,
    required this.selectedTab,
    required this.tongSo,
    required this.soChuaDoc,
    required this.onTabChanged,
    required this.onDanhDauTatCa,
  });

  Widget _buildTab(int index, String title, int count) {
    final bool active = selectedTab == index;
    return GestureDetector(
      onTap: () => onTabChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                _buildTab(0, 'Tất cả', tongSo),
                _buildTab(1, 'Chưa đọc', soChuaDoc),
              ],
            ),
          ),
          const Spacer(),
          if (soChuaDoc > 0)
            TextButton(
              onPressed: onDanhDauTatCa,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Đã đọc tất cả',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
