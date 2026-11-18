import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_session.dart';

import '../../models/nhan_vien_model.dart';
import '../../services/nhan_vien_service.dart';
import 'CapTK_Scream.dart';
import 'danhSachTaiKhoanDaTao_Screen.dart';

export '../../models/nhan_vien_model.dart' show NhanVienModel;

class NhanSuScreen extends StatefulWidget {
  final bool isTab;
  final String? benhVienId;
  const NhanSuScreen({super.key, this.isTab = true, this.benhVienId});

  @override
  State<NhanSuScreen> createState() => _NhanSuScreenState();
}

class _NhanSuScreenState extends State<NhanSuScreen> {
  final NhanVienService _nhanVienService = NhanVienService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nhanVienService.chuanHoaDinhDangMaNhanVien(_getBenhVienId());
    });
  }

  String _getBenhVienId() {
    if (widget.benhVienId != null && widget.benhVienId!.isNotEmpty) {
      return widget.benhVienId!;
    }
    if (AppSession.benhVienId.isNotEmpty) {
      return AppSession.benhVienId;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }
  String _tuKhoa = '';
  String _filterRole = 'Tất cả';

  Color _getRoleBgColor(String vaiTro) {
    final lower = vaiTro.toLowerCase();
    if (lower.contains('lễ tân') || lower.contains('receptionist')) {
      return const Color(0xFFE0F2FE);
    }
    if (lower.contains('bác sĩ') || lower.contains('doctor')) {
      return const Color(0xFFDCFCE7);
    }
    if (lower.contains('support') || lower.contains('cskh')) {
      return const Color(0xFFFEF3C7);
    }
    return const Color(0xFFF1F5F9);
  }

  Color _getRoleTextColor(String vaiTro) {
    final lower = vaiTro.toLowerCase();
    if (lower.contains('lễ tân') || lower.contains('receptionist')) {
      return const Color(0xFF0284C7);
    }
    if (lower.contains('bác sĩ') || lower.contains('doctor')) {
      return const Color(0xFF16A34A);
    }
    if (lower.contains('support') || lower.contains('cskh')) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF475569);
  }

  void _hienChiTietNhanVien(BuildContext context, NhanVienModel nv) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getRoleBgColor(nv.vaiTro),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        nv.hoTen.isNotEmpty ? nv.hoTen.split(' ').last[0] : 'NV',
                        style: TextStyle(
                          color: _getRoleTextColor(nv.vaiTro),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nv.hoTen,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Mã NV: ${nv.maNv} • ${nv.khoa}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: nv.dangHoatDong
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        nv.dangHoatDong ? 'Hoạt động' : 'Tạm khóa',
                        style: TextStyle(
                          color: nv.dangHoatDong
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                _buildInfoRow('Vai trò:', nv.vaiTro),
                _buildInfoRow('Email đăng nhập:', nv.email),
                _buildInfoRow(
                  'Số điện thoại:',
                  nv.soDienThoai.isNotEmpty ? nv.soDienThoai : 'Chưa cập nhật',
                ),
                _buildInfoRow('Mật khẩu:', nv.matKhau),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final nav = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          final nextStatus = !nv.dangHoatDong;
                          nav.pop();
                          try {
                            await _nhanVienService.capNhatTrangThai(
                              nhanVienId: nv.id,
                              dangHoatDong: nextStatus,
                            );
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  nextStatus
                                      ? 'Đã kích hoạt lại tài khoản ${nv.maNv}'
                                      : 'Đã tạm khóa tài khoản ${nv.maNv}',
                                ),
                                backgroundColor: nextStatus
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFD97706),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Lỗi cập nhật trạng thái: $e'),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          nv.dangHoatDong
                              ? Icons.lock_outline_rounded
                              : Icons.lock_open_rounded,
                          size: 16,
                        ),
                        label: Text(
                          nv.dangHoatDong ? 'Khóa TK' : 'Mở khóa',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                            text: 'Mã NV: ${nv.maNv}\nMật khẩu: ${nv.matKhau}',
                          ));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép thông tin đăng nhập!'),
                              backgroundColor: Color(0xFF16A34A),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Sao chép', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                      onPressed: () async {
                        final nav = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Xác nhận xóa tài khoản?'),
                            content: Text(
                              'Bạn có chắc chắn muốn xóa nhân viên ${nv.hoTen} (${nv.maNv}) khỏi Firestore?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, false),
                                child: const Text('Hủy'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(dCtx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Xóa'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          nav.pop();
                          try {
                            await _nhanVienService.xoaNhanVien(nv.id, _getBenhVienId());
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Đã xóa nhân viên ${nv.maNv}'),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Lỗi xóa nhân viên: $e'),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = StreamBuilder<List<NhanVienModel>>(
      stream: _nhanVienService.streamNhanVien(benhVienId: _getBenhVienId()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allStaff = snapshot.data ?? [];

        // Lọc theo từ khóa và vai trò
        final filteredList = allStaff.where((nv) {
          final matchKeyword = nv.hoTen.toLowerCase().contains(_tuKhoa) ||
              nv.maNv.toLowerCase().contains(_tuKhoa) ||
              nv.khoa.toLowerCase().contains(_tuKhoa);
          final matchRole = _filterRole == 'Tất cả' ||
              nv.vaiTro == _filterRole ||
              (_filterRole == 'Support' &&
                  (nv.vaiTro.toLowerCase().contains('support') ||
                      nv.vaiTro.toLowerCase().contains('cskh') ||
                      nv.role == 'customerSupport'));
          return matchKeyword && matchRole;
        }).toList();

        return Column(
          children: [
            // 1. Thống kê nhanh & Nút cấp tài khoản
            _buildTopActions(context, allStaff),

            // 2. Ô tìm kiếm & Bộ lọc vai trò
            _buildSearchAndFilters(),

            // 3. Danh sách nhân sự
            Expanded(
              child: allStaff.isEmpty
                  ? _buildEmptyState()
                  : filteredList.isEmpty
                      ? _buildEmptySearchState()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                          itemCount: filteredList.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) =>
                              _buildStaffCard(filteredList[i]),
                        ),
            ),
          ],
        );
      },
    );

    if (widget.isTab) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Quản lý nhân sự',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: bodyContent,
    );
  }

  Widget _buildTopActions(BuildContext context, List<NhanVienModel> staffList) {
    final tongNv = staffList.length;
    final leTanCount = staffList
        .where((e) =>
            e.vaiTro == 'Lễ tân' ||
            e.role == 'receptionist' ||
            e.vaiTro.toLowerCase().contains('lễ tân'))
        .length;
    final bsCount = staffList
        .where((e) =>
            e.vaiTro == 'Hỗ trợ bác sĩ' ||
            e.role == 'doctorAssistant' ||
            e.vaiTro.toLowerCase().contains('bác sĩ'))
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Thẻ tóm tắt số liệu trực tiếp từ Firestore
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Tổng nhân sự', '$tongNv', const Color(0xFF0F172A)),
                Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                _buildStatItem('Lễ tân', '$leTanCount', const Color(0xFF0284C7)),
                Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                _buildStatItem('Hỗ trợ BS', '$bsCount', const Color(0xFF16A34A)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // CẶP NÚT HÀNH ĐỘNG: CẤP TÀI KHOẢN & XEM TK VỪA TẠO
          Row(
            children: [
              Expanded(
                flex: 11,
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CapTaiKhoanNhanVienScreen(benhVienId: _getBenhVienId()),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text(
                      'Cấp Tài Khoản',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 10,
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DanhSachTaiKhoanDaTaoScreen(benhVienId: _getBenhVienId()),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.vpn_key_rounded,
                      size: 17,
                      color: Color(0xFF16A34A),
                    ),
                    label: const Text(
                      'Xem TK Vừa Tạo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF0FDF4),
                      side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          // Ô tìm kiếm
          TextField(
            onChanged: (v) => setState(() => _tuKhoa = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, mã NV hoặc khoa...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Thanh lọc vai trò
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                'Tất cả',
                'Lễ tân',
                'Hỗ trợ bác sĩ',
                'Support',
              ].map((role) {
                final isSelected = _filterRole == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(role),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _filterRole = role),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    selectedColor: const Color(0xFF0284C7),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF0284C7)
                          : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(NhanVienModel nv) {
    return InkWell(
      onTap: () => _hienChiTietNhanVien(context, nv),
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getRoleBgColor(nv.vaiTro),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                nv.hoTen.isNotEmpty ? nv.hoTen.split(' ').last[0] : 'NV',
                style: TextStyle(
                  color: _getRoleTextColor(nv.vaiTro),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Thông tin nhân sự
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          nv.hoTen,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleBgColor(nv.vaiTro),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          nv.vaiTro,
                          style: TextStyle(
                            color: _getRoleTextColor(nv.vaiTro),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        nv.maNv,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nv.khoa,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        nv.soDienThoai.isNotEmpty
                            ? 'SĐT: ${nv.soDienThoai}'
                            : nv.email,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!nv.dangHoatDong)
                        const Text(
                          'Đã khóa',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Chưa có nhân viên nào trên Firestore',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hệ thống chưa ghi nhận tài khoản nhân viên nào. Hãy nhấn "Cấp Tài Khoản" để khởi tạo tự động.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CapTaiKhoanNhanVienScreen(benhVienId: _getBenhVienId()),
                  ),
                );
              },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Cấp Tài Khoản Đầu Tiên'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Text(
            'Không tìm thấy nhân sự phù hợp',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
