import 'package:flutter/material.dart';
import '../../../config/constants.dart';

/// Header hiển thị avatar chữ viết tắt, tên bệnh viện, huy hiệu trạng thái và nút thông báo.
class HospitalHeader extends StatelessWidget {
  final String hospitalUid;
  final String tenBenhVien;
  final bool daGuiDon;
  final bool daXacThuc;
  final int trangThaiId;
  final String? email;

  const HospitalHeader({
    super.key,
    required this.hospitalUid,
    required this.tenBenhVien,
    required this.daGuiDon,
    required this.daXacThuc,
    required this.trangThaiId,
    this.email,
  });

  /// "Bệnh Viện Đa Khoa An Bình" -> "AB"
  static String chuVietTat(String ten) {
    final tu = ten.split(' ').where((e) => e.isNotEmpty).toList();
    if (tu.isEmpty) return 'AB';
    if (tu.length == 1) return tu[0].substring(0, 1).toUpperCase();
    return (tu.first[0] + tu.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    String badgeText = 'Chưa xác thực';
    Color badgeBg = const Color(0xFFFFFBEB);
    Color badgeTextColor = const Color(0xFFD97706);
    Color badgeBorder = const Color(0xFFFDE68A);

    if (trangThaiId == TrangThaiId.huyHopTac) {
      badgeText = 'Hủy / Từ chối hợp tác';
      badgeBg = const Color(0xFFFEF2F2);
      badgeTextColor = const Color(0xFFDC2626);
      badgeBorder = const Color(0xFFFECACA);
    } else if (daXacThuc) {
      badgeText = 'Đã hợp tác';
      badgeBg = const Color(0xFFECFDF5);
      badgeTextColor = const Color(0xFF059669);
      badgeBorder = const Color(0xFFA7F3D0);
    } else if (daGuiDon) {
      badgeText = 'Đang chờ duyệt';
      badgeBg = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFD97706);
      badgeBorder = const Color(0xFFFCD34D);
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2FE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              chuVietTat(tenBenhVien),
              style: const TextStyle(
                color: Color(0xFF0284C7),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenBenhVien,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeBorder, width: 0.8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF334155),
                size: 20,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Không có thông báo mới.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
