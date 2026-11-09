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

## Thẻ "Thông báo từ Bác sĩ": giờ chụp lúc bấm nút

Thẻ ở `lib/support_doctor/queue_screen.dart` (`_StatusBanner`) không còn để cứng
`08:42` và **không có đồng hồ chạy liên tục**:

- Khi bác sĩ bấm **Tạm dừng khám** hoặc **Tiếp tục khám**, `_QueueScreenState`
  chụp `DateTime.now()` (**giờ địa phương của máy**) vào
  `_lastStatusChangeAt` + nhãn `Tạm dừng lúc` / `Tiếp tục lúc`. Mốc giờ đó
  đứng yên cho đến lần bấm tiếp theo; lời nhắn trong thẻ cũng ghi kèm giờ.
- `_LiveStatusFooter` là `StatelessWidget`: footer chỉ hiện mốc giờ nếu đã có
  lần bấm nút, kèm trạng thái luồng dữ liệu (`QueueFeedState`): `Giờ máy` /
  `Đang kết nối…` / `Realtime` / `Mất kết nối`. Không còn `Timer.periodic` hay
  `WidgetsBindingObserver`, nên không có rebuild mỗi giây.
- Mốc giờ được lưu trong `RoomSessionSnapshot` (`statusChangedAt`,
  `statusChangeLabel`) để rời phòng rồi mở lại vẫn giữ nguyên.
- Nội dung thẻ (`_defaultStatusMessage`) vẫn được tính lại ở mỗi đợt
  `setState` do `watchAppointmentQueue()` phát ra, nên STT / tên bệnh nhân /
  trạng thái realtime đổi ngay khi dữ liệu Firebase đổi — chỉ phần giờ là đứng yên.

### 3 trạng thái phòng + nút Đóng / Mở phòng khám

`RoomRuntimeStatus` (`lib/support_doctor/room_session_store.dart`) nay có đủ
`open` / `paused` / `closed`, độ ưu tiên **Đóng > Tạm dừng > Đang khám**:

- `_QueueScreenState.closed` được lưu/khôi phục cùng `RoomSessionSnapshot`,
  nên màn hình chọn khoa/phòng hiện nhãn `Đã đóng` và lọc đúng nhóm phòng.
- **Nút dưới cùng**, ngay dưới thẻ thông báo: `Đóng phòng khám` ↔
  `Mở phòng khám` (`_ActionButton`, khoá các thao tác gọi số / xác nhận
  vắng mặt / đổi lượt / gọi lại số khi phòng đóng).
- Thẻ thông báo có bảng màu riêng cho 3 trạng thái (`_BannerStyle`): xanh /
  kem-cam / đỏ nhạt, kèm tiêu đề `Thông báo đóng phòng khám`; footer thêm
  nhãn `Đã đóng phòng`.
- Bấm Đóng / Mở **không đổi mốc giờ** của lần Tạm dừng / Tiếp tục khám
  (đúng yêu cầu "chỉ hiện thời gian lúc ấn tạm dừng và tiếp tục khám").
- Phòng đã đóng vẫn bấm được từ màn hình chọn phòng để vào trong và mở lại.

### Xem thử ngay trên máy (không cần Flutter SDK / Firebase)

```bash
cd web && python3 -m http.server 8000 --bind 0.0.0.0
# mở http://localhost:8000/status_banner_realtime.html
```

Trang `web/status_banner_realtime.html` dựng lại đúng thẻ trong thiết kế, có
nút mô phỏng "duyệt lịch hẹn", "Tiếp theo", "Tạm dừng khám", "Mất kết nối",
nút **Đóng / Mở phòng khám** ở dưới cùng và tự phát sự kiện mỗi 6 giây để thấy
nội dung thẻ đổi realtime. Riêng giờ chỉ xuất hiện/đổi khi bấm
**Tạm dừng / Tiếp tục khám** (không tick theo giây).

Với app Flutter thật: `flutter run -d chrome` (hoặc `-d windows` / `-d macos` /
`-d linux`) rồi đăng nhập vai trò bác sĩ → chọn phòng → bấm Tạm dừng khám để
thấy mốc giờ máy trên thẻ.
