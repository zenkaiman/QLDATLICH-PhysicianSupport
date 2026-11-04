import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import 'letan_lichhen_screen_c1.dart';

class LetanTimkiemScreenC1 extends StatefulWidget {
  const LetanTimkiemScreenC1({super.key});

  @override
  State<LetanTimkiemScreenC1> createState() => _LetanTimkiemScreenC1State();
}

class _LetanTimkiemScreenC1State extends State<LetanTimkiemScreenC1> {
  final TextEditingController _controller = TextEditingController();

  void _thucHienTimKiem(String tuKhoa) {
    final query = tuKhoa.trim();
    if (query.isEmpty) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LetanLichhenScreenC1(
          tuKhoaBanDau: query,
          laTab: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tìm Bệnh Nhân',
          style: TextStyle(
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nhập Tên hoặc Số Điện Thoại',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Hệ thống sẽ tra cứu hồ sơ và chuyển thẳng đến danh sách lịch hẹn của bệnh nhân.',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Ô nhập liệu
              TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _thucHienTimKiem,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: 0901234567 hoặc Nguyễn Văn An...',
                  hintStyle: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search, color: AppDesignSystemC1.primary),
                  filled: true,
                  fillColor: isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF2F2F7),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: isDark ? const BorderSide(color: AppDesignSystemC1.darkBorder) : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: isDark ? const BorderSide(color: AppDesignSystemC1.darkBorder) : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppDesignSystemC1.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Nút tìm kiếm
              ElevatedButton.icon(
                onPressed: () => _thucHienTimKiem(_controller.text),
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text(
                  'Tìm Kiếm Ngay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystemC1.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Gợi ý nhanh
              Text(
                'GỢI Ý TÌM NHANH:',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChipGoiY('0901234567 (An)', isDark),
                  _buildChipGoiY('0912345678 (Hoa)', isDark),
                  _buildChipGoiY('Nguyễn Văn An', isDark),
                  _buildChipGoiY('Lê Minh', isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChipGoiY(String text, bool isDark) {
    final tuKhoa = text.split(' ')[0];
    return ActionChip(
      label: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
        ),
      ),
      backgroundColor: isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF2F2F7),
      side: isDark ? const BorderSide(color: AppDesignSystemC1.darkBorder) : BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        _controller.text = tuKhoa;
        _thucHienTimKiem(tuKhoa);
      },
    );
  }
}
