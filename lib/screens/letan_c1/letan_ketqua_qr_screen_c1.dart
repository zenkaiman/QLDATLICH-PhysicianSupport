import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_qr_model_c1.dart';

class LetanKetquaQrScreenC1 extends StatelessWidget {
  final KetQuaQuetQrC1 ketQua;
  final VoidCallback? onQuetTiep;

  const LetanKetquaQrScreenC1({
    super.key,
    required this.ketQua,
    this.onQuetTiep,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Scaffold(
      backgroundColor: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF334155),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Kết Quả Quét QR',
          style: TextStyle(
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF334155)),
            onPressed: () {
              if (onQuetTiep != null) {
                Navigator.pop(context);
                onQuetTiep!();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildBody(context),
              ),
            ),
            _buildBottomButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (ketQua.trangThaiNgayKham) {
      case TrangThaiNgayKhamC1.dungNgay:
        return _buildGiaoDienDungNgay(context);
      case TrangThaiNgayKhamC1.chuaToiNgay:
        return _buildGiaoDienChuaToiNgay(context);
      case TrangThaiNgayKhamC1.daQuaHan:
        return _buildGiaoDienDaQuaHan(context);
      case TrangThaiNgayKhamC1.khongXacDinh:
        return _buildGiaoDienThatBai(context);
    }
  }

  // TRƯỜNG HỢP 1: ĐÚNG NGÀY KHÁM (XANH LÁ - HIỆN TOÀN BỘ THÔNG TIN & SỐ THỨ TỰ)
  Widget _buildGiaoDienDungNgay(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thẻ thông báo xanh lá: Xác thực QR thành công
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ketQua.thongBao,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ketQua.chiTietLoi,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Thẻ gradient xanh dương: SỐ THỨ TỰ KHÁM
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'SỐ THỨ TỰ KHÁM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${ketQua.soThuTu ?? 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  children: [
                    TextSpan(text: '${ketQua.caKham ?? 'Khung giờ'}: Dự kiến lúc '),
                    TextSpan(
                      text: ketQua.gioKhamDuKien ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Thẻ thông tin bệnh nhân chi tiết
        _buildThongTinChiTietCard(isDark),
      ],
    );
  }

  // TRƯỜNG HỢP 2: CHƯA TỚI NGÀY KHÁM (VÀNG CAM - NHẤN MẠNH CHƯA TỚI NGÀY KHÁM)
  Widget _buildGiaoDienChuaToiNgay(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thẻ cảnh báo vàng cam
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFFD97706) : const Color(0xFFFCD34D)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_busy, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ketQua.thongBao,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ketQua.chiTietLoi,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Dòng nhấn mạnh nổi bật
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.priority_high, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'CHƯA TỚI NGÀY KHÁM • Ngày hẹn: ${ketQua.ngayKham ?? 'Theo lịch'}',
                  style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Vẫn hiển thị đầy đủ thông tin cơ bản của lịch hẹn
        _buildThongTinChiTietCard(isDark),
      ],
    );
  }

  // TRƯỜNG HỢP 3: ĐÃ QUA NGÀY HOẶC ĐÃ KHÁM (MÀU ĐỎ)
  Widget _buildGiaoDienDaQuaHan(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thẻ thông báo đỏ lỗi
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFFB91C1C) : const Color(0xFFFECACA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history_toggle_off, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ketQua.thongBao,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ketQua.chiTietLoi,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Dòng nhấn mạnh cảnh báo quá hạn
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'LỊCH HẸN ĐÃ HẾT HẠN HOẶC ĐÃ HOÀN TẤT KHÁM',
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Vẫn hiển thị mã lịch hẹn và thông tin cơ bản để nhân viên tra cứu đối chứng
        _buildThongTinChiTietCard(isDark),
      ],
    );
  }

  // Thẻ thông tin bệnh nhân và lịch hẹn dùng chung cho cả 3 trường hợp
  Widget _buildThongTinChiTietCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header thẻ + badge BHYT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thông tin lịch hẹn & bệnh nhân',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (ketQua.bhyt != null && ketQua.bhyt!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0369A1).withValues(alpha: 0.3) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ketQua.bhyt!,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Các dòng thông tin chi tiết
          _buildRowInfo('Mã lịch hẹn:', ketQua.maLichHen ?? ketQua.maBenhNhan ?? '', colorValue: const Color(0xFF0284C7), isBold: true),
          _buildRowInfo('Họ và tên:', ketQua.hoTen ?? 'Chưa rõ', isBold: true, isUpper: true),
          if (ketQua.ngayKham != null)
            _buildRowInfo('Ngày hẹn khám:', ketQua.ngayKham!, isBold: true),
          if (ketQua.gioKhamDuKien != null)
            _buildRowInfo('Khung giờ khám:', ketQua.gioKhamDuKien!, isBold: true),
          if (ketQua.namSinhGioiTinh != null)
            _buildRowInfo('Năm sinh / Giới tính:', ketQua.namSinhGioiTinh!, isBold: true),
          if (ketQua.cccd != null)
            _buildRowInfo('CCCD:', ketQua.cccd!, isBold: true),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0), height: 1),
          ),

          _buildRowInfo('Khoa khám:', ketQua.khoaKham ?? '', isBold: true),
          _buildRowInfo('Phòng khám:', ketQua.phongKham ?? '', isBold: true),
        ],
      ),
    );
  }

  // TRƯỜNG HỢP 4: ĐÃ XÁC THỰC HOẶC MÃ QR KHÔNG HỢP LỆ
  Widget _buildGiaoDienThatBai(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thẻ thông báo đỏ/cam lỗi
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFFB91C1C) : const Color(0xFFFECACA)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.error_outline, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ketQua.thongBao,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ketQua.chiTietLoi,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Thẻ chi tiết nếu có thông tin bệnh nhân cũ
        if (ketQua.hoTen != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFEDF2F7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thông tin ghi nhận trước đó:',
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildRowInfo('Bệnh nhân:', ketQua.hoTen ?? ''),
                _buildRowInfo('Mã bệnh nhân:', ketQua.maBenhNhan ?? ''),
                _buildRowInfo('Khoa tiếp nhận:', ketQua.khoaKham ?? ''),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFEDF2F7)),
            ),
            child: Column(
              children: [
                Icon(Icons.qr_code_2, size: 64, color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                Text(
                  'Vui lòng yêu cầu bệnh nhân mở lại mã QR trên ứng dụng hoặc chuyển sang tìm kiếm bằng CCCD / SĐT.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRowInfo(String label, String value, {bool isBold = false, bool isUpper = false, Color? colorValue}) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isUpper ? value.toUpperCase() : value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                color: colorValue ?? (isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A)),
                fontSize: 13.5,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2 Nút bấm cuối màn hình: Quét Tiếp Mã Khác & Trở Về Trang Chủ
  Widget _buildBottomButtons(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFEDF2F7))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nút Quét tiếp mã khác
          InkWell(
            onTap: () {
              Navigator.pop(context);
              if (onQuetTiep != null) {
                onQuetTiep!();
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Quét Tiếp Mã Khác',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Nút Trở về trang chủ
          InkWell(
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_outlined,
                    color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF334155),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Trở Về Trang Chủ',
                    style: TextStyle(
                      color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF334155),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
