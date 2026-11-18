import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_session.dart';

import '../../config/app_routes.dart';
import '../../models/nhan_vien_model.dart';
import '../../services/nhan_vien_service.dart';
import 'CapTK_Scream.dart';

export '../../models/nhan_vien_model.dart' show TaiKhoanItem, DotCapTaiKhoan;

class StaffAccountStore {
  // Mật khẩu mặc định chung cho toàn bộ tài khoản nhân viên được cấp
  static const String matKhauMacDinh = '123456';

  // Lưu đợt cấp vừa tạo trong bộ nhớ phiên làm việc (không hardcode)
  static DotCapTaiKhoan? dotCapGanNhat;
  static final List<DotCapTaiKhoan> lichSuCacDot = [];

  static void luuDotCap(DotCapTaiKhoan dot) {
    dotCapGanNhat = dot;
    lichSuCacDot.removeWhere((d) => d.id == dot.id);
    lichSuCacDot.insert(0, dot);
  }
}

class DanhSachTaiKhoanDaTaoScreen extends StatefulWidget {
  final String? benhVienId;
  final String? tenKhoa;
  final String? vaiTro;
  final int? soLuong;
  final List<TaiKhoanItem>? danhSachTaiKhoan;

  const DanhSachTaiKhoanDaTaoScreen({
    super.key,
    this.benhVienId,
    this.tenKhoa,
    this.vaiTro,
    this.soLuong,
    this.danhSachTaiKhoan,
  });

  @override
  State<DanhSachTaiKhoanDaTaoScreen> createState() =>
      _DanhSachTaiKhoanDaTaoScreenState();
}

class _DanhSachTaiKhoanDaTaoScreenState
    extends State<DanhSachTaiKhoanDaTaoScreen> {
  final NhanVienService _nhanVienService = NhanVienService();
  DotCapTaiKhoan? _selectedBatch;
  bool _isLoading = true;

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
    _khoiTaoDuLieu();
  }

  Future<void> _khoiTaoDuLieu() async {
    // 1. Nếu có truyền qua constructor
    if (widget.danhSachTaiKhoan != null &&
        widget.danhSachTaiKhoan!.isNotEmpty) {
      final listChuaKichHoat = widget.danhSachTaiKhoan!
          .where((e) => e.trangThai == 'Đợi kích hoạt' || e.trangThai == 'Chưa kích hoạt')
          .toList();

      final batch = DotCapTaiKhoan(
        tenKhoa: widget.tenKhoa ??
            StaffAccountStore.dotCapGanNhat?.tenKhoa ??
            'Khoa',
        vaiTro: widget.vaiTro ??
            StaffAccountStore.dotCapGanNhat?.vaiTro ??
            'Nhân viên',
        soLuong: listChuaKichHoat.length,
        danhSachTaiKhoan: listChuaKichHoat,
      );
      if (mounted) {
        setState(() {
          _selectedBatch = listChuaKichHoat.isNotEmpty ? batch : null;
          _isLoading = false;
        });
      }
      if (listChuaKichHoat.isNotEmpty) {
        StaffAccountStore.luuDotCap(batch);
      }
      return;
    }

    // 2. Nếu trong store đã có đợt vừa tạo
    if (StaffAccountStore.dotCapGanNhat != null) {
      final listChuaKichHoat = StaffAccountStore.dotCapGanNhat!.danhSachTaiKhoan
          .where((e) => e.trangThai == 'Đợi kích hoạt' || e.trangThai == 'Chưa kích hoạt')
          .toList();

      if (listChuaKichHoat.isNotEmpty) {
        final batch = DotCapTaiKhoan(
          id: StaffAccountStore.dotCapGanNhat!.id,
          tenKhoa: StaffAccountStore.dotCapGanNhat!.tenKhoa,
          vaiTro: StaffAccountStore.dotCapGanNhat!.vaiTro,
          soLuong: listChuaKichHoat.length,
          danhSachTaiKhoan: listChuaKichHoat,
          thoiGian: StaffAccountStore.dotCapGanNhat!.thoiGian,
        );
        if (mounted) {
          setState(() {
            _selectedBatch = batch;
            _isLoading = false;
          });
        }
        return;
      }
    }

    // 3. Đọc dữ liệu tài khoản chưa kích hoạt từ Firebase Firestore thông qua service
    try {
      final list = await _nhanVienService.layDanhSachTaiKhoanChuaKichHoat(_getBenhVienId());
      if (list.isNotEmpty) {
        final batch = DotCapTaiKhoan(
          tenKhoa: widget.tenKhoa ?? 'Toàn viện',
          vaiTro: widget.vaiTro ?? 'Nhân viên',
          soLuong: list.length,
          danhSachTaiKhoan: list,
        );

        StaffAccountStore.luuDotCap(batch);

        if (mounted) {
          setState(() {
            _selectedBatch = batch;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _selectedBatch = null;
        _isLoading = false;
      });
    }
  }

  void _saoChep(BuildContext context, String text, String thongBao) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(thongBao),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _saoChepTatCa(BuildContext context) {
    final batch = _selectedBatch;
    if (batch == null) return;

    final buffer = StringBuffer();
    buffer.writeln(
      '=== DANH SÁCH TÀI KHOẢN ${batch.vaiTro} - ${batch.tenKhoa} ===',
    );
    buffer.writeln('Mật khẩu chung: ${StaffAccountStore.matKhauMacDinh}');
    for (int i = 0; i < batch.danhSachTaiKhoan.length; i++) {
      final item = batch.danhSachTaiKhoan[i];
      buffer.writeln('${i + 1}. TK: ${item.maTk} | MK: ${item.matKhau}');
    }
    _saoChep(
      context,
      buffer.toString(),
      'Đã sao chép toàn bộ danh sách tài khoản!',
    );
  }


  Future<void> _xoaTaiKhoan(TaiKhoanItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Xác nhận xóa tài khoản?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản ${item.maTk} không? Tài khoản sẽ bị xóa khỏi hệ thống.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _nhanVienService.xoaNhanVien(item.id ?? item.maTk, _getBenhVienId());

      if (!mounted) return;

      setState(() {
        if (_selectedBatch != null) {
          final updatedList = List<TaiKhoanItem>.from(_selectedBatch!.danhSachTaiKhoan)
            ..removeWhere((tk) => tk.maTk == item.maTk);

          if (updatedList.isEmpty) {
            _selectedBatch = null;
          } else {
            _selectedBatch = DotCapTaiKhoan(
              id: _selectedBatch!.id,
              tenKhoa: _selectedBatch!.tenKhoa,
              vaiTro: _selectedBatch!.vaiTro,
              soLuong: updatedList.length,
              danhSachTaiKhoan: updatedList,
              thoiGian: _selectedBatch!.thoiGian,
            );
          }

          if (StaffAccountStore.dotCapGanNhat?.id == _selectedBatch?.id || _selectedBatch == null) {
            StaffAccountStore.dotCapGanNhat = _selectedBatch;
          }

          for (int i = 0; i < StaffAccountStore.lichSuCacDot.length; i++) {
            final dot = StaffAccountStore.lichSuCacDot[i];
            if (dot.danhSachTaiKhoan.any((tk) => tk.maTk == item.maTk)) {
              final newDotList = dot.danhSachTaiKhoan
                  .where((tk) => tk.maTk != item.maTk)
                  .toList();
              if (newDotList.isEmpty) {
                StaffAccountStore.lichSuCacDot.removeAt(i);
                i--;
              } else {
                StaffAccountStore.lichSuCacDot[i] = DotCapTaiKhoan(
                  id: dot.id,
                  tenKhoa: dot.tenKhoa,
                  vaiTro: dot.vaiTro,
                  soLuong: newDotList.length,
                  danhSachTaiKhoan: newDotList,
                  thoiGian: dot.thoiGian,
                );
              }
            }
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa tài khoản ${item.maTk}'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xóa tài khoản: $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  void _hienThiLichSuCacDot() {
    final cacDot = StaffAccountStore.lichSuCacDot;
    if (cacDot.isEmpty) return;

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lịch sử các đợt cấp tài khoản',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                    ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: cacDot.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final dot = cacDot[index];
                      final isSelected = dot.id == _selectedBatch?.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFF1F5F9),
                          child: Icon(
                            Icons.group_rounded,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF64748B),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          '${dot.soLuong} tài khoản ${dot.vaiTro}',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF0F172A),
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${dot.tenKhoa} • ${dot.thoiGian.hour.toString().padLeft(2, '0')}:${dot.thoiGian.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF0284C7),
                                size: 20,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedBatch = dot;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final batch = _selectedBatch;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                // Header chuẩn
                _buildHeader(context),

                // Nội dung danh sách
                Expanded(
                  child: batch == null || batch.danhSachTaiKhoan.isEmpty
                      ? _buildEmptyState()
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hộp thông báo xanh lá
                              _buildSuccessBanner(batch),
                              const SizedBox(height: 16),

                              // Tiêu đề & nút Sao chép tất cả
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Chi tiết tài khoản & Mật khẩu',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Mật khẩu khởi tạo chung: ${StaffAccountStore.matKhauMacDinh}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: () => _saoChepTatCa(context),
                                    borderRadius: BorderRadius.circular(6),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        'Sao chép tất cả',
                                        style: TextStyle(
                                          color: Color(0xFF0284C7),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Danh sách thẻ tài khoản
                              for (int i = 0;
                                  i < batch.danhSachTaiKhoan.length;
                                  i++) ...[
                                _buildAccountCard(
                                  context,
                                  i + 1,
                                  batch.danhSachTaiKhoan[i],
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ),
                        ),
                ),

                // Các nút dưới đáy
                _buildBottomButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 54, color: const Color(0xFF16A34A)),
            const SizedBox(height: 12),
            const Text(
              'Không có tài khoản đợi kích hoạt',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tất cả tài khoản nhân viên đã được kích hoạt hoặc chưa có tài khoản mới tạo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CapTaiKhoanNhanVienScreen(benhVienId: _getBenhVienId()),
                  ),
                );
              },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Cấp Tài Khoản Mới'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const Text(
            'Danh Sách Tài Khoản Đã Tạo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          Row(
            children: [
              if (StaffAccountStore.lichSuCacDot.length > 1) ...[
                InkWell(
                  onTap: _hienThiLichSuCacDot,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Đang chuẩn bị file danh sách tài khoản...',
                      ),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.file_download_outlined,
                    size: 20,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(DotCapTaiKhoan batch) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã tạo thành công ${batch.danhSachTaiKhoan.length} tài khoản',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${batch.tenKhoa} • Vai trò: ${batch.vaiTro} (Đợi kích hoạt)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (StaffAccountStore.lichSuCacDot.length > 1) ...[
            InkWell(
              onTap: _hienThiLichSuCacDot,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Text(
                  'Đổi đợt',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, int index, TaiKhoanItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$index. ${item.maTk}',
                style: const TextStyle(
                  color: Color(0xFF0284C7),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.trangThai,
                      style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _xoaTaiKhoan(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Mật khẩu: ',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      item.matKhau,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _saoChep(
                    context,
                    item.matKhau,
                    'Đã sao chép mật khẩu: ${item.matKhau}',
                  ),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Chép',
                      style: TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đang xuất danh sách tài khoản ra file Excel / PDF...',
                    ),
                    backgroundColor: Color(0xFF0284C7),
                  ),
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 20),
              label: const Text(
                'Xuất File / In Danh Sách',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.NhanSuScreen,
                  (route) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Quay lại trang Nhân sự',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}