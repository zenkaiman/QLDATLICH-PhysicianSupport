import 'lichhen_model.dart';

/// Dữ liệu hiển thị trên vé (lấy từ lịch hẹn hoặc từ tham số màn hình).
class TicketData {
  final String bookingCode;
  final String qrData;
  final String queueNumber;
  final String patientName;
  final String hospitalName;
  final String? roomName;
  final String? departmentName;
  final String timeLabel;
  final String dateLabel;
  final String statusLabel;
  final bool confirmed;

  const TicketData({
    required this.bookingCode,
    required this.qrData,
    required this.queueNumber,
    required this.patientName,
    required this.hospitalName,
    required this.roomName,
    required this.departmentName,
    required this.timeLabel,
    required this.dateLabel,
    required this.statusLabel,
    required this.confirmed,
  });

  /// Tạo dữ liệu vé từ một lịch hẹn trong Firestore.
  factory TicketData.fromBooking(LichHenModel b, {String? patientName}) {
    final status = b.trangThaiId.toString();
    final hasHours = b.gioBatDau != null && b.gioKetThuc != null;
    final caName = b.tenCa ?? 'Ca khám';
    final time = hasHours
        ? '$caName (${b.gioBatDau} - ${b.gioKetThuc})'
        : (b.gioDuKien.isNotEmpty ? b.gioDuKien : caName);
    final date = b.ngayDat;

    return TicketData(
      bookingCode: '#${b.id}',
      qrData: buildQrPayload(b),
      queueNumber: b.soThuTu > 0 ? b.soThuTu.toString().padLeft(2, '0') : '--',
      patientName: patientName ?? 'Bệnh nhân',
      hospitalName: b.tenBenhVien ?? 'Bệnh viện ${b.benhVienId}',
      roomName:
          b.tenPhongKham ?? (b.phongKhamId.isNotEmpty ? b.phongKhamId : null),
      departmentName: b.tenKhoa,
      timeLabel: time,
      dateLabel: date == null ? 'Chưa cập nhật ngày' : formatDateFull(date),
      statusLabel: statusLabelOf(status),
      confirmed: status == '2', // '2' là Đã xác nhận
    );
  }

  static String buildQrPayload(LichHenModel b) {
    return b.id.replaceAll('#', '').trim();
  }

  /// Định dạng ngày đầy đủ: "Thứ 3, 10/09/2026".
  static String formatDateFull(DateTime d) {
    const weekdays = [
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'Chủ nhật',
    ];
    return '${weekdays[d.weekday - 1]}, '
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Tên trạng thái theo mã trong bảng TrangThai.
  static String statusLabelOf(String id) {
    switch (id) {
      case '2':
        return 'Đã xác nhận';
      case '3':
      case '4':
        return 'Đã hủy';
      case '5':
        return 'Hoàn thành';
      case '6':
        return 'Vắng mặt';
      case '7':
        return 'Đến trễ';
      default:
        return 'Chờ duyệt';
    }
  }
}