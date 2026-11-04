import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../../services/patient_notification_service.dart';

/// Chuông thông báo có badge số chưa đọc — dùng trong phần Bệnh nhân.
///
/// Bấm vào sẽ mở màn hình `PatientNotificationsScreen`.
class PatientNotificationBell extends StatelessWidget {
  const PatientNotificationBell({super.key});

  void _moDanhSachThongBao(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.patientNotifications);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: PatientNotificationService.streamSoThongBaoChuaDocCuaToi(),
      builder: (context, snapshot) {
        final soChuaDoc = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'Thông báo',
          onPressed: () => _moDanhSachThongBao(context),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_active_outlined, size: 24),
              if (soChuaDoc > 0)
                Positioned(
                  right: -6,
                  top: -5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 1.6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      soChuaDoc > 99 ? '99+' : '$soChuaDoc',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
