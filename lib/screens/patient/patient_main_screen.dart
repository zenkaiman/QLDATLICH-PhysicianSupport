import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ✅ 1. Import Provider
import 'package:firebase_auth/firebase_auth.dart'; // ✅ 2. Import FirebaseAuth để lấy UID
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../providers/notification_provider.dart'; // ✅ 3. Import NotificationProvider

// ✅ 4. IMPORT TẤT CẢ CÁC MÀN HÌNH TAB VÀO ĐÂY
import '../patient/home_screen.dart';
import '../patient/my_appointments_screen.dart';
import 'chat_list_screen.dart';
import '../patient/notification_screen.dart';
import '../patient/profile_screen.dart';

class PatientMainScreen extends StatefulWidget {
  final int initialIndex;

  const PatientMainScreen({super.key, this.initialIndex = 0});

  @override
  State<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends State<PatientMainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4).toInt();

    // ✅ 5. Khởi tạo lắng nghe thông báo ngay khi màn hình chính được load
    // Đảm bảo badge cập nhật ngay cả khi người dùng chưa bấm vào tab Thông báo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        // Hàm listen() trong Provider đã có sẵn logic chống gọi lặp (nếu đã listen rồi sẽ bỏ qua)
        context.read<NotificationProvider>().listen(userId);
      }
    });
  }

  // ✅ 6. KHAI BÁO DANH SÁCH CÁC MÀN HÌNH CẦN CHẠY
  final List<Widget> _screens = const [
    HomeScreen(), // Index 0
    MyAppointmentsScreen(showBottomNavBar: false), // Index 1
    ChatListScreen(), // Index 2
    NotificationScreen(), // Index 3
    ProfileScreen(), // Index 4
  ];

  @override
  Widget build(BuildContext context) {
    // ✅ 7. Theo dõi (watch) NotificationProvider để nhận cập nhật real-time
    final notificationProvider = context.watch<NotificationProvider>();
    final realUnreadCount = notificationProvider.unreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      // ✅ 8. SỬ DỤNG INDEXED STACK ĐỂ GIỮ BOTTOM BAR LUÔN HIỆN
      body: IndexedStack(
        index: _currentIndex,
        children: _screens, // Truyền danh sách màn hình vào đây
      ),

      // ✅ 9. THANH ĐIỀU HƯỚNG VỚI DỮ LIỆU THỰC TẾ
      bottomNavigationBar: MedicalBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // Chỉ cần thay đổi index, IndexedStack sẽ tự động chuyển màn hình
          setState(() {
            _currentIndex = index;
          });
        },
        notificationCount: realUnreadCount, // ✅ Truyền số lượng thực tế vào đây
        chatCount: 1, // (Bạn có thể làm tương tự với ChatProvider nếu có)
      ),
    );
  }
}