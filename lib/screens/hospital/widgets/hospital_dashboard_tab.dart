import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_session.dart';
import '../../../services/benhVien_service.dart';
import '../listKhoaDieuTri.dart';

/// 1240 -> "1,240"
String _soCoDauPhay(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Tab Trang chủ khi Bệnh viện đã được Admin phê duyệt (Đã hợp tác).
class HospitalDashboardTab extends StatelessWidget {
  final String hospitalUid;
  final VoidCallback onXemTatCaKhoa;

  const HospitalDashboardTab({
    super.key,
    required this.hospitalUid,
    required this.onXemTatCaKhoa,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              const Expanded(child: TongSoKhoaCard()),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: BenhVienService.thongKeHomNay(hospitalUid),
                  builder: (context, snap) {
                    final d = snap.data?.data();
                    final tong = ((d?['tongBenhNhan'] ?? 0) as num).toInt();
                    final dang = ((d?['dangKham'] ?? 0) as num).toInt();
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1D89D1), Color(0xFF1E79C2)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bệnh nhân hôm nay',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _soCoDauPhay(tong),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Đang khám: $dang lượt',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                AppSession.benhVienId = hospitalUid;
                Navigator.pushNamed(context, AppRoutes.addClinic);
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Thêm Khoa Khám Mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E87D8),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListKhoaDieuTri(
            onXemTatCa: onXemTatCaKhoa,
          ),
        ),
      ],
    );
  }
}
