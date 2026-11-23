import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/admin_store.dart';
import '../widgets/shared_widgets.dart';

// ================= MÀN 11: SỬA THÔNG TIN BỆNH VIỆN =================
class EditHospitalScreen extends StatefulWidget {
  final Hospital hospital;
  const EditHospitalScreen({super.key, required this.hospital});

  @override
  State<EditHospitalScreen> createState() => _EditHospitalScreenState();
}

class _EditHospitalScreenState extends State<EditHospitalScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _doctorsCtrl;
  late String _type;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.hospital.name);
    _addrCtrl = TextEditingController(text: widget.hospital.address ?? '');
    _doctorsCtrl = TextEditingController(text: widget.hospital.doctors.toString());
    _type = widget.hospital.type;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _doctorsCtrl.dispose();
    super.dispose();
  }

  Widget _buildField({
    required String label,
    required TextEditingController ctrl,
    IconData? icon,
    TextInputType keyboard = TextInputType.text,
    int lines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: kSlate500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
            boxShadow: kCardShadow,
          ),
          child: Row(
            crossAxisAlignment: lines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Padding(
                  padding: EdgeInsets.only(top: lines > 1 ? 10 : 0),
                  child: Icon(icon, size: 18, color: kSlate400),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: keyboard,
                  maxLines: lines,
                  style: const TextStyle(fontSize: 14, color: kSlate900, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  BackCircle(),
                  SizedBox(width: 12),
                  Text(
                    'Cập Nhật Thông Tin',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: kSlate900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kBorder),
                  boxShadow: kCardShadow,
                ),
                child: Row(
                  children: [
                    AvatarBox(
                      text: widget.hospital.initials,
                      bg: widget.hospital.avatarBg,
                      fg: widget.hospital.avatarText,
                      size: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.hospital.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: kSlate900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.hospital.type} · Mã: ${widget.hospital.code ?? 'BV'}',
                            style: const TextStyle(fontSize: 12, color: kSlate500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildField(
                label: 'TÊN CƠ SỞ Y TẾ',
                ctrl: _nameCtrl,
                icon: Icons.local_hospital_outlined,
              ),

              const SizedBox(height: 14),

              const Text(
                'LOẠI HÌNH HOẠT ĐỘNG',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kSlate500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                  boxShadow: kCardShadow,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: kSlate400),
                    items: const [
                      DropdownMenuItem(
                        value: 'Công lập',
                        child: Text('Bệnh viện Công lập', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      DropdownMenuItem(
                        value: 'Tư nhân',
                        child: Text('Bệnh viện Tư nhân', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _type = v);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 14),

              _buildField(
                label: 'ĐỊA CHỈ TRỤ SỞ CHÍNH',
                ctrl: _addrCtrl,
                icon: Icons.location_on_outlined,
                lines: 2,
              ),

              const SizedBox(height: 14),

              _buildField(
                label: 'SỐ LƯỢNG BÁC SĨ & CHUYÊN GIA',
                ctrl: _doctorsCtrl,
                icon: Icons.people_outline_rounded,
                keyboard: TextInputType.number,
              ),

              const SizedBox(height: 26),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kSlate600,
                          side: const BorderSide(color: kBorder),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy bỏ', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Lưu & Đồng Bộ Firebase', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final docNum = int.tryParse(_doctorsCtrl.text.trim()) ?? widget.hospital.doctors;
                          AdminStore.instance.updateHospital(
                            widget.hospital,
                            name: _nameCtrl.text.trim(),
                            type: _type,
                            address: _addrCtrl.text.trim(),
                            doctors: docNum,
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã cập nhật thông tin bệnh viện thành công ✓'),
                              backgroundColor: kGreen,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
