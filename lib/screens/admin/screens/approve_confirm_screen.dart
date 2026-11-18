import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/admin_store.dart';
import '../widgets/shared_widgets.dart';

// ================= MÀN 8: XÁC NHẬN PHÊ DUYỆT BỆNH VIỆN =================
class ApproveConfirmScreen extends StatelessWidget {
  final Map<String, String> hospital;
  const ApproveConfirmScreen({super.key, required this.hospital});

  @override
  Widget build(BuildContext context) {
    final name = hospital['name'] ?? 'Bệnh viện';
    final tag = hospital['tag'] ?? 'BV';
    final type = hospital['type'] ?? 'Tư nhân';
    final bs = hospital['bs'] ?? '15 Bác sĩ';
    final code = hospital['code'] ?? 'BV-NEW';

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Row(
                children: [
                  BackCircle(),
                  SizedBox(width: 12),
                  Text(
                    'Phê Duyệt Hồ Sơ Hợp Tác',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: kSlate900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kBorder),
                  boxShadow: kElevatedShadow,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: kGreenLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: kGreen, size: 54),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Xác nhận duyệt cơ sở y tế này?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: kSlate900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bệnh viện sẽ được cấp quyền hoạt động trên ứng dụng và đồng bộ dữ liệu trực tiếp lên Firebase.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: kSlate500, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(
                        children: [
                          AvatarBox(
                            text: tag,
                            bg: kPrimaryLight,
                            fg: kPrimary,
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: kSlate900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$type · $bs',
                                  style: const TextStyle(fontSize: 12, color: kSlate500),
                                ),
                                Text(
                                  'Mã hồ sơ: $code',
                                  style: const TextStyle(fontSize: 11.5, color: kSlate400),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kSlate600,
                          side: const BorderSide(color: kBorder),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy bỏ', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text('Xác nhận Duyệt ngay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          AdminStore.instance.approveHospital(hospital);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã duyệt thành công $name trên Firebase ✓'),
                              backgroundColor: kGreen,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
