import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/app_snackbar.dart';
import 'book_appointment_widget.dart' show AppTheme, InfoPill;

class AppointmentTicketWidget extends StatelessWidget {
  final String hospitalName;
  final String patientName;
  final String departmentName;
  final String dateLabel;
  final String timeLabel;
  final String appointmentId;
  final String qrData;
  final int queueNumber;

  const AppointmentTicketWidget({
    super.key,
    required this.hospitalName,
    required this.patientName,
    required this.departmentName,
    required this.dateLabel,
    required this.timeLabel,
    required this.appointmentId,
    required this.qrData,
    required this.queueNumber,
  });

  static const double _width = 320;

  /// _buildHeader: dải tiêu đề màu xanh chứa tên bệnh viện.
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryBlue,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_hospital_rounded,
              size: 24,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vé khám điện tử',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),

                const SizedBox(height: 2),
                Text(
                  hospitalName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// _buildField: ô thông tin gồm nhãn nhỏ và giá trị đậm.
  Widget _buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppTheme.textGrey),
        ),

        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  /// _buildPatientInfo: phần tên người khám, chuyên khoa, ngày và khung giờ khám.
  Widget _buildPatientInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Người khám',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textGrey),
          ),

          const SizedBox(height: 3),
          Text(
            patientName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),

          const SizedBox(height: 14),
          _buildField('Chuyên khoa', departmentName),

          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildField('Ngày khám', dateLabel)),

              const SizedBox(width: 12),
              Expanded(child: _buildField('Khung giờ', timeLabel)),
            ],
          ),
        ],
      ),
    );
  }

  /// _buildPerforation: đường cắt nét đứt với hai khuyết tròn hai bên như vé.
  Widget _buildPerforation() {
    Widget hole() => Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppTheme.bgColor,
        shape: BoxShape.circle,
      ),
    );

    return SizedBox(
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _DashedLine(),
            ),
          ),
          Positioned(left: -12, top: 0, child: hole()),
          Positioned(right: -12, top: 0, child: hole()),
        ],
      ),
    );
  }

  /// _buildQrSection: mã QR bên trái, số thứ tự và trạng thái bên phải.
  Widget _buildQrSection() {
    final hasQueue = queueNumber > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 104,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 6),
              Text(
                '#$appointmentId',
                style: const TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.4,
                  color: AppTheme.textGrey,
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Số thứ tự',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textGrey),
                ),

                const SizedBox(height: 2),
                Text(
                  hasQueue ? '$queueNumber' : 'Chờ cấp',
                  style: TextStyle(
                    fontSize: hasQueue ? 44 : 22,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryBlue,
                  ),
                ),

                const SizedBox(height: 10),

                const InfoPill(
                  icon: Icons.verified_rounded,
                  text: 'Đã duyệt',
                  color: AppTheme.primaryGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// _buildFooter: dòng hướng dẫn đưa mã QR cho nhân viên tiếp đón.
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: AppTheme.mutedFill,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            size: 18,
            color: AppTheme.textGrey,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đưa mã QR này cho nhân viên tiếp đón tại bệnh viện để vào khám.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppTheme.textGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bgColor,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: _width,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildPatientInfo(),
              _buildPerforation(),
              _buildQrSection(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

/// _DashedLine: đường nét đứt nằm ngang dùng cho đường cắt của vé.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 9).floor();

        return Align(
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => Container(
                width: 5,
                height: 1.5,
                color: const Color(0xFFB8C4D2),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// showAppointmentTicketSheet: mở bảng xem trước vé khám kèm nút chia sẻ.
Future<void> showAppointmentTicketSheet(
  BuildContext context, {
  required String hospitalName,
  required String patientName,
  required String departmentName,
  required String dateLabel,
  required String timeLabel,
  required String appointmentId,
  required String qrData,
  required int queueNumber,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AppointmentTicketSheet(
      hospitalName: hospitalName,
      patientName: patientName,
      departmentName: departmentName,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      appointmentId: appointmentId,
      qrData: qrData,
      queueNumber: queueNumber,
    ),
  );
}

/// AppointmentTicketSheet: bảng hiển thị vé khám, chụp vé thành ảnh PNG và chia sẻ qua Zalo, Messenger.
class AppointmentTicketSheet extends StatefulWidget {
  final String hospitalName;
  final String patientName;
  final String departmentName;
  final String dateLabel;
  final String timeLabel;
  final String appointmentId;
  final String qrData;
  final int queueNumber;

  const AppointmentTicketSheet({
    super.key,
    required this.hospitalName,
    required this.patientName,
    required this.departmentName,
    required this.dateLabel,
    required this.timeLabel,
    required this.appointmentId,
    required this.qrData,
    required this.queueNumber,
  });

  @override
  State<AppointmentTicketSheet> createState() => _AppointmentTicketSheetState();
}

class _AppointmentTicketSheetState extends State<AppointmentTicketSheet> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;

  /// _captureTicket: chụp vé trong RepaintBoundary thành ảnh PNG độ phân giải cao.
  Future<Uint8List?> _captureTicket() async {
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  /// _shareTicket: Chụp vé, tạo link web theo dõi và mở hộp thoại chia sẻ hệ thống.
  Future<void> _shareTicket() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    final box = context.findRenderObject() as RenderBox?;

    try {
      final bytes = await _captureTicket();
      if (bytes == null) throw Exception('Không chụp được vé khám');

      // Làm sạch ID để dùng làm tên file
      final safeId = widget.appointmentId.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '',
      );

      final trackingLink =
          'https://datlichkham-37558.web.app/?id=${widget.appointmentId}';

      final shareMessage =
          '🎫 *VÉ KHÁM ĐIỆN TỬ*\n'
          '👤 Người khám: ${widget.patientName}\n'
          '🏥 Bệnh viện: ${widget.hospitalName}\n'
          '📅 Ngày: ${widget.dateLabel} | ⏰ Giờ: ${widget.timeLabel}\n\n'
          '📱 *BẤM VÀO LINK ĐỂ XEM SỐ THỨ TỰ CẬP NHẬT REAL-TIME:*\n'
          '$trackingLink\n\n'
          '💡 *Lưu ý:* Khi đến bệnh viện, vui lòng đưa *hình ảnh mã QR* trong tin nhắn này cho nhân viên tiếp đón để được quét và vào khám.';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: ['ve_kham_$safeId.png'],
          text: shareMessage, // Gửi kèm đoạn text có chứa link
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(
          title: 'Chia sẻ thất bại',
          message: 'Không thể chia sẻ vé khám. Vui lòng thử lại.',
          type: SnackBarType.error,
        );
      }
      debugPrint('Lỗi chia sẻ vé: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              children: [
                Text(
                  'Vé khám điện tử',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Gửi vé cho người thân để quét mã tại bệnh viện',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: AppointmentTicketWidget(
                    hospitalName: widget.hospitalName,
                    patientName: widget.patientName,
                    departmentName: widget.departmentName,
                    dateLabel: widget.dateLabel,
                    timeLabel: widget.timeLabel,
                    appointmentId: widget.appointmentId,
                    qrData: widget.qrData,
                    queueNumber: widget.queueNumber,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textGrey,
                        side: const BorderSide(color: AppTheme.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusItem,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Đóng',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSharing ? null : _shareTicket,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.share_rounded, size: 20),
                      label: const Text(
                        'Chia sẻ vé',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusItem,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
