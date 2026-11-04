import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';

/// MÀN HÌNH 2.1.38: GỬI BÁO CÁO THÀNH CÔNG (THEO ĐẶC TẢ TÀI LIỆU SDS MỤC 2.1.38, HÌNH 38)
class LetanBaocaoThanhcongScreenC1 extends StatelessWidget {
  final String maBaoCao;
  final String loaiLoi;
  final String mucDoUuTien;
  final String thoiGianGui;
  final String moTa;
  final bool coDinhKemAnh;

  const LetanBaocaoThanhcongScreenC1({
    super.key,
    this.maBaoCao = '#ERR-0926',
    required this.loaiLoi,
    required this.mucDoUuTien,
    this.thoiGianGui = '08:45, 09/10/2026',
    this.moTa = '',
    this.coDinhKemAnh = false,
  });

  Color _getPriorityColor() {
    switch (mucDoUuTien) {
      case 'Cao':
        return AppDesignSystemC1.error;
      case 'Trung bình':
        return AppDesignSystemC1.warning;
      default:
        return AppDesignSystemC1.info;
    }
  }

  void _moLichSuBaoCao(BuildContext context) {
    moLichSuBaoCao(context, maBaoCaoHienTai: maBaoCao);
  }

  static void moLichSuBaoCao(BuildContext context, {String? maBaoCaoHienTai}) {
    AppDesignSystemC1.hapticLight();
    final isDark = AppDesignSystemC1.laCheDoToi;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.history_rounded, color: Color(0xFF0284C7), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Lịch Sử Báo Cáo Lỗi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppDesignSystemC1.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? AppDesignSystemC1.darkTextSecondary : AppDesignSystemC1.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirebaseServiceC1.streamBaoCaoLoiCuaToi(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final dsLoi = snapshot.data ?? [];
                      if (dsLoi.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                              const SizedBox(height: 8),
                              Text(
                                'Bạn chưa gửi báo cáo lỗi nào.',
                                style: TextStyle(
                                  color: isDark ? AppDesignSystemC1.darkTextSecondary : AppDesignSystemC1.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: dsLoi.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = dsLoi[index];
                          final ma = (item['id'] ?? item['doc_id'] ?? '').toString();
                          final tieuDe = (item['tieu_de'] ?? item['noi_dung'] ?? 'Sự cố hệ thống').toString();
                          final loai = (item['loai'] ?? 'Khác').toString();
                          final trangThaiRaw = (item['trang_thai'] ?? item['trang_thai_xu_ly'] ?? '').toString().toLowerCase();
                          final laDaSua = trangThaiRaw == 'da_sua' || trangThaiRaw == 'da_giai_quyet';
                          final phanHoi = item['phan_hoi_admin']?.toString();

                          String thoiGian = (item['thoi_gian_hien_thi'] ?? '').toString();
                          final ngayTao = item['ngay_tao'];
                          if (ngayTao is Timestamp) {
                            final d = ngayTao.toDate();
                            thoiGian = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} - ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                          }
                          if (thoiGian.isEmpty) thoiGian = 'Vừa xong';

                          return _buildItemLichSuFirebase(
                            context: ctx,
                            ma: ma,
                            tieuDe: tieuDe,
                            loai: loai,
                            thoiGian: thoiGian,
                            laDaSua: laDaSua,
                            phanHoiAdmin: phanHoi,
                            isDark: isDark,
                            isCurrent: ma == maBaoCaoHienTai,
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
    );
  }

  static Widget _buildItemLichSuFirebase({
    required BuildContext context,
    required String ma,
    required String tieuDe,
    required String loai,
    required String thoiGian,
    required bool laDaSua,
    String? phanHoiAdmin,
    required bool isDark,
    required bool isCurrent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? AppDesignSystemC1.primary
              : (isDark ? AppDesignSystemC1.darkBorder : AppDesignSystemC1.border),
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent ? AppDesignSystemC1.primary.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ma,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? AppDesignSystemC1.primary : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tieuDe,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppDesignSystemC1.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Badge trạng thái: "Chờ sửa" (cam) hoặc "Đã sửa" (xanh)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: laDaSua
                      ? AppDesignSystemC1.success.withValues(alpha: 0.15)
                      : AppDesignSystemC1.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      laDaSua ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                      size: 11,
                      color: laDaSua ? AppDesignSystemC1.success : AppDesignSystemC1.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      laDaSua ? 'Đã sửa' : 'Chờ sửa',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: laDaSua ? AppDesignSystemC1.success : AppDesignSystemC1.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Loại: $loai • $thoiGian',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : AppDesignSystemC1.textSecondary,
                ),
              ),
            ],
          ),
          if (phanHoiAdmin != null && phanHoiAdmin.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '💬 Phản hồi: $phanHoiAdmin',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppDesignSystemC1.isDarkMode,
      builder: (context, isDark, child) {
        final bg = isDark ? AppDesignSystemC1.darkBackground : AppDesignSystemC1.background;
        final cardBg = isDark ? AppDesignSystemC1.darkSurface : Colors.white;
        final borderCol = isDark ? AppDesignSystemC1.darkBorder : AppDesignSystemC1.border;
        final textCol = isDark ? AppDesignSystemC1.darkTextPrimary : AppDesignSystemC1.textPrimary;
        final subTextCol = isDark ? AppDesignSystemC1.darkTextSecondary : AppDesignSystemC1.textSecondary;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: cardBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded, color: textCol, size: 22),
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
            title: Text(
              'Báo Cáo Thành Công',
              style: TextStyle(
                color: textCol,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // 1. BIỂU TƯỢNG THÀNH CÔNG (✓)
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: AppDesignSystemC1.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppDesignSystemC1.success.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: const BoxDecoration(
                        color: AppDesignSystemC1.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. TIÊU ĐỀ: "Gửi báo cáo thành công!"
                  Text(
                    'Gửi báo cáo thành công!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textCol,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // 3. NỘI DUNG THÔNG BÁO KÈM MÃ BÁO CÁO (VD: #ERR-0926)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppDesignSystemC1.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Mã báo cáo: $maBaoCao',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystemC1.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Báo cáo sự cố đã được chuyển đến bộ phận kỹ thuật để tiếp nhận và khắc phục.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: subTextCol,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),

                  // 4. KHỐI "CHI TIẾT BÁO CÁO"
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: AppDesignSystemC1.borderRadMedium,
                      border: Border.all(color: borderCol),
                      boxShadow: isDark ? [] : AppDesignSystemC1.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              color: AppDesignSystemC1.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Chi tiết báo cáo',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textCol,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(color: borderCol, height: 1),
                        const SizedBox(height: 14),

                        // Dòng Loại lỗi
                        _buildChiTietRow(
                          tieuDe: 'Loại lỗi:',
                          giaTri: loaiLoi,
                          textCol: textCol,
                          subTextCol: subTextCol,
                        ),
                        const SizedBox(height: 12),

                        // Dòng Mức ưu tiên
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mức ưu tiên:',
                              style: TextStyle(fontSize: 13.5, color: subTextCol),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getPriorityColor().withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                mucDoUuTien,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _getPriorityColor(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Dòng Thời gian gửi
                        _buildChiTietRow(
                          tieuDe: 'Thời gian gửi:',
                          giaTri: thoiGianGui,
                          textCol: textCol,
                          subTextCol: subTextCol,
                        ),
                        const SizedBox(height: 12),

                        // Đính kèm hình ảnh
                        _buildChiTietRow(
                          tieuDe: 'Ảnh đính kèm:',
                          giaTri: coDinhKemAnh ? '1 tệp ảnh lỗi' : 'Không có',
                          textCol: textCol,
                          subTextCol: subTextCol,
                        ),

                        if (moTa.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Divider(color: borderCol, height: 1),
                          const SizedBox(height: 12),
                          Text(
                            'Nội dung mô tả:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: subTextCol,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              moTa,
                              style: TextStyle(
                                fontSize: 13,
                                color: textCol,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 5. NÚT: "QUAY LẠI MÀN HÌNH CHÍNH"
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        AppDesignSystemC1.hapticLight();
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystemC1.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.home_rounded, size: 20),
                      label: const Text(
                        'Quay lại màn hình chính',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 6. NÚT: "XEM LỊCH SỬ BÁO CÁO"
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => _moLichSuBaoCao(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : AppDesignSystemC1.primary,
                        side: BorderSide(
                          color: isDark ? AppDesignSystemC1.darkBorder : AppDesignSystemC1.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 20),
                      label: const Text(
                        'Xem lịch sử báo cáo',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChiTietRow({
    required String tieuDe,
    required String giaTri,
    required Color textCol,
    required Color subTextCol,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          tieuDe,
          style: TextStyle(fontSize: 13.5, color: subTextCol),
        ),
        Text(
          giaTri,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: textCol,
          ),
        ),
      ],
    );
  }
}
