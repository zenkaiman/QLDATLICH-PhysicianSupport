import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/phong_kham_model.dart';
import '../../models/review_model.dart';
import '../../providers/lich_hen_provider.dart';

class BookingHelper {
  /// departmentIdOf: lấy id của khoa (ưu tiên 'id', không có thì dùng 'ten_khoa').
  static String departmentIdOf(Map department) =>
      (department['id'] ?? department['ten_khoa'] ?? '').toString();

  /// departmentName: lấy tên khoa theo id trong danh sách khoa (mặc định "Chuyên khoa").
  static String departmentName(
    String id,
    List<Map<String, dynamic>> departments,
  ) {
    for (final d in departments) {
      if (departmentIdOf(d) == id) {
        return d['ten_khoa']?.toString() ?? 'Chuyên khoa';
      }
    }
    return 'Chuyên khoa';
  }

  /// roomIdOf: lấy id của phòng khám.
  static String roomIdOf(PhongKhamModel room) => room.id;

  /// roomNameOf: lấy tên của phòng khám.
  static String roomNameOf(PhongKhamModel room) => room.tenPhong;

  /// roomSubtitleOf: lấy phụ đề của phòng khám (hiện luôn rỗng).
  static String roomSubtitleOf(PhongKhamModel room) => '';

  /// roomMaxOf: lấy số bệnh nhân tối đa của phòng khám (0 nếu không có hoặc không đọc được).
  static int roomMaxOf(PhongKhamModel room) {
    try {
      final v = (room as dynamic).soBenhNhanToiDa;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// roomName: tìm tên phòng khám theo khoa và id phòng (mặc định "Phòng khám").
  static String roomName(
    String departmentId,
    String roomId,
    Map<String, List<PhongKhamModel>> roomsByDept,
  ) {
    for (final r in roomsByDept[departmentId] ?? <PhongKhamModel>[]) {
      if (roomIdOf(r) == roomId) return roomNameOf(r);
    }
    return 'Phòng khám';
  }

  /// roomMax: tìm số bệnh nhân tối đa của phòng khám theo khoa và id phòng (0 nếu không thấy).
  static int roomMax(
    String departmentId,
    String roomId,
    Map<String, List<PhongKhamModel>> roomsByDept,
  ) {
    for (final r in roomsByDept[departmentId] ?? <PhongKhamModel>[]) {
      if (roomIdOf(r) == roomId) return roomMaxOf(r);
    }
    return 0;
  }

  /// today: lấy ngày hôm nay (bỏ giờ phút giây).
  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// isSameDay: kiểm tra hai thời điểm có cùng ngày không.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// dayEntry: tạo dữ liệu một ngày cho thanh chọn ngày (nhãn thứ hoặc "HÔM NAY", số ngày, ngày).
  static Map<String, dynamic> dayEntry(DateTime date, DateTime todayDate) {
    const weekdayLabels = [
      'THỨ 2',
      'THỨ 3',
      'THỨ 4',
      'THỨ 5',
      'THỨ 6',
      'T.BẢY',
      'C.NHẬT',
    ];
    return {
      'label': isSameDay(date, todayDate)
          ? 'HÔM NAY'
          : weekdayLabels[date.weekday - 1],
      'day': date.day.toString(),
      'date': date,
    };
  }

  /// scheduleDays: tạo danh sách các ngày liên tiếp từ hôm nay cho thanh chọn ngày.
  static List<Map<String, dynamic>> scheduleDays(
    DateTime todayDate,
    int soNgayHienThi,
  ) {
    return List.generate(
      soNgayHienThi,
      (i) => dayEntry(
        DateTime(todayDate.year, todayDate.month, todayDate.day + i),
        todayDate,
      ),
    );
  }

  /// formatDayMonth: định dạng ngày thành "dd/MM".
  static String formatDayMonth(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  /// getTimeAgo: đổi thời điểm thành chuỗi tương đối (Vừa xong, 5 phút trước, 2 tuần trước...).
  static String getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7} tuần trước';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30} tháng trước';
    return '${diff.inDays ~/ 365} năm trước';
  }

  /// slotKeyFor: tạo khóa cache tình trạng ca theo bệnh viện, khoa, phòng và ngày.
  static String slotKeyFor({
    required String departmentId,
    required String roomId,
    required DateTime date,
    required String hospitalId,
  }) {
    return LichHenProvider.makeKey(
      ngay: date,
      benhVienId: hospitalId,
      khoaId: departmentId,
      phongKhamId: roomId,
    );
  }

  /// availabilityColor: chọn màu theo tỷ lệ chỗ còn lại (xám khi hết chỗ, xanh từ 50%, vàng từ 20%, đỏ dưới 20%).
  static Color availabilityColor(int left, int total) {
    if (left <= 0 || total <= 0) return Colors.grey;
    final ratio = left / total;
    if (ratio >= 0.5) return const Color(0xFF5B8C3E);
    if (ratio >= 0.2) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  /// ratingLabelOfAverage: đổi điểm trung bình thành nhãn chất lượng (Tuyệt vời, Rất tốt, Tốt, Trung bình, Cần cải thiện).
  static String ratingLabelOfAverage(double average) {
    if (average >= 4.5) return 'Tuyệt vời';
    if (average >= 4) return 'Rất tốt';
    if (average >= 3) return 'Tốt';
    if (average >= 2) return 'Trung bình';
    return 'Cần cải thiện';
  }

  /// ratingChipText: đổi số sao của một đánh giá thành nhãn mức độ hài lòng.
  static String ratingChipText(int rating) {
    if (rating >= 5) return 'Rất hài lòng';
    if (rating == 4) return 'Hài lòng';
    if (rating == 3) return 'Bình thường';
    if (rating == 2) return 'Chưa hài lòng';
    return 'Không hài lòng';
  }

  /// ratingChipColor: chọn màu nhãn theo số sao (xanh từ 4 sao, vàng 3 sao, cam 2 sao, đỏ dưới 2 sao).
  static Color ratingChipColor(int rating) {
    if (rating >= 4) return const Color(0xFF5B8C3E);
    if (rating == 3) return const Color(0xFFF59E0B);
    if (rating == 2) return const Color(0xFFEA580C);
    return const Color(0xFFDC2626);
  }

  /// starRow: vẽ hàng 5 ngôi sao (đầy, nửa, rỗng) theo giá trị điểm.
  static Widget starRow(double value, {double size = 16, bool center = false}) {
    const amber = Color(0xFFFFA000);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: List.generate(5, (i) {
        final IconData icon;
        if (value >= i + 1) {
          icon = Icons.star_rounded;
        } else if (value >= i + 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }

        return Icon(icon, size: size, color: amber);
      }),
    );
  }

  /// reviewerInitial: lấy chữ cái đại diện người đánh giá ("?" nếu ẩn danh, ký tự cuối của mã bệnh nhân, "B" nếu mã rỗng).
  static String reviewerInitial(ReviewModel review) {
    if (review.anDanh) return '?';
    final id = review.benhNhanId.trim();
    return id.isEmpty ? 'B' : id.substring(id.length - 1).toUpperCase();
  }
}