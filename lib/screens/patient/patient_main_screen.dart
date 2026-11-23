import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../patient/home_screen.dart';
import '../patient/my_appointments_screen.dart';
import '../patient/notification_screen.dart';
import '../patient/profile_screen.dart';
import 'chat_list_screen.dart';

/// PatientMainScreen: khung chính của bệnh nhân gồm 5 tab và thanh điều hướng dưới.
class PatientMainScreen extends StatefulWidget {
  /// Tab hiển thị đầu tiên (0 Trang chủ, 1 Lịch khám, 2 Tin nhắn, 3 Thông báo, 4 Hồ sơ).
  final int initialIndex;

  const PatientMainScreen({super.key, this.initialIndex = 0});

  @override
  State<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends State<PatientMainScreen> {
  late int _currentIndex;

  /// Danh sách tab; IndexedStack giữ nguyên trạng thái từng tab khi chuyển.
  final List<Widget> _screens = const [
    HomeScreen(),
    MyAppointmentsScreen(showBottomNavBar: false),
    ChatListScreen(),
    NotificationScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _screens.length - 1).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenNotifications());
  }

  /// _listenNotifications: bắt đầu lắng nghe thông báo để badge luôn đúng,
  /// kể cả khi chưa mở tab Thông báo (provider tự bỏ qua nếu đã listen).
  void _listenNotifications() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      context.read<NotificationProvider>().listen(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationProvider>().unreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: MedicalBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}