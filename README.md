# QLDATLICH
ứng dụng giúp chúng ta kết nối với các bệnh viện ,phòng khám để hỗ trợ đặt lịch khám.

## Bản gộp các nhóm

Bản gộp lấy mã nguồn từ `PATBIBIBOY/QLDATLICH` tại các mốc sau:

| Nhánh nguồn | Commit |
| --- | --- |
| `CauTrucFile` | `e19ecac` |
| `DangKi/DangNhap` | `e4e952b` |
| `Benh_Nhan` | `c5dc814` |
| `PhysicianSupport` | `af3a8f6` |
| `benhvien` | `fef2d14` |
| `letan_cuoc` | `ebcc26d` |
| `Admin` | `c38134f` |

Dùng bản gộp nguồn `9a92185` làm nền để giữ các xử lý xung đột đã có; đối
chiếu thêm với `Admin` và bổ sung `sync_firebase_schema.py`. Không đưa lịch
sử chứa khóa dịch vụ, file cache Firebase hay tài liệu Word vào bản gộp.

### Chạy và cấu hình

- Flutter: chạy `flutter pub get`, `flutter analyze` và `flutter test`.
- Để bật thao tác quản lý Firebase Authentication, triển khai hàm
  `manageAuthUser` vào dự án Firebase đang cấu hình trong ứng dụng. Tài khoản
  chạy hàm cần quyền quản lý Firebase Authentication. Cấp custom claim
  `admin: true` từ môi trường quản trị tin cậy, sau đó đăng nhập lại để nhận token mới.
- Chạy `sync_firebase_schema.py` bằng Application Default Credentials của
  đúng dự án, ưu tiên môi trường thử nghiệm vì script ghi vào Firestore.
- Thu hồi và thay thế khóa Service Account đã lộ trong repo nguồn. Không đưa
  khóa mới vào Flutter, file cấu hình trong Git hoặc tham số build.
