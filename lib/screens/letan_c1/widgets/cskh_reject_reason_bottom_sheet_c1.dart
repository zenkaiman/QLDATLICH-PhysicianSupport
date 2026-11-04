import 'package:flutter/material.dart';

import '../../../mock/mock_c1/dulieu_mau_cskh_c1.dart';
import '../../../models/letan_c1/letan_design_system_c1.dart';
import '../../../services/letan_c1/letan_firebase_service_c1.dart';

/// Modal BottomSheet chọn lý do từ chối đơn khám (Figma 15.1)
class CskhRejectReasonBottomSheetC1 {
  static void show({
    required BuildContext context,
    required Map<String, dynamic> don,
    VoidCallback? onRejected,
  }) {
    AppDesignSystemC1.hapticLight();
    final isDark = AppDesignSystemC1.laCheDoToi;
    int lyDoDangChon = 0;
    final lyDoKhacController = TextEditingController();
    final cacLyDo = DuLieuCskhKhoaC1.danhSachLyDoTuChoi;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 14,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppDesignSystemC1.darkBackground : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh kéo xám
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Card tóm tắt bệnh nhân bị từ chối
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MÃ ĐẶT LỊCH: ${don['maBenhNhan'] ?? don['id']}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (don['hoTen'] ?? 'Bệnh nhân').toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${don['tenKhoa']} • ${don['gioKham']}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'STT',
                                  style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  (don['stt'] ?? '1').toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tiêu đề
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Lý do không duyệt đơn khám',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vui lòng chọn lý do từ chối để hệ thống gửi thông báo và hướng dẫn bệnh nhân chọn khung giờ hoặc khoa khác:',
                      style: TextStyle(
                        color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Danh sách lý do từ chối
                    ...List.generate(cacLyDo.length, (index) {
                      final isSelected = lyDoDangChon == index;
                      final lyDoText = cacLyDo[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () {
                            setSheetState(() {
                              lyDoDangChon = index;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.6) : const Color(0xFFFEF2F2))
                                  : (isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFEF4444)
                                    : (isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? const Color(0xFFEF4444) : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Center(
                                          child: Icon(Icons.circle, color: Colors.white, size: 8),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    lyDoText,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFFDC2626)
                                          : (isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1E293B)),
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    if (lyDoDangChon == 3) ...[
                      TextField(
                        controller: lyDoKhacController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Nhập chi tiết lý do từ chối gửi cho bệnh nhân...',
                          hintStyle: TextStyle(
                            color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF94A3B8),
                            fontSize: 12.5,
                          ),
                          filled: true,
                          fillColor: isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 8),

                    // Hai nút hành động: Hủy / Xác nhận từ chối
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppDesignSystemC1.darkSurface : const Color(0xFFF1F5F9),
                                foregroundColor: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF475569),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: () async {
                                final lyDoChon = lyDoDangChon == 3 && lyDoKhacController.text.trim().isNotEmpty
                                    ? lyDoKhacController.text.trim()
                                    : cacLyDo[lyDoDangChon];

                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final appointmentId = don['id'];
                                final docPath = don['docPath'];
                                Navigator.pop(ctx);
                                if (appointmentId != null) {
                                  await FirebaseServiceC1.capNhatTrangThaiLichHen(
                                    appointmentId: appointmentId,
                                    docPath: docPath,
                                    trangThaiMoi: 'tu_choi',
                                    lyDoTuChoi: lyDoChon,
                                  );
                                }

                                onRejected?.call();

                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('✕ Đã từ chối đơn của ${don['hoTen']}: $lyDoChon'),
                                    backgroundColor: const Color(0xFFEF4444),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Xác nhận từ chối', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
