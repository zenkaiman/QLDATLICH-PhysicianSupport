import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../data/mock_data.dart';
import '../widgets/shared_widgets.dart';

// ================= MÀN 3: ĐÁNH GIÁ BỆNH VIỆN TỪ BỆNH NHÂN =================
class ReviewScreen extends StatelessWidget {
  final Hospital hospital;
  const ReviewScreen({super.key, required this.hospital});

  Widget _buildReviewCard({
    required String name,
    required String content,
    required String date,
    required String dept,
    int stars = 5,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: kPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: kSlate900,
                      ),
                    ),
                    Text(
                      '$date · $dept',
                      style: const TextStyle(fontSize: 11, color: kSlate400),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: index < stars ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(fontSize: 13, color: kSlate800, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  BackCircle(),
                  SizedBox(width: 12),
                  Text(
                    'Đánh Giá Từ Bệnh Nhân',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: kSlate900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hospital Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kBorder),
                  boxShadow: kCardShadow,
                ),
                child: Row(
                  children: [
                    AvatarBox(
                      text: hospital.initials,
                      bg: hospital.avatarBg,
                      fg: hospital.avatarText,
                      size: 50,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hospital.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: kSlate900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 3),
                              Text(
                                '${hospital.rating.toStringAsFixed(1)} / 5.0',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: kSlate900,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${hospital.totalReviews ?? 200} lượt đánh giá)',
                                style: const TextStyle(fontSize: 11.5, color: kSlate500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Overview Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kGreenLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kGreen.withValues(alpha: 0.2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chỉ số hài lòng tổng quan',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: kGreen,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Chất lượng chẩn đoán y khoa: 4.9★\n• Thái độ phục vụ y bác sĩ: 4.8★\n• Cơ sở vật chất và phòng khám: 4.7★\n• Thời gian tiếp đón và check-in: 4.6★',
                      style: TextStyle(fontSize: 12.5, color: kSlate800, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                'Nhận xét thực tế gần đây',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: kSlate900,
                ),
              ),
              const SizedBox(height: 10),

              // Realtime Stream from Firestore
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('DanhGia')
                    .where('benh_vien_id', isEqualTo: hospital.code)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final docs = snapshot.data!.docs;
                    return Column(
                      children: docs.map((d) {
                        final data = d.data();
                        final tenKhoa = data['ten_khoa']?.toString() ?? 'Khoa Khám Bệnh';
                        final comment = data['nhan_xet']?.toString() ?? 'Dịch vụ bác sĩ rất tận tâm và chuyên nghiệp.';
                        final name = data['an_danh'] == 1
                            ? 'Bệnh nhân (Ẩn danh)'
                            : (data['ho_ten']?.toString() ?? 'Bệnh nhân Mediconnect');
                        final dateStr = data['ngay_danh_gia']?.toString().split(' ').first ?? 'Gần đây';
                        final stars = (data['diem_danh_gia'] as num?)?.toInt() ?? 5;
                        return _buildReviewCard(
                          name: name,
                          content: comment,
                          date: dateStr,
                          dept: tenKhoa,
                          stars: stars,
                        );
                      }).toList(),
                    );
                  }

                  // Default sample reviews if none yet for this code
                  return Column(
                    children: [
                      _buildReviewCard(
                        name: 'Nguyễn Văn An',
                        content: 'Bác sĩ tận tâm, khám nhanh, giải thích rõ ràng và chu đáo. Rất hài lòng với dịch vụ đặt lịch qua app!',
                        date: '18/10/2026',
                        dept: 'Khoa Ngoại Tổng Quát',
                        stars: 5,
                      ),
                      _buildReviewCard(
                        name: 'Trần Thị Bích Ngọc',
                        content: 'Thủ tục check-in bằng mã QR rất tiện lợi, không phải xếp hàng lấy số thứ tự lâu.',
                        date: '16/10/2026',
                        dept: 'Khoa Khám Bệnh',
                        stars: 5,
                      ),
                      _buildReviewCard(
                        name: 'Lê Hoàng Nam',
                        content: 'Phòng khám sạch sẽ, kết quả xét nghiệm gửi nhanh trực tiếp vào tài khoản bệnh nhân.',
                        date: '12/10/2026',
                        dept: 'Khoa Nội Tim Mạch',
                        stars: 4,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
