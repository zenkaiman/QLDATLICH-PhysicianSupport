// lib/models/appointment_item.dart

import 'package:flutter/material.dart';

enum AppointmentStatus {
  pending, // Chờ duyệt (1)
  approved, // Đã xác nhận (2)
  cancelled, // Đã hủy (3, 4)
  completed, // Hoàn thành (5)
  missed, // Vắng mặt (6)
  late, // Đến trễ (7)
}

class MyAppointmentItem {
  final String id;
  final String hospitalName;
  final String subtitle;
  final AppointmentStatus status;
  final String departmentName;
  final String dateLabel;
  final String timeLabel;

  const MyAppointmentItem({
    required this.id,
    required this.hospitalName,
    required this.subtitle,
    required this.status,
    this.departmentName = 'Chuyên khoa',
    this.dateLabel = '—',
    this.timeLabel = '—',
  });
}

/// Map trangThaiId từ Firestore → AppointmentStatus
AppointmentStatus statusFromTrangThaiId(dynamic trangThaiId) {
  final id = int.tryParse(trangThaiId?.toString() ?? '') ?? 0;
  switch (id) {
    case 1:
      return AppointmentStatus.pending;
    case 2:
      return AppointmentStatus.approved;
    case 3:
    case 4:
      return AppointmentStatus.cancelled;
    case 5:
      return AppointmentStatus.completed;
    case 6:
      return AppointmentStatus.missed;
    case 7:
      return AppointmentStatus.late;
    default:
      return AppointmentStatus.pending;
  }
}

/// Extension để StatusChip dùng được .label / .background / .foreground / .borderColor
extension AppointmentStatusX on AppointmentStatus {
  String get label {
    switch (this) {
      case AppointmentStatus.pending:
        return 'Chờ duyệt';
      case AppointmentStatus.approved:
        return 'Đã xác nhận';
      case AppointmentStatus.cancelled:
        return 'Đã hủy';
      case AppointmentStatus.completed:
        return 'Hoàn thành';
      case AppointmentStatus.missed:
        return 'Vắng mặt';
      case AppointmentStatus.late:
        return 'Đến trễ';
    }
  }

  Color get background {
    switch (this) {
      case AppointmentStatus.pending:
        return const Color(0xFFFFF6DD); // Vàng nhạt
      case AppointmentStatus.approved:
        return const Color(0xFFE8F5E9); // Xanh lá nhạt
      case AppointmentStatus.cancelled:
        return const Color(0xFFFDECEC); // Đỏ nhạt
      case AppointmentStatus.completed:
        return const Color(0xFFE0F2F1); // Xanh ngọc nhạt (Thành công) ✅ MỚI
      case AppointmentStatus.missed:
        return const Color(0xFFF3F4F6); // Xám nhạt (Trung tính) ✅ MỚI
      case AppointmentStatus.late:
        return const Color(0xFFFFF3E0); // Cam nhạt (Cảnh báo) ✅ MỚI
    }
  }

  Color get foreground {
    switch (this) {
      case AppointmentStatus.pending:
        return const Color(0xFFF59E0B); // Vàng đậm
      case AppointmentStatus.approved:
        return const Color(0xFF22C55E); // Xanh lá đậm
      case AppointmentStatus.cancelled:
        return const Color(0xFFE53935); // Đỏ đậm
      case AppointmentStatus.completed:
        return const Color(0xFF00897B); // Xanh ngọc đậm ✅ MỚI
      case AppointmentStatus.missed:
        return const Color(0xFF64748B); // Xám đậm ✅ MỚI
      case AppointmentStatus.late:
        return const Color(0xFFF97316); // Cam đậm ✅ MỚI
    }
  }

  Color get borderColor {
    switch (this) {
      case AppointmentStatus.pending:
        return const Color(0xFFFFE3A0);
      case AppointmentStatus.approved:
        return const Color(0xFFBBF7D0);
      case AppointmentStatus.cancelled:
        return const Color(0xFFF8CACA);
      case AppointmentStatus.completed:
        return const Color(0xFFB2DFDB);
      case AppointmentStatus.missed:
        return const Color(0xFFE2E8F0);
      case AppointmentStatus.late:
        return const Color(0xFFFED7AA);
    }
  }
}
