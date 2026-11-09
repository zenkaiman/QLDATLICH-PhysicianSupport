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

## Thẻ "Thông báo từ Bác sĩ" chạy realtime trên máy

Thẻ ở `lib/support_doctor/queue_screen.dart` (`_StatusBanner`) không còn để cứng
`08:42` nữa:

- `_LiveStatusFooter` lấy `DateTime.now()` — **giờ địa phương của máy đang chạy
  app** — và tự nhảy mỗi giây bằng `Timer.periodic`. Chỉ dòng footer nhỏ này
  vẽ lại, không rebuild cả màn hình hàng chờ. Khi app nằm nền rồi mở lại,
  `WidgetsBindingObserver` cập nhật giờ ngay lập tức.
- Cạnh đồng hồ là trạng thái của luồng dữ liệu (`QueueFeedState`):
  `Giờ máy` (không có stream), `Đang kết nối…`, `Realtime` (đã nhận lịch hẹn
  từ Firestore `snapshots()`), `Mất kết nối` (stream báo lỗi).
- Nội dung thẻ (`_defaultStatusMessage`) vốn đã được tính lại ở mỗi đợt
  `setState` do `watchAppointmentQueue()` phát ra, nên STT / tên bệnh nhân /
  trạng thái tạm dừng đổi ngay khi dữ liệu trên Firebase đổi.

### Xem thử ngay trên máy (không cần Flutter SDK / Firebase)

```bash
cd web && python3 -m http.server 8000 --bind 0.0.0.0
# mở http://localhost:8000/status_banner_realtime.html
```

Trang `web/status_banner_realtime.html` dựng lại đúng thẻ trong thiết kế, đồng
hồ chạy theo giờ trình duyệt/máy, có nút mô phỏng "duyệt lịch hẹn", "Tiếp
theo", "Tạm dừng khám", "Mất kết nối" và tự phát sự kiện mỗi 6 giây để thấy
thẻ đổi nội dung realtime.

Với app Flutter thật: `flutter run -d chrome` (hoặc `-d windows` / `-d macos` /
`-d linux`) rồi đăng nhập vai trò bác sĩ → chọn phòng → thẻ hiện giờ máy và
nhãn `Realtime` khi đã nhận được dữ liệu `LichHen` của phòng hôm nay.
