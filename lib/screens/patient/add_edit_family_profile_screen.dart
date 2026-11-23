import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/family_profile_model.dart';
import '../../providers/family_profile_provider.dart';
import '../../utils/app_snackbar.dart';

const Color _kPrimary = Color(0xFF2563EB);
const Color _kPrimaryDark = Color(0xFF1E40AF);
const Color _kBg = Color(0xFFF4F7FB);
const Color _kText = Color(0xFF0F172A);
const Color _kGrey = Color(0xFF64748B);
const Color _kHint = Color(0xFF94A3B8);
const Color _kBorder = Color(0xFFE6EBF2);
const Color _kDanger = Color(0xFFDC2626);
const Color _kFieldFill = Color(0xFFF8FAFC);

/// Icon theo mối quan hệ với người dùng.
const Map<String, IconData> _relationIcons = {
  'Bố': Icons.man_rounded,
  'Mẹ': Icons.woman_rounded,
  'Con': Icons.child_care_rounded,
  'Vợ': Icons.favorite_rounded,
  'Chồng': Icons.favorite_border_rounded,
  'Anh/Chị/Em': Icons.people_alt_rounded,
  'Ông/Bà': Icons.elderly_rounded,
  'Khác': Icons.person_outline_rounded,
};

/// Icon theo giới tính.
const Map<String, IconData> _genderIcons = {
  'Nam': Icons.male_rounded,
  'Nữ': Icons.female_rounded,
  'Khác': Icons.transgender_rounded,
};

/// AddEditFamilyProfileScreen: form thêm hoặc sửa hồ sơ người thân.
/// Route arguments là [FamilyProfileModel]: có giá trị thì sửa, null thì thêm mới.
class AddEditFamilyProfileScreen extends StatefulWidget {
  const AddEditFamilyProfileScreen({super.key});

  @override
  State<AddEditFamilyProfileScreen> createState() =>
      _AddEditFamilyProfileScreenState();
}

class _AddEditFamilyProfileScreenState
    extends State<AddEditFamilyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cccd = TextEditingController();
  final _phone = TextEditingController();

  FamilyProfileModel? _editing;
  DateTime? _dob;
  String _gender = '';
  String _relation = FamilyProfileModel.quanHeOptions.first;
  bool _saving = false;
  bool _initialized = false;

  bool get _isEdit => _editing != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {})); // cập nhật avatar xem trước
  }

  /// didChangeDependencies: nạp dữ liệu hồ sơ cần sửa từ route arguments (chỉ một lần).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! FamilyProfileModel) return;

    _editing = args;
    _name.text = args.hoTen;
    _cccd.text = args.soCccd;
    _phone.text = args.soDienThoai;
    _dob = args.ngaySinh;
    _gender = args.gioiTinh;
    if (FamilyProfileModel.quanHeOptions.contains(args.quanHe)) {
      _relation = args.quanHe;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _cccd.dispose();
    _phone.dispose();
    super.dispose();
  }

  // ───────────── Logic ─────────────

  /// _ageOf: tính tuổi theo ngày sinh.
  int _ageOf(DateTime d) {
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return age < 0 ? 0 : age;
  }

  /// _initials: chữ cái đầu của từ đầu và từ cuối trong họ tên (hiện trên avatar).
  String get _initials {
    final words = _name.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  /// _dobText: chuỗi ngày sinh "dd/MM/yyyy (n tuổi)" hoặc lời nhắc chọn.
  String get _dobText {
    final d = _dob;
    if (d == null) return 'Chọn ngày sinh *';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}  (${_ageOf(d)} tuổi)';
  }

  /// _pickDob: mở hộp chọn ngày sinh.
  Future<void> _pickDob() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: _kPrimary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  /// _save: kiểm tra form rồi thêm mới hoặc cập nhật hồ sơ; xong thì đóng màn (trả true).
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      context.showAppSnackBar(
        message: 'Vui lòng chọn ngày sinh',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<FamilyProfileProvider>();
    try {
      final model = FamilyProfileModel(
        id: _editing?.id ?? '',
        hoTen: _name.text.trim(),
        ngaySinh: _dob,
        gioiTinh: _gender,
        soCccd: _cccd.text.trim(),
        soDienThoai: _phone.text.trim(),
        quanHe: _relation,
        anhDaiDien: _editing?.anhDaiDien ?? '',
        isDefault: _editing?.isDefault ?? false,
      );
      if (_isEdit) {
        await provider.update(model);
      } else {
        await provider.add(model);
      }

      if (!mounted) return;
      context.showAppSnackBar(
        message: _isEdit ? 'Đã cập nhật hồ sơ' : 'Đã thêm người thân',
        type: SnackBarType.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showAppSnackBar(
        message: 'Lưu thất bại: $e',
        type: SnackBarType.error,
      );
    }
  }

  // ───────────── Giao diện ─────────────

  /// _dec: kiểu viền, màu và icon chung cho các ô nhập.
  InputDecoration _dec(String label, {required IconData icon, String? hint}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _kGrey, fontSize: 14),
      hintStyle: const TextStyle(color: _kHint, fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: _kPrimary),
      filled: true,
      fillColor: _kFieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(_kBorder),
      enabledBorder: border(_kBorder),
      focusedBorder: border(_kPrimary, 1.6),
      errorBorder: border(_kDanger),
      focusedErrorBorder: border(_kDanger, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  _buildBasicSection(),
                  const SizedBox(height: 16),
                  _buildContactSection(),
                  const SizedBox(height: 16),
                  _buildPrivacyNote(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  /// _buildBasicSection: họ tên, mối quan hệ, ngày sinh, giới tính.
  Widget _buildBasicSection() {
    final genders = FamilyProfileModel.gioiTinhOptions;

    return _SectionCard(
      title: 'Thông tin cơ bản',
      icon: Icons.badge_rounded,
      color: _kPrimary,
      children: [
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: _dec(
            'Họ và tên *',
            icon: Icons.person_rounded,
            hint: 'Nhập họ tên đầy đủ',
          ),
          validator: (v) => (v == null || v.trim().length < 2)
              ? 'Vui lòng nhập họ tên'
              : null,
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Mối quan hệ với bạn *'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in FamilyProfileModel.quanHeOptions)
              _SelectChip(
                label: r,
                icon: _relationIcons[r] ?? Icons.person_outline_rounded,
                selected: _relation == r,
                onTap: () => setState(() => _relation = r),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Ngày sinh *'),
        const SizedBox(height: 10),
        _buildDobField(),
        const SizedBox(height: 18),
        const _FieldLabel('Giới tính'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final g in genders)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: g == genders.last ? 0 : 8),
                  child: _SelectChip(
                    label: g,
                    icon: _genderIcons[g] ?? Icons.person_outline_rounded,
                    selected: _gender == g,
                    expand: true,
                    onTap: () => setState(() => _gender = g),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// _buildDobField: ô bấm để mở hộp chọn ngày sinh.
  Widget _buildDobField() {
    final empty = _dob == null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickDob,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_rounded, size: 20, color: _kPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _dobText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: empty ? FontWeight.w400 : FontWeight.w700,
                  color: empty ? _kHint : _kText,
                ),
              ),
            ),
            const Icon(Icons.calendar_month_rounded, size: 20, color: _kHint),
          ],
        ),
      ),
    );
  }

  /// _buildContactSection: CCCD/CMND và số điện thoại (không bắt buộc, chỉ kiểm tra khi có nhập).
  Widget _buildContactSection() {
    return _SectionCard(
      title: 'Giấy tờ & liên hệ',
      icon: Icons.contact_phone_rounded,
      color: const Color(0xFF8B5CF6),
      trailing: 'Tùy chọn',
      children: [
        TextFormField(
          controller: _cccd,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          maxLength: 12,
          decoration: _dec(
            'Số CCCD / CMND',
            icon: Icons.credit_card_rounded,
            hint: '12 số (CMND cũ 9 số)',
          ).copyWith(counterText: ''),
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return null;
            return RegExp(r'^\d{9}$|^\d{12}$').hasMatch(s)
                ? null
                : 'CCCD gồm 12 số (CMND cũ 9 số)';
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          maxLength: 10,
          decoration: _dec(
            'Số điện thoại',
            icon: Icons.phone_rounded,
            hint: '10 số, bắt đầu bằng 0',
          ).copyWith(counterText: ''),
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return null;
            return RegExp(r'^0\d{9}$').hasMatch(s)
                ? null
                : 'Số điện thoại gồm 10 số, bắt đầu bằng 0';
          },
        ),
      ],
    );
  }

  /// _buildPrivacyNote: dòng cam kết bảo mật thông tin.
  Widget _buildPrivacyNote() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_rounded, size: 14, color: _kHint),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Thông tin chỉ dùng để đặt lịch khám và được bảo mật theo quy định của pháp luật.',
            style: TextStyle(fontSize: 12, height: 1.45, color: _kHint),
          ),
        ),
      ],
    );
  }

  /// _buildHeader: đầu trang gồm nút quay lại, tiêu đề, avatar chữ cái xem trước
  /// và nhãn mối quan hệ đang chọn.
  Widget _buildHeader() {
    Widget bubble(double size, double opacity) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );

    const radius = BorderRadius.vertical(bottom: Radius.circular(32));

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), _kPrimaryDark, Color(0xFF3B82F6)],
        ),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(top: -50, right: -40, child: bubble(170, 0.09)),
            Positioned(bottom: -30, left: -50, child: bubble(130, 0.06)),
            Positioned(
              top: 70,
              left: 30,
              child: Icon(
                Icons.add_rounded,
                size: 26,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.white.withOpacity(0.18),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.maybePop(context),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _isEdit ? 'Sửa hồ sơ người thân' : 'Thêm người thân',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPreviewAvatar(),
                    const SizedBox(height: 10),
                    _buildRelationBadge(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// _buildPreviewAvatar: avatar tròn hiện chữ cái đầu của tên (icon người nếu chưa nhập).
  Widget _buildPreviewAvatar() {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFDBEAFE)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: _name.text.trim().isEmpty
            ? const Icon(Icons.person_rounded, size: 40, color: _kPrimary)
            : Text(
                _initials,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _kPrimary,
                ),
              ),
      ),
    );
  }

  /// _buildRelationBadge: nhãn "Người thân: ..." theo mối quan hệ đang chọn.
  Widget _buildRelationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _relationIcons[_relation] ?? Icons.person,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            'Người thân: $_relation',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// _buildBottomBar: nút Lưu / Thêm cố định ở đáy (hiện vòng xoay khi đang lưu).
  Widget _buildBottomBar() {
    final label = _saving
        ? 'Đang lưu...'
        : (_isEdit ? 'Lưu thay đổi' : 'Thêm người thân');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _kBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isEdit
                        ? Icons.check_rounded
                        : Icons.person_add_alt_1_rounded,
                    size: 22,
                  ),
            label: Text(
              label,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kPrimary.withOpacity(0.7),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// _SectionCard: thẻ nhóm có thanh màu, icon, tiêu đề, nhãn phụ (tùy chọn) và nội dung.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder),
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
                  color: _kText,
                ),
              ),
              const Spacer(),
              if (trailing != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trailing!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kGrey,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// _FieldLabel: nhãn nhỏ phía trên một nhóm lựa chọn.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: _kGrey,
    ),
  );
}

/// _SelectChip: ô chọn dạng chip có icon (dùng cho mối quan hệ và giới tính).
/// [expand] = true thì chip giãn đều theo chiều ngang.
class _SelectChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool expand;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kPrimary.withOpacity(0.10) : _kFieldFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _kPrimary : _kBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? _kPrimary : _kGrey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? _kPrimary : _kText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}