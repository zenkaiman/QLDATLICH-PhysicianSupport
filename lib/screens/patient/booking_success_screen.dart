import 'package:flutter/material.dart';
import '../../widgets/appointment_card.dart';

/// Màn hình "ĐẶT LỊCH THÀNH CÔNG!" (sau khi bệnh viện đã xác nhận).
class BookingSuccessScreen extends StatelessWidget {
  final String bookingCode;
  final String hospitalLine;
  final String timeLine;
  final String doctorLine;
  final String queueLine;
  final VoidCallback? onViewTicket;
  final VoidCallback? onGoAppointments;
  final VoidCallback? onGoHome;

  const BookingSuccessScreen({
    super.key,
    this.bookingCode = '#MED-2026-8921',
    this.hospitalLine = 'Bạch Mai (Phòng 302)',
    this.timeLine = '08:30 - 9:30 · Thứ 3, 10/09/2026',
    this.doctorLine = 'BS.CKII Nguyễn Thu Trang',
    this.queueLine = 'STT 08',
    this.onViewTicket,
    this.onGoAppointments,
    this.onGoHome,
  });

  /// Một dòng thông tin: icon + "Nhãn: giá trị"
  Widget _line({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: ApptColors.textDark,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontWeight: valueColor == null
                          ? FontWeight.w500
                          : FontWeight.w900,
                      color: valueColor,
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

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF15803D);
    const sky = Color(0xFF0288D1);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
          child: Column(
            children: [
              // ── Biểu tượng chúc mừng ──
              Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  size: 52,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'ĐẶT LỊCH THÀNH CÔNG!',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: green,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Lịch khám của bạn đã được ghi nhận vào hệ thống',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: ApptColors.textGrey),
              ),
              const SizedBox(height: 22),

              // ── Thẻ thông tin ──
              ApptCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MÃ ĐẶT LỊCH:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: ApptColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bookingCode,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: sky,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: ApptColors.border),
                    const SizedBox(height: 6),
                    _line(
                      icon: Icons.apartment_rounded,
                      iconColor: sky,
                      label: 'Bệnh viện',
                      value: hospitalLine,
                    ),
                    _line(
                      icon: Icons.schedule_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Thời gian',
                      value: timeLine,
                    ),
                    _line(
                      icon: Icons.medical_information_rounded,
                      iconColor: const Color(0xFF16A34A),
                      label: 'Bác sĩ',
                      value: doctorLine,
                    ),
                    _line(
                      icon: Icons.confirmation_number_rounded,
                      iconColor: ApptColors.red,
                      label: 'Số thứ tự',
                      value: queueLine,
                      valueColor: sky,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // ── Nút hành động ──
              ApptButton(
                text: 'Xem phiếu khám & Mã QR ngay',
                icon: Icons.qr_code_2_rounded,
                background: sky,
                onPressed: onViewTicket,
              ),
              const SizedBox(height: 12),
              ApptButton(
                text: 'Quay về Lịch Khám',
                background: const Color(0xFFF1F4F9),
                foreground: ApptColors.textDark,
                borderColor: ApptColors.border,
                onPressed: onGoAppointments,
              ),
              const SizedBox(height: 12),
              ApptButton(
                text: 'Quay về Trang chủ',
                background: const Color(0xFFF1F4F9),
                foreground: ApptColors.textDark,
                borderColor: ApptColors.border,
                onPressed: onGoHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}