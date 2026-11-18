import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


class ConversationModel {
  final String id; // CONV_{benhVienId}_{benhNhanId}
  final String benhNhanId;
  final String benhVienId;
  final String supportId; // nhân viên support phụ trách ('' nếu chưa gán)
  final String tenBenhNhan;
  final String tenBenhVien;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCountPatient;
  final int unreadCountSupport;
  final String status; // open | closed
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ConversationModel({
    required this.id,
    required this.benhNhanId,
    required this.benhVienId,
    this.supportId = '',
    this.tenBenhNhan = '',
    this.tenBenhVien = '',
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCountPatient = 0,
    this.unreadCountSupport = 0,
    this.status = 'open',
    this.createdAt,
    this.updatedAt,
  });

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;
  static int _int(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  factory ConversationModel.fromMap(Map<String, dynamic> m, {String? id}) {
    return ConversationModel(
      id: id ?? (m['id'] ?? '').toString(),
      benhNhanId: (m['benhNhanId'] ?? '').toString(),
      benhVienId: (m['benhVienId'] ?? '').toString(),
      supportId: (m['supportId'] ?? '').toString(),
      tenBenhNhan: (m['tenBenhNhan'] ?? '').toString(),
      tenBenhVien: (m['tenBenhVien'] ?? '').toString(),
      lastMessage: (m['lastMessage'] ?? '').toString(),
      lastMessageAt: _date(m['lastMessageAt']),
      unreadCountPatient: _int(m['unreadCountPatient']),
      unreadCountSupport: _int(m['unreadCountSupport']),
      status: (m['status'] ?? 'open').toString(),
      createdAt: _date(m['createdAt']),
      updatedAt: _date(m['updatedAt']),
    );
  }

  bool get isOpen => status != 'closed';
  bool get hasSupport => supportId.isNotEmpty;

  /// Thời điểm dùng để sắp xếp danh sách (mới nhất lên đầu).
  DateTime get sortTime =>
      lastMessageAt ??
      createdAt ??
      updatedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  /// Tên hiển thị: "CSKH BV Quận 17".
  String get displayName =>
      tenBenhVien.isEmpty ? 'CSKH Bệnh viện' : 'CSKH $tenBenhVien';

  /// Chữ viết tắt cho avatar: "BV Bạch Mai" -> "BM".
  String get initials {
    final words = tenBenhVien
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length > 1) {
      final first = words.first.toLowerCase();
      if (first == 'bv' || first == 'bệnh') {
        words.removeAt(0);
        if (words.isNotEmpty && words.first.toLowerCase() == 'viện') {
          words.removeAt(0);
        }
      }
    }
    if (words.isEmpty) return 'BV';
    if (words.length == 1) {
      final w = words.first;
      return (w.length > 3 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  static const _palette = [
    Color(0xFF2563EB),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFEA580C),
    Color(0xFF0EA5E9),
  ];

  /// Màu avatar cố định theo bệnh viện.
  Color get accent {
    final h = benhVienId.codeUnits.fold<int>(0, (s, c) => s + c);
    return _palette[h % _palette.length];
  }
}