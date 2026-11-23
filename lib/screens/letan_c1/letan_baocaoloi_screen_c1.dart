import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'widgets/medical_reusable_widgets_c1.dart';

/// MÀN HÌNH QUẢN LÝ SỰ CỐ & BÁO CÁO LỖI HỢP NHẤT (PHƯƠNG ÁN 2)
/// - Tab 1: Gửi báo cáo sự cố (Có đầy đủ chọn mức độ ưu tiên, loại lỗi, đính kèm ảnh)
/// - Tab 2: Lịch sử các báo cáo của nhân viên + xem trạng thái phản hồi từ kỹ thuật IT
class LetanBaocaoloiScreenC1 extends StatefulWidget {
  final String tenKhoa;
  final int initialTabIndex;

  const LetanBaocaoloiScreenC1({
    super.key,
    this.tenKhoa = 'Khoa Tim Mạch',
    this.initialTabIndex = 0,
  });

  @override
  State<LetanBaocaoloiScreenC1> createState() => _LetanBaocaoloiScreenC1State();
}

class _LetanBaocaoloiScreenC1State extends State<LetanBaocaoloiScreenC1> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tieuDeController = TextEditingController(text: 'Số thứ tự hiển thị sai');
  final _moTaController = TextEditingController(
    text: 'Số đang gọi trên màn hình là 11 nhưng bệnh nhân số 12 đã vào phòng...',
  );
  String _loaiLoiDuocChon = 'Số thứ tự hiển thị sai';
  String _mucDoUuTien = 'Cao'; // 'Cao', 'Trung bình', 'Thấp'
  final bool _coDinhKemAnh = false;
  bool _dangGui = false;

  final List<String> _danhSachLoaiLoi = [
    'Số thứ tự hiển thị sai',
    'Không quét được mã QR bệnh nhân',
    'Hệ thống phản hồi chậm / đơ',
    'Sai thông tin lịch hẹn hôm nay',
    'Lỗi kết nối máy in phiếu số',
    'Lỗi khác...',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tieuDeController.dispose();
    _moTaController.dispose();
    super.dispose();
  }

  Future<void> _guiBaoCao() async {
    final tieuDe = _tieuDeController.text.trim();
    final moTa = _moTaController.text.trim();

    if (tieuDe.isEmpty) {
      AppDesignSystemC1.hapticError();
      AppDesignSystemC1.showCustomSnackBar(context, message: 'Vui lòng nhập tiêu đề sự cố!', isSuccess: false);
      return;
    }

    if (moTa.isEmpty) {
      AppDesignSystemC1.hapticError();
      AppDesignSystemC1.showCustomSnackBar(context, message: 'Vui lòng nhập mô tả chi tiết lỗi!', isSuccess: false);
      return;
    }

    AppDesignSystemC1.hapticLight();
    setState(() => _dangGui = true);

    try {
      final maBaoCao = await FirebaseServiceC1.guiBaoCaoLoi(
        tieuDe: tieuDe,
        moTa: moTa,
        loaiLoi: _loaiLoiDuocChon,
        mucDoUuTien: _mucDoUuTien,
        coDinhKemAnh: _coDinhKemAnh,
        tenKhoa: widget.tenKhoa,
      );

      if (!mounted) return;
      AppDesignSystemC1.hapticSuccess();
      AppDesignSystemC1.showCustomSnackBar(
        context,
        message: '✓ Đã gửi báo cáo $maBaoCao thành công! Chuyển sang xem lịch sử.',
        isSuccess: true,
      );

      setState(() => _dangGui = false);
      _tabController.animateTo(1); // Tự động chuyển sang Tab Lịch sử
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangGui = false);
      AppDesignSystemC1.hapticError();
      AppDesignSystemC1.showCustomSnackBar(context, message: 'Lỗi khi gửi báo cáo: $e', isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Scaffold(
      backgroundColor: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quản lý sự cố & Báo cáo lỗi',
          style: TextStyle(
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppDesignSystemC1.primary,
          unselectedLabelColor: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
          indicatorColor: AppDesignSystemC1.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Gửi báo cáo lỗi', icon: Icon(Icons.report_problem_outlined, size: 20)),
            Tab(text: 'Lịch sử báo cáo', icon: Icon(Icons.history_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormGuiBaoCao(isDark),
          _buildDanhSachLichSu(isDark),
        ],
      ),
    );
  }

  // TAB 1: FORM GỬI BÁO CÁO LỖI
  Widget _buildFormGuiBaoCao(bool isDark) {
    final profile = DuLieuProfileMauC1.thongTinHienTai;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner thông tin nhân viên gửi
          MedicalCardC1(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: Color(0xFF0284C7), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.hoTen,
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        'Mã: ${profile.maNhanVien} • ${widget.tenKhoa}',
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Chọn loại lỗi
          Text('Loại sự cố gặp phải:', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _loaiLoiDuocChon,
                dropdownColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                items: _danhSachLoaiLoi.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13.5)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _loaiLoiDuocChon = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mức độ ưu tiên
          Text('Mức độ ưu tiên:', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPriorityChip('Cao', const Color(0xFFEF4444), isDark),
              const SizedBox(width: 8),
              _buildPriorityChip('Trung bình', const Color(0xFFF59E0B), isDark),
              const SizedBox(width: 8),
              _buildPriorityChip('Thấp', const Color(0xFF3B82F6), isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Tiêu đề sự cố
          Text('Tiêu đề sự cố:', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          TextField(
            controller: _tieuDeController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Nhập tóm tắt lỗi...',
              filled: true,
              fillColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFCBD5E1))),
            ),
          ),
          const SizedBox(height: 16),

          // Mô tả chi tiết
          Text('Mô tả chi tiết:', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          TextField(
            controller: _moTaController,
            maxLines: 4,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Mô tả cụ thể vấn đề để đội ngũ IT hỗ trợ nhanh nhất...',
              filled: true,
              fillColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFCBD5E1))),
            ),
          ),
          const SizedBox(height: 20),

          // Nút bấm Gửi báo cáo
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _dangGui ? null : _guiBaoCao,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignSystemC1.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _dangGui
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(_dangGui ? 'Đang gửi...' : 'Gửi báo cáo sự cố', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String label, Color color, bool isDark) {
    final isSelected = _mucDoUuTien == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mucDoUuTien = label),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : (isDark ? AppDesignSystemC1.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : (isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFCBD5E1))),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : (isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B)),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // TAB 2: LỊCH SỬ BÁO CÁO LỖI (REALTIME STREAM)
  Widget _buildDanhSachLichSu(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseServiceC1.streamBaoCaoLoiCuaToi(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final danhSach = snapshot.data ?? [];
        if (danhSach.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                Text('Bạn chưa có báo cáo sự cố nào', style: TextStyle(color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B), fontSize: 15)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: danhSach.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = danhSach[index];
            final bool daSua = item['trang_thai'] == 'da_sua' || item['trang_thai'] == 'da_giai_quyet';
            final maBaoCao = item['id'] ?? '#ERR';
            final tieuDe = item['tieu_de'] ?? 'Báo cáo sự cố';
            final moTa = item['mo_ta'] ?? '';
            final phanHoi = item['phan_hoi_admin'];

            return MedicalCardC1(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          maBaoCao,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0284C7), fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: daSua ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: daSua ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          daSua ? 'ĐÃ SỬA' : 'CHỜ XỬ LÝ',
                          style: TextStyle(color: daSua ? const Color(0xFF059669) : const Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tieuDe,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  if (moTa.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(moTa, style: TextStyle(fontSize: 13, color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B))),
                  ],
                  if (phanHoi != null && phanHoi.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: Text('Phản hồi IT: $phanHoi', style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontStyle: FontStyle.italic)),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
