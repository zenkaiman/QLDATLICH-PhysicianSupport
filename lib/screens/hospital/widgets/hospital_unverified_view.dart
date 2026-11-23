import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../config/constants.dart';
import '../guiDonThanhCong_Screen.dart';
import '../guiYeuCauHopTac_Screen.dart';

/// Giao diện hiển thị khi Bệnh viện Chưa gửi đơn / Đang chờ duyệt / Bị từ chối hợp tác.
class HospitalUnverifiedView extends StatelessWidget {
  final String hospitalUid;
  final String tenBenhVien;
  final bool daGuiDon;
  final int trangThaiId;
  final Map<String, dynamic>? data;

  const HospitalUnverifiedView({
    super.key,
    required this.hospitalUid,
    required this.tenBenhVien,
    required this.daGuiDon,
    required this.trangThaiId,
    this.data,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBiTuChoiHoacHuy = (trangThaiId == TrangThaiId.huyHopTac);
    final String emailDangKy = (data?['email'] ??
            FirebaseAuth.instance.currentUser?.email ??
            '')
        .toString();
    final String lyDoTuChoi = (data?['ly_do_tu_choi'] ??
            'Hồ sơ pháp lý chưa đầy đủ hoặc cơ sở y tế đã chấm dứt hợp tác.')
        .toString();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 36),

          // Icon tài liệu / Cảnh báo hủy hợp tác
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: isBiTuChoiHoacHuy
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: (isBiTuChoiHoacHuy
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF0284C7))
                      .withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              isBiTuChoiHoacHuy
                  ? Icons.cancel_outlined
                  : Icons.description_outlined,
              size: 46,
              color: isBiTuChoiHoacHuy
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF0284C7),
            ),
          ),
          const SizedBox(height: 22),

          // Tiêu đề
          Text(
            isBiTuChoiHoacHuy
                ? 'Yêu Cầu Hợp Tác Bị Từ Chối / Đã Hủy'
                : 'Chào mừng Bệnh viện mới!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          // Dòng mô tả
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              isBiTuChoiHoacHuy
                  ? 'Yêu cầu hợp tác của bệnh viện đã bị từ chối hoặc hủy bỏ.\nThông báo chi tiết đã được gửi về email của người đăng ký.\nQuý viện có thể nộp lại đơn yêu cầu hợp tác mới từ đầu.'
                  : 'Trang chủ chưa có dữ liệu. Bệnh viện cần gửi\nđơn xác nhận hợp tác để kích hoạt các tính năng\nquản lý khoa và phân luồng tiếp đón.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ),

          // Box thông báo gửi email khi bị từ chối / hủy
          if (isBiTuChoiHoacHuy) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.mark_email_read_rounded,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đã gửi thông báo giải thích về email:',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (emailDangKy.isNotEmpty)
                          Text(
                            emailDangKy,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF7F1D1D),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          'Lý do: $lyDoTuChoi',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB91C1C),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Card Quy trình 3 bước kích hoạt
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quy trình 3 bước kích hoạt:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStepRow(
                  stepNumber: '1',
                  title: isBiTuChoiHoacHuy
                      ? 'Điền lại thông tin pháp lý & gửi lại hồ sơ'
                      : 'Điền thông tin pháp lý & loại hình cơ sở',
                  isActive: true,
                  isDone: daGuiDon && !isBiTuChoiHoacHuy,
                ),
                const SizedBox(height: 14),
                _buildStepRow(
                  stepNumber: '2',
                  title: 'Admin đối soát giấy phép & phê duyệt',
                  isActive: daGuiDon && !isBiTuChoiHoacHuy,
                  isDone: false,
                ),
                const SizedBox(height: 14),
                _buildStepRow(
                  stepNumber: '3',
                  title: 'Kích hoạt tạo khoa, phân luồng & cấp tài khoản',
                  isActive: false,
                  isDone: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          // Nút Gửi đơn xác nhận hợp tác / Gửi lại từ đầu
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                if (daGuiDon && !isBiTuChoiHoacHuy) {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => GuiDonThanhCongScreen(
                        maHoSo: (data?['ma_ho_so'] ?? '#HS-BV-202688').toString(),
                        tenBenhVien: tenBenhVien,
                        loaiHinh: (data?['loai_hinh'] ?? 'Bệnh viện Tư lập').toString(),
                        coBhyt: data?['co_bhyt'] ?? true,
                        hospitalUid: hospitalUid,
                        extraData: data,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => GuiYeuCauHopTacScreen(
                        initialTenBenhVien: tenBenhVien,
                        initialDiaChi: data?['dia_chi']?.toString(),
                      ),
                    ),
                  );
                }
              },
              icon: Icon(
                (daGuiDon && !isBiTuChoiHoacHuy)
                    ? Icons.hourglass_top_rounded
                    : Icons.assignment_outlined,
                size: 20,
              ),
              label: Text(
                isBiTuChoiHoacHuy
                    ? 'Gửi Lại Yêu Cầu Hợp Tác Từ Đầu'
                    : (daGuiDon
                        ? 'Đã Gửi Đơn - Chờ Admin Phê Duyệt'
                        : 'Gửi Đơn Xác Nhận Hợp Tác'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: (daGuiDon && !isBiTuChoiHoacHuy)
                    ? const Color(0xFFD97706)
                    : const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String stepNumber,
    required String title,
    required bool isActive,
    required bool isDone,
  }) {
    Color circleColor = const Color(0xFFE2E8F0);
    Widget circleChild = Text(
      stepNumber,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );

    if (isDone) {
      circleColor = const Color(0xFF16A34A);
      circleChild = const Icon(Icons.check, size: 13, color: Colors.white);
    } else if (isActive) {
      circleColor = const Color(0xFF0284C7);
      circleChild = Text(
        stepNumber,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: circleChild,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: (isActive || isDone)
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF475569),
              fontWeight:
                  (isActive || isDone) ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
