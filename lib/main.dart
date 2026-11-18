import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_migration_service.dart';

import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'config/firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/family_profile_provider.dart';
import 'providers/hospital_provider.dart';
import 'providers/lich_hen_provider.dart';
import 'providers/review_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/khoa_provider.dart';
import 'services/admin_provider.dart';
import 'screens/auth/login_screen.dart';
import 'seeder/hospital_seeder.dart';
import 'seeder/specialty_seeder.dart';
import 'seeder/phong_kham_seeder.dart';
import 'seeder/lichhen_seeder.dart';
import 'seeder/danh_gia_seeder.dart';
import 'seeder/thong_bao_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Bỏ comment dòng dưới đây nếu bạn muốn chạy seeder để đẩy dữ liệu lên Firebase 1 lần
  //await SpecialtySeeder.seedSpecialties();
  //await HospitalSeeder.seedAllData();
  //await PhongKhamSeeder.seedPhongKham();
  //await LichHenSeeder.seedAllLichHen();
  //await DanhGiaSeeder.seedAllDanhGia();
  //await ThongBaoSeeder.seedAllThongBao();
  //await LichHenSeeder.seedQueueTestAppointments();
  //await LichHenSeeder.seed39AppointmentsForSpecificRoom();

  runApp(const QLDatLichApp());
}

class QLDatLichApp extends StatelessWidget {
  const QLDatLichApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ 2. THAY ĐỔI: Dùng MultiProvider để khai báo nhiều Provider cùng lúc
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FamilyProfileProvider()),
        ChangeNotifierProvider(create: (_) => HospitalProvider()),
        ChangeNotifierProvider(create: (_) => LichHenProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => KhoaProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: MaterialApp(
        title: 'QLDATLICH',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
        routes: AppRoutes.routes,
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      ),
    );
  }
}
