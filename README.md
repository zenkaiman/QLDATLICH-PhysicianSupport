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

## Chặn đăng nhập khi bệnh viện ngừng hợp tác

`lib/services/hospital_access_service.dart` đọc document `BenhVien/{benhVienId}`
và chỉ cho vào khi `trang_thai_hop_tac_id == 10`. Chấp nhận cả số `10` lẫn
chuỗi `"10"` và các biến thể tên trường (`trangThaiHopTacId`,
`trang_thai_hop_tac`, `trangThaiHopTac`).

| Trường hợp | Kết quả |
| --- | --- |
| Có document, trạng thái `10` | Đăng nhập bình thường |
| Không có document / không suy ra được `benhVienId` / thiếu trường trạng thái | `Bệnh viện không tồn tại hoặc tài khoản không thuộc bệnh viện nào.` |
| Trạng thái khác `10` | `Bệnh viện đã ngừng hợp tác (trạng thái …). Vui lòng liên hệ quản trị.` |
| Lỗi đọc Firestore (mất mạng, không có quyền) | `Không kiểm tra được thông tin bệnh viện. Vui lòng thử lại.` |

Mọi trường hợp không hợp lệ đều: **không lưu phiên ghi nhớ đăng nhập**, hiện
thông báo trên màn hình đăng nhập rồi **tự động đăng xuất**
(`AuthProvider.logout()` → `FirebaseAuth.signOut()`,
`FirebaseServiceC1.xoaPhienDangNhap()`, xoá định danh bệnh nhân, đẩy về
`/login`). Kiểm tra được chèn **trước** khi điều hướng theo vai trò ở cả hai
màn đăng nhập nhân viên: `screens/auth/login_screen.dart` và
`screens/letan_c1/letan_dangnhap_screen_c1.dart` (kể cả luồng tự động đăng
nhập lại từ phiên đã lưu).

> Dữ liệu cũ chưa có trường `trang_thai_hop_tac_id`: mặc định fail-closed
> (chặn). Đặt `HospitalAccessService.coiThieuTruongLaKhongHopLe = false;`
> trong `main()` nếu muốn tạm cho đăng nhập.

Phạm vi hiện tại: 2 luồng đăng nhập **nhân viên y tế** (bác sĩ / lễ tân /
CSKH), vì chỉ các luồng này suy ra được `benhVienId` từ document `NhanVien`.
Tab Bệnh viện / Bệnh nhân / Admin chưa có mã bệnh viện khi đăng nhập nên chưa
áp dụng.

## Trạng thái phòng khám theo `trang_thai_id` (12 / 13 / 14)

Bảng dùng chung nằm ở `lib/support_doctor/room_status.dart`. App lấy đúng
document `PhongKham/{roomId}` theo mã phòng đã chọn (ví dụ
`PhongKham/BV502_K001_HH001`), đọc `trang_thai_id`, so sánh với bảng
12/13/14 rồi áp vào **bảng trạng thái phòng khám** (chip lọc + thẻ phòng) và
**các nút Tạm dừng / Tiếp tục / Đóng / Mở phòng khám**.

| `trang_thai_id` | Trạng thái | Nút / hành động |
| --- | --- | --- |
| `12` | Tạm dừng khám | Nút `Tiếp tục khám`, banner kem-cam, chặn gọi số mới |
| `13` | Đang khám | Nút `Tạm dừng khám` / `Đóng phòng khám`, banner xanh |
| `14` | Đóng phòng khám | Nút `Mở phòng khám`, banner đỏ, khoá mọi thao tác gọi số |

- Trường chính là `trang_thai_id` (số hoặc chuỗi `"12"` …). Các biến thể
  `trangThaiId`, `statusId`, `id_trang_thai`, `ma_trang_thai`, `trang_thai`,
  `trangThai` vẫn được đọc để hỗ trợ dữ liệu cũ. Thiếu field hoặc mã lạ →
  coi như `13` và giữ nguyên trạng thái phiên `RoomSessionStore` như trước.
- `clinic_firestore_service.dart`: `watchRoomStatusId()` nghe realtime đúng
  document phòng; `updateRoomStatusId()` ghi `12/13/14` bằng `set(merge: true)`
  nên không xoá các field `hospitalId`, `khoaId`, `ten_phong` … đang có.
- Khi document có field, **Firestore là nguồn sự thật**: màn hình chọn
  khoa/phòng hiện nhãn đầy đủ kèm mã (`Tạm dừng khám · 12` …), chip lọc
  `Đang khám (13)` / `Tạm dừng khám (12)` / `Đóng phòng khám (14)` và không
  để trạng thái phiên local ghi đè lên.
- Trên `QueueScreen`, bấm **Tạm dừng khám** ghi `12`, **Tiếp tục khám** và
  **Mở phòng khám** ghi `13`, **Đóng phòng khám** ghi `14`. Trạng thái từ
  thiết bị khác cũng cập nhật banner/nút ngay qua stream. Thay đổi từ
  Firestore **không chụp lại giờ máy**: mốc `HH:mm:ss` vẫn chỉ đổi khi bấm
  Tạm dừng / Tiếp tục trên chính thiết bị đó.
- `web/status_banner_realtime.html` có thêm bảng 12/13/14 và tô dòng đang
  áp dụng; các nút mô phỏng cũng ghi log mã trạng thái tương ứng.

### Bổ sung field cho document phòng đã có

Trên Firebase Console, mở `PhongKham/BV502_K001_HH001` → **Add field**
`trang_thai_id` (kiểu `number`, giá trị `13` để bắt đầu ở **Đang khám**).
Hoặc gọi từ code dev (không tự chạy khi khởi động app):

```dart
await DatabaseSeeder.seedRoomStatusId(
  roomId: 'BV502_K001_HH001',
  statusId: 13, // 12 tạm dừng | 13 đang khám | 14 đóng phòng
);
```

> Tên field `trang_thai_id` là mặc định đã chọn cho luồng này; nếu document
> `BV502_K001_HH001` đang dùng tên khác, thêm tên đó vào
> `kRoomStatusFieldVariants` trong `lib/support_doctor/room_status.dart` hoặc
> đổi trực tiếp trên Firebase Console.

`lib/database_seeder.dart` dùng `SetOptions(merge: true)` nên chỉ thêm field
trạng thái, không tạo lại document. Cần đảm bảo Firestore rules cho phép nhân
viên/bác sĩ đọc và ghi field này. Không thay đổi cấu hình Firebase, không tạo
collection/subcollection mới, không thêm dependency và không thêm test.
