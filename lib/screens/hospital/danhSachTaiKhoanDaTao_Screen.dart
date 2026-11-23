import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../config/app_session.dart';
import '../../config/app_routes.dart';
import '../../models/nhan_vien_model.dart';
import '../../services/nhan_vien_service.dart';
import '../../services/xuat_pdf_service.dart';
import 'CapTK_Scream.dart';

export '../../models/nhan_vien_model.dart' show TaiKhoanItem, DotCapTaiKhoan;

class StaffAccountStore {
  // Mật khẩu mặc định chung cho toàn bộ tài khoản nhân viên được cấp
  static const String matKhauMacDinh = '123456';

  // Lưu đợt cấp vừa tạo trong bộ nhớ phiên làm việc
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

  // Tab đang xem trên màn hình chính: 0 = Đợi kích hoạt, 1 = Đã kích hoạt
  int _selectedTabIndex = 0;

  // Bộ lọc vai trò (dùng Spinner / Dropdown): 'Tất cả' hoặc vai trò cụ thể
  String _selectedRoleFilter = 'Tất cả';

  // Danh sách toàn bộ tài khoản
  List<TaiKhoanItem> _allAccounts = [];
  bool _isLoading = true;
  String _tenBenhVien = 'Bệnh viện';

  // Đợt vừa tạo từ màn hình trước (nếu có)
  DotCapTaiKhoan? _vuaTaoBatch;

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
    setState(() => _isLoading = true);

    // 1. Nếu có đợt vừa tạo truyền qua constructor
    if (widget.danhSachTaiKhoan != null &&
        widget.danhSachTaiKhoan!.isNotEmpty) {
      _vuaTaoBatch = DotCapTaiKhoan(
        tenKhoa: widget.tenKhoa ?? 'Khoa',
        vaiTro: widget.vaiTro ?? 'Nhân viên',
        soLuong: widget.danhSachTaiKhoan!.length,
        danhSachTaiKhoan: widget.danhSachTaiKhoan!,
      );
      StaffAccountStore.luuDotCap(_vuaTaoBatch!);
    } else if (StaffAccountStore.dotCapGanNhat != null) {
      _vuaTaoBatch = StaffAccountStore.dotCapGanNhat;
    }

    // 2. Tải toàn bộ tài khoản từ Firestore
    try {
      final bvid = _getBenhVienId();
      final accounts = await _nhanVienService.layTatCaTaiKhoan(bvid);

      // Nếu có danh sách từ constructor nhưng Firestore chưa kịp sync hết, gộp vào
      if (widget.danhSachTaiKhoan != null &&
          widget.danhSachTaiKhoan!.isNotEmpty) {
        for (final item in widget.danhSachTaiKhoan!) {
          if (!accounts.any((a) => a.maTk == item.maTk)) {
            accounts.add(item);
          }
        }
      }

      // Lấy tên bệnh viện
      String tenBv = '';
      try {
        tenBv = await _nhanVienService.layTenBenhVien(bvid);
      } catch (_) {}
      if (tenBv.isEmpty) {
        try {
          final authUser = FirebaseAuth.instance.currentUser;
          if (authUser?.displayName != null &&
              authUser!.displayName!.isNotEmpty) {
            tenBv = authUser.displayName!;
          }
        } catch (_) {}
      }
      if (tenBv.isEmpty) tenBv = 'Bệnh viện MediConnect';

      if (mounted) {
        setState(() {
          _allAccounts = accounts;
          _tenBenhVien = tenBv;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Lỗi tải danh sách tài khoản: $e');
      if (mounted) {
        setState(() {
          _allAccounts = widget.danhSachTaiKhoan ?? [];
          _isLoading = false;
        });
      }
    }
  }

  // Danh sách tài khoản đợi kích hoạt
  List<TaiKhoanItem> get _danhSachDoiKichHoat {
    return _allAccounts.where((tk) => !tk.daKichHoat).toList();
  }

  // Danh sách tài khoản đã kích hoạt
  List<TaiKhoanItem> get _danhSachDaKichHoat {
    return _allAccounts.where((tk) => tk.daKichHoat).toList();
  }

  // Tập hợp danh sách các vai trò để hiển thị trong Spinner
  List<String> _layDanhSachVaiTro(List<TaiKhoanItem> sourceList) {
    final setRoles = <String>{};
    for (final item in sourceList) {
      if (item.vaiTro.isNotEmpty) {
        setRoles.add(item.vaiTro.trim());
      }
    }
    const defaultRoles = ['Bác sĩ', 'Điều dưỡng', 'Dược sĩ', 'Lễ tân', 'CSKH'];
    for (final r in defaultRoles) {
      if (!setRoles.contains(r)) {
        setRoles.add(r);
      }
    }

    return ['Tất cả', ...setRoles];
  }

  // Lọc theo vai trò và SẮP XẾP TỪ MỚI ĐẾN CŨ
  List<TaiKhoanItem> _locVaSapXep(
    List<TaiKhoanItem> sourceList,
    String roleFilter,
  ) {
    var filtered = sourceList;

    // 1. Lọc theo vai trò
    if (roleFilter != 'Tất cả') {
      filtered = filtered.where((item) {
        final r = item.vaiTro.toLowerCase();
        final filter = roleFilter.toLowerCase();
        if (r == filter) return true;
        if (filter == 'bác sĩ' &&
            (r.contains('bác sĩ') || item.role == 'doctor')) {
          return true;
        }
        if (filter == 'điều dưỡng' &&
            (r.contains('điều dưỡng') || item.role == 'nurse')) {
          return true;
        }
        if (filter == 'dược sĩ' &&
            (r.contains('dược') || item.role == 'pharmacist')) {
          return true;
        }
        if (filter == 'lễ tân' &&
            (r.contains('lễ tân') || item.role == 'receptionist')) {
          return true;
        }
        if (filter == 'cskh' &&
            (r.contains('cskh') || item.role == 'customerSupport')) {
          return true;
        }

        return false;
      }).toList();
    }

    // 2. Sắp xếp thứ tự TỪ MỚI ĐẾN CŨ
    final result = List<TaiKhoanItem>.from(filtered);
    result.sort((a, b) {
      if (a.ngayTao != null && b.ngayTao != null) {
        final cmp = b.ngayTao!.compareTo(a.ngayTao!);
        if (cmp != 0) return cmp;
      } else if (a.ngayTao != null) {
        return -1;
      } else if (b.ngayTao != null) {
        return 1;
      }

      final numA = _extractTrailingNumber(a.maTk);
      final numB = _extractTrailingNumber(b.maTk);
      if (numA != null && numB != null) {
        return numB.compareTo(numA);
      }

      return b.maTk.compareTo(a.maTk);
    });

    return result;
  }

  int? _extractTrailingNumber(String code) {
    final match = RegExp(r'(\d+)$').firstMatch(code);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
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

  void _saoChepTatCa(BuildContext context, List<TaiKhoanItem> list) {
    if (list.isEmpty) return;

    final tabName = _selectedTabIndex == 0 ? 'ĐỢI KÍCH HOẠT' : 'ĐÃ KÍCH HOẠT';
    final buffer = StringBuffer();
    buffer.writeln(
      '=== DANH SÁCH TÀI KHOẢN $tabName ($_selectedRoleFilter) ===',
    );
    buffer.writeln('Bệnh viện: $_tenBenhVien');
    buffer.writeln('Mật khẩu khởi tạo: ${StaffAccountStore.matKhauMacDinh}');
    buffer.writeln('Tổng số: ${list.length} tài khoản\n');

    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      final vaiTroStr = item.vaiTro.isNotEmpty ? item.vaiTro : 'Nhân viên';
      final khoaStr = item.khoa.isNotEmpty ? ' • ${item.khoa}' : '';
      buffer.writeln(
        '${i + 1}. TK: ${item.maTk} | MK: ${item.matKhau} | $vaiTroStr$khoaStr',
      );
    }

    _saoChep(
      context,
      buffer.toString(),
      'Đã sao chép toàn bộ ${list.length} tài khoản!',
    );
  }

  Future<void> _xoaTaiKhoan(TaiKhoanItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xác nhận xóa tài khoản?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản ${item.maTk} không? Tài khoản sẽ bị xóa hoàn toàn khỏi hệ thống.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
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
            child: const Text(
              'Xóa',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _nhanVienService.xoaNhanVien(
        item.id ?? item.maTk,
        _getBenhVienId(),
      );

      if (!mounted) return;

      setState(() {
        _allAccounts.removeWhere((tk) => tk.maTk == item.maTk);
        if (_vuaTaoBatch != null) {
          final newBatchList = _vuaTaoBatch!.danhSachTaiKhoan
              .where((tk) => tk.maTk != item.maTk)
              .toList();
          _vuaTaoBatch = DotCapTaiKhoan(
            id: _vuaTaoBatch!.id,
            tenKhoa: _vuaTaoBatch!.tenKhoa,
            vaiTro: _vuaTaoBatch!.vaiTro,
            soLuong: newBatchList.length,
            danhSachTaiKhoan: newBatchList,
            thoiGian: _vuaTaoBatch!.thoiGian,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa tài khoản ${item.maTk} thành công'),
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

  /// Hộp thoại xác nhận xuất file: "bạn có muốn xuất file không và chọn có hoặc không"
  Future<void> _xacNhanXuatFilePdf(
    List<TaiKhoanItem> listToExport, {
    String? tieuDeTuyChinh,
    String? vaiTroTuyChinh,
  }) async {
    if (listToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có tài khoản nào trong danh sách để xuất file.'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                color: Color(0xFF0284C7),
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Xác nhận xuất file',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Bạn có muốn xuất file PDF cho danh sách ${listToExport.length} tài khoản này không?',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dCtx, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Không',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Có',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (xacNhan == true) {
      await _xuatFilePdf(
        listToExport,
        tieuDeTuyChinh: tieuDeTuyChinh,
        vaiTroTuyChinh: vaiTroTuyChinh,
      );
    }
  }

  /// Xuất file PDF danh sách tài khoản thực sự
  Future<void> _xuatFilePdf(
    List<TaiKhoanItem> listToExport, {
    String? tieuDeTuyChinh,
    String? vaiTroTuyChinh,
  }) async {
    if (listToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không có tài khoản nào trong danh sách để xuất file PDF.',
          ),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final tabTitle =
        tieuDeTuyChinh ??
        (_selectedTabIndex == 0
            ? 'Danh Sách Tài Khoản Đợi Kích Hoạt'
            : 'Danh Sách Tài Khoản Đã Kích Hoạt');

    final roleFilter = vaiTroTuyChinh ?? _selectedRoleFilter;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 10),
              Text('Đang tạo và chuẩn bị tệp PDF...'),
            ],
          ),
          backgroundColor: Color(0xFF0284C7),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await XuatPdfService.xuatVaInPdf(
        tenBenhVien: _tenBenhVien,
        tieuDeTrang: tabTitle,
        vaiTroDangLoc: roleFilter,
        danhSach: listToExport,
      );
    } catch (e) {
      debugPrint('⚠️ Lỗi xuất file PDF: $e');
      if (mounted) {
        if (e.toString().contains('MissingPluginException') ||
            e.toString().contains('net.nfet.printing')) {
          _hienThiDialogMissingPlugin(context, listToExport);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xuất file PDF: $e'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Hiển thị hộp thoại hướng dẫn khi gặp lỗi MissingPluginException do app chưa được build lại sau khi thêm plugin
  void _hienThiDialogMissingPlugin(
    BuildContext context,
    List<TaiKhoanItem> listToExport,
  ) {
    showDialog<void>(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.restart_alt_rounded,
                color: Color(0xFFD97706),
                size: 26,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cần Khởi Động Lại Ứng Dụng',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thư viện in/xuất file PDF (printing) vừa được thêm mới vào dự án.',
                style: TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFD97706),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Do đây là plugin có mã nguồn Native (Android), cơ chế Hot Reload không thể nạp plugin mới. Bạn cần Dừng chạy (Stop) và chạy lại (flutter run) để sử dụng tính năng in PDF.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Trong lúc chờ chạy lại ứng dụng, bạn có thể bấm sao chép toàn bộ danh sách tài khoản & mật khẩu bên dưới:',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dCtx);
                _saoChepTatCa(context, listToExport);
              },
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Sao chép danh sách'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0284C7),
                side: const BorderSide(color: Color(0xFF0284C7)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
              child: const Text('Đã hiểu'),
            ),
          ],
        );
      },
    );
  }

  /// Mở hộp thoại "Lịch Sử Tài Khoản Đã Tạo" khi bấm nút Lịch Sử ở góc trên bên phải
  void _moLichSuTaiKhoan() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final doiList = _danhSachDoiKichHoat;
            final daList = _danhSachDaKichHoat;

            final activeSourceList = _selectedTabIndex == 0 ? doiList : daList;
            final roles = _layDanhSachVaiTro(activeSourceList);

            if (!roles.contains(_selectedRoleFilter)) {
              _selectedRoleFilter = 'Tất cả';
            }

            final filteredHistoryList = _locVaSapXep(
              activeSourceList,
              _selectedRoleFilter,
            );

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Thanh kéo đầu modal
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header của Modal Lịch Sử
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE0F2FE),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                color: Color(0xFF0284C7),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lịch Sử Tài Khoản Đã Tạo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Xem tài khoản đợi kích hoạt & đã kích hoạt',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2 Phần trong Lịch Sử: [1. Đợi kích hoạt] & [2. Đã kích hoạt]
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Phần 1: Đợi kích hoạt
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  _selectedTabIndex = 0;
                                  _selectedRoleFilter = 'Tất cả';
                                });
                                setState(() {
                                  _selectedTabIndex = 0;
                                  _selectedRoleFilter = 'Tất cả';
                                });
                              },
                              borderRadius: BorderRadius.circular(9),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedTabIndex == 0
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _selectedTabIndex == 0
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.hourglass_top_rounded,
                                      size: 15,
                                      color: _selectedTabIndex == 0
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Đợi kích hoạt (${doiList.length})',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: _selectedTabIndex == 0
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: _selectedTabIndex == 0
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Phần 2: Đã kích hoạt
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  _selectedTabIndex = 1;
                                  _selectedRoleFilter = 'Tất cả';
                                });
                                setState(() {
                                  _selectedTabIndex = 1;
                                  _selectedRoleFilter = 'Tất cả';
                                });
                              },
                              borderRadius: BorderRadius.circular(9),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedTabIndex == 1
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _selectedTabIndex == 1
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 15,
                                      color: _selectedTabIndex == 1
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Đã kích hoạt (${daList.length})',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: _selectedTabIndex == 1
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: _selectedTabIndex == 1
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF64748B),
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

                  // SPINNER (Dropdown) chọn vai trò: "xắp sếp theo vai trò nào thì xem vai trò đó và thứ tự từ mới đến cũ"
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _buildRoleSpinner(
                      currentRole: _selectedRoleFilter,
                      availableRoles: roles,
                      onChanged: (newRole) {
                        setModalState(() {
                          _selectedRoleFilter = newRole;
                        });
                        setState(() {
                          _selectedRoleFilter = newRole;
                        });
                      },
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Danh sách tài khoản trong lịch sử (từ mới đến cũ)
                  Expanded(
                    child: filteredHistoryList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _selectedTabIndex == 0
                                        ? Icons.hourglass_empty_rounded
                                        : Icons.info_outline_rounded,
                                    size: 46,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _selectedTabIndex == 0
                                        ? 'Không có tài khoản đợi kích hoạt phù hợp'
                                        : 'Không có tài khoản đã kích hoạt phù hợp',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bộ lọc vai trò: $_selectedRoleFilter',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredHistoryList.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (lCtx, index) {
                              return _buildAccountCard(
                                context,
                                index + 1,
                                filteredHistoryList[index],
                              );
                            },
                          ),
                  ),

                  // Nút đóng Modal Lịch Sử
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Đóng',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Spinner (Dropdown) chọn vai trò: "dùng spiner để chọn chứ không kéo xuống như vậy"
  Widget _buildRoleSpinner({
    required String currentRole,
    required List<String> availableRoles,
    required ValueChanged<String> onChanged,
  }) {
    final validCurrentRole = availableRoles.contains(currentRole)
        ? currentRole
        : availableRoles.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF0284C7)),
          const SizedBox(width: 8),
          // const Text(
          //   'Xem vai trò:',
          //   style: TextStyle(
          //     fontSize: 12.5,
          //     fontWeight: FontWeight.w600,
          //     color: Color(0xFF475569),
          //   ),
          // ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: validCurrentRole,
                isExpanded: true,
                icon: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Color(0xFF0284C7),
                  size: 24,
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                items: availableRoles.map((role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(
                      role == 'Tất cả' ? 'Tất cả vai trò' : role,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (newVal) {
                  if (newVal != null) {
                    onChanged(newVal);
                  }
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Mới nhất',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF0284C7)),
              SizedBox(height: 12),
              Text(
                'Đang tải danh sách tài khoản...',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    // Danh sách tài khoản đang hiển thị trên màn hình chính
    final currentSourceList = _selectedTabIndex == 0
        ? _danhSachDoiKichHoat
        : _danhSachDaKichHoat;

    final displayedList = _locVaSapXep(currentSourceList, _selectedRoleFilter);
    final availableRoles = _layDanhSachVaiTro(currentSourceList);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                // 1. Header AppBar với NÚT LỊCH SỬ ở góc trên bên phải
                _buildHeader(context),

                // 2. SPINNER chọn vai trò trên màn hình chính
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: _buildRoleSpinner(
                    currentRole: _selectedRoleFilter,
                    availableRoles: availableRoles,
                    onChanged: (role) {
                      setState(() {
                        _selectedRoleFilter = role;
                      });
                    },
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // 3. Nội dung danh sách tài khoản
                Expanded(
                  child: displayedList.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _khoiTaoDuLieu,
                          color: const Color(0xFF0284C7),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            children: [
                              // Hộp thông báo nếu vừa tạo đợt tài khoản mới
                              if (_selectedTabIndex == 0 &&
                                  _vuaTaoBatch != null &&
                                  _vuaTaoBatch!.danhSachTaiKhoan.isNotEmpty)
                                _buildSuccessBanner(_vuaTaoBatch!),

                              const SizedBox(height: 12),

                              // Tiêu đề & Nút Sao chép tất cả (ĐÃ FIX TRIỆT ĐỂ LỖI TRÀN PIXEL)
                              _buildSubHeader(displayedList),

                              const SizedBox(height: 10),

                              // Danh sách các thẻ tài khoản (sắp xếp từ mới đến cũ)
                              for (
                                int i = 0;
                                i < displayedList.length;
                                i++
                              ) ...[
                                _buildAccountCard(
                                  context,
                                  i + 1,
                                  displayedList[i],
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ),
                        ),
                ),

                // 4. Nút Xuất File PDF & Quay lại trang Nhân sự
                _buildBottomButtons(context, displayedList),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header AppBar với NÚT LỊCH SỬ ở góc trên bên phải ("đổi cái nút xuất file trên góc file thành cái lich sử")
  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
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
          const Expanded(
            child: Text(
              'Danh Sách Tài Khoản Đã Tạo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          // NÚT LỊCH SỬ Ở GÓC TRÊN BÊN PHẢI (thay cho nút PDF cũ)
          Tooltip(
            message:
                'Mở lịch sử tài khoản đã tạo (Đợi kích hoạt & Đã kích hoạt)',
            child: InkWell(
              onTap: _moLichSuTaiKhoan,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tiêu đề & Nút Sao chép tất cả: ĐÃ FIX HOÀN TOÀN LỖI TRÀN PIXEL
  Widget _buildSubHeader(List<TaiKhoanItem> displayedList) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Bọc toàn bộ tiêu đề và mật khẩu chung vào Expanded để không bao giờ bị tràn pixel
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _selectedTabIndex == 0
                          ? 'Chi tiết tài khoản & Mật khẩu'
                          : 'Tài khoản đã kích hoạt',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${displayedList.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Mật khẩu khởi tạo: ${StaffAccountStore.matKhauMacDinh}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Nút Sao chép tất cả
        InkWell(
          onTap: () => _saoChepTatCa(context, displayedList),
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.copy_all_rounded,
                  size: 14,
                  color: Color(0xFF0284C7),
                ),
                SizedBox(width: 3),
                Text(
                  'Sao chép tất cả',
                  style: TextStyle(
                    color: Color(0xFF0284C7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
                  'Đã tạo thành công ${batch.danhSachTaiKhoan.length} tài khoản mới',
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
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, int index, TaiKhoanItem item) {
    final bool isActivated = item.daKichHoat;
    final vaiTroStr = item.vaiTro.isNotEmpty ? item.vaiTro : 'Nhân viên';
    final khoaStr = item.khoa.isNotEmpty ? item.khoa : 'Toàn viện';
    final ngayTaoStr = item.ngayTao != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(item.ngayTao!)
        : 'Mới tạo';

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
          // Dòng 1: STT, Mã tài khoản, Badge trạng thái và Thùng rác
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '$index. ',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        item.maTk,
                        style: const TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge trạng thái
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isActivated
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isActivated ? 'Đã kích hoạt' : 'Đợi kích hoạt',
                      style: TextStyle(
                        color: isActivated
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFD97706),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Nút xóa (chỉ hiển thị cho tài khoản chưa kích hoạt để tránh xóa nhầm)
                  if (!isActivated)
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
                          size: 17,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Dòng 2: Thông tin vai trò, khoa & ngày tạo (Mới đến cũ)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  vaiTroStr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '• $khoaStr',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.access_time_rounded,
                size: 12,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 3),
              Text(
                ngayTaoStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Dòng 3: Khung mật khẩu & nút Chép
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Mật khẩu khởi tạo: ',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: Color(0xFF0284C7),
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Chép',
                          style: TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 52,
              color: Color(0xFF16A34A),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedRoleFilter == 'Tất cả'
                  ? 'Không có tài khoản nào'
                  : 'Không có tài khoản vai trò $_selectedRoleFilter',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bấm vào biểu tượng Lịch Sử ở góc trên bên phải để xem toàn bộ tài khoản Đợi kích hoạt & Đã kích hoạt.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CapTaiKhoanNhanVienScreen(benhVienId: _getBenhVienId()),
                  ),
                );
              },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Cấp Thêm Tài Khoản Mới'),
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

  Widget _buildBottomButtons(
    BuildContext context,
    List<TaiKhoanItem> displayedList,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nút Xuất File PDF thực sự hoạt động
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _xacNhanXuatFilePdf(displayedList),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: Text(
                'Xuất File PDF / In Danh Sách (${displayedList.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
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
                  AppRoutes.nhanSuScreen,
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
