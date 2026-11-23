import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';

import '../../config/app_routes.dart';
import '../../database_seeder.dart';
import '../../config/app_session.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../letan_c1/cskh_duyetdon_khoa_screen_c1.dart';
import '../letan_c1/letan_thietlap_thongtin_screen_c1.dart';
import '../letan_c1/letan_trangchu_screen_c1.dart';
import '../../support_doctor/clinic_firestore_service.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../config/staff_session.dart';
import 'otp_screen.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ✅ 1. THÊM _formKey
  final _formKey = GlobalKey<FormState>();

  static const _primary = Color(0xFF1E78E0);
  static const _danger = Color(0xFFE53935);
  static const _grey = Color(0xFF64748B);

  // ✅ 2. ĐỊNH NGHĨA CÁC DANH SÁCH ROLE CÒN THIẾU
  static const List<String> _roleLeTan = ['receptionist', 'le_tan'];
  static const List<String> _roleCskh = [
    'customerSupport',
    'cskh',
    'cham_soc_khach_hang'
  ];
  static const List<String> _roleBacSi = [
    'doctorAssistant',
    'ho_tro_bac_si',
    'bac_si'
  ];

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  int _selectedRoleIndex = 0;
  bool _obscure = true;
  bool _isPhone = false;

  final List<Map<String, dynamic>> _roles = [
    {'name': 'Bệnh nhân', 'icon': Icons.person_outline, 'code': 'benh_nhan'},
    {'name': 'Bệnh viện', 'icon': Icons.local_hospital, 'code': 'benh_vien'},
    {'name': 'Admin', 'icon': Icons.admin_panel_settings, 'code': 'admin'},
  ];

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool _isPhoneInput(String input) =>
      RegExp(r'^(\+84|0)\d{9}$').hasMatch(input.replaceAll(RegExp(r'\s+'), ''));

  void _onInputChanged() {
    final value = _isPhoneInput(_emailCtrl.text.trim());
    if (value != _isPhone) setState(() => _isPhone = value);
  }

  bool _isStaffRole(String role) =>
      _roleLeTan.contains(role) ||
      _roleCskh.contains(role) ||
      _roleBacSi.contains(role);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _danger),
    );
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ email và mật khẩu')),
      );
      return;
    }

    try {
      final auth = context.read<AuthProvider>();
      final selectedRoleCode = _roles[_selectedRoleIndex]['code'] as String;

      // 1. Xử lý đăng nhập bằng số điện thoại (Chỉ dành cho Bệnh nhân)
      if (_isPhoneInput(email)) {
        if (selectedRoleCode != 'benh_nhan') {
          throw Exception(
              'Đăng nhập bằng số điện thoại chỉ dành cho bệnh nhân. Vui lòng chọn tab Bệnh nhân.');
        }
        await _loginByPhone(email);
        return;
      }

      // 2. Ưu tiên kiểm tra đăng nhập NHÂN VIÊN Y TẾ (nếu không phải Admin)
      if (selectedRoleCode != 'admin') {
        Map<String, dynamic>? nhanVienData;
        try {
          nhanVienData = await FirebaseServiceC1.dangNhapNhanVien(
            taiKhoanHoacEmail: email,
            matKhau: password,
          );
        } catch (e) {
          final errStr = e.toString();
          if (errStr.contains('Mật khẩu không chính xác') ||
              errStr.contains('Mật khẩu cấp ban đầu không chính xác')) {
            rethrow;
          }
        }

        if (nhanVienData != null) {
          final role =
              (nhanVienData['role'] ?? nhanVienData['vai_tro'] ?? '').toString();
          final bool daKichHoat = (nhanVienData['da_kich_hoat'] == true) ||
              (nhanVienData['trang_thai'] == 'dang_hoat_dong');
          final maNvThucTe = (nhanVienData['ma_nhan_vien'] ??
                  nhanVienData['ma_tai_khoan'] ??
                  email)
              .toString();
          
          // ✅ 3. GIỮ LOGIC LINH HOẠT, TỰ ĐỘNG FALLBACK NHIỀU KEY KHÁC NHAU
          final bvId = (nhanVienData['ma_benh_vien'] ??
                  nhanVienData['benh_vien_id'] ??
                  nhanVienData['benhVienId'] ??
                  nhanVienData['hospital_id'] ??
                  nhanVienData['hospitalId'] ??
                  nhanVienData['id_benh_vien'] ??
                  'BV502') // Fallback cuối cùng an toàn
              .toString()
              .trim();
              
          final tenBv = (nhanVienData['ten_benh_vien'] ??
                  nhanVienData['tenBenhVien'] ??
                  nhanVienData['hospital_name'] ??
                  'Bệnh viện')
              .toString()
              .trim();

          DuLieuProfileMauC1.thongTinHienTai =
              DuLieuProfileMauC1.thongTinHienTai.copyWith(
            maNhanVien: maNvThucTe,
            hoTen: (nhanVienData['ho_ten'] ?? 'Nhân viên').toString(),
            chucVu: (nhanVienData['chuc_vu'] ??
                    (role.contains('cskh')
                        ? 'Chăm sóc khách hàng'
                        : 'Lễ tân tiếp đón'))
                .toString(),
            khoa: (nhanVienData['khoa'] ??
                    (role.contains('cskh')
                        ? 'Bộ Phận CSKH & Tiếp Nhận'
                        : 'Khoa Khám Bệnh'))
                .toString(),
            email: (nhanVienData['email'] ?? email).toString(),
            benhVienId: bvId,
            tenBenhVien: tenBv,
          );

          await FirebaseServiceC1.luuPhienDangNhap(
              taiKhoan: email, matKhau: password);
          if (!mounted) return;

          if (!daKichHoat) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      LetanThietlapThongtinScreenC1(maNhanVienMacDinh: maNvThucTe)),
            );
            return;
          }

          if (role == 'customerSupport' ||
              role == 'cskh' ||
              role == 'cham_soc_khach_hang') {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const CskhDuyetdonKhoaScreenC1()));
          } else if (role == 'receptionist' || role == 'le_tan') {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LeTanHomeScreenC1()));
          } else if (role == 'doctorAssistant' ||
              role == 'ho_tro_bac_si' ||
              role == 'bac_si') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => FirestoreClinicRoomPickerScreen(
                      hospitalId: bvId, hospitalName: tenBv)),
            );
          } else {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LeTanHomeScreenC1()));
          }
          return;
        }
      }

      // 4. Nếu KHÔNG PHẢI nhân viên -> Đăng nhập theo vai trò chuẩn
      if (selectedRoleCode == 'admin') {
        await auth.loginAdmin(email: email, password: password);
      } else {
        await auth.login(email: email, password: password, role: selectedRoleCode);
      }

      if (!mounted) return;

      // 5. Xử lý chuyển hướng sau khi đăng nhập chuẩn thành công
      if (selectedRoleCode == 'admin' && auth.admin != null) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.adminDashboard, (route) => false);
        return;
      }

      if (selectedRoleCode == 'benh_vien') {
        if (auth.hospital != null) {
          AppSession.benhVienId =
              auth.hospital?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.hospitalDashboard, (route) => false);
          return;
        } else {
          await auth.logout();
          throw Exception(
            'Tài khoản này chưa đăng ký là bệnh viện. '
            'Vui lòng đăng nhập ở tab Bệnh nhân hoặc đăng ký tài khoản bệnh viện.',
          );
        }
      }

      // 6. Xử lý trường hợp Bệnh nhân
      if (auth.user != null) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.patientMain, (route) => false, arguments: 0);
        return;
      }

      // 7. Fallback
      await auth.logout();
      final isHospital = auth.hospital != null;
      throw Exception(
        isHospital
            ? 'Đây là tài khoản bệnh viện. Vui lòng chọn tab Bệnh viện để đăng nhập.'
            : 'Không tìm thấy thông tin tài khoản phù hợp với vai trò đã chọn.',
      );
    } catch (e) {
      if (!mounted) return;

      String errorMessage = _loginErrorMessage(e);

      if (errorMessage.contains('EMAIL_NOT_VERIFIED')) {
        Navigator.pushReplacementNamed(context, AppRoutes.emailVerification,
            arguments: email);
        return;
      }

      _showError(errorMessage);
    }
  }

  void _goToPatientMain() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.patientMain,
      (route) => false,
      arguments: 0,
    );
  }

  Future<void> _loginByPhone(String phone) async {
    final auth = context.read<AuthProvider>();

    await auth.sendOtp(
      phone: phone,
      onCodeSent: () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              phone: phone,
              onVerify: (code) async {
                try {
                  await auth.loginWithPhoneOtp(smsCode: code);
                  if (!mounted) return;
                  _goToPatientMain();
                } catch (e) {
                  _showError(_loginErrorMessage(e));
                }
              },
              onResend: () => auth.sendOtp(
                phone: phone,
                onCodeSent: () {},
                onError: _showError,
              ),
            ),
          ),
        );
      },
      onError: _showError,
    );
  }

  Future<bool> _loginByStaffCode(String input, String password) async {
    final firestore = FirebaseFirestore.instance;

    DocumentSnapshot<Map<String, dynamic>> nhanVienDoc =
        await firestore.collection('NhanVien').doc(input).get();

    if (!nhanVienDoc.exists) {
      final q = await firestore
          .collection('NhanVien')
          .where('ma_tai_khoan', isEqualTo: input)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) nhanVienDoc = q.docs.first;
    }

    final upper = input.toUpperCase();
    if (!nhanVienDoc.exists && (upper == 'LT_TM_01' || upper == 'CSKH_01')) {
      if (password != '123456') {
        throw Exception('Mật khẩu cấp ban đầu không chính xác! (Mặc định: 123456)');
      }
      final isCskh = upper.contains('CSKH');
      await firestore.collection('NhanVien').doc(upper).set({
        'ma_tai_khoan': upper,
        'ma_nhan_vien': upper,
        'mat_khau': '123456',
        'ho_ten': isCskh ? 'Nhân Viên CSKH' : 'Đinh Hoàng Cước',
        'role': isCskh ? 'customerSupport' : 'receptionist',
        'khoa': 'KHOA TIM',
        'da_kich_hoat': false,
        'ngay_tao': FieldValue.serverTimestamp(),
      });
      nhanVienDoc = await firestore.collection('NhanVien').doc(upper).get();
    }

    if (!nhanVienDoc.exists) return false;

    final nvData = nhanVienDoc.data()!;
    if (nvData['mat_khau'] != null && nvData['mat_khau'] != password) {
      throw Exception('Mật khẩu không chính xác!');
    }

    return _enterStaffHome(
      data: nvData,
      defaultRole: 'receptionist',
      fallbackId: input,
      setupId: upper,
      requireStaffRole: false,
    );
  }

  Future<bool> _loginStaffByAccount(String currentUid, String email) async {
    final firestore = FirebaseFirestore.instance;

    DocumentSnapshot<Map<String, dynamic>> userDoc =
        await firestore.collection('NhanVien').doc(currentUid).get();

    if (userDoc.exists) {
      final maNvGoc =
          userDoc.data()?['ma_nhan_vien'] ?? userDoc.data()?['ma_tai_khoan'];
      if (maNvGoc != null &&
          maNvGoc.toString().isNotEmpty &&
          maNvGoc.toString() != currentUid) {
        final docGoc =
            await firestore.collection('NhanVien').doc(maNvGoc.toString()).get();
        if (docGoc.exists) userDoc = docGoc;
      }
    }

    if (!userDoc.exists || userDoc.data()?['role'] == null) {
      final qUid = await firestore
          .collection('NhanVien')
          .where('uid', isEqualTo: currentUid)
          .limit(1)
          .get();
      if (qUid.docs.isNotEmpty) userDoc = qUid.docs.first;
    }

    if (!userDoc.exists) {
      final q = await firestore
          .collection('NhanVien')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) userDoc = q.docs.first;
    }

    var fromUsers = false;
    if (!userDoc.exists) {
      userDoc = await firestore.collection('users').doc(currentUid).get();
      fromUsers = true;
    }

    if (!userDoc.exists) return false;

    final data = userDoc.data() ?? <String, dynamic>{};

    return _enterStaffHome(
      data: data,
      defaultRole: 'patient',
      fallbackId: currentUid,
      fallbackEmail: email,
      requireStaffRole: fromUsers,
    );
  }

  Future<bool> _enterStaffHome({
    required Map<String, dynamic> data,
    required String defaultRole,
    required String fallbackId,
    required bool requireStaffRole,
    String? setupId,
    String fallbackEmail = '',
  }) async {
    final role = (data['role'] ?? defaultRole).toString();

    if (requireStaffRole && !_isStaffRole(role)) return false;
    if (!mounted) return false;

    final maNvThucTe =
        (data['ma_nhan_vien'] ?? data['ma_tai_khoan'] ?? fallbackId).toString();

    if (data['da_kich_hoat'] != true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LetanThietlapThongtinScreenC1(
            maNhanVienMacDinh: setupId ?? maNvThucTe,
          ),
        ),
      );
      return true;
    }

    await StaffSession.save(maNvThucTe);

    final isLeTan = _roleLeTan.contains(role);
    DuLieuProfileMauC1.thongTinHienTai = DuLieuProfileMauC1.thongTinHienTai
        .copyWith(
      maNhanVien: maNvThucTe,
      hoTen: (data['ho_ten'] ?? 'Nhân viên').toString(),
      chucVu: (data['chuc_vu'] ??
              (isLeTan ? 'Lễ tân tiếp đón' : 'Chăm sóc khách hàng'))
          .toString(),
      khoa: (data['khoa'] ?? 'Khoa Khám Bệnh').toString(),
      email: (data['email'] ?? fallbackEmail).toString(),
    );

    // ✅ 4. SỬA TÊN CLASS ĐÚNG VỚI IMPORT
    final Widget? screen = isLeTan
        ? const LeTanHomeScreenC1()
        : _roleCskh.contains(role)
            ? const CskhDuyetdonKhoaScreenC1()
            : _roleBacSi.contains(role)
                ? FirestoreClinicRoomPickerScreen(
                    hospitalId: (data['benh_vien_id'] ?? 'BV502').toString(),
                    hospitalName: (data['ten_benh_vien'] ?? 'Bệnh viện').toString(),
                  )
                : null;

    if (screen == null) return false;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    return true;
  }

  String _loginErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
        case 'user-not-found':
          return 'Email không đúng hoặc chưa được đăng ký.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Mật khẩu không đúng.';
        case 'user-disabled':
          return 'Tài khoản này đã bị vô hiệu hóa.';
        case 'too-many-requests':
          return 'Bạn thử đăng nhập quá nhiều lần. Vui lòng thử lại sau.';
      }
    }
    return error.toString().replaceAll('Exception: ', '');
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: 1.5),
      );

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child:
                        const Icon(Icons.add, color: Colors.white, size: 50),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'MEDICONNECT',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hệ thống Y tế & Đặt lịch khám thông minh\nhàng đầu Việt Nam',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: _grey, height: 1.4),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: List.generate(_roles.length, (index) {
                    final isSelected = index == _selectedRoleIndex;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedRoleIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? _primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _roles[index]['icon'] as IconData,
                                size: 18,
                                color: isSelected ? Colors.white : _grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _roles[index]['name'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected ? Colors.white : _grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chức năng đang phát triển'),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.g_mobiledata,
                    color: _primary,
                    size: 24,
                  ),
                  label: const Text(
                    'Đăng nhập với Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: _grey.withOpacity(0.3))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'hoặc đăng nhập bằng tài khoản nội bộ',
                      style: TextStyle(fontSize: 13, color: _grey),
                    ),
                  ),
                  Expanded(child: Divider(color: _grey.withOpacity(0.3))),
                ],
              ),
              const SizedBox(height: 24),
              
              // ✅ 5. SỬ DỤNG _formKey ĐÃ KHAI BÁO
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final input = (value ?? '').trim();
                        if (input.isEmpty)
                          return 'Vui lòng nhập email hoặc số điện thoại';
                        if (input.contains('@')) return validateEmail(input);
                        if (_isPhoneInput(input)) return validatePhone(input);
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Email Hoặc Số điện thoại',
                        prefixIcon: Icon(
                          _isPhone ? Icons.phone_outlined : Icons.email_outlined,
                          color: _grey,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: _border(const Color(0xFFE2E8F0)),
                        enabledBorder: _border(const Color(0xFFE2E8F0)),
                        focusedBorder: _border(_primary),
                        errorBorder: _border(_danger),
                        focusedErrorBorder: _border(_danger),
                      ),
                    ),
                    if (!_isPhone) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập mật khẩu';
                          }
                          if (value.trim().length < 6) {
                            return 'Mật khẩu phải có ít nhất 6 ký tự';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Mật khẩu',
                          prefixIcon:
                              const Icon(Icons.lock_outline, color: _grey),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                              color: _grey,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: _border(const Color(0xFFE2E8F0)),
                          enabledBorder: _border(const Color(0xFFE2E8F0)),
                          focusedBorder: _border(_primary),
                          errorBorder: _border(_danger),
                          focusedErrorBorder: _border(_danger),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isPhone)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bạn sẽ nhận mã OTP qua SMS để đăng nhập.',
                      style: TextStyle(fontSize: 13, color: _grey),
                    ),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.forgotPassword,
                      arguments: _emailCtrl.text.trim(),
                    ),
                    child: const Text(
                      'Quên mật khẩu?',
                      style: TextStyle(
                        fontSize: 14,
                        color: _primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isPhone ? 'Gửi mã OTP' : 'Đăng nhập',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.register),
                child: const Text(
                  'Đăng ký tài khoản mới',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _danger,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, color: _danger, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Hotline hỗ trợ 24/7: 1900 6868',
                      style: TextStyle(
                        color: _danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}