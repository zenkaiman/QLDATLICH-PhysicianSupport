import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../config/app_session.dart';
import '../../services/nhan_vien_service.dart';
import 'addKhoaHospital_Screen.dart';
import 'danhSachTaiKhoanDaTao_Screen.dart';

class CapTaiKhoanNhanVienScreen extends StatefulWidget {
  final String? benhVienId;
  const CapTaiKhoanNhanVienScreen({super.key, this.benhVienId});

  @override
  State<CapTaiKhoanNhanVienScreen> createState() =>
      _CapTaiKhoanNhanVienScreenState();
}

class _CapTaiKhoanNhanVienScreenState extends State<CapTaiKhoanNhanVienScreen> {
  static const _blue = Color(0xFF2F83FF);
  final NhanVienService _nhanVienService = NhanVienService();

  // Danh sách khoa được tải trực tiếp từ Firestore (hoàn toàn không hardcode)
  List<String> _departments = [];
  bool _isLoadingDepartments = true;

  String? _selectedDepartment;
  _StaffRole _selectedRole = _StaffRole.receptionist;
  int _accountCount = 5;
  bool _isLoading = false;

  String _getBenhVienId() {
    if (widget.benhVienId != null && widget.benhVienId!.isNotEmpty) {
      return widget.benhVienId!;
    }
    if (AppSession.benhVienId.isNotEmpty) {
      return AppSession.benhVienId;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDepartments = true);
    final bvid = _getBenhVienId();
    final list = await _nhanVienService.layDanhSachKhoaDaTao(bvid);
    if (mounted) {
      setState(() {
        _departments = list;
        _isLoadingDepartments = false;
        if (_departments.isNotEmpty) {
          // Nếu khoa đang chọn vẫn có trong danh sách mới thì giữ nguyên, ngược lại chọn khoa đầu tiên
          if (_selectedDepartment == null ||
              !_departments.contains(_selectedDepartment)) {
            _selectedDepartment = _departments.first;
          }
        } else {
          _selectedDepartment = null;
        }
      });
    }
  }

  Future<void> _selectDepartment() async {
    if (_departments.isEmpty) {
      final themMoi = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chưa có khoa khám nào'),
          content: const Text(
            'Hệ thống chưa tìm thấy khoa khám nào đã được tạo cho bệnh viện. Bạn có muốn thêm khoa khám mới ngay bây giờ không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Để sau'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Thêm khoa ngay'),
            ),
          ],
        ),
      );

      if (themMoi == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ThemKhoaScreen(benhVienId: _getBenhVienId()),
          ),
        );
        if (mounted) {
          _loadDepartments();
        }
      }
      return;
    }

    final department = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Chọn khoa làm việc',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _departments
                      .map(
                        (department) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            department,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: department == _selectedDepartment
                              ? const Icon(Icons.check_circle, color: _blue)
                              : const Icon(
                                  Icons.radio_button_unchecked,
                                  color: Color(0xFFB8C0CC),
                                ),
                          onTap: () => Navigator.pop(context, department),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (department != null) {
      setState(() => _selectedDepartment = department);
    }
  }

  void _changeCount(int amount) {
    setState(() {
      _accountCount = (_accountCount + amount).clamp(1, 99);
    });
  }

  String _getDepartmentCode(String dept) {
    final lower = dept.toLowerCase();
    if (lower.contains('tim')) return 'TM';
    if (lower.contains('mắt') || lower.contains('mat')) return 'MT';
    if (lower.contains('nhi')) return 'NH';
    if (lower.contains('răng') || lower.contains('rang')) return 'RHM';
    if (lower.contains('cấp cứu') || lower.contains('cap cuu')) return 'CC';
    if (lower.contains('hô hấp') || lower.contains('ho hap')) return 'HH';
    if (lower.contains('sản') || lower.contains('san')) return 'PS';
    if (lower.contains('ngoại') || lower.contains('ngoai')) return 'NG';
    if (lower.contains('nội') || lower.contains('noi')) return 'NOI';
    if (lower.contains('ung bướu') || lower.contains('ung buou')) return 'UB';
    if (lower.contains('tai mũi họng')) return 'TMH';
    if (lower.contains('da liễu') || lower.contains('da lieu')) return 'DL';
    if (lower.contains('xét nghiệm') || lower.contains('xet nghiem'))
      return 'XN';

    // Rút gọn theo chữ cái đầu
    final words = dept
        .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '')
        .split(' ')
        .where((w) => w.isNotEmpty && w.toLowerCase() != 'khoa')
        .toList();

    if (words.isNotEmpty) {
      final code = words.map((w) => w[0].toUpperCase()).join();
      return code.length > 4 ? code.substring(0, 4) : code;
    }

    return 'KHOA';
  }

  String _getRolePrefix(_StaffRole role) {
    switch (role) {
      case _StaffRole.receptionist:
        return 'LT';
      case _StaffRole.doctorAssistant:
        return 'BS';
      case _StaffRole.customerSupport:
        return 'CSKH';
    }
  }

  String _getRoleCode(_StaffRole role) {
    switch (role) {
      case _StaffRole.receptionist:
        return 'receptionist';
      case _StaffRole.doctorAssistant:
        return 'doctorAssistant';
      case _StaffRole.customerSupport:
        return 'customerSupport';
    }
  }

  Future<void> _taoTaiKhoan() async {
    if (_departments.isEmpty ||
        _selectedDepartment == null ||
        _selectedDepartment!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bệnh viện chưa có khoa khám nào được tạo. Vui lòng thêm khoa trước!',
          ),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final deptShort = _getDepartmentCode(_selectedDepartment!);
      final rolePrefix = _getRolePrefix(_selectedRole);
      final roleCode = _getRoleCode(_selectedRole);

      // Cấp tài khoản qua service và lưu đồng loạt lên Firebase Firestore
      final dotMoi = await _nhanVienService.taoVaLuuNhanVien(
        benhVienId: _getBenhVienId(),
        tenKhoa: _selectedDepartment!,
        deptCode: deptShort,
        vaiTro: _selectedRole.title,
        rolePrefix: rolePrefix,
        roleCode: roleCode,
        soLuong: _accountCount,
        matKhau: StaffAccountStore.matKhauMacDinh,
      );

      StaffAccountStore.luuDotCap(dotMoi);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã tạo thành công $_accountCount tài khoản cho ${_selectedDepartment!}!',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DanhSachTaiKhoanDaTaoScreen(
            benhVienId: _getBenhVienId(),
            tenKhoa: dotMoi.tenKhoa,
            vaiTro: dotMoi.vaiTro,
            soLuong: dotMoi.soLuong,
            danhSachTaiKhoan: dotMoi.danhSachTaiKhoan,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tạo tài khoản: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(
                          'Chọn khoa làm việc',
                          required: true,
                        ),
                        const SizedBox(height: 6),
                        _buildDepartmentSelector(),
                        const SizedBox(height: 12),
                        _buildRoleHeader(),
                        const SizedBox(height: 7),
                        for (final role in _StaffRole.values) ...[
                          _buildRoleCard(role),
                          const SizedBox(height: 7),
                        ],
                        const SizedBox(height: 3),
                        _buildSectionLabel(
                          'Số lượng tài khoản',
                          required: true,
                        ),
                        const SizedBox(height: 7),
                        _buildCounter(),
                        const SizedBox(height: 9),
                        _buildPresets(),
                        const SizedBox(height: 10),
                        _buildPolicy(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_departments.isEmpty
                                ? () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ThemKhoaScreen(
                                          benhVienId: _getBenhVienId(),
                                        ),
                                      ),
                                    );
                                    if (mounted) _loadDepartments();
                                  }
                                : _taoTaiKhoan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _departments.isEmpty
                            ? const Color(0xFF0284C7)
                            : _blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _departments.isEmpty
                                  ? 'Tạo Khoa Mới Trước'
                                  : 'Tạo $_accountCount Tài Khoản Nhân Viên',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
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

  Widget _buildHeader() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EBEF))),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'Cấp Tài Khoản Nhân Viên',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF0F1F3),
                minimumSize: const Size(32, 32),
                maximumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFF171A1F),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: '  *',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
        ],
      ),
    );
  }

  Widget _buildDepartmentSelector() {
    String textHienThi;
    Color textColor;
    if (_isLoadingDepartments) {
      textHienThi = 'Đang tải danh sách khoa đã tạo...';
      textColor = const Color(0xFF858B94);
    } else if (_departments.isEmpty) {
      textHienThi = 'Chưa có khoa nào (Nhấn để thêm khoa)';
      textColor = const Color(0xFFEF4444);
    } else {
      textHienThi = _selectedDepartment ?? 'Chọn khoa làm việc';
      textColor = _selectedDepartment == null
          ? const Color(0xFF858B94)
          : const Color(0xFF252A32);
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _selectDepartment,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(
              color: _departments.isEmpty && !_isLoadingDepartments
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFD9DDE3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                color: _departments.isEmpty && !_isLoadingDepartments
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF9AA1AA),
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  textHienThi,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: _selectedDepartment != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (_isLoadingDepartments)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  _departments.isEmpty
                      ? Icons.add_circle_outline
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF9299A3),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleHeader() {
    return Row(
      children: [
        Expanded(child: _buildSectionLabel('Chọn vai trò', required: true)),
        const Text(
          'Phân quyền ca\ntrực',
          textAlign: TextAlign.right,
          style: TextStyle(color: Color(0xFF9AA1AA), fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildRoleCard(_StaffRole role) {
    final selected = _selectedRole == role;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF3FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _blue : const Color(0xFFD9DDE3),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 33,
                height: 33,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFD5E8FF)
                      : const Color(0xFFF0F1F3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  role.icon,
                  color: selected
                      ? const Color(0xFF3388F5)
                      : const Color(0xFF7B838E),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.title,
                      style: const TextStyle(
                        color: Color(0xFF252A32),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role.description,
                      style: const TextStyle(
                        color: Color(0xFF858B94),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? _blue : const Color(0xFFC6CBD2),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounter() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9DDE3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _CounterButton(
            icon: Icons.remove,
            onPressed: _accountCount > 1 ? () => _changeCount(-1) : null,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_accountCount',
                  style: const TextStyle(
                    color: _blue,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'tài khoản',
                  style: TextStyle(color: Color(0xFF858B94), fontSize: 9),
                ),
              ],
            ),
          ),
          _CounterButton(
            icon: Icons.add,
            onPressed: _accountCount < 99 ? () => _changeCount(1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    return Row(
      children: [
        _PresetButton(label: '+1 acc', onTap: () => _changeCount(1)),
        const SizedBox(width: 7),
        _PresetButton(
          label: '+5 acc',
          selected: true,
          onTap: () => _changeCount(5),
        ),
        const SizedBox(width: 7),
        _PresetButton(label: '+10 acc', onTap: () => _changeCount(10)),
      ],
    );
  }

  Widget _buildPolicy() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFD0D5DD),
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quy chuẩn cấp phát:',
            style: TextStyle(
              color: Color(0xFF252A32),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Mật khẩu khởi tạo chung cho tất cả tài khoản: ${StaffAccountStore.matKhauMacDinh}. Nhân viên đổi mật khẩu ở lần đăng nhập đầu tiên.',
            style: const TextStyle(
              color: Color(0xFF737B86),
              fontSize: 9.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

enum _StaffRole {
  receptionist(
    title: 'Lễ tân',
    description: 'Quét QR, tiếp nhận bệnh nhân',
    icon: Icons.people_alt_outlined,
  ),
  doctorAssistant(
    title: 'Support',
    description: 'Hồ sơ, điều phối khám',
    icon: Icons.person_outline_rounded,
  ),
  customerSupport(
    title: 'CSKH',
    description: 'Đặt lịch hẹn, hỗ trợ bệnh nhân',
    icon: Icons.support_agent_rounded,
  );

  const _StaffRole({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: double.infinity,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        color: const Color(0xFF606873),
        disabledColor: const Color(0xFFC6CBD2),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 31,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: selected
                ? const Color(0xFF2679EE)
                : const Color(0xFF656D78),
            backgroundColor: selected ? const Color(0xFFEAF3FF) : Colors.white,
            side: BorderSide(
              color: selected
                  ? _CapTaiKhoanNhanVienScreenState._blue
                  : const Color(0xFFD9DDE3),
            ),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
