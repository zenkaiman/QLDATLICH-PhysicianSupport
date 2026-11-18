import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qldatlich/services/khoa_service.dart';

import '../../config/app_routes.dart';
import '../../config/app_session.dart';

const _xanh = Color(0xFF1E88E5);

String _gio(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// ===================== MÀN HÌNH THÊM / SỬA KHOA =====================
class ThemKhoaScreen extends StatefulWidget {
  final String benhVienId;
  final String? khoaId;
  final Map<String, dynamic>? duLieuKhoa;

  const ThemKhoaScreen({
    super.key,
    required this.benhVienId,
    this.khoaId,
    this.duLieuKhoa,
  });

  @override
  State<ThemKhoaScreen> createState() => _ThemKhoaScreenState();
}

class _ThemKhoaScreenState extends State<ThemKhoaScreen> {
  bool get _isEditing => widget.khoaId != null && widget.khoaId!.isNotEmpty;

  String get _currentBenhVienId {
    if (widget.benhVienId.isNotEmpty &&
        widget.benhVienId != 'dFmZHBjFNUT1eRzJjXp5') {
      return widget.benhVienId;
    }
    if (AppSession.benhVienId.isNotEmpty) {
      return AppSession.benhVienId;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  String? _selectedChuyenKhoaId;
  String? _selectedTenChuyenKhoa;
  List<Map<String, String>> _dsChuyenKhoa = [];
  bool _dangTaiChuyenKhoa = true;

  final _ten = TextEditingController();
  final _soBuoi = TextEditingController(text: '2');
  final _slMoiBuoi = TextEditingController(text: '45');
  final List<TextEditingController> _phong = [TextEditingController()];
  final Set<int> _ngay = {2, 3, 4, 5, 6, 7};
  final List<List<TimeOfDay>> _khung = [
    [
      const TimeOfDay(hour: 7, minute: 30),
      const TimeOfDay(hour: 11, minute: 30),
    ],
    [
      const TimeOfDay(hour: 13, minute: 30),
      const TimeOfDay(hour: 17, minute: 0),
    ],
  ];
  bool _dangLuu = false;

  @override
  void initState() {
    super.initState();
    _taiDanhSachChuyenKhoa();
    if (_isEditing && widget.duLieuKhoa != null) {
      final data = widget.duLieuKhoa!;
      _ten.text = (data['tenKhoa'] ?? '').toString();
      _soBuoi.text = (data['soCaMoiNgay'] ?? '2').toString();
      _slMoiBuoi.text = (data['gioiHanBenhNhan'] ?? '45').toString();

      // Ngày làm việc
      if (data['ngayLamViec'] is List) {
        _ngay.clear();
        for (final n in data['ngayLamViec']) {
          if (n is int) _ngay.add(n);
          if (n is num) _ngay.add(n.toInt());
        }
      }

      // Khung giờ
      if (data['khungGio'] is List && (data['khungGio'] as List).isNotEmpty) {
        final List<List<TimeOfDay>> loadedKhung = [];
        for (final kg in data['khungGio']) {
          final bdStr = (kg['batDau'] ?? '07:30').toString();
          final ktStr = (kg['ketThuc'] ?? '11:30').toString();
          final bdParts = bdStr.split(':');
          final ktParts = ktStr.split(':');
          loadedKhung.add([
            TimeOfDay(
              hour: int.tryParse(bdParts[0]) ?? 7,
              minute:
                  int.tryParse(bdParts.length > 1 ? bdParts[1] : '30') ?? 30,
            ),
            TimeOfDay(
              hour: int.tryParse(ktParts[0]) ?? 11,
              minute:
                  int.tryParse(ktParts.length > 1 ? ktParts[1] : '30') ?? 30,
            ),
          ]);
        }
        if (loadedKhung.isNotEmpty) {
          _khung.clear();
          _khung.addAll(loadedKhung);
        }
      }

      // Tải danh sách phòng từ Firestore
      _taiDanhSachPhong();
    }
  }

  Future<void> _taiDanhSachChuyenKhoa() async {
    final Map<String, Map<String, String>> danhSachMap = {};

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('chuyen_khoa').get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = (data['ma_chuyen_khoa'] ?? doc.id).toString().trim();
        final ten = (data['ten_chuyen_khoa'] ??
                data['ten_khoa'] ??
                data['ten'] ??
                doc.id)
            .toString()
            .trim();
        if (id.isNotEmpty && ten.isNotEmpty) {
          danhSachMap[id] = {'id': id, 'ten': ten};
        }
      }

      // Nếu collection rỗng, thử collection 'ChuyenKhoa'
      if (danhSachMap.isEmpty) {
        final snapshotFallback =
            await FirebaseFirestore.instance.collection('ChuyenKhoa').get();
        for (final doc in snapshotFallback.docs) {
          final data = doc.data();
          final id = (data['ma_chuyen_khoa'] ?? doc.id).toString().trim();
          final ten = (data['ten_chuyen_khoa'] ??
                  data['ten_khoa'] ??
                  data['ten'] ??
                  doc.id)
              .toString()
              .trim();
          if (id.isNotEmpty && ten.isNotEmpty) {
            danhSachMap[id] = {'id': id, 'ten': ten};
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi tải chuyên khoa từ Firebase: $e');
    }

    final ds = danhSachMap.values.toList();
    ds.sort((a, b) => a['ten']!.compareTo(b['ten']!));

    if (mounted) {
      setState(() {
        _dsChuyenKhoa = ds;
        _dangTaiChuyenKhoa = false;
        _khoiTaoChuyenKhoaDuocChon();
      });
    }
  }

  void _khoiTaoChuyenKhoaDuocChon() {
    if (_isEditing && widget.duLieuKhoa != null) {
      final data = widget.duLieuKhoa!;
      final ckId =
          (data['chuyenKhoaId'] ?? data['chuyen_khoa_id'])?.toString();
      final ckTen =
          (data['tenChuyenKhoa'] ?? data['ten_chuyen_khoa'])?.toString();

      if (ckId != null && _dsChuyenKhoa.any((e) => e['id'] == ckId)) {
        _selectedChuyenKhoaId = ckId;
        _selectedTenChuyenKhoa =
            _dsChuyenKhoa.firstWhere((e) => e['id'] == ckId)['ten'];
      } else if (ckTen != null && _dsChuyenKhoa.any((e) => e['ten'] == ckTen)) {
        final found = _dsChuyenKhoa.firstWhere((e) => e['ten'] == ckTen);
        _selectedChuyenKhoaId = found['id'];
        _selectedTenChuyenKhoa = found['ten'];
      } else if (_ten.text.isNotEmpty) {
        // Thử khớp theo tên khoa hiện tại
        final match = _dsChuyenKhoa.firstWhere(
          (e) =>
              _ten.text.toLowerCase().contains((e['ten'] ?? '').toLowerCase()),
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          _selectedChuyenKhoaId = match['id'];
          _selectedTenChuyenKhoa = match['ten'];
        }
      }
    }
  }

  Future<void> _taiDanhSachPhong() async {
    try {
      final phongs =
          await KhoaService().dsPhong(_currentBenhVienId, widget.khoaId!);
      if (phongs.isNotEmpty && mounted) {
        setState(() {
          for (final c in _phong) {
            c.dispose();
          }
          _phong.clear();
          for (final p in phongs) {
            _phong.add(
              TextEditingController(text: (p['tenPhong'] ?? '').toString()),
            );
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ten.dispose();
    _soBuoi.dispose();
    _slMoiBuoi.dispose();
    for (final c in _phong) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chonGio(int i) async {
    final caTen = i == 0 ? 'Ca sáng' : 'Ca chiều';
    final bd = await showTimePicker(
      context: context,
      initialTime: _khung[i][0],
      initialEntryMode: TimePickerEntryMode.inputOnly,
      helpText: '$caTen - Nhập giờ bắt đầu',
      cancelText: 'Hủy',
      confirmText: 'Tiếp tục',
    );
    if (bd == null || !mounted) return;
    final kt = await showTimePicker(
      context: context,
      initialTime: _khung[i][1],
      initialEntryMode: TimePickerEntryMode.inputOnly,
      helpText: '$caTen - Nhập giờ kết thúc',
      cancelText: 'Hủy',
      confirmText: 'Xác nhận',
    );
    if (kt == null) return;
    setState(() => _khung[i] = [bd, kt]);
  }

  void _loi(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _luu() async {
    if (_selectedChuyenKhoaId == null || _selectedChuyenKhoaId!.isEmpty) {
      return _loi('Vui lòng chọn chuyên khoa');
    }

    final ten = _ten.text.trim();
    final soBuoi = int.tryParse(_soBuoi.text.trim());
    final sl = int.tryParse(_slMoiBuoi.text.trim());
    final phong = _phong
        .map((c) => c.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (ten.isEmpty) return _loi('Vui lòng nhập tên khoa khám');
    if (soBuoi == null || soBuoi <= 0) return _loi('Số buổi khám không hợp lệ');
    if (sl == null || sl <= 0) {
      return _loi('Số lượng khám mỗi buổi không hợp lệ');
    }
    if (_ngay.isEmpty) return _loi('Chọn ít nhất 1 ngày làm việc');
    if (phong.isEmpty) return _loi('Thêm ít nhất 1 phòng khám');

    setState(() => _dangLuu = true);
    try {
      final hospitalId = _currentBenhVienId;

      if (_isEditing) {
        await KhoaService().capNhatKhoa(
          benhVienId: hospitalId,
          khoaId: widget.khoaId!,
          tenKhoa: ten,
          chuyenKhoaId: _selectedChuyenKhoaId,
          tenChuyenKhoa: _selectedTenChuyenKhoa,
          soCaMoiNgay: soBuoi,
          gioiHanBenhNhan: sl,
          khungGio:
              _khung.map((k) => KhungGio(_gio(k[0]), _gio(k[1]))).toList(),
          ngayLamViec: _ngay.toList(),
          phongKham: phong,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật thông tin khoa thành công!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        Navigator.pop(context, true);
      } else {
        final ketQua = await KhoaService().themKhoa(
          benhVienId: hospitalId,
          tenKhoa: ten,
          chuyenKhoaId: _selectedChuyenKhoaId,
          tenChuyenKhoa: _selectedTenChuyenKhoa,
          soCaMoiNgay: soBuoi,
          gioiHanBenhNhan: sl,
          khungGio:
              _khung.map((k) => KhungGio(_gio(k[0]), _gio(k[1]))).toList(),
          ngayLamViec: _ngay.toList(),
          phongKham: phong,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ThanhCongScreen(khoa: ketQua, benhVienId: hospitalId),
          ),
        );
      }
    } catch (e) {
      _loi('Lỗi khi lưu: $e');
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  Widget _nhan(String t, {String? phu}) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (phu != null)
          Text(phu, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ),
  );

  InputDecoration _deco({String? hint}) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const tenNgay = {
      2: 'Thứ\n2',
      3: 'Thứ\n3',
      4: 'Thứ\n4',
      5: 'Thứ\n5',
      6: 'Thứ\n6',
      7: 'Thứ\n7',
      8: 'Chủ\nCN',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Chỉnh Sửa Khoa' : 'Thêm Khoa Mới',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          // 1. CHUYÊN KHOA (SPINNER)
          _nhan('Chuyên khoa *', phu: 'Chọn chuyên khoa từ danh mục'),
          if (_dangTaiChuyenKhoa)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Đang tải danh sách chuyên khoa...',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          else if (_dsChuyenKhoa.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chưa có dữ liệu chuyên khoa trên Firebase (collection: chuyen_khoa).',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: (_selectedChuyenKhoaId != null &&
                      _dsChuyenKhoa.any((e) => e['id'] == _selectedChuyenKhoaId))
                  ? _selectedChuyenKhoaId
                  : null,
              decoration: _deco(hint: 'Chọn chuyên khoa').copyWith(
                prefixIcon: const Icon(Icons.local_hospital_outlined, color: _xanh),
              ),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              items: _dsChuyenKhoa.map((ck) {
                return DropdownMenuItem<String>(
                  value: ck['id'],
                  child: Text(
                    ck['ten'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final found = _dsChuyenKhoa.firstWhere(
                  (e) => e['id'] == val,
                  orElse: () => {'id': val, 'ten': val},
                );
                setState(() {
                  _selectedChuyenKhoaId = val;
                  _selectedTenChuyenKhoa = found['ten'];

                  final newName = found['ten'] ?? '';
                  _ten.text =
                      newName.startsWith('Khoa ') ? newName : 'Khoa $newName';

                  // Cập nhật mã phòng khám tự động theo tiền tố chuẩn Firebase (VD: NGT001, NGT002...)
                  final prefix = KhoaService.layPrefixKhoa(
                    _ten.text,
                    _selectedTenChuyenKhoa,
                  );
                  for (int i = 0; i < _phong.length; i++) {
                    if (_phong[i].text.isEmpty ||
                        RegExp(r'^[A-Z0-9_]+$').hasMatch(_phong[i].text) ||
                        _phong[i].text.startsWith('Phòng ')) {
                      _phong[i].text =
                          '$prefix${(i + 1).toString().padLeft(3, '0')}';
                    }
                  }
                });
              },
            ),

          // 2. TÊN KHOA KHÁM (CHỈ HIỂN THỊ KHI ĐÃ CHỌN CHUYÊN KHOA VÀ KHÔNG THỂ SỬA)
          if (_selectedChuyenKhoaId != null &&
              _selectedChuyenKhoaId!.isNotEmpty) ...[
            _nhan('Tên khoa khám *', phu: 'Cố định theo chuyên khoa đã chọn'),
            TextField(
              controller: _ten,
              readOnly: true,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
              decoration: _deco().copyWith(
                prefixIcon:
                    const Icon(Icons.business_outlined, color: Colors.grey),
                suffixIcon: const Tooltip(
                  message: 'Tên khoa được cố định theo chuyên khoa đã chọn',
                  child: Icon(Icons.lock_outline, size: 20, color: Colors.grey),
                ),
                fillColor: const Color(0xFFF1F5F9),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vui lòng chọn chuyên khoa ở trên để hiển thị tên khoa khám.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E40AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Số buổi + SL mỗi buổi
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _nhan('Số buổi khám / ngày'),
                    TextField(
                      controller: _soBuoi,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: _deco(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _nhan('SL khám mỗi buổi'),
                    TextField(
                      controller: _slMoiBuoi,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: _deco(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          _nhan('Thời gian khám', phu: 'Ca sáng & Chiều (nhập giờ)'),
          Row(
            children: [
              for (var i = 0; i < _khung.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _chonGio(i),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Text(
                            i == 0 ? 'Ca sáng' : 'Ca chiều',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_gio(_khung[i][0])} - ${_gio(_khung[i][1])}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          _nhan('Ngày làm việc trong tuần', phu: 'Chọn ngày làm việc'),
          Row(
            children: [
              for (final d in [2, 3, 4, 5, 6, 7, 8]) ...[
                if (d > 2) const SizedBox(width: 5),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      if (_ngay.contains(d)) {
                        if (_ngay.length > 1) {
                          _ngay.remove(d);
                        }
                      } else {
                        _ngay.add(d);
                      }
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _ngay.contains(d) ? _xanh : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              _ngay.contains(d) ? _xanh : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        tenNgay[d]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _ngay.contains(d)
                              ? Colors.white
                              : Colors.grey.shade700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _ngay.isEmpty
                      ? ''
                      : '✓ Đã chọn: ${taoLichLamViec(_ngay.toList())}',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _ngay
                      ..clear()
                      ..addAll([2, 3, 4, 5, 6, 7, 8]),
                  ),
                  child: const Text('Chọn cả tuần'),
                ),
              ],
            ),
          ),

          _nhan(
            'Vị trí / Tên phòng khám',
            phu: _selectedChuyenKhoaId != null
                ? 'Định dạng mã: ${KhoaService.layPrefixKhoa(_ten.text, _selectedTenChuyenKhoa)}001...'
                : 'Có thể thêm nhiều phòng',
          ),
          for (var i = 0; i < _phong.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _phong[i],
                decoration: _deco(
                  hint: _selectedChuyenKhoaId != null
                      ? 'VD: ${KhoaService.layPrefixKhoa(_ten.text, _selectedTenChuyenKhoa)}${(i + 1).toString().padLeft(3, '0')}'
                      : 'VD: NGT001',
                ).copyWith(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: _xanh,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  suffixIcon: _phong.length > 1
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => setState(() {
                            _phong.removeAt(i).dispose();
                          }),
                        )
                      : null,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              final prefix = KhoaService.layPrefixKhoa(
                _ten.text,
                _selectedTenChuyenKhoa,
              );
              final nextIndex = _phong.length + 1;
              final roomName =
                  '$prefix${nextIndex.toString().padLeft(3, '0')}';
              _phong.add(TextEditingController(text: roomName));
            }),
            icon: const Icon(Icons.add),
            label: const Text('Thêm phòng khám'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _dangLuu ? null : _luu,
            style: ElevatedButton.styleFrom(
              backgroundColor: _xanh,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _dangLuu
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isEditing ? 'Lưu Thay Đổi' : 'Thêm Khoa Khám',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ===================== MÀN HÌNH THÀNH CÔNG =====================
class ThanhCongScreen extends StatelessWidget {
  final KhoaVuaTao khoa;
  final String benhVienId;
  const ThanhCongScreen({
    super.key,
    required this.khoa,
    required this.benhVienId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 84),
              const SizedBox(height: 16),
              const Text(
                'Tạo Khoa Thành Công!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Khoa ${khoa.tenKhoa} đã được lưu vào hệ thống.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _dong('Mã khoa (ID):', khoa.khoaId),
                    _dong('Số ca khám:', '${khoa.soCaMoiNgay} ca/ngày'),
                    _dong('Giới hạn:', '${khoa.gioiHanBenhNhan} BN/ca'),
                    _dong('Lịch làm việc:', khoa.lichLamViec),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.hospitalDashboard,
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.home_outlined),
                label: const Text('Trở Về Trang Chủ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _xanh,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ThemKhoaScreen(benhVienId: benhVienId),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Tiếp tục thêm khoa khác'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dong(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(color: Color(0xFF64748B))),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
