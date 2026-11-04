import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'letan_baocao_thanhcong_screen_c1.dart';

class LetanBaocaoloiScreenC1 extends StatefulWidget {
  final String tenKhoa;

  const LetanBaocaoloiScreenC1({
    super.key,
    this.tenKhoa = 'Khoa Tim Mạch',
  });

  @override
  State<LetanBaocaoloiScreenC1> createState() => _LetanBaocaoloiScreenC1State();
}

class _LetanBaocaoloiScreenC1State extends State<LetanBaocaoloiScreenC1> {
  final _tieuDeController = TextEditingController(text: 'Số thứ tự hiển thị sai');
  final _moTaController = TextEditingController(
    text: 'Số đang gọi trên màn hình là 11 nhưng bệnh nhân số 12 đã vào phòng...',
  );
  String _loaiLoiDuocChon = 'Số thứ tự hiển thị sai';
  String _mucDoUuTien = 'Cao'; // 'Cao', 'Trung bình', 'Thấp'
  bool _coDinhKemAnh = false;
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
  void dispose() {
    _tieuDeController.dispose();
    _moTaController.dispose();
    super.dispose();
  }

  Future<void> _guiBaoCao() async {
    final tieuDe = _tieuDeController.text.trim();
    final moTa = _moTaController.text.trim();

    if (tieuDe.isEmpty) {
      AppDesignSystemC1.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tiêu đề sự cố!'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (moTa.isEmpty) {
      AppDesignSystemC1.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mô tả chi tiết lỗi!'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    AppDesignSystemC1.hapticLight();
    setState(() => _dangGui = true);

    try {
      // 1. Gửi thông tin lên collection BaoCaoLoi trên Firebase
      // Tự động đính kèm UID người gửi, trạng thái 'cho_sua'
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

      // 2. Chuyển sang màn hình xác nhận báo cáo thành công với mã thật
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LetanBaocaoThanhcongScreenC1(
            maBaoCao: maBaoCao,
            loaiLoi: _loaiLoiDuocChon,
            mucDoUuTien: _mucDoUuTien,
            thoiGianGui: 'Vừa xong',
            moTa: moTa,
            coDinhKemAnh: _coDinhKemAnh,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangGui = false);
      AppDesignSystemC1.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gửi báo cáo: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final profile = DuLieuProfileMauC1.thongTinHienTai;

    return Scaffold(
      backgroundColor: isDark ? AppDesignSystemC1.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
            size: 20,
          ),
          onPressed: () {
            AppDesignSystemC1.hapticLight();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Báo cáo lỗi',
          style: TextStyle(
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF0284C7)),
            tooltip: 'Lịch sử báo cáo lỗi',
            onPressed: () {
              LetanBaocaoThanhcongScreenC1.moLichSuBaoCao(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header cảnh báo lỗi
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFFB91C1C) : const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠ Mô tả lỗi hệ thống hoặc thao tác sai',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFFF3B30),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Báo cáo sẽ được gửi lên hệ thống và chuyển đến bộ phận kỹ thuật tiếp nhận.',
                      style: TextStyle(
                        color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Thông tin người gửi (UID / Mã tài khoản & Trạng thái khởi tạo)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person_rounded, color: Color(0xFF0284C7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Người báo cáo: ${profile.hoTen}',
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Mã NV: ${profile.maNhanVien} • ${profile.khoa}',
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppDesignSystemC1.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_top_rounded, size: 11, color: AppDesignSystemC1.warning),
                          SizedBox(width: 4),
                          Text(
                            'Chờ sửa',
                            style: TextStyle(
                              color: AppDesignSystemC1.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Loại lỗi
              Text(
                'Loại lỗi',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF3A3A3C),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : Colors.transparent),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _loaiLoiDuocChon,
                    isExpanded: true,
                    dropdownColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                    icon: Icon(Icons.keyboard_arrow_down, color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93)),
                    items: _danhSachLoaiLoi.map((item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(
                          item,
                          style: TextStyle(
                            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                            fontSize: 15,
                            fontFamily: 'Inter',
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _loaiLoiDuocChon = val;
                          if (_tieuDeController.text.isEmpty || _danhSachLoaiLoi.contains(_tieuDeController.text)) {
                            _tieuDeController.text = val;
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Tiêu đề sự cố
              Text(
                'Tiêu đề sự cố',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF3A3A3C),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : Colors.transparent),
                ),
                child: TextField(
                  controller: _tieuDeController,
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nhập tiêu đề tóm tắt lỗi...',
                    hintStyle: TextStyle(
                      color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFFAEAEB2),
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Mô tả chi tiết
              Text(
                'Mô tả chi tiết',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF3A3A3C),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppDesignSystemC1.darkBorder : Colors.transparent),
                ),
                child: TextField(
                  controller: _moTaController,
                  maxLines: 4,
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nhập chi tiết lỗi sự cố bạn gặp phải...',
                    hintStyle: TextStyle(
                      color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFFAEAEB2),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 5. Mức độ ưu tiên
              Text(
                'Mức độ ưu tiên',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF3A3A3C),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildMucDoItem('Cao', const Color(0xFFFF3B30), isDark),
                  const SizedBox(width: 10),
                  _buildMucDoItem('Trung bình', const Color(0xFFFF9500), isDark),
                  const SizedBox(width: 10),
                  _buildMucDoItem('Thấp', const Color(0xFF34C759), isDark),
                ],
              ),
              const SizedBox(height: 20),

              // 6. Đính kèm ảnh (nếu có)
              Text(
                'Đính kèm ảnh (nếu có)',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF3A3A3C),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () {
                    AppDesignSystemC1.hapticLight();
                    setState(() {
                      _coDinhKemAnh = !_coDinhKemAnh;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _coDinhKemAnh
                          ? (isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE))
                          : (isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF2F2F7)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _coDinhKemAnh
                            ? const Color(0xFF0284C7)
                            : (isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _coDinhKemAnh
                        ? const Icon(Icons.check, color: Color(0xFF0284C7), size: 28)
                        : Text(
                            '+',
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFFC7C7CC),
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Inter',
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 7. Nút Gửi báo cáo lỗi
              InkWell(
                onTap: _dangGui ? null : _guiBaoCao,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _dangGui ? const Color(0xFFFF3B30).withValues(alpha: 0.6) : const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _dangGui
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Gửi báo cáo lỗi lên hệ thống',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),

              // 8. Nút Hủy
              InkWell(
                onTap: () {
                  AppDesignSystemC1.hapticLight();
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Hủy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMucDoItem(String label, Color activeColor, bool isDark) {
    final bool isSelected = _mucDoUuTien == label;

    return Expanded(
      child: InkWell(
        onTap: () {
          AppDesignSystemC1.hapticLight();
          setState(() {
            _mucDoUuTien = label;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor
                : (isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF2F2F7)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? AppDesignSystemC1.darkBorder : Colors.transparent),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF3A3A3C)),
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }
}
