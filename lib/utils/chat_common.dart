import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Màu và kiểu chữ dùng chung cho các màn hình nhắn tin CSKH.
class ChatColors {
  static const primary = Color(0xFF1E6FE0);
  static const primaryDark = Color(0xFF0B3F8F);
  static const primaryLight = Color(0xFFE8F1FD);
  static const bg = Color(0xFFF4F7FB);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE6EBF2);
  static const online = Color(0xFF16C79A);
  static const danger = Color(0xFFEF4444);
}

TextStyle chatFont(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = ChatColors.ink,
  double? height,
}) => GoogleFonts.beVietnamPro(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

// ───────────────────────── Định dạng thời gian ─────────────────────────

String _two(int n) => n.toString().padLeft(2, '0');

String chatHm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

bool chatSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Nhãn ngăn cách ngày trong cuộc trò chuyện: Hôm nay / Hôm qua / dd/MM/yyyy.
String chatDayLabel(DateTime d) {
  final now = DateTime.now();
  if (chatSameDay(d, now)) return 'Hôm nay';
  if (chatSameDay(d, now.subtract(const Duration(days: 1)))) return 'Hôm qua';
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

/// Nhãn thời gian ở danh sách: "Hôm nay · 09:43", "2 ngày trước", "12/09/2026".
String chatTimeLabel(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;

  if (diff <= 0) return 'Hôm nay · ${chatHm(d)}';
  if (diff == 1) return 'Hôm qua · ${chatHm(d)}';
  if (diff < 7) return '$diff ngày trước';
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

/// Avatar bo góc có chữ viết tắt và chấm trạng thái (tuỳ chọn).
class ChatAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  final bool showDot;

  const ChatAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 52,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.20),
                  color.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Text(
              initials,
              style: chatFont(
                initials.length > 2 ? size * 0.30 : size * 0.36,
                weight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          if (showDot)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: ChatColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}