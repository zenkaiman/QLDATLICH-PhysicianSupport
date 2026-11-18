import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';
import '../../../models/letan_c1/letan_phancong_model_c1.dart';
import '../../../models/letan_c1/letan_profile_model_c1.dart';

/// Widget hiển thị màn hình khóa chức năng khi nhân viên chưa được Bệnh viện
/// phân công ca trực hợp lệ (yêu cầu trang_thai_id == 16).
/// Chỉ cho phép chuyển sang tab Profile để xem thông tin và Đăng xuất.
class LetanKhoaCaTrucWidgetC1 extends StatelessWidget {
  final PhanCongCaTrucModelC1 phanCong;
  final VoidCallback onChuyenProfile;
  final String tenChucNangBiKhoa; // Ví dụ: "Duyệt đơn", "Quét QR", "Lịch hẹn", "Trang chủ"

  const LetanKhoaCaTrucWidgetC1({
    super.key,
    required this.phanCong,
    required this.onChuyenProfile,
    this.tenChucNangBiKhoa = 'Thao tác nghiệp vụ',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final profile = DuLieuProfileMauC1.thongTinHienTai;

    final String tenNvHienThi = phanCong.tenNhanVien.isNotEmpty ? phanCong.tenNhanVien : profile.hoTen;
    final String maNvHienThi = phanCong.maNhanVien.isNotEmpty ? phanCong.maNhanVien : profile.maNhanVien;
    final String tenKhoaHienThi = phanCong.tenKhoa.isNotEmpty ? phanCong.tenKhoa : profile.khoa;
    final String phongHienThi = phanCong.tenPhong.isNotEmpty
        ? phanCong.tenPhong
        : (phanCong.phongId.isNotEmpty ? phanCong.phongId : 'Chưa xếp phòng');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Ổ khóa lớn nổi bật
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.6) : const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.6 : 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                size: 42,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 20),

            // Tiêu đề khóa chức năng
            Text(
              'CHỨC NĂNG ĐANG TẠM KHÓA',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),

            // Huy hiệu trạng thái phân công
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  Text(
                    phanCong.trangThaiId != 0
                        ? 'Mã trạng thái: ${phanCong.trangThaiId} ("${phanCong.trangThai}") • Cần mã 16'
                        : 'Chưa có lịch phân công ca trực hôm nay (Cần mã TT: 16)',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Mô tả chi tiết lý do khóa
            Text(
              'Bệnh viện chưa kích hoạt ca trực cho bạn. Bạn cần được Bệnh viện phân công ca trực để được quyền mở các chức năng nghiệp vụ.\n\nHiện tại bạn chỉ được xem thông tin tại mục Hồ sơ và Đăng xuất.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Thẻ chi tiết thông tin ca trực & nhân sự
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildRowInfo('Bệnh viện:', profile.tenBenhVien, isDark),
                  const Divider(height: 14, thickness: 0.6),
                  _buildRowInfo('Nhân viên:', '$tenNvHienThi ($maNvHienThi)', isDark),
                  const Divider(height: 14, thickness: 0.6),
                  _buildRowInfo('Khoa chỉ định:', tenKhoaHienThi, isDark),
                  const Divider(height: 14, thickness: 0.6),
                  _buildRowInfo('Phòng khám:', phongHienThi, isDark),
                  const Divider(height: 14, thickness: 0.6),
                  _buildRowInfo('Trạng thái ca trực:', phanCong.trangThai, isDark, isWarning: true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dòng thông báo Realtime Listener
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Đang tự động lắng nghe Realtime từ Bệnh viện. Quyền sẽ tự động mở ngay khi mã trạng thái thành 16.',
                      style: TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nút bấm: "VÀO HỒ SƠ & ĐĂNG XUẤT"
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  AppDesignSystemC1.hapticLight();
                  onChuyenProfile();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystemC1.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text(
                  'Vào Xem Hồ Sơ & Đăng Xuất',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowInfo(String label, String value, bool isDark, {bool isWarning = false}) {
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isWarning
                  ? const Color(0xFFEF4444)
                  : (isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A)),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
