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

## Danh mục loại thông báo — `LoaiThongBao/benh_vien_thong_bao`

Nội dung thông báo gửi sang bệnh nhân lấy từ document
`LoaiThongBao/benh_vien_thong_bao` trên Firestore (`lib/services/loai_thong_bao_service.dart`).

Mỗi thông báo ghi vào `ThongBaoHeThong` đều mang `loai_thong_bao_id = "benh_vien_thong_bao"`
và `ma_loai_thong_bao` để tra icon/màu/nội dung.

Các mã loại đang dùng:

| Mã (`ma`) | Dùng khi |
| --- | --- |
| `kham_xong` | Nhân viên bấm “Tiếp theo” → bệnh nhân đã khám xong |
| `xin_doi` | Bấm “Đợi / Gọi lại” → cho số qua lượt (đợi) |
| `chen_so` | Bấm “+ Chèn” → đưa số trở lại hàng chờ |
| `vang_mat` | “Xác nhận vắng mặt” |
| `duyet_lich` | Duyệt đơn đặt lịch |
| `tu_choi_lich` | Từ chối đơn đặt lịch |

Document có thể khai báo trực tiếp các loại con bằng field dạng mảng/object
(`danh_sach`, `items`, `loai`, `cac_loai`, …) hoặc bằng subcollection
`LoaiThongBao/benh_vien_thong_bao/danh_sach/{ma_loai}`:

```json
{
  "ma": "benh_vien_thong_bao",
  "ten": "Bệnh viện thông báo",
  "icon": "campaign",
  "mau": "#0284C7",
  "bat": true,
  "danh_sach": [
    {
      "ma": "kham_xong",
      "tieu_de": "Đã khám xong",
      "noi_dung": "Bạn đã hoàn thành lượt khám tại {phong} ({so_thu_tu}). Chúc bạn nhiều sức khoẻ!",
      "icon": "check_circle",
      "mau": "#16A34A",
      "bat": true
    }
  ]
}
```

Placeholder hỗ trợ trong `tieu_de` / `noi_dung`:
`{so_thu_tu}`, `{khoa}`, `{phong}`, `{gio}`, `{ngay}`, `{ly_do}`, `{ho_ten}`, `{ghi_chu}`.

- Loại không khai báo → dùng câu mặc định trong app (không lỗi).
- `bat: false` (hoặc `trang_thai: "tat"`) → **không gửi** loại thông báo đó.
- Đổi cấu hình trên Firestore xong, gọi `LoaiThongBaoService.layCauHinh(lamMoi: true)`
  (hoặc khởi động lại app) để nạp lại.
