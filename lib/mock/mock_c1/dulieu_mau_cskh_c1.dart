import '../../models/letan_c1/cskh_model_c1.dart';
import '../../models/letan_c1/letan_model_c1.dart';

/// LỚP QUẢN LÝ DỮ LIỆU TẬP TRUNG CHO CSKH & DUYỆT ĐƠN (C1)
/// Thiết kế chuẩn Service Pattern: Hiện tại cung cấp Mock Data,
/// khi nào kết nối Firebase Firestore chỉ cần thay thế hàm đọc/ghi ở đây,
/// UI bên ngoài hoàn toàn KHÔNG CẦN SỬA LẠI.
class DuLieuCskhKhoaC1 {
  // 1. Dữ liệu danh sách chuyên khoa
  static List<KhoaKhamModelC1> danhSachKhoa = [
    const KhoaKhamModelC1(
      id: 'khoa_tim_mach',
      tenKhoa: 'Khoa Tim Mạch',
      moTaPhong: 'Phòng 201 • Ca sáng & chiều',
      tongDonCho: 25,
      chiTieuNgay: 25,
      laDayDon: true,
    ),
    const KhoaKhamModelC1(
      id: 'khoa_noi_tong_quat',
      tenKhoa: 'Khoa Nội Tổng Quát',
      moTaPhong: 'Phòng 102 • BS. Nguyễn Văn Hùng',
      tongDonCho: 20,
      chiTieuNgay: 30,
      laDayDon: false,
    ),
    const KhoaKhamModelC1(
      id: 'khoa_nhi',
      tenKhoa: 'Khoa Nhi',
      moTaPhong: 'Phòng 305 • Khám nhi đồng',
      tongDonCho: 15,
      chiTieuNgay: 20,
      laDayDon: false,
    ),
    const KhoaKhamModelC1(
      id: 'khoa_rang_ham_mat',
      tenKhoa: 'Khoa Răng Hàm Mặt',
      moTaPhong: 'Phòng 401 • Nha khoa chuyên sâu',
      tongDonCho: 12,
      chiTieuNgay: 15,
      laDayDon: false,
    ),
    const KhoaKhamModelC1(
      id: 'khoa_mat',
      tenKhoa: 'Khoa Mắt',
      moTaPhong: 'Phòng 204 • Đo thị lực & khúc xạ',
      tongDonCho: 10,
      chiTieuNgay: 15,
      laDayDon: false,
    ),
  ];

  // 2. Dữ liệu đơn khám bệnh theo khoa
  static List<DonKhamKhoaModelC1> layDanhSachDonKhamTheoKhoa(String tenKhoa) {
    return [
      DonKhamKhoaModelC1(id: 'dk_01', stt: 1, maDon: '#MED-2026-8921', hoTen: 'Nguyễn Văn A', tenKhoa: tenKhoa, phongKham: 'Phòng 201', caKham: 'Ca sáng', khungGio: '08:00 - 08:30', gioiTinh: 'Nam', tuoi: 32, trangThai: 'cho_duyet'),
      DonKhamKhoaModelC1(id: 'dk_02', stt: 2, maDon: '#MED-2026-8922', hoTen: 'Trần Thị Mai', tenKhoa: tenKhoa, phongKham: 'Phòng 201', caKham: 'Ca sáng', khungGio: '08:30 - 09:00', gioiTinh: 'Nữ', tuoi: 45, trangThai: 'da_duyet'),
      DonKhamKhoaModelC1(id: 'dk_03', stt: 3, maDon: '#MED-2026-8923', hoTen: 'Lê Hoàng Nam', tenKhoa: tenKhoa, phongKham: 'Phòng 201', caKham: 'Ca sáng', khungGio: '09:00 - 09:30', gioiTinh: 'Nam', tuoi: 28, trangThai: 'cho_duyet'),
      DonKhamKhoaModelC1(id: 'dk_04', stt: 4, maDon: '#MED-2026-8924', hoTen: 'Phạm Minh Đức', tenKhoa: tenKhoa, phongKham: 'Phòng 201', caKham: 'Ca sáng', khungGio: '09:30 - 10:00', gioiTinh: 'Nam', tuoi: 54, trangThai: 'cho_duyet'),
      DonKhamKhoaModelC1(id: 'dk_05', stt: 5, maDon: '#MED-2026-8925', hoTen: 'Vũ Thu Trang', tenKhoa: tenKhoa, phongKham: 'Phòng 201', caKham: 'Ca sáng', khungGio: '10:00 - 10:30', gioiTinh: 'Nữ', tuoi: 39, trangThai: 'cho_duyet'),
      DonKhamKhoaModelC1(id: 'dk_06', stt: 6, maDon: '#MED-2026-8926', hoTen: 'Đỗ Văn Tuấn', tenKhoa: tenKhoa, phongKham: 'Phòng 201', caKham: 'Ca sáng', khungGio: '10:30 - 11:00', gioiTinh: 'Nam', tuoi: 61, trangThai: 'cho_duyet'),
      DonKhamKhoaModelC1(id: 'dk_07', stt: 7, maDon: '#MED-2026-8927', hoTen: 'Hoàng Bích Ngọc', tenKhoa: tenKhoa, phongKham: 'Phòng 201', caKham: 'Ca sáng', khungGio: '11:00 - 11:30', gioiTinh: 'Nữ', tuoi: 25, trangThai: 'cho_duyet'),
      DonKhamKhoaModelC1(id: 'dk_08', stt: 8, maDon: '#MED-2026-8928', hoTen: 'Bùi Quang Huy', tenKhoa: tenKhoa, phongKham: 'Phòng 201', caKham: 'Ca chiều', khungGio: '13:30 - 14:00', gioiTinh: 'Nam', tuoi: 48, trangThai: 'tu_choi', lyDoTuChoi: 'Phòng khám đã đủ số lượng tiếp nhận tối đa'),
      DonKhamKhoaModelC1(id: 'dk_09', stt: 9, maDon: '#MED-2026-8929', hoTen: 'Nguyễn Thị Lan', tenKhoa: tenKhoa, phongKham: 'Phòng 201', caKham: 'Ca chiều', khungGio: '14:00 - 14:30', gioiTinh: 'Nữ', tuoi: 50, trangThai: 'cho_duyet'),
      DonKhamKhoaModelC1(id: 'dk_10', stt: 10, maDon: '#MED-2026-8930', hoTen: 'Trịnh Quốc Bảo', tenKhoa: tenKhoa, phongKham: 'Phòng 201', caKham: 'Ca chiều', khungGio: '14:30 - 15:00', gioiTinh: 'Nam', tuoi: 36, trangThai: 'cho_duyet'),
    ];
  }

  // 3. Dữ liệu danh sách hội thoại CSKH hỗ trợ bệnh nhân
  static List<HoiThoaiCskhModelC1> danhSachHoiThoai = [
    const HoiThoaiCskhModelC1(
      id: 'ht_01',
      benhNhanId: 'BN01',
      hoTen: 'Nguyễn Văn A',
      vietTat: 'NA',
      tinNhanCuoi: 'Anh bị đau ngực trái + khó thở...',
      thoiGian: '09:42',
      khoa: 'Khoa Tim mạch',
      tuoi: 54,
      maBhyt: 'GD-2201457',
      tinChuaDoc: 1,
      dangChoPhanHoi: true,
    ),
    const HoiThoaiCskhModelC1(
      id: 'ht_02',
      benhNhanId: 'BN02',
      hoTen: 'Trần Thị Bích',
      vietTat: 'TB',
      tinNhanCuoi: 'Em muốn hỏi lịch tái khám tuần sau...',
      thoiGian: '08:15',
      khoa: 'Khoa Nội',
      tuoi: 42,
      maBhyt: 'GD-8830192',
      tinChuaDoc: 0,
      dangChoPhanHoi: true,
    ),
    const HoiThoaiCskhModelC1(
      id: 'ht_03',
      benhNhanId: 'BN03',
      hoTen: 'Lê Hoàng',
      vietTat: 'LH',
      tinNhanCuoi: 'Kết quả xét nghiệm máu của tôi thế nào?',
      thoiGian: 'Hôm qua',
      khoa: 'Khoa Xét nghiệm',
      tuoi: 38,
      maBhyt: 'GD-4491028',
      tinChuaDoc: 0,
      dangChoPhanHoi: false,
    ),
    const HoiThoaiCskhModelC1(
      id: 'ht_04',
      benhNhanId: 'BN04',
      hoTen: 'Phạm Minh',
      vietTat: 'PM',
      tinNhanCuoi: 'Tôi cần đổi ca khám sang chiều...',
      thoiGian: 'Hôm qua',
      khoa: 'Khoa Ngoại',
      tuoi: 49,
      maBhyt: 'GD-7712390',
      tinChuaDoc: 0,
      dangChoPhanHoi: true,
    ),
    const HoiThoaiCskhModelC1(
      id: 'ht_05',
      benhNhanId: 'BN05',
      hoTen: 'Hoàng Thị Tuyết',
      vietTat: 'HT',
      tinNhanCuoi: 'Cảm ơn bác sĩ đã tư vấn...',
      thoiGian: '2 ngày trước',
      khoa: 'Khoa Sản',
      tuoi: 29,
      maBhyt: 'GD-1192837',
      tinChuaDoc: 0,
      dangChoPhanHoi: false,
    ),
  ];

  // 4. Dữ liệu tin nhắn trong 1 phòng chat
  static List<TinNhanCskhModelC1> layTinNhanTheoHoiThoai(String hoiThoaiId) {
    return [
      TinNhanCskhModelC1(
        id: 'tn_01',
        hoiThoaiId: hoiThoaiId,
        noiDung: 'Chào em, dạo này anh bị đau ngực trái kèm khó thở nhẹ, đặc biệt khi leo cầu thang. Anh lo có phải bệnh tim không?',
        thoiGian: '09:42',
        laCskhGui: false,
      ),
      TinNhanCskhModelC1(
        id: 'tn_02',
        hoiThoaiId: hoiThoaiId,
        noiDung: 'Dạ anh ơi, triệu chứng đau ngực + khó thở cần được kiểm tra sớm. Em khuyên anh nên đến Khoa Tim mạch để đo ECG và siêu âm tim. Anh muốn đặt lịch không ạ?',
        thoiGian: '09:43',
        laCskhGui: true,
      ),
      TinNhanCskhModelC1(
        id: 'tn_03',
        hoiThoaiId: hoiThoaiId,
        noiDung: 'Vâng em ơi, anh muốn đặt lịch sớm nhất có thể được không?',
        thoiGian: '09:44',
        laCskhGui: false,
      ),
    ];
  }

  // 5. Danh sách thông báo riêng của CSKH
  static List<ThongBaoLeTanC1> danhSachThongBao = const [
    ThongBaoLeTanC1(
      id: 'cskh_01',
      tieuDe: 'Khoa Tim Mạch đã đủ 25/25 chỉ tiêu',
      noiDungNgan: 'Hệ thống đã nhận đủ 25 đơn khám sáng & chiều cho phòng 201.',
      noiDungChiTiet: 'Hệ thống tiếp nhận ghi nhận Khoa Tim Mạch đã đạt tối đa 25 bệnh nhân đăng ký khám trong ngày. Đề nghị chuyên viên CSKH hướng dẫn các bệnh nhân tiếp theo dời lịch hoặc đăng ký khám nội tổng quát.',
      thoiGian: '5 phút trước',
      loai: 'khan_cap',
      daDoc: false,
    ),
    ThongBaoLeTanC1(
      id: 'cskh_02',
      tieuDe: '82 đơn khám đang chờ duyệt tiếp nhận',
      noiDungNgan: 'Vui lòng kiểm tra và duyệt nhanh danh sách bệnh nhân đặt lịch.',
      noiDungChiTiet: 'Hiện có 82 hồ sơ đặt khám trước qua app cần bộ phận CSKH rà soát thông tin BHYT và xác nhận khung giờ trước 09:00.',
      thoiGian: '20 phút trước',
      loai: 'lich_hen',
      daDoc: false,
    ),
    ThongBaoLeTanC1(
      id: 'cskh_03',
      tieuDe: 'Đồng bộ danh sách phòng khám ca sáng',
      noiDungNgan: '5 chuyên khoa đã sẵn sàng nhận bệnh nhân theo thứ tự số thứ tự.',
      noiDungChiTiet: 'Tất cả các phòng khám 102, 201, 204, 305, 401 đã kích hoạt hệ thống gọi số tự động.',
      thoiGian: '1 giờ trước',
      loai: 'he_thong',
      daDoc: true,
    ),
  ];

  // 6. Danh mục lý do từ chối đơn khám
  static const List<String> danhSachLyDoTuChoi = [
    'Phòng khám đã đủ số lượng tiếp nhận tối đa',
    'Bác sĩ chỉ định có lịch mổ / hội chẩn đột xuất',
    'Thông tin thẻ BHYT hoặc thông tin cá nhân chưa khớp',
    'Khác (Nhập lý do gửi riêng cho bệnh nhân...)',
  ];

  // 7. Gợi ý trả lời nhanh cho chat (Canned Responses theo nghiệp vụ thực tế)
  static const List<Map<String, String>> danhMucTraLoiNhanh = [
    {
      'tieuDe': 'Xác nhận lịch hẹn',
      'noiDung': 'Chào bạn, bệnh viện đã xác nhận lịch khám của bạn. Vui lòng đến trước 15 phút tại quầy Lễ tân để quét mã tiếp nhận.',
    },
    {
      'tieuDe': 'Hướng dẫn BHYT',
      'noiDung': 'Khi đi khám, bạn vui lòng mang theo Thẻ BHYT (hoặc ứng dụng VssID) và CCCD gắn chip để được hưởng đầy đủ quyền lợi.',
    },
    {
      'tieuDe': 'Chuẩn bị trước xét nghiệm',
      'noiDung': 'Đối với các xét nghiệm máu và nội soi, bạn cần nhịn ăn sáng tối thiểu 6-8 tiếng và chỉ uống nước lọc.',
    },
    {
      'tieuDe': 'Hướng dẫn đổi giờ khám',
      'noiDung': 'Bạn có thể vào mục "Lịch khám của tôi" trên ứng dụng để chọn lại khung giờ khám mới phù hợp hơn.',
    },
    {
      'tieuDe': 'Khoa tạm kín lịch',
      'noiDung': 'Hiện phòng khám chuyên khoa này trong ca sáng đã đủ số lượng tiếp nhận. Bạn có thể đăng ký ca chiều (từ 13:30) hoặc chuyển sang ngày mai.',
    },
    {
      'tieuDe': 'Cảm ơn & Chào tạm biệt',
      'noiDung': 'Cảm ơn bạn đã liên hệ bộ phận Chăm sóc khách hàng bệnh viện. Chúc bạn một ngày nhiều sức khỏe!',
    },
  ];

  static const List<String> goiYTraLoiNhanh = [
    'Xác nhận lịch hẹn',
    'Hướng dẫn BHYT',
    'Nhịn ăn xét nghiệm',
    'Đổi giờ khám',
    'Khoa kín lịch',
    'Cảm ơn bạn',
  ];
}
