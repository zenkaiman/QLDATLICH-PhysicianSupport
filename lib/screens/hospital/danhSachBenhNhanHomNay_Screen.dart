import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/benhVien_service.dart';

class DanhSachBenhNhanHomNayScreen extends StatefulWidget {
  final String hospitalUid;

  const DanhSachBenhNhanHomNayScreen({
    super.key,
    required this.hospitalUid,
  });

  @override
  State<DanhSachBenhNhanHomNayScreen> createState() =>
      _DanhSachBenhNhanHomNayScreenState();
}

class _DanhSachBenhNhanHomNayScreenState
    extends State<DanhSachBenhNhanHomNayScreen> {
  DateTime _ngayChon = DateTime.now();
  String _selectedTab = 'Tất cả';
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  final List<String> _tabs = [
    'Tất cả',
    'Chờ khám',
    'Đang khám',
    'Đã khám',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _chonNgayKhac() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _ngayChon,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'CHỌN NGÀY XEM BỆNH NHÂN KHÁM',
      cancelText: 'HỦY',
      confirmText: 'CHỌN',
    );
    if (picked != null && picked != _ngayChon) {
      setState(() {
        _ngayChon = picked;
      });
    }
  }

  void _saoChep(String text, String thongBao) {
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Đang khám':
        return const Color(0xFF0284C7);
      case 'Đã khám':
        return const Color(0xFF16A34A);
      case 'Đã tiếp nhận':
        return const Color(0xFF0D9488);
      case 'Đã hủy':
        return const Color(0xFFDC2626);
      case 'Chờ khám':
      default:
        return const Color(0xFFD97706);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Đang khám':
        return const Color(0xFFE0F2FE);
      case 'Đã khám':
        return const Color(0xFFDCFCE7);
      case 'Đã tiếp nhận':
        return const Color(0xFFCCFBF1);
      case 'Đã hủy':
        return const Color(0xFFFEE2E2);
      case 'Chờ khám':
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  void _hienThiChiTietBenhNhan(Map<String, dynamic> item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final trangThai = (item['trang_thai'] ?? 'Chờ khám').toString();
        final statusColor = _getStatusColor(trangThai);
        final statusBgColor = _getStatusBgColor(trangThai);

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chi Tiết Lịch Hẹn Khám',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trangThai,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),

              _buildDetailRow(
                'Mã lịch hẹn',
                item['id'] ?? '',
                canCopy: true,
              ),
              _buildDetailRow(
                'Bệnh nhân (Mã BN)',
                '${item['ho_ten']} (${item['benh_nhan_id']})',
              ),
              if ((item['sdt'] ?? '').toString().isNotEmpty)
                _buildDetailRow(
                  'Số điện thoại',
                  item['sdt'],
                  canCopy: true,
                ),
              _buildDetailRow(
                'Ca khám',
                item['ca_kham'] ?? 'Ca sáng',
              ),
              if ((item['gio_du_kien'] ?? '').toString().isNotEmpty)
                _buildDetailRow(
                  'Giờ dự kiến',
                  item['gio_du_kien'],
                ),
              _buildDetailRow(
                'Khoa khám',
                (item['ten_khoa'] ?? '').toString().isNotEmpty
                    ? item['ten_khoa']
                    : (item['khoa_id'] ?? 'Khoa khám'),
              ),
              _buildDetailRow(
                'Phòng khám',
                (item['ten_phong_kham'] ?? '').toString().isNotEmpty
                    ? item['ten_phong_kham']
                    : (item['phong_kham_id'] ?? '-'),
              ),
              _buildDetailRow(
                'Quan hệ',
                item['quan_he'] ?? 'Chính tôi',
              ),
              _buildDetailRow(
                'Số thứ tự',
                'Số ${item['so_thu_tu'] ?? 1}',
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (canCopy && value.isNotEmpty)
                  InkWell(
                    onTap: () => _saoChep(value, 'Đã sao chép: $value'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: Color(0xFF0284C7),
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = _ngayChon.year == now.year &&
        _ngayChon.month == now.month &&
        _ngayChon.day == now.day;

    final dateStr = DateFormat('dd/MM/yyyy').format(_ngayChon);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.all(8),
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
        title: Column(
          children: [
            Text(
              isToday ? 'Bệnh Nhân Khám Hôm Nay' : 'Bệnh Nhân Khám',
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            InkWell(
              onTap: _chonNgayKhac,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: isToday
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$dateStr ${isToday ? "(Hôm nay)" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isToday
                          ? const Color(0xFF0284C7)
                          : const Color(0xFFD97706),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _chonNgayKhac,
            icon: const Icon(
              Icons.edit_calendar_rounded,
              color: Color(0xFF0284C7),
              size: 22,
            ),
            tooltip: 'Chọn ngày khác',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: BenhVienService.streamDanhSachBenhNhanHomNay(
          widget.hospitalUid,
          ngay: _ngayChon,
        ),
        builder: (context, snapshot) {
          final allList = snapshot.data ?? [];

          // Đếm thống kê theo trạng thái
          final tongSo = allList.length;
          final choKham = allList
              .where((e) =>
                  e['trang_thai'] == 'Chờ khám' ||
                  e['trang_thai'] == 'Đã tiếp nhận')
              .length;
          final dangKham =
              allList.where((e) => e['trang_thai'] == 'Đang khám').length;
          final daKham =
              allList.where((e) => e['trang_thai'] == 'Đã khám').length;

          // Lọc danh sách theo Tab đang chọn
          var filteredList = allList;
          if (_selectedTab == 'Chờ khám') {
            filteredList = filteredList
                .where((e) =>
                    e['trang_thai'] == 'Chờ khám' ||
                    e['trang_thai'] == 'Đã tiếp nhận')
                .toList();
          } else if (_selectedTab == 'Đang khám') {
            filteredList = filteredList
                .where((e) => e['trang_thai'] == 'Đang khám')
                .toList();
          } else if (_selectedTab == 'Đã khám') {
            filteredList =
                filteredList.where((e) => e['trang_thai'] == 'Đã khám').toList();
          }

          // Lọc theo từ khóa tìm kiếm
          if (_searchKeyword.isNotEmpty) {
            final kw = _searchKeyword.toLowerCase();
            filteredList = filteredList.where((e) {
              final id = (e['id'] ?? '').toString().toLowerCase();
              final bnId = (e['benh_nhan_id'] ?? '').toString().toLowerCase();
              final name = (e['ho_ten'] ?? '').toString().toLowerCase();
              final sdt = (e['sdt'] ?? '').toString();
              final khoa = (e['ten_khoa'] ?? e['khoa_id'] ?? '').toString().toLowerCase();
              final pk = (e['phong_kham_id'] ?? '').toString().toLowerCase();

              return id.contains(kw) ||
                  bnId.contains(kw) ||
                  name.contains(kw) ||
                  sdt.contains(kw) ||
                  khoa.contains(kw) ||
                  pk.contains(kw);
            }).toList();
          }

          return Column(
            children: [
              // 1. Thẻ tổng quan số liệu
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    _buildStatPill('Tổng số', '$tongSo', const Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    _buildStatPill('Chờ khám', '$choKham', const Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    _buildStatPill('Đang khám', '$dangKham', const Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    _buildStatPill('Đã khám', '$daKham', const Color(0xFF16A34A)),
                  ],
                ),
              ),

              // 2. Ô tìm kiếm
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchKeyword = val.trim();
                      });
                    },
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên, mã LH, mã BN, SĐT...',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                      suffixIcon: _searchKeyword.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchKeyword = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

              // 3. Tab trạng thái (Segmented Button)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: _tabs.map((tab) {
                      final isSelected = _selectedTab == tab;
                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTab = tab;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              tab,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // 4. Danh sách các bệnh nhân
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_search_rounded,
                                size: 54,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchKeyword.isNotEmpty
                                    ? 'Không tìm thấy bệnh nhân phù hợp'
                                    : 'Không có bệnh nhân trong danh mục "$_selectedTab"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ngày $dateStr',
                                style: const TextStyle(
                                  fontSize: 12.5,
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
                        itemCount: filteredList.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          return _buildPatientCard(item, index + 1);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> item, int index) {
    final trangThai = (item['trang_thai'] ?? 'Chờ khám').toString();
    final statusColor = _getStatusColor(trangThai);
    final statusBgColor = _getStatusBgColor(trangThai);

    final hoTen = (item['ho_ten'] ?? 'Bệnh nhân').toString();
    final maBn = (item['benh_nhan_id'] ?? '').toString();
    final maLh = (item['id'] ?? '').toString();
    final caKham = (item['ca_kham'] ?? 'Ca sáng').toString();
    final khoa = (item['ten_khoa'] ?? item['khoa_id'] ?? '').toString();
    final phongKham = (item['phong_kham_id'] ?? '').toString();
    final soThuTu = item['so_thu_tu'] ?? index;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _hienThiChiTietBenhNhan(item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
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
              // Dòng 1: STT, Mã lịch hẹn & Badge trạng thái
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$soThuTu',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            maLh,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trangThai,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Dòng 2: Tên bệnh nhân & Mã BN
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF0284C7),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hoTen,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (maBn.isNotEmpty)
                          Text(
                            'Mã BN: $maBn',
                            style: const TextStyle(
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

              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),

              // Dòng 3: Ca khám & Phòng khám
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    caKham,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  if (phongKham.isNotEmpty || khoa.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Text(
                      '•',
                      style: TextStyle(color: Color(0xFFCBD5E1)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        phongKham.isNotEmpty ? phongKham : khoa,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
