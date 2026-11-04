enum Role {
  patient,
  receptionist,
  doctorAssistant,
  customerSupport,
  hospital,
  admin,
}

class AppConstants {
  static const String usersCollection = 'users';
  static const String appointmentsCollection = 'appointments';
  static const String medicalRecordsCollection = 'medical_records';
  static const String doctorsCollection = 'doctors';
  static const String hospitalsCollection = 'hospitals';
  static const String chatsCollection = 'chats';

  static const Map<Role, String> roleNames = {
    Role.patient: 'Bệnh nhân',
    Role.receptionist: 'Lễ tân',
    Role.doctorAssistant: 'Hỗ trợ bác sĩ',
    Role.customerSupport: 'CSKH',
    Role.hospital: 'Bệnh viện',
    Role.admin: 'Quản trị viên',
  };
}
