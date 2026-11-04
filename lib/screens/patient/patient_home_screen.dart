import 'package:flutter/material.dart';

import '../../config/app_routes.dart';
import '../../services/patient_notification_service.dart';
import 'widgets/patient_notification_bell.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {'title': 'Đặt lịch khám', 'route': AppRoutes.bookAppointment},
      {'title': 'Lịch hẹn của tôi', 'route': AppRoutes.myAppointments},
      {'title': 'Hồ sơ bệnh án', 'route': AppRoutes.medicalHistory},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ bệnh nhân'),
        actions: const [PatientNotificationBell()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _TheThongBaoBenhNhan(),
          const SizedBox(height: 12),
          for (final item in menuItems)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(item['title'] as String),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => Navigator.pushNamed(context, item['route'] as String),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thẻ "Thông báo" ở đầu trang chủ bệnh nhân — hiện số thông báo chưa đọc
/// theo thời gian thực từ `ThongBaoHeThong`.
class _TheThongBaoBenhNhan extends StatelessWidget {
  const _TheThongBaoBenhNhan();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<int>(
      stream: PatientNotificationService.streamSoThongBaoChuaDocCuaToi(),
      builder: (context, snapshot) {
        final soChuaDoc = snapshot.data ?? 0;
        final coThongBaoMoi = soChuaDoc > 0;

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: coThongBaoMoi
                  ? const Color(0xFFE0F2FE)
                  : colorScheme.surfaceContainerHighest,
              child: Icon(
                coThongBaoMoi
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: coThongBaoMoi ? const Color(0xFF0284C7) : colorScheme.onSurfaceVariant,
              ),
            ),
            title: const Text(
              'Thông báo',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              coThongBaoMoi
                  ? 'Bạn có $soChuaDoc thông báo chưa đọc'
                  : 'Chưa có thông báo mới',
              style: TextStyle(
                fontSize: 12.5,
                color: coThongBaoMoi ? const Color(0xFF0284C7) : null,
                fontWeight: coThongBaoMoi ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (coThongBaoMoi)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      soChuaDoc > 99 ? '99+' : '$soChuaDoc',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            onTap: () => Navigator.pushNamed(context, AppRoutes.patientNotifications),
          ),
        );
      },
    );
  }
}
