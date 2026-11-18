import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/validators.dart';
import '../../config/app_routes.dart';
import '../../models/hospital_model.dart';
import '../../models/patient_model.dart';
import '../../providers/auth_provider.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _primary = Color(0xFF1E78E0);
  static const _danger = Color(0xFFE53935);
  static const _grey = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();

  // Controllers cho Bệnh nhân
  final _patientNameCtrl = TextEditingController();
  final _patientIdCtrl = TextEditingController();
  final _patientPassCtrl = TextEditingController();
  final _patientConfirmCtrl = TextEditingController();

  // Controllers cho Bệnh viện
  final _hospitalNameCtrl = TextEditingController();
  final _hospitalEmailCtrl = TextEditingController();
  final _hospitalAddressCtrl = TextEditingController();
  final _hospitalPassCtrl = TextEditingController();
  final _hospitalConfirmCtrl = TextEditingController();

  // ✅ Danh sách vai trò sẽ được load và LỌC từ Firebase
  List<Map<String, dynamic>> _roles = [];
  int _roleIndex = 0;
  bool _isLoadingRoles = true;

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _agreed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadRoles();
      }
    });
  }

  // ✅ Hàm load danh sách vai trò từ Firebase và CHỈ GIỮ LẠI 2 ROLE
  Future<void> _loadRoles() async {
    final auth = context.read<AuthProvider>();
    await auth.loadRoles();

    if (mounted) {
      setState(() {
        // 🛡️ LỌC: Chỉ giữ lại 'benh_nhan' và 'benh_vien'
        _roles = auth.roles.where((role) {
          final maVaiTro = role['ma_vai_tro'] as String?;
          return maVaiTro == 'benh_nhan' || maVaiTro == 'benh_vien';
        }).toList();

        _isLoadingRoles = false;

        // Nếu đã có selectedRole từ màn hình trước, tìm index tương ứng
        if (auth.selectedRole != null && _roles.isNotEmpty) {
          _roleIndex = _roles.indexWhere(
            (role) => role['ma_vai_tro'] == auth.selectedRole,
          );
          if (_roleIndex == -1)
            _roleIndex = 0; // Fallback về 0 nếu không tìm thấy
        }
      });
    }
  }

  @override
  void dispose() {
    _patientNameCtrl.dispose();
    _patientIdCtrl.dispose();
    _patientPassCtrl.dispose();
    _patientConfirmCtrl.dispose();
    _hospitalNameCtrl.dispose();
    _hospitalEmailCtrl.dispose();
    _hospitalAddressCtrl.dispose();
    _hospitalPassCtrl.dispose();
    _hospitalConfirmCtrl.dispose();
    super.dispose();
  }

  void _onRoleChanged(int index) {
    setState(() {
      _roleIndex = index;
      _obscure = true;
      _obscureConfirm = true;
    });
    final auth = context.read<AuthProvider>();
    auth.setSelectedRole(_roles[index]['ma_vai_tro']);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý với Điều khoản & chính sách'),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final currentRole = _roles[_roleIndex];
    final maVaiTro = currentRole['ma_vai_tro'];

    PatientModel? patient;
    HospitalModel? hospital;
    String emailOrPhone = '';
    String password = '';

    if (maVaiTro == 'benh_nhan') {
      final id = _patientIdCtrl.text.trim();
      emailOrPhone = id;
      password = _patientPassCtrl.text;

      patient = PatientModel(
        uid: '',
        hoTen: _patientNameCtrl.text.trim(),
        email: id.contains('@') ? id : null,
        soDienThoai: !id.contains('@') ? id : null,
        role: maVaiTro,
      );
    } else if (maVaiTro == 'benh_vien') {
      emailOrPhone = _hospitalEmailCtrl.text.trim();
      password = _hospitalPassCtrl.text;

      hospital = HospitalModel(
        tenBenhVien: _hospitalNameCtrl.text.trim(),
        diaChi: _hospitalAddressCtrl.text.trim(),
        email: _hospitalEmailCtrl.text.trim(),
        role: maVaiTro,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vai trò này chưa hỗ trợ đăng ký trực tiếp trên app.'),
        ),
      );
      return;
    }

    if (emailOrPhone.contains('@')) {
      try {
        if (hospital != null) {
          await auth.registerHospitalWithEmail(
            email: emailOrPhone,
            password: password,
            hospital: hospital,
          );
        } else {
          await auth.registerWithEmail(
            email: emailOrPhone,
            password: password,
            user: patient!,
          );
        }
        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          AppRoutes.emailVerification,
          arguments: emailOrPhone,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } else {
      if (patient == null) return;
      await auth.sendOtp(
        phone: emailOrPhone,
        onCodeSent: () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                phone: emailOrPhone,
                onVerify: (code) async {
                  try {
                    await auth.verifyOtpAndRegister(
                      smsCode: code,
                      user: patient!,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đăng ký thành công!')),
                    );
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (route) => false,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceAll('Exception: ', ''),
                        ),
                      ),
                    );
                  }
                },
                onResend: () => auth.sendOtp(
                  phone: emailOrPhone,
                  onCodeSent: () {},
                  onError: (msg) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
                  },
                ),
              ),
            ),
          );
        },
        onError: (msg) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        },
      );
    }
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c),
  );

  InputDecoration _decoration(IconData icon, String hint, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: _grey),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: _border(const Color(0xFFE2E8F0)),
        enabledBorder: _border(const Color(0xFFE2E8F0)),
        focusedBorder: _border(_primary),
        errorBorder: _border(_danger),
        focusedErrorBorder: _border(_danger),
      );

  Widget _label(String text, {bool required = false, String? note}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Color(0xFF0F172A),
        ),
        children: [
          if (required)
            const TextSpan(
              text: '  *',
              style: TextStyle(color: _danger),
            ),
          if (note != null)
            TextSpan(
              text: ' $note',
              style: const TextStyle(fontWeight: FontWeight.w400, color: _grey),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    if (_isLoadingRoles) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: _primary),
              const SizedBox(height: 16),
              Text(
                'Đang tải thông tin...',
                style: TextStyle(color: _grey, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final roleLabel = _roles.isNotEmpty
        ? _roles[_roleIndex]['ten_vai_tro'] ?? 'Vai trò'
        : 'Vai trò';
    final maVaiTro = _roles.isNotEmpty ? _roles[_roleIndex]['ma_vai_tro'] : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          maVaiTro == 'benh_nhan'
                              ? Icons.person
                              : Icons.local_hospital,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'MEDICONNECT',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                      Text(
                        'Đăng ký tài khoản $roleLabel',
                        style: const TextStyle(fontSize: 15, color: _grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ✅ Tabs vai trò
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: List.generate(_roles.length, (i) {
                      final active = i == _roleIndex;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onRoleChanged(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active ? _primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _roles[i]['ten_vai_tro'] ?? 'Vai trò',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: active ? Colors.white : _grey,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // ✅ CÁC Ô NHẬP LIỆU THAY ĐỔI THEO TAB
                if (maVaiTro == 'benh_nhan') ...[
                  _label('Họ và Tên', required: true),
                  TextFormField(
                    controller: _patientNameCtrl,
                    decoration: _decoration(
                      Icons.person_outline,
                      'Nguyễn Văn An',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập họ và tên'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  _label('Email hoặc số điện thoại', required: true),
                  TextFormField(
                    controller: _patientIdCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _decoration(
                      Icons.mail_outline,
                      'an.nguyen@gmail.com / 0912 345 678',
                    ),
                    // ✅ ĐÃ SỬA: Tích hợp hàm validateEmail
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) {
                        return 'Vui lòng nhập email hoặc số điện thoại';
                      }

                      if (value.contains('@')) {
                        return validateEmail(value);
                      }

                      return validatePhone(value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // ───────────────────────── Ô MẬT KHẨU ─────────────────────────
                  _label('Mật khẩu', required: true),
                  TextFormField(
                    controller: _patientPassCtrl,
                    obscureText: _obscure,
                    decoration: _decoration(
                      Icons.lock_outline,
                      'Nhập mật khẩu',
                      suffix: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: _grey,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: validatePassword,
                  ),
                  const SizedBox(height: 16),

                  // ───────────────────────── Ô NHẬP LẠI MẬT KHẨU ─────────────────────────
                  _label('Nhập lại mật khẩu', required: true),
                  TextFormField(
                    controller: _patientConfirmCtrl,
                    obscureText: _obscureConfirm,
                    decoration: _decoration(
                      Icons.lock_outline,
                      'Nhập lại mật khẩu',
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: _grey,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      final passwordError = validatePassword(v);
                      if (passwordError != null) {
                        return passwordError;
                      }
                      if (v != _patientPassCtrl.text) {
                        return 'Mật khẩu nhập lại không khớp';
                      }

                      return null; // Hợp lệ
                    },
                  ),
                ] else if (maVaiTro == 'benh_vien') ...[
                  _label('Tên bệnh viện / Cơ sở y tế', required: true),
                  TextFormField(
                    controller: _hospitalNameCtrl,
                    decoration: _decoration(
                      Icons.business_outlined,
                      'Bệnh viện Đa Khoa An Bình',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tên bệnh viện'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  _label('Email đại diện bệnh viện', required: true),
                  TextFormField(
                    controller: _hospitalEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _decoration(
                      Icons.mail_outline,
                      'admin@benhvien.vn',
                    ),
                    validator: (v) {
                      return validateEmail(v);
                    },
                  ),
                  const SizedBox(height: 16),

                  _label('Địa chỉ bệnh viện', required: true),
                  TextFormField(
                    controller: _hospitalAddressCtrl,
                    decoration: _decoration(
                      Icons.location_on_outlined,
                      'Số nhà, đường, phường/xã, tỉnh/thành phố',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập địa chỉ bệnh viện'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  _label('Mật khẩu', required: true),
                  TextFormField(
                    controller: _hospitalPassCtrl,
                    obscureText: _obscure,
                    decoration: _decoration(
                      Icons.lock_outline,
                      'Nhập mật khẩu',
                      suffix: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: _grey,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: validatePassword,
                  ),
                  const SizedBox(height: 16),

                  _label('Nhập lại mật khẩu', required: true),
                  TextFormField(
                    controller: _hospitalConfirmCtrl,
                    obscureText: _obscureConfirm,
                    decoration: _decoration(
                      Icons.lock_outline,
                      'Nhập lại mật khẩu',
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: _grey,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      final passwordError = validatePassword(v);
                      if (passwordError != null) return passwordError;
                      if (v != _hospitalPassCtrl.text)
                        return 'Mật khẩu nhập lại không khớp';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),

                // Điều khoản
                Row(
                  children: [
                    Checkbox(
                      value: _agreed,
                      activeColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'Đồng ý với ',
                          style: TextStyle(color: _grey, fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Điều khoản & chính sách',
                              style: TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: maVaiTro == 'benh_nhan'
                                  ? ' người dùng.'
                                  : ' cơ sở y tế.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Nút đăng ký
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
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
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Đăng Ký Tài Khoản $roleLabel',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 22),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text.rich(
                      TextSpan(
                        text: 'Đã có tài khoản? ',
                        style: TextStyle(color: _grey, fontSize: 15),
                        children: [
                          TextSpan(
                            text: 'Đăng nhập ngay',
                            style: TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
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
