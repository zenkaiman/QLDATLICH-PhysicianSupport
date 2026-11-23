import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/admin_store.dart';
import '../widgets/shared_widgets.dart';

// ================= MÀN 9: TỪ CHỐI PHÊ DUYỆT BỆNH VIỆN =================
class RejectScreen extends StatefulWidget {
  final Map<String, String> hospital;
  const RejectScreen({super.key, required this.hospital});

  @override
  State<RejectScreen> createState() => _RejectScreenState();
}

class _RejectScreenState extends State<RejectScreen> {
  int _selected = 0;
  final List<String> _reasons = [
    'Thiếu giấy phép hoạt động BYT',
    'Thông tin người đại diện chưa rõ',
    'Địa chỉ hoặc phòng khám không hợp lệ',
    'Trùng lặp cơ sở đã tồn tại',
  ];

  final TextEditingController _ctrl = TextEditingController(
    text: 'Giấy phép hoạt động đã hết hạn hoặc chưa hoàn tất kiểm định BYT. Vui lòng bổ sung giấy tờ hợp lệ trước khi gửi lại yêu cầu.',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.hospital['name'] ?? 'Bệnh viện';
    final tag = widget.hospital['tag'] ?? 'BV';
    final type = widget.hospital['type'] ?? 'Tư nhân';
    final bs = widget.hospital['bs'] ?? '15 Bác sĩ';

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
                    'Từ Chối Phê Duyệt',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: kSlate900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hospital Summary
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
                      text: tag,
                      bg: kRedBg,
                      fg: kRed,
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
                              fontSize: 15,
                              color: kSlate900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$type · $bs',
                            style: const TextStyle(fontSize: 12, color: kSlate500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kOrangeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Chờ duyệt',
                        style: TextStyle(fontSize: 11, color: kAmber, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Reason Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kBorder),
                  boxShadow: kCardShadow,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: kRedBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline_rounded, color: kRed, size: 28),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Lý do từ chối hồ sơ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: kSlate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Phản hồi này sẽ được gửi trực tiếp đến người đăng ký cơ sở y tế',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: kSlate500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'CHỌN LÝ DO CHÍNH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kSlate500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_reasons.length, (i) {
                  final bool active = i == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: active ? kRedBg : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? kRed : kBorder,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        _reasons[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? kRed : kSlate700,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 18),

              const Text(
                'NỘI DUNG PHẢN HỒI CHI TIẾT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kSlate500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                  boxShadow: kCardShadow,
                ),
                child: TextField(
                  controller: _ctrl,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 13.5, color: kSlate900, height: 1.4),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Nhập lý do hoặc hướng dẫn khắc phục hồ sơ...',
                    hintStyle: TextStyle(fontSize: 13, color: kSlate400),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
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
                        child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Gửi Thông Báo Từ Chối', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final fullReason = '${_reasons[_selected]}: ${_ctrl.text.trim()}';
                          AdminStore.instance.rejectHospital(
                            widget.hospital,
                            reason: fullReason,
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã gửi thông báo từ chối đến $name'),
                              backgroundColor: kRed,
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
