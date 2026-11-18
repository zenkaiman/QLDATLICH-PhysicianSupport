import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_routes.dart';

class AssistantHomeScreen extends StatelessWidget {
  const AssistantHomeScreen({super.key});

  Future<void> _dangXuat(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận đăng xuất', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi bàn làm việc Hỗ trợ bác sĩ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'BS_TM_01';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E78E0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Hỗ Trợ Bác Sĩ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _dangXuat(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
                  ),
                  child: const Icon(
                    Icons.medical_services_rounded,
                    color: Color(0xFF1E78E0),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Bàn Làm Việc Hỗ Trợ Bác Sĩ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đăng nhập với: $userEmail',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tài khoản đã kích hoạt & phân quyền chuẩn',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Luồng cấp mã từ Bệnh viện, kích hoạt đổi mật khẩu và đăng nhập đã hoạt động hoàn toàn tự động. Giao diện điều phối hàng chờ khám đang được đồng bộ từ nhánh PhysicianSupport.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => _dangXuat(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Đăng xuất tài khoản'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
