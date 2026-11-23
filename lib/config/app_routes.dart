import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/appointment_item.dart';
import '../models/lichhen_model.dart';
import '../config/app_session.dart';

// Auth Screens
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/email_verification_screen.dart';
import '../screens/auth/forgot_password_screen.dart';

// Patient Screens
import '../screens/patient/home_screen.dart';
import '../screens/patient/patient_main_screen.dart';
import '../screens/patient/book_appointment_screen.dart';
import '../screens/patient/booking_request_sent_screen.dart';
import '../screens/patient/appointment_detail_screen.dart';
import '../screens/patient/my_appointments_screen.dart';
import '../screens/patient/medical_history_screen.dart';
import '../screens/patient/hospital_filter_screen.dart';
import '../screens/patient/qr_ticket_screen.dart';
import '../screens/patient/edit_profile_screen.dart';
import '../screens/patient/notification_screen.dart';
import '../screens/patient/theo_doi_lich_kham.dart';
import '../screens/patient/family_profiles_screen.dart';
import '../screens/patient/add_edit_family_profile_screen.dart';

// Receptionist & Staff Screens
import '../screens/receptionist/receptionist_home_screen.dart';
import '../screens/receptionist/check_in_screen.dart';
import '../screens/receptionist/appointment_list_screen.dart';
import '../screens/letan_c1/letan_trangchu_screen_c1.dart'; // Giữ lại nếu cần dùng màn C1

// Doctor Assistant Screens
import '../screens/doctor_assistant/assistant_home_screen.dart';
import '../screens/doctor_assistant/patient_queue_screen.dart';
import '../screens/doctor_assistant/update_record_screen.dart';

// Customer Support Screens
import '../screens/customer_support/support_home_screen.dart';
import '../screens/customer_support/chat_list_screen.dart';
import '../screens/customer_support/ticket_screen.dart';

// Hospital & Admin Screens
import '../screens/hospital/homeHospital_Screem.dart';
import '../screens/hospital/addKhoaHospital_Screen.dart';
import '../screens/hospital/guiYeuCauHopTac_Screen.dart';
import '../screens/hospital/guiDonThanhCong_Screen.dart';
import '../screens/hospital/statistics_screen.dart';
import '../screens/hospital/staff_management_screen.dart';
import '../screens/hospital/nhanSu_Screen.dart';
import '../screens/admin/admin_dashboard.dart';

// ⚠️ LƯU Ý: Nếu ThemKhoaScreen báo lỗi không tìm thấy, hãy thêm import đúng đường dẫn của nó, ví dụ:
// import '../screens/hospital/them_khoa_screen.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const String login = '/login';
  static const String register = '/register';
  static const String hospitalRegister = '/hospital-register';
  static const String roleSelection = '/role-selection';
  static const String emailVerification = '/email-verification';
  static const String forgotPassword = '/forgot-password';

  static const String patientHome = '/patient-home';
  static const String patientMain = '/patient-main';
  static const String bookAppointment = '/book-appointment';
  static const String bookingRequestSent = '/booking-request-sent';
  static const String appointmentDetail = '/appointment-detail';
  static const String myAppointments = '/my-appointments';
  static const String medicalHistory = '/medical-history';
  static const String hospitalFilter = '/hospital-filter';
  static const String qrTicket = '/qr-ticket';
  static const String editProfile = '/edit-profile';
  static const String notification = '/notification';
  static const String appointmentTracking = '/appointment-tracking';
  static const String familyProfiles = '/family-profiles';
  static const String addEditFamilyProfile = '/family-profiles/edit';

  static const String receptionistHome = '/receptionist-home';
  static const String checkIn = '/check-in';
  static const String appointmentList = '/appointment-list';

  static const String assistantHome = '/assistant-home';
  static const String patientQueue = '/patient-queue';
  static const String updateRecord = '/update-record';

  static const String supportHome = '/support-home';
  static const String chatList = '/chat-list';
  static const String ticket = '/ticket';

  static const String hospitalDashboard = '/hospital-dashboard';
  static const String hospitalRequestCollaboration = '/hospital-request-collaboration';
  static const String hospitalRequestSuccess = '/hospital-request-success';
  static const String addClinic = '/add-clinic';
  static const String staffManagement = '/staff-management';
  static const String nhanSuScreen = '/hospital-nhan-su';
  static const String phanCongScreen = '/hospital-phan-cong';
  static const String statistics = '/statistics';
  static const String adminDashboard = '/admin-dashboard';

  static Map<String, WidgetBuilder> get routes => {
        // =========================================================================
        // AUTH ROUTES
        // =========================================================================
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        emailVerification: (context) {
          final email = ModalRoute.of(context)?.settings.arguments as String? ?? 'Email không xác định';
          return EmailVerificationScreen(email: email);
        },
        forgotPassword: (context) {
          final email = ModalRoute.of(context)?.settings.arguments as String?;
          return ForgotPasswordScreen(initialEmail: email);
        },

        // =========================================================================
        // PATIENT ROUTES
        // =========================================================================
        patientHome: (_) => const HomeScreen(),
        patientMain: (context) {
          final index = ModalRoute.of(context)?.settings.arguments;
          return PatientMainScreen(initialIndex: index is int ? index : 0);
        },
        bookAppointment: (_) => const BookAppointmentScreen(),
        bookingRequestSent: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final appointment = args is MyAppointmentItem ? args : null;

          return BookingRequestSentScreen(
            requestCode: appointment?.id ?? '#REQ-2026-8921',
            hospitalName: appointment?.hospitalName ?? 'Bệnh viện Bạch Mai',
            departmentName: appointment?.departmentName ?? 'Khoa Tim mạch',
            dateLabel: appointment?.dateLabel ?? '24/09/2026',
            shiftLabel: appointment?.timeLabel ?? 'Ca sáng (08:00-12:00)',
            onViewStatus: () => Navigator.pushNamed(
              context,
              myAppointments,
              arguments: appointment == null ? null : <MyAppointmentItem>[appointment],
            ),
            onGoHome: () => Navigator.pushNamedAndRemoveUntil(
              context,
              patientMain,
              (_) => false,
              arguments: 0,
            ),
          );
        },
        myAppointments: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final onOpenDetail = (MyAppointmentItem item) {
            Navigator.pushNamed(context, appointmentDetail, arguments: item);
          };

          if (args is List<MyAppointmentItem>) {
            return MyAppointmentsScreen(appointments: args, onOpenDetail: onOpenDetail);
          }
          if (args is MyAppointmentItem) {
            return MyAppointmentsScreen(appointments: [args], onOpenDetail: onOpenDetail);
          }
          return MyAppointmentsScreen(onOpenDetail: onOpenDetail);
        },
        appointmentDetail: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is! MyAppointmentItem) {
            return const Scaffold(
              body: Center(child: Text('Không tìm thấy thông tin lịch khám.', style: TextStyle(color: Colors.red))),
            );
          }
          return AppointmentDetailScreen(appointment: args);
        },
        
        // Các route mới được bổ sung từ nhánh gop_code_tong_hop
        editProfile: (_) => const EditProfileScreen(),
        qrTicket: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final booking = args is LichHenModel ? args : null;
          return QrTicketScreen(booking: booking);
        },
        appointmentTracking: (_) => const AppointmentTrackingScreen(),
        familyProfiles: (_) => const FamilyProfilesScreen(),
        addEditFamilyProfile: (_) => const AddEditFamilyProfileScreen(),
        medicalHistory: (_) => const MedicalHistoryScreen(),
        hospitalFilter: (_) => const HospitalFilterScreen(),
        notification: (_) => const NotificationScreen(),

        // =========================================================================
        // STAFF & RECEPTIONIST ROUTES
        // =========================================================================
        // Lưu ý: Nếu muốn dùng màn C1, hãy đổi thành const LeTanHomeScreenC1()
        receptionistHome: (_) => const ReceptionistHomeScreen(), 
        checkIn: (_) => const CheckInScreen(),
        appointmentList: (_) => const AppointmentListScreen(),
        assistantHome: (_) => const AssistantHomeScreen(),
        patientQueue: (_) => const PatientQueueScreen(),
        updateRecord: (_) => const UpdateRecordScreen(),
        supportHome: (_) => const SupportHomeScreen(),
        chatList: (_) => const ChatListScreen(),
        ticket: (_) => const TicketScreen(),

        // =========================================================================
        // HOSPITAL & ADMIN ROUTES
        // =========================================================================
        hospitalDashboard: (context) {
          final tabIndex = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
          return HomeHospitalScreen(initialTabIndex: tabIndex);
        },
        hospitalRequestCollaboration: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return GuiYeuCauHopTacScreen(
            initialTenBenhVien: args?['tenBenhVien'],
            initialDiaChi: args?['diaChi'],
          );
        },
        hospitalRequestSuccess: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return GuiDonThanhCongScreen(
            maHoSo: args?['maHoSo'] ?? '#HS-BV-202688',
            tenBenhVien: args?['tenBenhVien'] ?? 'Bệnh viện Đa Khoa An Bình',
            loaiHinh: args?['loaiHinh'] ?? 'Bệnh viện Tư lập',
            coBhyt: args?['coBhyt'] ?? true,
            // Logic lấy hospitalUid an toàn và đầy đủ fallback
            hospitalUid: args?['hospitalUid'] ??
                args?['maBenhVien'] ??
                args?['extraData']?['ma_benh_vien'] ??
                args?['extraData']?['uid'],
            extraData: args?['extraData'],
          );
        },
        addClinic: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as String?;
          // Logic lấy benhVienId ưu tiên AppSession, fallback sang Firebase Auth
          final bvid = (args != null && args.isNotEmpty && args != 'dFmZHBjFNUT1eRzJjXp5')
              ? args
              : (AppSession.benhVienId.isNotEmpty 
                  ? AppSession.benhVienId 
                  : (FirebaseAuth.instance.currentUser?.uid ?? ''));
          
          // ⚠️ Đảm bảo class ThemKhoaScreen đã được import đúng ở đầu file
          return ThemKhoaScreen(benhVienId: bvid); 
        },
        staffManagement: (_) => const StaffManagementScreen(),
        nhanSuScreen: (_) => const HomeHospitalScreen(initialTabIndex: 2),
        phanCongScreen: (_) => const HomeHospitalScreen(initialTabIndex: 3),
        statistics: (_) => const StatisticsScreen(),
        adminDashboard: (_) => const AdminDashboard(),
      };
}
