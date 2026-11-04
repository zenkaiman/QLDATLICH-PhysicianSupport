import 'package:flutter/material.dart';

import '../screens/admin/admin_dashboard.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/customer_support/chat_list_screen.dart';
import '../screens/customer_support/support_home_screen.dart';
import '../screens/customer_support/ticket_screen.dart';
import '../screens/doctor_assistant/assistant_home_screen.dart';
import '../screens/doctor_assistant/patient_queue_screen.dart';
import '../screens/doctor_assistant/update_record_screen.dart';
import '../screens/hospital/hospital_dashboard.dart';
import '../screens/hospital/statistics_screen.dart';
import '../screens/hospital/staff_management_screen.dart';
import '../screens/patient/book_appointment_screen.dart';
import '../screens/patient/medical_history_screen.dart';
import '../screens/patient/my_appointments_screen.dart';
import '../screens/patient/patient_home_screen.dart';
import '../screens/receptionist/appointment_list_screen.dart';
import '../screens/receptionist/check_in_screen.dart';
import '../screens/receptionist/receptionist_home_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String roleSelection = '/role-selection';

  static const String patientHome = '/patient-home';
  static const String bookAppointment = '/book-appointment';
  static const String myAppointments = '/my-appointments';
  static const String medicalHistory = '/medical-history';

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
  static const String staffManagement = '/staff-management';
  static const String statistics = '/statistics';

  static const String adminDashboard = '/admin-dashboard';

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        roleSelection: (_) => const RoleSelectionScreen(),
        patientHome: (_) => const PatientHomeScreen(),
        bookAppointment: (_) => const BookAppointmentScreen(),
        myAppointments: (_) => const MyAppointmentsScreen(),
        medicalHistory: (_) => const MedicalHistoryScreen(),
        receptionistHome: (_) => const ReceptionistHomeScreen(),
        checkIn: (_) => const CheckInScreen(),
        appointmentList: (_) => const AppointmentListScreen(),
        assistantHome: (_) => const AssistantHomeScreen(),
        patientQueue: (_) => const PatientQueueScreen(),
        updateRecord: (_) => const UpdateRecordScreen(),
        supportHome: (_) => const SupportHomeScreen(),
        chatList: (_) => const ChatListScreen(),
        ticket: (_) => const TicketScreen(),
        hospitalDashboard: (_) => const HospitalDashboard(),
        staffManagement: (_) => const StaffManagementScreen(),
        statistics: (_) => const StatisticsScreen(),
        adminDashboard: (_) => const AdminDashboard(),
      };
}
