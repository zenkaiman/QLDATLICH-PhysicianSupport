import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_snackbar.dart';

/// EditProfileScreen: form cập nhật thông tin cá nhân của bệnh nhân
/// (họ tên, giới tính, ngày sinh, CCCD, BHYT, số điện thoại, email, địa chỉ).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Bảng màu.
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryLight = Color(0xFFDBEAFE);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textGrey = Color(0xFF64748B);
  static const Color _hint = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _fieldFill = Color(0xFFF8FAFC);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cccdController = TextEditingController();
  final _bhytController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedGender = 'Nam';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    _cccdController.dispose();
    _bhytController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ───────────── Dữ liệu & logic ─────────────

  String _str(dynamic v) => (v ?? '').toString().trim();

  /// _readField: đọc một field của user qua [getter]; trả rỗng nếu model chưa có field đó
  /// (cccd và soBhyt là hai field thêm sau).
  String _readField(dynamic user, String Function(dynamic) getter) {
    try {
      return _str(getter(user));
    } catch (_) {
      return '';
    }
  }

  /// _loadUserData: điền sẵn form bằng thông tin người dùng hiện tại.
  void _loadUserData() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    _nameController.text = _str(user.hoTen);
    _selectedGender = _str(user.gioiTinh) == 'Nữ' ? 'Nữ' : 'Nam';
    _birthdayController.text =
        user.ngaySinh != null ? _formatDate(user.ngaySinh!) : '';
    _phoneController.text = _str(user.soDienThoai);
    _cccdController.text = _readField(user, (u) => u.cccd);
    _bhytController.text = _readField(user, (u) => u.soBhyt);
    _addressController.text = _str(user.diaChi);
    _emailController.text = _str(user.email);
  }

  /// _formatDate: DateTime -> "dd/MM/yyyy".
  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// _parseDate: "dd/MM/yyyy" -> DateTime (null nếu sai định dạng).
  DateTime? _parseDate(String text) {
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  /// _selectDate: mở hộp chọn ngày sinh và ghi vào ô ngày sinh.
  Future<void> _selectDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDate(_birthdayController.text) ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _birthdayController.text = _formatDate(picked));
    }
  }

  /// _saveProfile: kiểm tra form rồi lưu thông tin; thành công thì đóng màn hình.
  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      context.showAppSnackBar(
        message: 'Vui lòng kiểm tra lại các trường được đánh dấu',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().updateUserProfile(
        hoTen: _nameController.text.trim(),
        gioiTinh: _selectedGender,
        ngaySinh: _parseDate(_birthdayController.text),
        diaChi: _addressController.text.trim(),
        email: _emailController.text.trim(),
        soDienThoai: _phoneController.text.trim(),
        cccd: _cccdController.text.trim(),
        soBhyt: _bhytController.text.trim(),
      );

      if (!mounted) return;
      context.showAppSnackBar(
        title: 'Cập nhật thành công',
        message: 'Thông tin cá nhân của bạn đã được lưu.',
        type: SnackBarType.success,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      context.showAppSnackBar(
        title: 'Cập nhật thất bại',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────── Giao diện chính ─────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _buildIntroBanner(),
              const SizedBox(height: 18),
              _buildBasicSection(),
              const SizedBox(height: 16),
              _buildDocumentSection(),
              const SizedBox(height: 16),
              _buildContactSection(),
            ],
          ),
        ),
        bottomNavigationBar: _buildSaveBar(),
      ),
    );
  }

  /// _buildBasicSection: họ tên, giới tính, ngày sinh.
  Widget _buildBasicSection() {
    return _section(
      title: 'Thông tin cơ bản',
      icon: Icons.person_rounded,
      color: _primary,
      children: [
        _label('Họ và tên'),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: _decoration(
            hint: 'Nguyễn Văn An',
            icon: Icons.person_outline_rounded,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập họ tên';
            if (v.trim().length < 2) return 'Họ tên quá ngắn';
            return null;
          },
        ),
        const SizedBox(height: 18),
        _label('Giới tính'),
        Row(
          children: [
            Expanded(child: _genderButton('Nam', Icons.male_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _genderButton('Nữ', Icons.female_rounded)),
          ],
        ),
        const SizedBox(height: 18),
        _label('Ngày sinh'),
        GestureDetector(
          onTap: _selectDate,
          child: AbsorbPointer(
            child: TextFormField(
              controller: _birthdayController,
              decoration: _decoration(
                hint: 'DD/MM/YYYY',
                icon: Icons.cake_outlined,
                suffix: const Icon(Icons.expand_more_rounded, color: _primary),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng chọn ngày sinh'
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  /// _buildDocumentSection: CCCD/CMND và số thẻ BHYT (không bắt buộc, chỉ kiểm tra khi có nhập).
  Widget _buildDocumentSection() {
    return _section(
      title: 'Giấy tờ & bảo hiểm',
      icon: Icons.verified_user_rounded,
      color: const Color(0xFFF59E0B),
      children: [
        _label('CCCD / CMND', optional: true),
        TextFormField(
          controller: _cccdController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          decoration: _decoration(
            hint: '12 chữ số (hoặc 9 số với CMND)',
            icon: Icons.credit_card_rounded,
            accent: const Color(0xFFF59E0B),
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            if (t.length != 9 && t.length != 12) {
              return 'CCCD gồm 12 số, CMND gồm 9 số';
            }
            return null;
          },
        ),
        const SizedBox(height: 18),
        _label('Số thẻ BHYT', optional: true),
        TextFormField(
          controller: _bhytController,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(15),
            _UpperCaseFormatter(),
          ],
          decoration: _decoration(
            hint: 'VD: DN4797915012345',
            icon: Icons.health_and_safety_rounded,
            accent: _danger,
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            return t.length == 15 ? null : 'Số thẻ BHYT gồm 15 ký tự';
          },
        ),
        const SizedBox(height: 10),
        _note(
          Icons.lock_outline_rounded,
          'Thông tin giấy tờ chỉ dùng để xác minh khi khám và thanh toán BHYT.',
        ),
      ],
    );
  }

  /// _buildContactSection: số điện thoại, email, địa chỉ (đều bắt buộc).
  Widget _buildContactSection() {
    return _section(
      title: 'Thông tin liên hệ',
      icon: Icons.contact_phone_rounded,
      color: const Color(0xFF8B5CF6),
      children: [
        _label('Số điện thoại'),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: _decoration(
            hint: '0912345678',
            icon: Icons.phone_outlined,
            accent: const Color(0xFF8B5CF6),
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Vui lòng nhập số điện thoại';
            return RegExp(r'^0\d{9}$').hasMatch(t)
                ? null
                : 'Số điện thoại gồm 10 số, bắt đầu bằng 0';
          },
        ),
        const SizedBox(height: 18),
        _label('Email'),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: _decoration(
            hint: 'email@example.com',
            icon: Icons.email_outlined,
            accent: const Color(0xFF0EA5E9),
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Vui lòng nhập email';
            return RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(t)
                ? null
                : 'Email không hợp lệ';
          },
        ),
        const SizedBox(height: 18),
        _label('Địa chỉ'),
        TextFormField(
          controller: _addressController,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: _decoration(
            hint: 'Số nhà, đường, phường/xã, quận/huyện, tỉnh/thành phố',
            icon: Icons.location_on_outlined,
            accent: const Color(0xFFEC4899),
            topAlignIcon: true,
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Vui lòng nhập địa chỉ'
              : null,
        ),
      ],
    );
  }

  // ───────────── Thành phần giao diện ─────────────

  /// _buildAppBar: thanh tiêu đề trắng có nút quay lại.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: Material(
            color: _primaryLight,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _primary,
                  size: 17,
                ),
              ),
            ),
          ),
        ),
      ),
      title: const Text(
        'Thông tin bệnh nhân',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _textDark,
        ),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFEEF2F7)),
      ),
    );
  }

  /// _buildIntroBanner: khung giới thiệu ở đầu form.
  Widget _buildIntroBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.assignment_ind_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Thông tin chính xác giúp bệnh viện xác nhận lịch khám và tra cứu hồ sơ của bạn nhanh hơn.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// _section: thẻ nhóm gồm tiêu đề có icon và các ô nhập.
  Widget _section({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EBF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  /// _label: nhãn phía trên ô nhập; dấu * đỏ nếu bắt buộc, chip "Không bắt buộc" nếu [optional].
  Widget _label(String text, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          if (!optional)
            const Text(
              ' *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _danger,
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Không bắt buộc',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _textGrey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// _note: dòng ghi chú nhỏ có icon.
  Widget _note(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: _hint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, height: 1.4, color: _hint),
          ),
        ),
      ],
    );
  }

  /// _genderButton: nút chọn giới tính, có dấu tick khi đang chọn.
  Widget _genderButton(String gender, IconData icon) {
    final selected = _selectedGender == gender;

    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _primaryLight : _fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _primary : _border,
            width: selected ? 2 : 1.3,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? _primary : _textGrey, size: 22),
            const SizedBox(width: 8),
            Text(
              gender,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selected ? _primary : _textDark,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded, color: _primary, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  /// _decoration: kiểu ô nhập chung (icon nằm trong hộp màu [accent]).
  /// [topAlignIcon] đặt icon sát đầu ô (dùng cho ô nhiều dòng).
  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Color accent = _primary,
    Widget? suffix,
    bool topAlignIcon = false,
  }) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    final iconBox = Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: accent, size: 19),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hint, fontSize: 13.5),
      prefixIcon: topAlignIcon
          ? Align(
              alignment: Alignment.topCenter,
              widthFactor: 1,
              heightFactor: 1,
              child: iconBox,
            )
          : iconBox,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix != null
          ? Padding(padding: const EdgeInsets.only(right: 8), child: suffix)
          : null,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: border(_border, 1.3),
      enabledBorder: border(_border, 1.3),
      focusedBorder: border(_primary, 1.8),
      errorBorder: border(_danger, 1.3),
      focusedErrorBorder: border(_danger, 1.8),
      errorStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  /// _buildSaveBar: thanh cố định ở đáy gồm nút Hủy và nút Lưu thay đổi.
  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textGrey,
                    side: const BorderSide(color: _border, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveProfile,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 22),
                  label: Text(
                    _isLoading ? 'Đang lưu...' : 'Lưu thay đổi',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _success.withOpacity(0.6),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// _UpperCaseFormatter: tự động viết hoa chữ cái khi nhập (dùng cho số thẻ BHYT).
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}