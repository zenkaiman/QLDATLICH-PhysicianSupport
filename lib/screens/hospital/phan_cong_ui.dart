import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/nhan_vien_model.dart';
import '../../models/phan_cong_model.dart';
import '../../services/phan_cong_service.dart';

// ==========================================
// 1. HEADER & THANH ĐIỀU HƯỚNG
// ==========================================

class PhanCongHeader extends StatelessWidget {
  final bool isTab;
  final VoidCallback? onBack;

  const PhanCongHeader({super.key, this.isTab = true, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (!isTab) ...[
            InkWell(
              onTap: onBack ??
                  () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFF0F172A),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Phân Công Trực',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Mỗi phòng khám phân công trực theo chuyên khoa',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (!isTab) const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class PhanCongDatePicker extends StatelessWidget {
  final DateTime ngayDuocChon;
  final ValueChanged<int> onDoiNgay;
  final ValueChanged<DateTime> onChonNgay;

  const PhanCongDatePicker({
    super.key,
    required this.ngayDuocChon,
    required this.onDoiNgay,
    required this.onChonNgay,
  });

  static String dinhDangThuNgay(DateTime dt) {
    const listThu = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final thu = listThu[dt.weekday - 1];
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return '$thu, $d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => onDoiNgay(-1),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF475569),
            ),
            splashRadius: 20,
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: ngayDuocChon,
                firstDate: DateTime(2025),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                onChonNgay(picked);
              }
            },
            child: Text(
              dinhDangThuNgay(ngayDuocChon),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
            onPressed: () => onDoiNgay(1),
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF475569),
            ),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

class PhanCongKhoaSelector extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> dsKhoaDocs;
  final String currentKhoaId;
  final ValueChanged<String> onSelectKhoa;

  const PhanCongKhoaSelector({
    super.key,
    required this.dsKhoaDocs,
    required this.currentKhoaId,
    required this.onSelectKhoa,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: dsKhoaDocs.map((doc) {
          final isSelected = doc.id == currentKhoaId;
          final data = doc.data();
          final ten = (data['tenKhoa'] ?? data['ten_khoa'] ?? doc.id).toString();

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onSelectKhoa(doc.id),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFCBD5E1),
                  ),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x332563EB),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  ten,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==========================================
// 2. PAINTER & CARD PHÒNG KHÁM
// ==========================================

/// CustomPainter vẽ viền nét đứt (Dashed Border) cho phòng chưa phân công
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  const DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}

class CardPhongPhanCong extends StatelessWidget {
  final PhongItemPhanCong phong;
  final List<Map<String, dynamic>> danhSachPhanCong;
  final VoidCallback onTap;

  const CardPhongPhanCong({
    super.key,
    required this.phong,
    required this.danhSachPhanCong,
    required this.onTap,
  });

  static String getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'NV';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static Color getAvatarBg(String id) {
    final colors = [
      const Color(0xFFEFF6FF),
      const Color(0xFFFEF3C7),
      const Color(0xFFFFEDD5),
      const Color(0xFFDCFCE7),
      const Color(0xFFF3E8FF),
      const Color(0xFFFCE7F3),
    ];
    int sum = 0;
    for (int i = 0; i < id.length; i++) {
      sum += id.codeUnitAt(i);
    }
    return colors[sum % colors.length];
  }

  static Color getAvatarTextColor(String id) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFFD97706),
      const Color(0xFFEA580C),
      const Color(0xFF16A34A),
      const Color(0xFF9333EA),
      const Color(0xFFDB2777),
    ];
    int sum = 0;
    for (int i = 0; i < id.length; i++) {
      sum += id.codeUnitAt(i);
    }
    return colors[sum % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final daPhanCong = danhSachPhanCong.isNotEmpty;

    if (!daPhanCong) {
      // Card viền nét đứt màu cam (Phòng chưa phân công)
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CustomPaint(
          painter: const DashedBorderPainter(
            color: Color(0xFFF59E0B),
            strokeWidth: 1.5,
            radius: 18,
            dashWidth: 6,
            dashSpace: 4,
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.table_restaurant_outlined,
                      color: Color(0xFFD97706),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phong.tenPhong,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phong.thoiGianVaDiaDiem,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '+ Phân công',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Card phòng đã có phân công
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.table_restaurant_outlined,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              phong.tenPhong,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${danhSachPhanCong.length} vai trò',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phong.thoiGianVaDiaDiem,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),
              ...danhSachPhanCong.map((pc) {
                final maNv =
                    (pc['nhan_vien_id'] ?? pc['ma_nhan_vien'] ?? '').toString();
                final tenNv =
                    (pc['ten_nhan_vien'] ?? 'Nhân viên trực').toString();
                final vaiTroNv = (pc['vai_tro'] ?? 'Trực phòng').toString();
                final roleCode = (pc['vai_tro_code'] ?? '').toString();
                final initials = getInitials(tenNv);
                final avBg = getAvatarBg(maNv);
                final avTxt = getAvatarTextColor(maNv);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: avBg,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: avTxt,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tenNv,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '$vaiTroNv • $maNv',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (roleCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Text(
                            roleCode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. MODAL CHỌN NHÂN VIÊN TRỰC
// ==========================================

class ChonNhanVienModal extends StatefulWidget {
  final String benhVienId;
  final String ngayStr;
  final String ngayHienThi;
  final PhongItemPhanCong phong;
  final String khoaId;
  final String tenKhoa;
  final String prefixKhoa;
  final List<NhanVienModel> tatCaNhanVienBv;
  final Map<String, List<Map<String, dynamic>>> phanCongTheoPhong;
  final Map<String, Map<String, dynamic>> phanCongTheoNhanVien;

  const ChonNhanVienModal({
    super.key,
    required this.benhVienId,
    required this.ngayStr,
    required this.ngayHienThi,
    required this.phong,
    required this.khoaId,
    required this.tenKhoa,
    required this.prefixKhoa,
    required this.tatCaNhanVienBv,
    required this.phanCongTheoPhong,
    required this.phanCongTheoNhanVien,
  });

  @override
  State<ChonNhanVienModal> createState() => _ChonNhanVienModalState();
}

class _ChonNhanVienModalState extends State<ChonNhanVienModal> {
  final PhanCongService _service = PhanCongService();
  String _tuKhoa = '';
  NhanVienModel? _nhanVienDuocChon;
  bool _isSaving = false;

  List<Map<String, dynamic>> get _danhSachDangTruc =>
      widget.phanCongTheoPhong[widget.phong.tenPhong] ?? [];

  List<NhanVienModel> _locNhanVienTheoChuyenKhoa() {
    final tenKhoaChuan = widget.tenKhoa.trim().toLowerCase();
    final prefixChuan = widget.prefixKhoa.trim().toLowerCase();

    return widget.tatCaNhanVienBv.where((nv) {
      if (!nv.daKichHoat) return false;

      if (nv.benhVienId.isNotEmpty &&
          widget.benhVienId.isNotEmpty &&
          nv.benhVienId != widget.benhVienId) {
        return false;
      }

      final nvKhoa = nv.khoa.trim().toLowerCase();
      final matchKhoa = nvKhoa.isNotEmpty &&
          (nvKhoa == tenKhoaChuan ||
              nvKhoa.contains(tenKhoaChuan) ||
              tenKhoaChuan.contains(nvKhoa));

      final matchPrefix = prefixChuan.isNotEmpty &&
          (nv.maNv.toLowerCase().contains('_${prefixChuan}_') ||
              nv.id.toLowerCase().contains('_${prefixChuan}_') ||
              nv.maNv.toLowerCase().endsWith('_$prefixChuan') ||
              nv.id.toLowerCase().endsWith('_$prefixChuan'));

      if (!matchKhoa && !matchPrefix) {
        return false;
      }

      if (_tuKhoa.isNotEmpty) {
        final matchTen = nv.hoTen.toLowerCase().contains(_tuKhoa.toLowerCase());
        final matchMa = nv.maNv.toLowerCase().contains(_tuKhoa.toLowerCase());
        return matchTen || matchMa;
      }

      return true;
    }).toList();
  }

  Future<void> _xacNhanPhanCong(NhanVienModel nv) async {
    setState(() => _isSaving = true);
    try {
      final roleCode = await _service.xacNhanPhanCong(
        benhVienId: widget.benhVienId,
        ngayStr: widget.ngayStr,
        phong: widget.phong,
        khoaId: widget.khoaId,
        tenKhoa: widget.tenKhoa,
        prefixKhoa: widget.prefixKhoa,
        nv: nv,
        dangTrucTrongPhong: _danhSachDangTruc,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã phân công ${nv.hoTen} ($roleCode) trực ${widget.phong.tenPhong}!',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi phân công: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _huyPhanCongMotNhanVien(Map<String, dynamic> pcData) async {
    setState(() => _isSaving = true);
    try {
      final tenNv = (pcData['ten_nhan_vien'] ?? 'Nhân viên').toString();

      await _service.huyPhanCongMotNhanVien(
        benhVienId: widget.benhVienId,
        ngayStr: widget.ngayStr,
        phong: widget.phong,
        khoaId: widget.khoaId,
        pcData: pcData,
        soLuongDangTruc: _danhSachDangTruc.length,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã hủy phân công $tenNv trực ${widget.phong.tenPhong}.'),
          backgroundColor: const Color(0xFF475569),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi hủy phân công: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _huyToanBoPhanCongPhong() async {
    setState(() => _isSaving = true);
    try {
      await _service.huyToanBoPhanCongPhong(
        benhVienId: widget.benhVienId,
        ngayStr: widget.ngayStr,
        phong: widget.phong,
        khoaId: widget.khoaId,
        danhSachDangTruc: _danhSachDangTruc,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã hủy toàn bộ phân công trực cho ${widget.phong.tenPhong}.',
          ),
          backgroundColor: const Color(0xFF475569),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi hủy phân công: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listNhanVienPhuHop = _locNhanVienTheoChuyenKhoa();
    final coDangTruc = _danhSachDangTruc.isNotEmpty;
    final previewRoleCode = _nhanVienDuocChon != null
        ? PhanCongService.taoMaVaiTro(
            _nhanVienDuocChon!,
            _danhSachDangTruc,
          )
        : '';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chọn nhân viên trực',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.phong.tenPhong} · ${widget.tenKhoa} · ${widget.ngayHienThi}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Danh sách đang trực
          if (coDangTruc) ...[
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 6),
                Text(
                  'ĐANG TRỰC TẠI PHÒNG NÀY (${_danhSachDangTruc.length})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 130),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _danhSachDangTruc.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (ctx, idx) {
                  final pc = _danhSachDangTruc[idx];
                  final maNv = (pc['nhan_vien_id'] ??
                          pc['ma_nhan_vien'] ??
                          '')
                      .toString();
                  final tenNv =
                      (pc['ten_nhan_vien'] ?? 'Nhân viên').toString();
                  final vaiTroNv = (pc['vai_tro'] ?? '').toString();
                  final roleCode = (pc['vai_tro_code'] ?? '').toString();
                  final initials = CardPhongPhanCong.getInitials(tenNv);
                  final avBg = CardPhongPhanCong.getAvatarBg(maNv);
                  final avTxt = CardPhongPhanCong.getAvatarTextColor(maNv);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: avBg,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: avTxt,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tenNv,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '$vaiTroNv  •  $maNv',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (roleCode.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              roleCode,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _isSaving
                              ? null
                              : () => _huyPhanCongMotNhanVien(pc),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Tìm kiếm
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _tuKhoa = val.trim()),
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên hoặc mã nhân viên...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Tiêu đề danh sách
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NHÂN VIÊN ${widget.tenKhoa.toUpperCase()} (${listNhanVienPhuHop.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                'Mã: ${widget.prefixKhoa}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Danh sách nhân viên
          Flexible(
            child: listNhanVienPhuHop.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_outline_rounded,
                            size: 40,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Chưa có nhân viên nào thuộc ${widget.tenKhoa}.\nHãy cấp tài khoản nhân viên cho khoa này trong tab Nhân sự.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: listNhanVienPhuHop.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final nv = listNhanVienPhuHop[index];
                      final isSelected = _nhanVienDuocChon?.maNv == nv.maNv;

                      Map<String, dynamic>? dangTrucPhongNay;
                      for (final pc in _danhSachDangTruc) {
                        final assignedNv = (pc['nhan_vien_id'] ??
                                pc['ma_nhan_vien'] ??
                                '')
                            .toString();
                        if (assignedNv == nv.maNv) {
                          dangTrucPhongNay = pc;
                          break;
                        }
                      }
                      final isCurrentlyThisRoom = dangTrucPhongNay != null;

                      final phanCongKhac = widget.phanCongTheoNhanVien[nv.maNv];
                      final isBusyOtherRoom = phanCongKhac != null &&
                          (phanCongKhac['phong_id'] ??
                                  phanCongKhac['ten_phong']) !=
                              widget.phong.tenPhong;
                      final tenPhongKhac = isBusyOtherRoom
                          ? (phanCongKhac['phong_id'] ??
                                  phanCongKhac['ten_phong'] ??
                                  '')
                              .toString()
                          : '';

                      final isAvailable =
                          !isCurrentlyThisRoom && !isBusyOtherRoom;

                      final initials = CardPhongPhanCong.getInitials(nv.hoTen);
                      final avBg = CardPhongPhanCong.getAvatarBg(nv.maNv);
                      final avTxt = CardPhongPhanCong.getAvatarTextColor(nv.maNv);

                      final String trangThaiText;
                      final Color trangThaiBg;
                      final Color trangThaiTxt;

                      if (isCurrentlyThisRoom) {
                        final code = (dangTrucPhongNay['vai_tro_code'] ?? '')
                            .toString();
                        trangThaiText = code.isNotEmpty
                            ? 'Đang trực ($code)'
                            : 'Đã phân công';
                        trangThaiBg = const Color(0xFFDCFCE7);
                        trangThaiTxt = const Color(0xFF16A34A);
                      } else if (isBusyOtherRoom) {
                        trangThaiText = 'Đã phân công ($tenPhongKhac)';
                        trangThaiBg = const Color(0xFFEFF6FF);
                        trangThaiTxt = const Color(0xFF2563EB);
                      } else {
                        trangThaiText = 'Chờ (15)';
                        trangThaiBg = const Color(0xFFFEF3C7);
                        trangThaiTxt = const Color(0xFFD97706);
                      }

                      return InkWell(
                        onTap: isAvailable
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _nhanVienDuocChon = null;
                                  } else {
                                    _nhanVienDuocChon = nv;
                                  }
                                });
                              }
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFEFF6FF)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: avBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: avTxt,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nv.hoTen,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isAvailable
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${nv.vaiTro}  •  ${nv.maNv}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: trangThaiBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  trangThaiText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: trangThaiTxt,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 22,
                                )
                              else if (isAvailable)
                                const Icon(
                                  Icons.radio_button_unchecked_rounded,
                                  color: Color(0xFFCBD5E1),
                                  size: 22,
                                )
                              else
                                const SizedBox(width: 22),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),

          // Nút xác nhận phân công
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _nhanVienDuocChon != null && !_isSaving
                  ? () => _xacNhanPhanCong(_nhanVienDuocChon!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      previewRoleCode.isNotEmpty
                          ? 'Xác nhận phân công ($previewRoleCode)'
                          : 'Xác nhận phân công',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),

          // Nút Hủy toàn bộ phòng
          if (coDangTruc) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton.icon(
                onPressed: _isSaving ? null : _huyToanBoPhanCongPhong,
                icon: const Icon(
                  Icons.person_remove_rounded,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
                label: const Text(
                  'Hủy phân công phòng này',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ],

          // Nút Đóng
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Đóng',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. BANNER & NÚT LƯU
// ==========================================

class PhanCongWarningBanner extends StatelessWidget {
  final List<PhongItemPhanCong> danhSachChuaCo;

  const PhanCongWarningBanner({super.key, required this.danhSachChuaCo});

  @override
  Widget build(BuildContext context) {
    final tenPhongChua = danhSachChuaCo.map((p) => p.tenPhong).join(', ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDD5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFEA580C),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.priority_high_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Còn ${danhSachChuaCo.length} phòng chưa có người trực',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$tenPhongChua hiện chưa được phân công',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PhanCongNoteBox extends StatelessWidget {
  const PhanCongNoteBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
          style: BorderStyle.solid,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quy định phân công:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4),
          Text(
            '• Nhân viên của bệnh viện nào chỉ hoạt động và phân công tại bệnh viện đó.\n'
            '• Nhân viên chỉ được phân công vào các phòng khám thuộc đúng chuyên khoa của mình.\n'
            '• Mỗi phòng khám có thể phân công nhiều vai trò (Bác sĩ, Lễ tân,...) theo ngày.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class PhanCongSaveButton extends StatelessWidget {
  final int soPhongDaPhanCong;
  final int tongSoPhong;
  final String ngayStr;

  const PhanCongSaveButton({
    super.key,
    required this.soPhongDaPhanCong,
    required this.tongSoPhong,
    required this.ngayStr,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dữ liệu phân công trực ngày $ngayStr đã được lưu hoàn tất ($soPhongDaPhanCong/$tongSoPhong phòng).',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Lưu Phân Công',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
