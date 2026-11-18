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

const Map<String, IconData> _genderIcons = {
  'Nam': Icons.male_rounded,
  'Nữ': Icons.female_rounded,
  'Khác': Icons.transgender_rounded,
};

/// Truyền FamilyProfileModel? qua route arguments: null = thêm mới, có giá trị = chỉnh sửa.
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is FamilyProfileModel) {
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
  }

  @override
  void dispose() {
    _name.dispose();
    _cccd.dispose();
    _phone.dispose();
    super.dispose();
  }

  int _ageOf(DateTime d) {
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return age < 0 ? 0 : age;
  }

  String get _initials {
    final w =
        _name.text.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (w.isEmpty) return '?';
    if (w.length == 1) return w[0][0].toUpperCase();
    return '${w.first[0]}${w.last[0]}'.toUpperCase();
  }

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
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: _kPrimary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

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

  InputDecoration _dec(String label, {required IconData icon, String? hint}) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
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
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: b(_kBorder),
      enabledBorder: b(_kBorder),
      focusedBorder: b(_kPrimary, 1.6),
      errorBorder: b(const Color(0xFFDC2626)),
      focusedErrorBorder: b(const Color(0xFFDC2626), 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dobText = _dob == null
        ? 'Chọn ngày sinh *'
        : '${_dob!.day.toString().padLeft(2, '0')}/'
            '${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}'
            '  (${_ageOf(_dob!)} tuổi)';

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  _SectionCard(
                    title: 'Thông tin cơ bản',
                    icon: Icons.badge_rounded,
                    color: _kPrimary,
                    children: [
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _dec('Họ và tên *',
                            icon: Icons.person_rounded,
                            hint: 'Nhập họ tên đầy đủ'),
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
                        children: FamilyProfileModel.quanHeOptions
                            .map((r) => _SelectChip(
                                  label: r,
                                  icon: _relationIcons[r] ??
                                      Icons.person_outline_rounded,
                                  selected: _relation == r,
                                  onTap: () => setState(() => _relation = r),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel('Ngày sinh *'),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _pickDob,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _kBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cake_rounded,
                                  size: 20, color: _kPrimary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  dobText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _dob == null
                                        ? FontWeight.w400
                                        : FontWeight.w700,
                                    color: _dob == null ? _kHint : _kText,
                                  ),
                                ),
                              ),
                              const Icon(Icons.calendar_month_rounded,
                                  size: 20, color: _kHint),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel('Giới tính'),
                      const SizedBox(height: 10),
                      Row(
                        children: FamilyProfileModel.gioiTinhOptions
                            .map((g) => Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                        right: g ==
                                                FamilyProfileModel
                                                    .gioiTinhOptions.last
                                            ? 0
                                            : 8),
                                    child: _SelectChip(
                                      label: g,
                                      icon: _genderIcons[g] ??
                                          Icons.person_outline_rounded,
                                      selected: _gender == g,
                                      expand: true,
                                      onTap: () =>
                                          setState(() => _gender = g),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
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
                        decoration: _dec('Số CCCD / CMND',
                                icon: Icons.credit_card_rounded,
                                hint: '12 số (CMND cũ 9 số)')
                            .copyWith(counterText: ''),
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
                        decoration: _dec('Số điện thoại',
                                icon: Icons.phone_rounded,
                                hint: '10 số, bắt đầu bằng 0')
                            .copyWith(counterText: ''),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return null;
                          return RegExp(r'^0\d{9}$').hasMatch(s)
                              ? null
                              : 'Số điện thoại gồm 10 số, bắt đầu bằng 0';
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.lock_rounded, size: 14, color: _kHint),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Thông tin chỉ dùng để đặt lịch khám và được bảo mật theo quy định của pháp luật.',
                          style: TextStyle(
                              fontSize: 12, height: 1.45, color: _kHint),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ───────────── Đầu trang: gradient + avatar xem trước ─────────────
  Widget _buildHeader(BuildContext context) {
    Widget bubble(double s, double o) => Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: Colors.white.withOpacity(o)),
        );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), _kPrimaryDark, Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            Positioned(top: -50, right: -40, child: bubble(170, 0.09)),
            Positioned(bottom: -30, left: -50, child: bubble(130, 0.06)),
            Positioned(
              top: 70,
              left: 30,
              child: Icon(Icons.add_rounded,
                  size: 26, color: Colors.white.withOpacity(0.12)),
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
                              child: Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _isEdit
                                ? 'Sửa hồ sơ người thân'
                                : 'Thêm người thân',
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
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Color(0xFFDBEAFE)],
                        ),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.55), width: 4),
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
                            ? const Icon(Icons.person_rounded,
                                size: 40, color: _kPrimary)
                            : Text(
                                _initials,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: _kPrimary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_relationIcons[_relation] ?? Icons.person,
                              size: 15, color: Colors.white),
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
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
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : Icon(
                    _isEdit ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
                    size: 22),
            label: Text(
              _saving
                  ? 'Đang lưu...'
                  : (_isEdit ? 'Lưu thay đổi' : 'Thêm người thân'),
              style:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kPrimary.withOpacity(0.7),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Thành phần con ─────────────────────────

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
                    color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kText)),
              const Spacer(),
              if (trailing != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(trailing!,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kGrey)),
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: _kGrey),
      );
}

/// Ô chọn dạng "chip" có icon (dùng cho mối quan hệ và giới tính).
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
      color: selected ? _kPrimary.withOpacity(0.10) : const Color(0xFFF8FAFC),
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