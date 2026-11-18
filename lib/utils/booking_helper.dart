import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/phong_kham_model.dart';
import '../models/review_model.dart';
import '../providers/lich_hen_provider.dart';

class BookingHelper {
  static String departmentIdOf(Map department) =>
      (department['id'] ?? department['ten_khoa'] ?? '').toString();
  static String departmentName(
    String id,
    List<Map<String, dynamic>> departments,
  ) {
    for (final d in departments) {
      if (departmentIdOf(d) == id)
        return d['ten_khoa']?.toString() ?? 'Chuyên khoa';
    }
    return 'Chuyên khoa';
  }

  static String roomIdOf(PhongKhamModel room) => room.id;
  static String roomNameOf(PhongKhamModel room) => room.tenPhong;
  static String roomSubtitleOf(PhongKhamModel room) => '';
  static int roomMaxOf(PhongKhamModel room) {
    try {
      final v = (room as dynamic).soBenhNhanToiDa;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

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

  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
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

  static String formatDayMonth(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  static Color availabilityColor(int left, int total) {
    if (left <= 0 || total <= 0) return Colors.grey;
    final ratio = left / total;
    if (ratio >= 0.5) return const Color(0xFF5B8C3E);
    if (ratio >= 0.2) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  static String ratingLabelOfAverage(double average) {
    if (average >= 4.5) return 'Tuyệt vời';
    if (average >= 4) return 'Rất tốt';
    if (average >= 3) return 'Tốt';
    if (average >= 2) return 'Trung bình';
    return 'Cần cải thiện';
  }

  static String ratingChipText(int rating) {
    if (rating >= 5) return 'Rất hài lòng';
    if (rating == 4) return 'Hài lòng';
    if (rating == 3) return 'Bình thường';
    if (rating == 2) return 'Chưa hài lòng';
    return 'Không hài lòng';
  }

  static Color ratingChipColor(int rating) {
    if (rating >= 4) return const Color(0xFF5B8C3E);
    if (rating == 3) return const Color(0xFFF59E0B);
    if (rating == 2) return const Color(0xFFEA580C);
    return const Color(0xFFDC2626);
  }

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


  static String reviewerInitial(ReviewModel review) {
    if (review.anDanh) return '?';
    final id = review.benhNhanId.trim();
    return id.isEmpty ? 'B' : id.substring(id.length - 1).toUpperCase();
  }

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
}