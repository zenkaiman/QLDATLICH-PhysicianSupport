# QLDATLICH
ứng dụng giúp chúng ta kết nối với các bệnh viện ,phòng khám để hỗ trợ đặt lịch khám.

## Thông báo sang phần Bệnh nhân

Mọi thao tác của nhân viên (Lễ tân / CSKH / phòng khám) đều tự động đẩy thông báo
sang phần Bệnh nhân qua collection `ThongBaoHeThong` — bệnh nhân không cần sửa code,
chỉ cần màn hình thông báo đang lắng nghe realtime.

Luồng chính:

| Thao tác của nhân viên | Nơi ghi | Trạng thái | Thông báo bệnh nhân nhận |
| --- | --- | --- | --- |
| Duyệt đơn đặt lịch | `FirebaseServiceC1.capNhatTrangThaiLichHen` | `2` | “Lịch hẹn đã được xác nhận” + số thứ tự |
| Từ chối đơn (kèm lý do) | `FirebaseServiceC1.capNhatTrangThaiLichHen` | `4` | “Lịch hẹn chưa được duyệt” + lý do |
| Nhấn “Tiếp theo” (xác nhận khám xong) | `ClinicFirestoreService.updateAppointmentStatus` | `5` | “Đã khám xong” |
| Nhấn “Đợi / Gọi lại” → Đợi | `ClinicFirestoreService.updateAppointmentStatus` | `7` | “Đã ghi nhận xin đợi” + số |
| Nhấn “+ Chèn” số trở lại hàng chờ | `ClinicFirestoreService.updateAppointmentStatus` | `2` | “Đã chèn lại vào hàng chờ” + số |
| “Xác nhận vắng mặt” | `ClinicFirestoreService.updateAppointmentStatus` | `6` | “Ghi nhận vắng mặt” |

Phía bệnh nhân:

- `lib/services/patient_notification_service.dart` — đọc realtime, đánh dấu đã đọc,
  đếm số chưa đọc; tự lọc thông báo đúng của bệnh nhân đang đăng nhập.
- `lib/screens/patient/patient_notifications_screen.dart` — màn hình “Thông báo”.
- `lib/screens/patient/widgets/patient_notification_bell.dart` — chuông + badge
  hiển thị trên trang chủ bệnh nhân (route `/patient-notifications`).

Định danh bệnh nhân lấy theo thứ tự: tham số truyền vào → `AppSession`
(`AppSession.capNhatDinhDanhBenhNhan(...)` gọi sau khi bệnh nhân đăng nhập).
Thông báo gắn `vai_tro_nhan = 'benh_nhan'` kèm `nguoi_nhan_id`, `benh_nhan_id`,
`so_dien_thoai`, `email` để khớp theo bất kỳ trường nào có trên document `LichHen`.

> Khi chạy thật, đặt `PatientNotificationService.cheDoXemThuKhiChuaDangNhap = false`
> để mỗi bệnh nhân chỉ thấy thông báo của chính mình.
