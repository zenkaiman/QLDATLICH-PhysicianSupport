import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/rendering.dart';

import '../../models/lichhen_model.dart';
import '../../models/ticket_data.dart';
import '../../utils/app_snackbar.dart';

// Màu dùng riêng cho màn hình này.
class _C {
  static const primary = Color(0xFF1976D2);
  static const primaryLight = Color(0xFF42A5F5);
  static const bg = Color(0xFFF4F7FB);
  static const textDark = Color(0xFF0F172A);
  static const textGrey = Color(0xFF64748B);
  static const border = Color(0xFFE6E9F0);
  static const green = Color(0xFF16A34A);
  static const qrInk = Color(0xFF0B2545);
}

// ───────────────────────── Màn hình ─────────────────────────
class QrTicketScreen extends StatefulWidget {
  final LichHenModel? booking;
  final String? patientName;
  final ValueChanged<int>? onNavTap;

  // ✅ LOẠI BỎ CÁC DỮ LIỆU GIẢ (DUMMY DATA)
  const QrTicketScreen({
    super.key,
    required this.booking, // Bắt buộc phải có hoặc xử lý null
    this.patientName,
    this.onNavTap,
  });

  @override
  State<QrTicketScreen> createState() => _QrTicketScreenState();
}

class _QrTicketScreenState extends State<QrTicketScreen> {
  final GlobalKey _ticketKey = GlobalKey();
  bool _saving = false;

  // ✅ CHỈ LẤY DỮ LIỆU THỰC TẾ, KHÔNG CÓ FALLBACK GIẢ
  TicketData? _resolveData(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final booking = widget.booking ?? (args is LichHenModel ? args : null);

    if (booking != null) {
      return TicketData.fromBooking(booking, patientName: widget.patientName);
    }

    return null; // Trả về null nếu không có dữ liệu thật
  }

  void _toast(
    String message, {
    SnackBarType type = SnackBarType.info,
    String? title,
  }) {
    if (!mounted) return;
    context.showAppSnackBar(message: message, type: type, title: title);
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _toast(
      'Đã sao chép mã đặt lịch',
      type: SnackBarType.success,
      title: 'Sao chép thành công',
    );
  }

  Future<void> _saveTicket() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final boundary =
          _ticketKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Không tạo được ảnh');

      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        album: 'MediConnect',
      );
      _toast(
        'Đã lưu vé vào thư viện ảnh',
        type: SnackBarType.success,
        title: 'Lưu vé thành công',
      );
    } catch (e) {
      debugPrint('Lỗi khi lưu vé: $e');
      _toast(
        'Không thể lưu vé. Hãy cấp quyền lưu ảnh rồi thử lại.',
        type: SnackBarType.error,
        title: 'Lưu vé thất bại',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _resolveData(context);

    // ✅ XỬ LÝ KHI KHÔNG CÓ DỮ LIỆU THAY VÌ HIỆN VÉ GIẢ
    if (data == null) {
      return Scaffold(
        backgroundColor: _C.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: _C.textGrey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Không tìm thấy thông tin vé',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _C.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vui lòng chọn lịch hẹn hợp lệ',
                style: TextStyle(fontSize: 14, color: _C.textGrey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                label: const Text('Quay lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          const _HeaderBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _TopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                    child: RepaintBoundary(
                      key: _ticketKey,
                      child: Container(
                        color: _C.bg,
                        padding: const EdgeInsets.all(16),
                        child: _Ticket(
                          data: data,
                          onCopy: () => _copyCode(data.bookingCode),
                        ),
                      ),
                    ),
                  ),
                ),
                _SaveBar(saving: _saving, onSave: _saveTicket),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Nền và thanh tiêu đề ─────────────────────────

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 260,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), _C.primary, _C.primaryLight],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(36),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -30,
                child: _Bubble(size: 160, opacity: 0.10),
              ),
              Positioned(
                top: 90,
                left: -50,
                child: _Bubble(size: 130, opacity: 0.07),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final double opacity;
  const _Bubble({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.maybePop(context),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: _C.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xuất trình mã khám',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Đưa mã QR này cho quầy tiếp nhận',
                  style: TextStyle(fontSize: 12.5, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Vé ─────────────────────────

class _Ticket extends StatelessWidget {
  final TicketData data;
  final VoidCallback onCopy;

  const _Ticket({required this.data, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.14),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _TicketHeader(data: data, onCopy: onCopy),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
            child: Column(
              children: [
                _QueueNumber(number: data.queueNumber),
                const SizedBox(height: 20),
                _QrFrame(
                  data: data.qrData,
                ), // ✅ Dữ liệu QR ở đây giờ là JSON chuẩn
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 18,
                      color: _C.primary,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Đưa mã này cho quầy tiếp nhận để check-in',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _C.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _TearLine(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              children: [
                _InfoLine(
                  icon: Icons.person_rounded,
                  label: 'Bệnh nhân',
                  value: data.patientName,
                ),
                _InfoLine(
                  icon: Icons.local_hospital_rounded,
                  label: 'Bệnh viện',
                  value: data.roomName == null
                      ? data.hospitalName
                      : '${data.hospitalName} (${data.roomName})',
                ),
                if (data.departmentName != null)
                  _InfoLine(
                    icon: Icons.medical_services_outlined,
                    label: 'Chuyên khoa',
                    value: data.departmentName!,
                  ),
                _InfoLine(
                  icon: Icons.schedule_rounded,
                  label: 'Thời gian',
                  value: data.timeLabel,
                  subValue: data.dateLabel,
                  valueColor: _C.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketHeader extends StatelessWidget {
  final TicketData data;
  final VoidCallback onCopy;

  const _TicketHeader({required this.data, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1565C0), _C.primaryLight],
          ),
        ),
        child: Column(
          children: [
            const Text(
              'MÃ ĐẶT LỊCH KHÁM',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      data.bookingCode, // ✅ Lấy mã thật từ LichHenModel
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onCopy,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    data.confirmed
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_top_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data.statusLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueNumber extends StatelessWidget {
  final String number;
  const _QueueNumber({required this.number});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'SỐ THỨ TỰ',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: _C.textGrey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.primary.withOpacity(0.15)),
          ),
          child: Text(
            number, // ✅ Lấy số thứ tự thật
            style: const TextStyle(
              fontSize: 44,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: _C.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _QrFrame extends StatelessWidget {
  final String data;
  const _QrFrame({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      height: 244,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          QrImageView(
            data: data, // ✅ Dữ liệu JSON từ TicketData
            version: QrVersions.auto,
            size: 190,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: _C.qrInk,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: _C.qrInk,
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border),
            ),
            child: const Icon(
              Icons.local_hospital_rounded,
              size: 26,
              color: _C.primary,
            ),
          ),
          const Positioned.fill(
            child: CustomPaint(painter: _CornerPainter(color: _C.primary)),
          ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const inset = 10.0;
    const len = 24.0;
    final w = size.width;
    final h = size.height;

    canvas.drawPath(
      Path()
        ..moveTo(inset, inset + len)
        ..lineTo(inset, inset)
        ..lineTo(inset + len, inset),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - inset - len, inset)
        ..lineTo(w - inset, inset)
        ..lineTo(w - inset, inset + len),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(inset, h - inset - len)
        ..lineTo(inset, h - inset)
        ..lineTo(inset + len, h - inset),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - inset - len, h - inset)
        ..lineTo(w - inset, h - inset)
        ..lineTo(w - inset, h - inset - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TearLine extends StatelessWidget {
  const _TearLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = (constraints.maxWidth / 10).floor();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(
                      count,
                      (_) => Container(width: 5, height: 1.6, color: _C.border),
                    ),
                  );
                },
              ),
            ),
          ),
          const Positioned(left: -13, top: 0, child: _Notch()),
          const Positioned(right: -13, top: 0, child: _Notch()),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(color: _C.bg, shape: BoxShape.circle),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subValue;
  final Color valueColor;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.subValue,
    this.valueColor = _C.textDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: _C.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: _C.textGrey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                ),
                if (subValue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subValue!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.textGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;

  const _SaveBar({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download_rounded, size: 22),
          label: Text(
            saving ? 'Đang lưu...' : 'Lưu vé vào máy điện thoại',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _C.primary.withOpacity(0.6),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
