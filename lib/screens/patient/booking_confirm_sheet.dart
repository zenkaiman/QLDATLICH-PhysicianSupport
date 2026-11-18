import 'package:flutter/material.dart';
import '../../widgets/patient_widget/book_appointment_widget.dart';

/// showBookingConfirmSheet: mở bảng xác nhận đặt lịch, trả về true nếu người dùng xác nhận.
Future<bool?> showBookingConfirmSheet(
  BuildContext context, {
  required String hospitalName,
  required List<Map<String, String>> bookingDetails,
  required String dateLabel,
  required String address,
  required String bhytNote,
  String? patientName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BookingConfirmSheet(
      hospitalName: hospitalName,
      bookingDetails: bookingDetails,
      dateLabel: dateLabel,
      address: address,
      bhytNote: bhytNote,
      patientName: patientName,
    ),
  );
}

/// BookingConfirmSheet: bảng tóm tắt bệnh viện, người khám và lịch khám trước khi gửi yêu cầu.
class BookingConfirmSheet extends StatelessWidget {
  final String hospitalName;
  final List<Map<String, String>> bookingDetails;
  final String dateLabel;
  final String address;
  final String bhytNote;
  final String? patientName;

  const BookingConfirmSheet({
    super.key,
    required this.hospitalName,
    required this.bookingDetails,
    required this.dateLabel,
    required this.address,
    required this.bhytNote,
    this.patientName,
  });

  /// _metaRow: dòng thông tin nhỏ gồm biểu tượng và nội dung.
  Widget _metaRow(IconData icon, String text, {Color? color}) {
    final tone = color ?? AppTheme.textGrey;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: tone),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.35, color: tone),
            ),
          ),
        ],
      ),
    );
  }

  /// _buildHeader: tay kéo, biểu tượng và tiêu đề của bảng.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.tint(AppTheme.primaryBlue, 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 30,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Xác nhận đặt lịch khám',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Kiểm tra thông tin trước khi gửi yêu cầu',
            style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }

  /// _buildHospitalCard: thẻ bệnh viện gồm tên, địa chỉ và thông tin BHYT.
  Widget _buildHospitalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.mutedFill,
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  size: 24,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bệnh viện',
                      style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hospitalName,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (address.isNotEmpty)
            _metaRow(Icons.location_on_rounded, address),
          if (bhytNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoPill(
              icon: Icons.verified_rounded,
              text: bhytNote,
              color: AppTheme.primaryGreen,
              background: Colors.white,
            ),
          ],
        ],
      ),
    );
  }

  /// _buildPatientCard: dòng hiển thị người được khám.
  Widget _buildPatientCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.tint(AppTheme.primaryGreen, 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_rounded,
            size: 20,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Khám cho: ',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textGrey,
                ),
                children: [
                  TextSpan(
                    text: patientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
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

  /// _departmentTile: thẻ lịch khám của một chuyên khoa.
  Widget _departmentTile(Map<String, String> detail) {
    final department = detail['departmentName'] ?? '';
    final room = detail['roomName'] ?? '';
    final shift = detail['shiftLabel'] ?? '';
    final date = (detail['dateLabel'] ?? '').isNotEmpty
        ? detail['dateLabel']!
        : dateLabel;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.tint(AppTheme.primaryBlue, 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              size: 20,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  department.isEmpty ? 'Chuyên khoa' : department,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                if (room.isNotEmpty)
                  _metaRow(Icons.meeting_room_outlined, room),
                if (date.isNotEmpty)
                  _metaRow(Icons.calendar_today_rounded, date),
                if (shift.isNotEmpty)
                  _metaRow(
                    Icons.schedule_rounded,
                    shift,
                    color: AppTheme.textDark,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// _buildNotice: lưu ý về việc bệnh viện sẽ xét duyệt lịch hẹn.
  Widget _buildNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DB),
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sau khi xác nhận, yêu cầu sẽ được chuyển cho bệnh viện xét duyệt lịch hẹn.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Color(0xFF7A4A07),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// _buildActions: hai nút Hủy và Xác nhận cố định ở cuối bảng.
  Widget _buildActions(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
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
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textGrey,
                  side: const BorderSide(color: AppTheme.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                  ),
                ),
                child: const Text(
                  'Hủy',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text(
                  'Xác nhận đặt lịch',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                  ),
                ),
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
      decoration: const BoxDecoration(
        color: AppTheme.bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHospitalCard(),
                  if (patientName?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    _buildPatientCard(),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Lịch khám đã chọn',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      InfoPill(
                        text: '${bookingDetails.length} chuyên khoa',
                        color: AppTheme.primaryBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < bookingDetails.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == bookingDetails.length - 1 ? 0 : 10,
                      ),
                      child: _departmentTile(bookingDetails[i]),
                    ),
                  const SizedBox(height: 16),
                  _buildNotice(),
                ],
              ),
            ),
          ),
          Container(color: Colors.white, child: _buildActions(context)),
        ],
      ),
    );
  }
}