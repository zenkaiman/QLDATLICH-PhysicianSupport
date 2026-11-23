import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_session.dart';
import '../../models/nhan_vien_model.dart';
import '../../services/khoa_service.dart';

/// Thông tin phòng khám hiển thị trên màn phân công
class PhongItemPhanCong {
  final String id;
  final String tenPhong;
  final String gioMoCua;
  final String gioDongCua;
  final int soBenhNhanToiDa;
  final String thoiGianKham;

  const PhongItemPhanCong({
    required this.id,
    required this.tenPhong,
    required this.gioMoCua,
    required this.gioDongCua,
    required this.soBenhNhanToiDa,
    required this.thoiGianKham,
  });

  String get thoiGianVaDiaDiem {
    final gio = (gioMoCua.isNotEmpty && gioDongCua.isNotEmpty)
        ? '$gioMoCua - $gioDongCua'
        : '07:30 - 17:00';
    return '$gio · Tối đa $soBenhNhanToiDa BN/ca';
  }
}

/// Màn hình Phân Công Trực - Đồng bộ 100% Firebase Firestore (Không dùng hashcode)
class PhanCongScreen extends StatefulWidget {
  final bool isTab;
  final String? benhVienId;

  const PhanCongScreen({super.key, this.isTab = true, this.benhVienId});

  @override
  State<PhanCongScreen> createState() => _PhanCongScreenState();
}

class _PhanCongScreenState extends State<PhanCongScreen> {
  late String _bvid;
  DateTime _ngayDuocChon = DateTime.now();
  String? _selectedKhoaId;

  String get _ngayStr =>
      '${_ngayDuocChon.year}-${_ngayDuocChon.month.toString().padLeft(2, '0')}-${_ngayDuocChon.day.toString().padLeft(2, '0')}';

  String _getHospitalId() {
    if (widget.benhVienId != null && widget.benhVienId!.trim().isNotEmpty) {
      return widget.benhVienId!.trim();
    }
    if (AppSession.benhVienId.isNotEmpty) {
      return AppSession.benhVienId;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  void initState() {
    super.initState();
    _bvid = _getHospitalId();
    _khoiTao();
  }

  Future<void> _khoiTao() async {
    if (!_bvid.startsWith('BV')) {
      final chuan = await KhoaService().chuanHoaBenhVienId(_bvid);
      if (chuan.isNotEmpty && chuan != _bvid && mounted) {
        setState(() {
          _bvid = chuan;
        });
        AppSession.benhVienId = chuan;
      }
    }
  }

  String _dinhDangThuNgay(DateTime dt) {
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

  void _doiNgay(int offsetDays) {
    setState(() {
      _ngayDuocChon = _ngayDuocChon.add(Duration(days: offsetDays));
    });
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'NV';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color _getAvatarBg(String id) {
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

  Color _getAvatarTextColor(String id) {
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

  /// Tạo mã vai trò cho phân công trực: ví dụ LT001, LT002, BS001,...
  /// ID collection chuẩn: tg_tenkhoa_vaitro (ví dụ: 2026-11-18_DL001_LT001)
  static String taoMaVaiTroPhanCong(
    NhanVienModel nv, [
    List<Map<String, dynamic>> dangTrucTrongPhong = const [],
  ]) {
    String prefix = 'NV';
    final maNvUpper = nv.maNv.toUpperCase();
    final vaiTroLower = nv.vaiTro.toLowerCase();

    if (maNvUpper.contains('_LT_') ||
        vaiTroLower.contains('lễ tân') ||
        vaiTroLower.contains('le tan') ||
        vaiTroLower.contains('reception')) {
      prefix = 'LT';
    } else if (maNvUpper.contains('_BS_') ||
        vaiTroLower.contains('bác sĩ') ||
        vaiTroLower.contains('bac si') ||
        vaiTroLower.contains('doctor') ||
        vaiTroLower.contains('support')) {
      prefix = 'BS';
    } else if (maNvUpper.contains('_DD_') ||
        vaiTroLower.contains('điều dưỡng') ||
        vaiTroLower.contains('dieu duong') ||
        vaiTroLower.contains('nurse')) {
      prefix = 'DD';
    } else if (maNvUpper.contains('_DS_') ||
        vaiTroLower.contains('dược sĩ') ||
        vaiTroLower.contains('duoc si') ||
        vaiTroLower.contains('pharmacist')) {
      prefix = 'DS';
    } else if (maNvUpper.contains('_CSKH_') ||
        vaiTroLower.contains('cskh') ||
        vaiTroLower.contains('chăm sóc')) {
      prefix = 'CSKH';
    } else if (maNvUpper.contains('_KT_') ||
        vaiTroLower.contains('kỹ thuật') ||
        vaiTroLower.contains('ky thuat')) {
      prefix = 'KT';
    }

    final usedIndices = <int>{};
    for (final pc in dangTrucTrongPhong) {
      final code = (pc['vai_tro_code'] ?? '').toString().toUpperCase();
      if (code.startsWith(prefix)) {
        final numPart = code.substring(prefix.length);
        final val = int.tryParse(numPart);
        if (val != null) {
          usedIndices.add(val);
        }
      }
    }

    int nextIndex = 1;
    while (usedIndices.contains(nextIndex)) {
      nextIndex++;
    }

    return '$prefix${nextIndex.toString().padLeft(3, '0')}';
  }

  /// Mở Bottom Sheet chọn nhân viên trực theo chuyên khoa và bệnh viện
  void _moSheetChonNhanVien({
    required PhongItemPhanCong phong,
    required String khoaId,
    required String tenKhoa,
    required String prefixKhoa,
    required List<NhanVienModel> tatCaNhanVienBv,
    required Map<String, List<Map<String, dynamic>>> phanCongTheoPhong,
    required Map<String, Map<String, dynamic>> phanCongTheoNhanVien,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChonNhanVienModal(
        benhVienId: _bvid,
        ngayStr: _ngayStr,
        ngayHienThi: _dinhDangThuNgay(_ngayDuocChon),
        phong: phong,
        khoaId: khoaId,
        tenKhoa: tenKhoa,
        prefixKhoa: prefixKhoa,
        tatCaNhanVienBv: tatCaNhanVienBv,
        phanCongTheoPhong: phanCongTheoPhong,
        phanCongTheoNhanVien: phanCongTheoNhanVien,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header: Phân Công Trực
            _buildHeader(),

            // Stream danh sách khoa của bệnh viện
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('Khoa')
                    .doc(_bvid)
                    .collection('danh_sach')
                    .snapshots(),
                builder: (context, khoaSnap) {
                  if (khoaSnap.hasError) {
                    return Center(
                      child: Text('Lỗi tải dữ liệu khoa: ${khoaSnap.error}'),
                    );
                  }
                  if (!khoaSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final dsKhoaDocs = khoaSnap.data!.docs;
                  if (dsKhoaDocs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Bệnh viện chưa tạo khoa khám nào.\nVui lòng thêm khoa khám trước khi phân công.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  }

                  // Tự động chọn khoa đầu tiên nếu chưa chọn hoặc khoa cũ bị xóa
                  QueryDocumentSnapshot<Map<String, dynamic>> khoaHienTaiDoc =
                      dsKhoaDocs.first;
                  for (final d in dsKhoaDocs) {
                    if (d.id == _selectedKhoaId) {
                      khoaHienTaiDoc = d;
                      break;
                    }
                  }
                  final currentKhoaId = khoaHienTaiDoc.id;
                  final khoaData = khoaHienTaiDoc.data();
                  final tenKhoaHienTai =
                      (khoaData['tenKhoa'] ??
                              khoaData['ten_khoa'] ??
                              'Khoa khám')
                          .toString();
                  final prefixKhoaHienTai =
                      (khoaData['prefixKhoa'] ?? khoaData['prefix_khoa'] ?? '')
                          .toString();

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    // Stream toàn bộ phân công của bệnh viện trong ngày được chọn
                    stream: FirebaseFirestore.instance
                        .collection('PhanCong')
                        .doc(_bvid)
                        .collection('danh_sach')
                        .where('ngay', isEqualTo: _ngayStr)
                        .snapshots(),
                    builder: (context, phanCongSnap) {
                      final phanCongTheoPhong =
                          <String, List<Map<String, dynamic>>>{};
                      final phanCongTheoNhanVien =
                          <String, Map<String, dynamic>>{};
                      if (phanCongSnap.hasData) {
                        for (final doc in phanCongSnap.data!.docs) {
                          final data = Map<String, dynamic>.from(doc.data());
                          data['_docId'] = doc.id;
                          final pId =
                              (data['phong_id'] ?? data['ten_phong'] ?? '')
                                  .toString();
                          final nvId =
                              (data['nhan_vien_id'] ??
                                      data['ma_nhan_vien'] ??
                                      '')
                                  .toString();
                          if (pId.isNotEmpty) {
                            phanCongTheoPhong
                                .putIfAbsent(pId, () => [])
                                .add(data);
                          }
                          if (nvId.isNotEmpty) {
                            phanCongTheoNhanVien[nvId] = data;
                          }
                        }
                      }

                      // Stream nhân viên của bệnh viện
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('NhanVien')
                            .doc(_bvid)
                            .collection('danh_sach')
                            .snapshots(),
                        builder: (context, nvSnap) {
                          final dsNhanVien = <NhanVienModel>[];
                          if (nvSnap.hasData) {
                            for (final d in nvSnap.data!.docs) {
                              final nv = NhanVienModel.fromDoc(d);
                              // Chỉ lấy tài khoản nhân sự đã kích hoạt theo yêu cầu
                              if (nv.daKichHoat) {
                                dsNhanVien.add(nv);
                              }
                            }
                          }

                          // Stream phòng khám của khoa hiện tại
                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream: FirebaseFirestore.instance
                                .collection('Khoa')
                                .doc(_bvid)
                                .collection('danh_sach')
                                .doc(currentKhoaId)
                                .collection('phongKham')
                                .snapshots(),
                            builder: (context, phongSnap) {
                              final dsPhong = <PhongItemPhanCong>[];
                              if (phongSnap.hasData) {
                                for (final d in phongSnap.data!.docs) {
                                  final p = d.data();
                                  final ten =
                                      (p['tenPhong'] ??
                                              p['ten_phong'] ??
                                              p['id'] ??
                                              d.id)
                                          .toString();
                                  dsPhong.add(
                                    PhongItemPhanCong(
                                      id: d.id,
                                      tenPhong: ten,
                                      gioMoCua:
                                          (p['gioMoCua'] ??
                                                  p['gio_mo_cua'] ??
                                                  '')
                                              .toString(),
                                      gioDongCua:
                                          (p['gioDongCua'] ??
                                                  p['gio_dong_cua'] ??
                                                  '')
                                              .toString(),
                                      soBenhNhanToiDa:
                                          (p['soBenhNhanToiDa'] ??
                                                  p['so_benh_nhan_toi_da'] ??
                                                  45)
                                              as int,
                                      thoiGianKham:
                                          (p['thoiGianKham'] ??
                                                  p['thoi_gian_kham'] ??
                                                  '15')
                                              .toString(),
                                    ),
                                  );
                                }
                              }

                              dsPhong.sort(
                                (a, b) => a.tenPhong.compareTo(b.tenPhong),
                              );

                              // Đếm số phòng đã được phân công trực
                              final soPhongDaPhanCong = dsPhong
                                  .where(
                                    (p) =>
                                        phanCongTheoPhong[p.tenPhong]
                                            ?.isNotEmpty ??
                                        false,
                                  )
                                  .length;
                              final tongSoPhong = dsPhong.length;
                              final phongChuaPhanCong = dsPhong
                                  .where(
                                    (p) =>
                                        phanCongTheoPhong[p.tenPhong]
                                            ?.isEmpty ??
                                        true,
                                  )
                                  .toList();

                              return SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Chọn ngày trực
                                    const Text(
                                      'Chọn ngày trực',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Thanh điều hướng chọn ngày
                                    _buildDatePickerBar(),

                                    const SizedBox(height: 16),

                                    // Thanh chuyển khoa (Chuyên khoa)
                                    const Text(
                                      'Chuyên khoa',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildKhoaSelector(
                                      dsKhoaDocs: dsKhoaDocs,
                                      currentKhoaId: currentKhoaId,
                                    ),

                                    const SizedBox(height: 20),

                                    // Tiêu đề Khoa và số phòng đã phân công
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            tenKhoaHienTai,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$soPhongDaPhanCong/$tongSoPhong phòng đã phân công',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                soPhongDaPhanCong ==
                                                        tongSoPhong &&
                                                    tongSoPhong > 0
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Danh sách các phòng
                                    if (dsPhong.isEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'Khoa này chưa có phòng khám nào.',
                                            style: TextStyle(
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      ...dsPhong.map(
                                        (p) => _buildCardPhong(
                                          phong: p,
                                          danhSachPhanCong:
                                              phanCongTheoPhong[p.tenPhong] ??
                                              [],
                                          khoaId: currentKhoaId,
                                          tenKhoa: tenKhoaHienTai,
                                          prefixKhoa: prefixKhoaHienTai,
                                          tatCaNhanVienBv: dsNhanVien,
                                          phanCongTheoPhong: phanCongTheoPhong,
                                          phanCongTheoNhanVien:
                                              phanCongTheoNhanVien,
                                        ),
                                      ),

                                    const SizedBox(height: 16),

                                    // Banner thông báo nếu còn phòng chưa có người trực
                                    if (phongChuaPhanCong.isNotEmpty) ...[
                                      _buildWarningBanner(phongChuaPhanCong),
                                      const SizedBox(height: 16),
                                    ],

                                    // Nút Lịch sử phân công trực
                                    _buildLichSuPhanCongButton(),
                                    const SizedBox(height: 16),

                                    // Nút Lưu Phân Công
                                    _buildSaveButton(
                                      soPhongDaPhanCong: soPhongDaPhanCong,
                                      tongSoPhong: tongSoPhong,
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== WIDGETS CON ====================

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (!widget.isTab) ...[
            InkWell(
              onTap: () {
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
                  'Mỗi phòng khám 1 người trực theo chuyên khoa',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (!widget.isTab) const SizedBox(width: 38),
        ],
      ),
    );
  }

  Widget _buildDatePickerBar() {
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
            onPressed: () => _doiNgay(-1),
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
                initialDate: _ngayDuocChon,
                firstDate: DateTime(2025),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                setState(() => _ngayDuocChon = picked);
              }
            },
            child: Text(
              _dinhDangThuNgay(_ngayDuocChon),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _doiNgay(1),
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

  Widget _buildKhoaSelector({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> dsKhoaDocs,
    required String currentKhoaId,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: dsKhoaDocs.map((doc) {
          final isSelected = doc.id == currentKhoaId;
          final data = doc.data();
          final ten = (data['tenKhoa'] ?? data['ten_khoa'] ?? doc.id)
              .toString();

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedKhoaId = doc.id;
                });
              },
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

  Widget _buildCardPhong({
    required PhongItemPhanCong phong,
    required List<Map<String, dynamic>> danhSachPhanCong,
    required String khoaId,
    required String tenKhoa,
    required String prefixKhoa,
    required List<NhanVienModel> tatCaNhanVienBv,
    required Map<String, List<Map<String, dynamic>>> phanCongTheoPhong,
    required Map<String, Map<String, dynamic>> phanCongTheoNhanVien,
  }) {
    final daPhanCong = danhSachPhanCong.isNotEmpty;

    if (!daPhanCong) {
      // Card viền nét đứt màu cam (Phòng chưa phân công)
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: const Color(0xFFF59E0B),
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
                // Icon phòng khám (Cam)
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

                // Tên phòng & giờ
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

                // Nút + Phân công
                InkWell(
                  onTap: () => _moSheetChonNhanVien(
                    phong: phong,
                    khoaId: khoaId,
                    tenKhoa: tenKhoa,
                    prefixKhoa: prefixKhoa,
                    tatCaNhanVienBv: tatCaNhanVienBv,
                    phanCongTheoPhong: phanCongTheoPhong,
                    phanCongTheoNhanVien: phanCongTheoNhanVien,
                  ),
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

    // Card phòng đã có phân công (1 hoặc nhiều nhân sự / vai trò)
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _moSheetChonNhanVien(
          phong: phong,
          khoaId: khoaId,
          tenKhoa: tenKhoa,
          prefixKhoa: prefixKhoa,
          tatCaNhanVienBv: tatCaNhanVienBv,
          phanCongTheoPhong: phanCongTheoPhong,
          phanCongTheoNhanVien: phanCongTheoNhanVien,
        ),
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
              // Header phòng: Icon, Tên phòng, Giờ mở cửa, Badge số lượng vai trò
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

              // Danh sách từng nhân sự & vai trò trong phòng
              ...danhSachPhanCong.map((pc) {
                final maNv = (pc['nhan_vien_id'] ?? pc['ma_nhan_vien'] ?? '')
                    .toString();
                final tenNv = (pc['ten_nhan_vien'] ?? 'Nhân viên trực')
                    .toString();
                final vaiTroNv = (pc['vai_tro'] ?? 'Trực phòng').toString();
                final roleCode = (pc['vai_tro_code'] ?? '').toString();
                final initials = _getInitials(tenNv);
                final avBg = _getAvatarBg(maNv);
                final avTxt = _getAvatarTextColor(maNv);

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
                      if (roleCode.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
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
                        const SizedBox(width: 6),
                      ],
                      // Nút xóa phân công nhân sự trực ngoài thẻ phòng
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _xoaPhanCongNhanVien(
                            phong: phong,
                            khoaId: khoaId,
                            pcData: pc,
                            soLuongDangTruc: danhSachPhanCong.length,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Color(0xFFDC2626),
                            ),
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

  Widget _buildWarningBanner(List<PhongItemPhanCong> danhSachChuaCo) {
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

  /// Xóa / hủy phân công nhân sự trực ngay tại ngoài thẻ phòng khám
  Future<void> _xoaPhanCongNhanVien({
    required PhongItemPhanCong phong,
    required String khoaId,
    required Map<String, dynamic> pcData,
    required int soLuongDangTruc,
  }) async {
    final tenNv = (pcData['ten_nhan_vien'] ?? 'nhân viên').toString();
    final roleCode = (pcData['vai_tro_code'] ?? '').toString();
    final vaiTroText = roleCode.isNotEmpty ? ' ($roleCode)' : '';

    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text('Hủy phân công',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
            'Bạn có chắc muốn hủy phân công $tenNv$vaiTroText trực tại ${phong.tenPhong}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Không', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (xacNhan != true) return;

    try {
      final docId = (pcData['_docId'] ??
              pcData['id'] ??
              '${_ngayStr}_${phong.tenPhong}_${pcData['vai_tro_code']}')
          .toString();
      final maNv =
          (pcData['nhan_vien_id'] ?? pcData['ma_nhan_vien'] ?? '').toString();

      final batch = FirebaseFirestore.instance.batch();

      if (maNv.isNotEmpty) {
        final nvRef = FirebaseFirestore.instance
            .collection('NhanVien')
            .doc(_bvid)
            .collection('danh_sach')
            .doc(maNv);

        batch.set(nvRef, {
          'trang_thai_id': 15,
          'trang_thai': 'chờ',
          'trang_thai_phan_cong': FieldValue.delete(),
          'trang_thai_phan_cong_id': FieldValue.delete(),
          'ngay_phan_cong': null,
          'phong_phan_cong': null,
          'khoa_phan_cong': null,
          'vai_tro_code': null,
          'lich_phan_cong': {
            _ngayStr: {
              'trang_thai_id': 15,
              'trang_thai': 'chờ',
              'ngay': _ngayStr,
              'ngay_cap_nhat': FieldValue.serverTimestamp(),
            },
          },
        }, SetOptions(merge: true));
      }

      final pcRef = FirebaseFirestore.instance
          .collection('PhanCong')
          .doc(_bvid)
          .collection('danh_sach')
          .doc(docId);
      batch.delete(pcRef);

      if (soLuongDangTruc <= 1) {
        final subPkRef = FirebaseFirestore.instance
            .collection('Khoa')
            .doc(_bvid)
            .collection('danh_sach')
            .doc(khoaId)
            .collection('phongKham')
            .doc(phong.tenPhong);
        batch.set(subPkRef, {
          'nhan_vien_id': null,
          'nhanVienId': null,
          'ten_nhan_vien': null,
          'vai_tro_nhan_vien': null,
        }, SetOptions(merge: true));

        final pkDocId = '${_bvid}_${khoaId}_${phong.tenPhong}';
        final rootPkRef =
            FirebaseFirestore.instance.collection('PhongKham').doc(pkDocId);
        batch.set(rootPkRef, {
          'nhan_vien_id': null,
          'nhanVienId': null,
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã hủy phân công $tenNv trực ${phong.tenPhong}.'),
          backgroundColor: const Color(0xFF475569),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi hủy phân công: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  /// Nút Lịch sử phân công trực thay cho khung trắng dư
  Widget _buildLichSuPhanCongButton() {
    return InkWell(
      onTap: _moSheetLichSuPhanCong,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFCBD5E1),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lịch sử phân công trực',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Xem lại các ca trực đã phân công theo ngày',
                    style: TextStyle(
                      fontSize: 11.5,
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
      ),
    );
  }

  /// Modal hiển thị lịch sử phân công trực theo ngày được chọn
  void _moSheetLichSuPhanCong() {
    DateTime ngayXemLichSu = _ngayDuocChon;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final ngayStr =
              '${ngayXemLichSu.year}-${ngayXemLichSu.month.toString().padLeft(2, '0')}-${ngayXemLichSu.day.toString().padLeft(2, '0')}';

          return FractionallySizedBox(
            heightFactor: 0.85,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Thanh kéo nhỏ
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Tiêu đề
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lịch sử phân công trực',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Chọn ngày để xem các ca trực đã phân công',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // THANH ĐIỀU HƯỚNG CHỌN NGÀY ĐỂ XEM
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
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
                          onPressed: () {
                            setSheetState(() {
                              ngayXemLichSu = ngayXemLichSu
                                  .subtract(const Duration(days: 1));
                            });
                          },
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Color(0xFF334155),
                          ),
                          splashRadius: 20,
                        ),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: ngayXemLichSu,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                ngayXemLichSu = picked;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 18,
                                  color: Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _dinhDangThuNgay(ngayXemLichSu),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setSheetState(() {
                              ngayXemLichSu =
                                  ngayXemLichSu.add(const Duration(days: 1));
                            });
                          },
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF334155),
                          ),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // Thanh trạng thái ngày đang xem & nút chọn hôm nay
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'Ngày xem: $ngayStr',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            setSheetState(() {
                              ngayXemLichSu = DateTime.now();
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Hôm nay',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Danh sách ca trực trong ngày đã chọn từ Firestore
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('PhanCong')
                          .doc(_bvid)
                          .collection('danh_sach')
                          .where('ngay', isEqualTo: ngayStr)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.event_busy_rounded,
                                      size: 30,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Không có ca trực nào',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Chưa có nhân sự nào được phân công trực trong ngày ${_dinhDangThuNgay(ngayXemLichSu)}.\nHãy dùng mũi tên hoặc bấm vào ngày để chọn ngày khác.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF94A3B8),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          itemCount: docs.length,
                          itemBuilder: (ctx, idx) {
                            final item = docs[idx].data();
                            final tenPhong = (item['ten_phong'] ??
                                    item['phong_id'] ??
                                    '')
                                .toString();
                            final tenKhoa =
                                (item['ten_khoa'] ?? '').toString();
                            final tenNv = (item['ten_nhan_vien'] ??
                                    'Nhân viên')
                                .toString();
                            final vaiTro =
                                (item['vai_tro'] ?? '').toString();
                            final maNv = (item['ma_nhan_vien'] ??
                                    item['nhan_vien_id'] ??
                                    '')
                                .toString();
                            final roleCode =
                                (item['vai_tro_code'] ?? '').toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x04000000),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF16A34A),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              tenPhong,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (tenKhoa.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '• $tenKhoa',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$tenNv ($vaiTro) • $maNv',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (roleCode.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                            color:
                                                const Color(0xFFBFDBFE)),
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
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSaveButton({
    required int soPhongDaPhanCong,
    required int tongSoPhong,
  }) {
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
                      'Dữ liệu phân công trực ngày $_ngayStr đã được lưu hoàn tất ($soPhongDaPhanCong/$tongSoPhong phòng).',
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

/// Modal Bottom Sheet chọn nhân viên trực (Chỉ lấy nhân viên đúng bệnh viện & đúng chuyên khoa)
class _ChonNhanVienModal extends StatefulWidget {
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

  const _ChonNhanVienModal({
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
  State<_ChonNhanVienModal> createState() => _ChonNhanVienModalState();
}

class _ChonNhanVienModalState extends State<_ChonNhanVienModal> {
  String _tuKhoa = '';
  NhanVienModel? _nhanVienDuocChon;
  bool _isSaving = false;

  List<Map<String, dynamic>> get _danhSachDangTruc =>
      widget.phanCongTheoPhong[widget.phong.tenPhong] ?? [];

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'NV';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color _getAvatarBg(String id) {
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

  Color _getAvatarTextColor(String id) {
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

  /// Lọc danh sách nhân viên:
  /// 1. Phải thuộc đúng bệnh viện (benhVienId)
  /// 2. Phải thuộc đúng chuyên khoa được phân công (tenKhoa hoặc prefixKhoa)
  List<NhanVienModel> _locNhanVienTheoChuyenKhoa() {
    final tenKhoaChuan = widget.tenKhoa.trim().toLowerCase();
    final prefixChuan = widget.prefixKhoa.trim().toLowerCase();

    return widget.tatCaNhanVienBv.where((nv) {
      // 0. Phải là nhân sự đã kích hoạt (yêu cầu từ người dùng)
      if (!nv.daKichHoat) return false;

      // 1. Kiểm tra bệnh viện
      if (nv.benhVienId.isNotEmpty &&
          widget.benhVienId.isNotEmpty &&
          nv.benhVienId != widget.benhVienId) {
        return false;
      }

      // 2. Kiểm tra chuyên khoa được phân công lúc tạo
      final nvKhoa = nv.khoa.trim().toLowerCase();
      final matchKhoa =
          nvKhoa.isNotEmpty &&
          (nvKhoa == tenKhoaChuan ||
              nvKhoa.contains(tenKhoaChuan) ||
              tenKhoaChuan.contains(nvKhoa));

      final matchPrefix =
          prefixChuan.isNotEmpty &&
          (nv.maNv.toLowerCase().contains('_${prefixChuan}_') ||
              nv.id.toLowerCase().contains('_${prefixChuan}_') ||
              nv.maNv.toLowerCase().endsWith('_$prefixChuan') ||
              nv.id.toLowerCase().endsWith('_$prefixChuan'));

      if (!matchKhoa && !matchPrefix) {
        return false;
      }

      // 3. Tìm kiếm theo từ khóa
      if (_tuKhoa.isNotEmpty) {
        final matchTen = nv.hoTen.toLowerCase().contains(_tuKhoa.toLowerCase());
        final matchMa = nv.maNv.toLowerCase().contains(_tuKhoa.toLowerCase());
        return matchTen || matchMa;
      }

      return true;
    }).toList();
  }

  /// Lưu phân công trực vào Firestore:
  /// ID collection chuẩn định dạng: `tg_tenkhoa_vaitro` (ví dụ: `2026-11-18_DL001_LT001`)
  Future<void> _xacNhanPhanCong(NhanVienModel nv) async {
    setState(() => _isSaving = true);
    try {
      final roleCode = _PhanCongScreenState.taoMaVaiTroPhanCong(
        nv,
        _danhSachDangTruc,
      );
      final docId = '${widget.ngayStr}_${widget.phong.tenPhong}_$roleCode';
      final batch = FirebaseFirestore.instance.batch();

      // 1. Cập nhật nhân viên được phân công vào NhanVien/{bvid}/danh_sach/{maNv}
      // Trạng thái: id = 16, ten_trang_thai = "đã phân công" (khớp collection TrangThai doc 16)
      final nvDocId = nv.id.isNotEmpty ? nv.id : nv.maNv;
      final nvRef = FirebaseFirestore.instance
          .collection('NhanVien')
          .doc(widget.benhVienId)
          .collection('danh_sach')
          .doc(nvDocId);

      batch.set(nvRef, {
        'trang_thai_id': 16,
        'trang_thai': 'đã phân công',
        'trang_thai_phan_cong': FieldValue.delete(),
        'trang_thai_phan_cong_id': FieldValue.delete(),
        'ngay_phan_cong': widget.ngayStr,
        'phong_phan_cong': widget.phong.tenPhong,
        'khoa_phan_cong': widget.tenKhoa,
        'vai_tro_code': roleCode,
        'lich_phan_cong': {
          widget.ngayStr: {
            'trang_thai_id': 16,
            'trang_thai': 'đã phân công',
            'phong': widget.phong.tenPhong,
            'khoa': widget.tenKhoa,
            'vai_tro_code': roleCode,
            'doc_id': docId,
            'ngay': widget.ngayStr,
            'ngay_cap_nhat': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));

      // 2. Lưu vào collection chuẩn PhanCong/{benhVienId}/danh_sach/{docId}
      final pcRef = FirebaseFirestore.instance
          .collection('PhanCong')
          .doc(widget.benhVienId)
          .collection('danh_sach')
          .doc(docId);

      batch.set(pcRef, {
        'id': docId,
        'ngay': widget.ngayStr,
        'benh_vien_id': widget.benhVienId,
        'khoa_id': widget.khoaId,
        'ten_khoa': widget.tenKhoa,
        'prefix_khoa': widget.prefixKhoa,
        'phong_id': widget.phong.tenPhong,
        'ten_phong': widget.phong.tenPhong,
        'vai_tro_code': roleCode,
        'nhan_vien_id': nv.maNv,
        'ma_nhan_vien': nv.maNv,
        'ten_nhan_vien': nv.hoTen,
        'vai_tro': nv.vaiTro,
        'trang_thai_id': 16,
        'trang_thai': 'đã phân công',
        'ngay_cap_nhat': FieldValue.serverTimestamp(),
      });

      // 3. Cập nhật subcollection Khoa/.../phongKham
      final subPkRef = FirebaseFirestore.instance
          .collection('Khoa')
          .doc(widget.benhVienId)
          .collection('danh_sach')
          .doc(widget.khoaId)
          .collection('phongKham')
          .doc(widget.phong.tenPhong);

      batch.set(subPkRef, {
        'nhan_vien_id': nv.maNv,
        'nhanVienId': nv.maNv,
        'ten_nhan_vien': nv.hoTen,
        'vai_tro_nhan_vien': nv.vaiTro,
      }, SetOptions(merge: true));

      // 4. Cập nhật root collection PhongKham
      final pkDocId =
          '${widget.benhVienId}_${widget.khoaId}_${widget.phong.tenPhong}';
      final rootPkRef = FirebaseFirestore.instance
          .collection('PhongKham')
          .doc(pkDocId);

      batch.set(rootPkRef, {
        'nhan_vien_id': nv.maNv,
        'nhanVienId': nv.maNv,
      }, SetOptions(merge: true));

      await batch.commit();

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



  /// Hủy phân công toàn bộ vai trò phòng này (chuyển trạng thái nhân viên về 15 "chờ")
  Future<void> _huyToanBoPhanCongPhong() async {
    setState(() => _isSaving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final pc in _danhSachDangTruc) {
        final docId =
            (pc['id'] ??
                    pc['_docId'] ??
                    '${widget.ngayStr}_${widget.phong.tenPhong}_${pc['vai_tro_code']}')
                .toString();
        final maNv = (pc['nhan_vien_id'] ?? pc['ma_nhan_vien'] ?? '')
            .toString();

        if (maNv.isNotEmpty) {
          final nvRef = FirebaseFirestore.instance
              .collection('NhanVien')
              .doc(widget.benhVienId)
              .collection('danh_sach')
              .doc(maNv);

          batch.set(nvRef, {
            'trang_thai_id': 15,
            'trang_thai': 'chờ',
            'trang_thai_phan_cong': FieldValue.delete(),
            'trang_thai_phan_cong_id': FieldValue.delete(),
            'ngay_phan_cong': null,
            'phong_phan_cong': null,
            'khoa_phan_cong': null,
            'vai_tro_code': null,
            'lich_phan_cong': {
              widget.ngayStr: {
                'trang_thai_id': 15,
                'trang_thai': 'chờ',
                'ngay': widget.ngayStr,
                'ngay_cap_nhat': FieldValue.serverTimestamp(),
              },
            },
          }, SetOptions(merge: true));
        }

        final pcRef = FirebaseFirestore.instance
            .collection('PhanCong')
            .doc(widget.benhVienId)
            .collection('danh_sach')
            .doc(docId);
        batch.delete(pcRef);
      }

      final subPkRef = FirebaseFirestore.instance
          .collection('Khoa')
          .doc(widget.benhVienId)
          .collection('danh_sach')
          .doc(widget.khoaId)
          .collection('phongKham')
          .doc(widget.phong.tenPhong);
      batch.set(subPkRef, {
        'nhan_vien_id': null,
        'nhanVienId': null,
        'ten_nhan_vien': null,
        'vai_tro_nhan_vien': null,
      }, SetOptions(merge: true));

      final pkDocId =
          '${widget.benhVienId}_${widget.khoaId}_${widget.phong.tenPhong}';
      final rootPkRef = FirebaseFirestore.instance
          .collection('PhongKham')
          .doc(pkDocId);
      batch.set(rootPkRef, {
        'nhan_vien_id': null,
        'nhanVienId': null,
      }, SetOptions(merge: true));

      await batch.commit();

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
        ? _PhanCongScreenState.taoMaVaiTroPhanCong(
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
          // Thanh kéo trên cùng
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

          // Tiêu đề & nút đóng X
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

          // Ô tìm kiếm nhân viên
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

          // Nhãn nhóm chuyên khoa
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

                      // 1. Kiểm tra xem nhân sự này đang trực ở phòng này không
                      Map<String, dynamic>? dangTrucPhongNay;
                      for (final pc in _danhSachDangTruc) {
                        final assignedNv =
                            (pc['nhan_vien_id'] ?? pc['ma_nhan_vien'] ?? '')
                                .toString();
                        if (assignedNv == nv.maNv) {
                          dangTrucPhongNay = pc;
                          break;
                        }
                      }
                      final isCurrentlyThisRoom = dangTrucPhongNay != null;

                      // 2. Kiểm tra xem nhân sự này đang trực ở phòng khác trong ngày không
                      final phanCongKhac = widget.phanCongTheoNhanVien[nv.maNv];
                      final isBusyOtherRoom =
                          phanCongKhac != null &&
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

                      final initials = _getInitials(nv.hoTen);
                      final avBg = _getAvatarBg(nv.maNv);
                      final avTxt = _getAvatarTextColor(nv.maNv);

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
                        trangThaiText = 'Chờ phân công';
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
                              // Avatar
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

                              // Tên, Mã nhân viên & Vai trò
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

                              // Trạng thái (Đang rảnh / Đang có ca khác)
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

                              // Checkbox / Radio
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

          // Nút xác nhận phân công (hiển thị trước mã vai trò sẽ gán)
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

          // Nút Hủy toàn bộ phân công phòng này nếu phòng đã có người trực
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

/// CustomPainter vẽ viền nét đứt (Dashed Border) cho phòng chưa phân công
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
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
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}
