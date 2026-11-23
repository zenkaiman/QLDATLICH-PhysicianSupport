import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/admin_store.dart';
import '../widgets/shared_widgets.dart';
import 'home_screen.dart';
import 'all_hospitals_screen.dart';
import 'patient_management_screen.dart';
import 'operations_screen.dart';

// Khung chính: Dashboard 4 Tabs + Đăng xuất
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    // Lắng nghe AdminStore để rebuild bottom bar khi badge count thay đổi
    AdminStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    AdminStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    AllHospitalsScreen(isEmbedded: true),
    PatientManagementScreen(isEmbedded: true),
    OperationsScreen(isEmbedded: true),
  ];

  void _onTap(int i) {
    if (i == 4) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.logout, color: kRed, size: 24),
              SizedBox(width: 10),
              Text('Đăng xuất tài khoản?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi trang Quản trị Hệ thống không?',
            style: TextStyle(color: kSlate600, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy bỏ', style: TextStyle(color: kSlate600, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã đăng xuất khỏi tài khoản Quản trị viên'),
                    backgroundColor: kSlate900,
                  ),
                );
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(
        index: index.clamp(0, 3),
        children: _screens,
      ),
      bottomNavigationBar: AdminBottomBar(
        current: index,
        onTap: _onTap,
      ),
    );
  }
}
