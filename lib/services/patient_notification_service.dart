import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../config/app_session.dart';

/// Cầu nối THÔNG BÁO giữa khu vực Lễ tân/CSKH và PHẦN BỆNH NHÂN.
///
/// Trước đây thông báo chỉ hiển thị bên Lễ tân/CSKH (bottom sheet "Thông Báo").
/// Service này tái sử dụng đúng collection `ThongBaoHeThong` trên Firestore
/// nhưng bổ sung luồng dành riêng cho bệnh nhân:
///
/// - Mỗi thông báo gửi cho bệnh nhân được gắn `vai_tro_nhan = 'benh_nhan'`
///   kèm định danh người nhận (`nguoi_nhan_id` / `benh_nhan_id` /
///   `so_dien_thoai` / `email`) để phần Bệnh nhân lọc realtime.
/// - Khi Lễ tân/CSKH duyệt hoặc từ chối một lịch hẹn, một thông báo sẽ được
///   đẩy ngay sang phần Bệnh nhân (xem `guiThongBaoKetQuaDuyetLichHen`).
/// - Phần Bệnh nhân đọc, đánh dấu đã đọc và đếm số thông báo chưa đọc.
class PatientNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String collectionThongBao = 'ThongBaoHeThong';
  static const String vaiTroBenhNhan = 'benh_nhan';
  static const String vaiTroTatCa = 'tat_ca';

  /// Chế độ xem thử phần Bệnh nhân khi app CHƯA có đăng nhập bệnh nhân.
  ///
  /// Khi bệnh nhân chưa có định danh (uid / mã bệnh nhân / số điện thoại /
  /// email), luồng thông báo sẽ hiển thị mọi thông báo có
  /// `vai_tro_nhan = 'benh_nhan'` để kiểm thử giao diện.
  ///
  /// ⚠️ Đặt về `false` khi chạy thật để tránh bệnh nhân này thấy thông báo
  /// của bệnh nhân khác.
  static bool cheDoXemThuKhiChuaDangNhap = true;

  /// ID bệnh viện đang dùng (ưu tiên tham số → AppSession → mặc định BV502)
  static String benhVienIdHienTai([String? benhVienId]) {
    final value = (benhVienId ?? '').trim();
    if (value.isNotEmpty && value != '1' && value != 'BV01') return value;

    final sessionValue = AppSession.benhVienId.trim();
    if (sessionValue.isNotEmpty && sessionValue != '1' && sessionValue != 'BV01') {
      return sessionValue;
    }
    return 'BV502';
  }

  /// Định danh của bệnh nhân đang đăng nhập.
  ///
  /// Lấy từ `AppSession` (nơi màn hình đăng nhập của bệnh nhân gọi
  /// `AppSession.capNhatDinhDanhBenhNhan(...)`) và từ tham số truyền vào.
  /// Không dùng Firebase Auth vì app này có thể đang đăng nhập tài khoản
  /// nhân viên — thông báo bệnh nhân phải khớp theo định danh bệnh nhân.
  static Set<String> dinhDanhHienTai({
    String? uid,
    String? benhNhanId,
    String? soDienThoai,
    String? email,
  }) {
    final ketQua = <String>{};

    void them(String? giaTri) {
      final value = (giaTri ?? '').trim().toLowerCase();
      if (value.isNotEmpty) ketQua.add(value);
    }

    them(AppSession.uidBenhNhan);
    them(AppSession.benhNhanId);
    them(AppSession.soDienThoaiBenhNhan);
    them(AppSession.emailBenhNhan);

    them(uid);
    them(benhNhanId);
    them(soDienThoai);
    them(email);

    return ketQua;
  }

  // ===========================================================================
  // 1. ĐỌC THÔNG BÁO REALTIME
  // ===========================================================================

  /// Lắng nghe thông báo dành cho bệnh nhân theo thời gian thực.
  ///
  /// [gioiHan] giới hạn số document tải về (mặc định 50) để tránh đọc nhiều.
  static Stream<List<Map<String, dynamic>>> streamThongBaoBenhNhan({
    String? uid,
    String? benhNhanId,
    String? soDienThoai,
    String? email,
    String? benhVienId,
    int gioiHan = 50,
  }) {
    final bvid = benhVienIdHienTai(benhVienId);
    final dinhDanh = dinhDanhHienTai(
      uid: uid,
      benhNhanId: benhNhanId,
      soDienThoai: soDienThoai,
      email: email,
    );
    final choPhepXemTatCa = dinhDanh.isEmpty && cheDoXemThuKhiChuaDangNhap;

    return _firestore
        .collection(collectionThongBao)
        .orderBy('thoi_gian', descending: true)
        .limit(gioiHan)
        .snapshots()
        .map((snap) {
      final ketQua = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (!_laThongBaoCuaBenhNhan(
          data,
          dinhDanh,
          choPhepXemTatCa: choPhepXemTatCa,
        )) {
          continue;
        }

        final docBv = (data['benh_vien_id'] ?? '').toString().trim();
        if (docBv.isNotEmpty && docBv != bvid) continue;

        ketQua.add({'id': doc.id, ...data});
      }
      return ketQua;
    });
  }

  /// Bản rút gọn: tự lấy định danh của bệnh nhân đang đăng nhập
  static Stream<List<Map<String, dynamic>>> streamThongBaoCuaToi({
    String? soDienThoai,
    String? benhVienId,
    int gioiHan = 50,
  }) {
    return streamThongBaoBenhNhan(
      soDienThoai: soDienThoai,
      benhVienId: benhVienId,
      gioiHan: gioiHan,
    );
  }

  /// Đếm số thông báo chưa đọc (dùng cho badge chuông trên trang chủ bệnh nhân)
  static Stream<int> streamSoThongBaoChuaDocCuaToi({
    String? soDienThoai,
    String? benhVienId,
  }) {
    return streamThongBaoCuaToi(soDienThoai: soDienThoai, benhVienId: benhVienId)
        .map((ds) => ds.where((e) => e['da_doc'] != true).length);
  }

  // ===========================================================================
  // 2. ĐÁNH DẤU ĐÃ ĐỌC
  // ===========================================================================

  static Future<void> danhDauDaDoc(String thongBaoId) async {
    final id = thongBaoId.trim();
    if (id.isEmpty) return;
    try {
      await _firestore.collection(collectionThongBao).doc(id).update({'da_doc': true});
    } catch (_) {
      // Không chặn UI khi lỗi mạng / thiếu quyền
    }
  }

  static Future<void> danhDauTatCaDaDoc(Iterable<Map<String, dynamic>> danhSach) async {
    final batch = _firestore.batch();
    var coThayDoi = false;

    for (final item in danhSach) {
      final id = (item['id'] ?? '').toString().trim();
      if (id.isEmpty || item['da_doc'] == true) continue;
      batch.update(
        _firestore.collection(collectionThongBao).doc(id),
        {'da_doc': true},
      );
      coThayDoi = true;
    }

    if (!coThayDoi) return;
    try {
      await batch.commit();
    } catch (_) {}
  }

  // ===========================================================================
  // 3. GỬI THÔNG BÁO TỪ LỄ TÂN / CSKH → BỆNH NHÂN
  // ===========================================================================

  /// Ghi 1 thông báo dành cho bệnh nhân vào `ThongBaoHeThong`.
  ///
  /// Truyền càng nhiều định danh (uid / mã bệnh nhân / số điện thoại / email)
  /// thì khả năng phần Bệnh nhân nhận được thông báo càng cao.
  static Future<void> guiThongBaoChoBenhNhan({
    required String tieuDe,
    required String noiDung,
    String loai = 'he_thong',
    String? nguoiNhanId,
    String? benhNhanId,
    String? soDienThoai,
    String? email,
    String? benhVienId,
    String? lichHenId,
    String? tenKhoa,
    Map<String, dynamic> duLieuThem = const {},
  }) async {
    final data = <String, dynamic>{
      ...duLieuThem,
      'tieu_de': tieuDe,
      'noi_dung': noiDung,
      'loai': loai,
      'vai_tro_nhan': vaiTroBenhNhan,
      'nguoi_nhan_id': (nguoiNhanId ?? '').trim(),
      'benh_nhan_id': (benhNhanId ?? '').trim(),
      'so_dien_thoai': (soDienThoai ?? '').trim(),
      'email': (email ?? '').trim(),
      'benh_vien_id': benhVienIdHienTai(benhVienId),
      'da_doc': false,
      'thoi_gian': FieldValue.serverTimestamp(),
      'thoi_gian_hien_thi': 'Vừa xong',
    };

    final maLichHen = (lichHenId ?? '').trim();
    if (maLichHen.isNotEmpty) data['lich_hen_id'] = maLichHen;

    final khoa = (tenKhoa ?? '').trim();
    if (khoa.isNotEmpty) data['ten_khoa'] = khoa;

    try {
      await _firestore.collection(collectionThongBao).add(data);
    } catch (_) {
      // Bỏ qua lỗi để không làm hỏng luồng duyệt lịch hẹn
    }
  }

  /// Thông báo kết quả duyệt / từ chối lịch hẹn cho bệnh nhân.
  /// Được gọi tự động từ `FirebaseServiceC1.capNhatTrangThaiLichHen`.
  static Future<void> guiThongBaoKetQuaDuyetLichHen({
    required String lichHenId,
    required bool daDuyet,
    String? hoTen,
    String? tenKhoa,
    String? gioKham,
    Object? ngayKham,
    int? soThuTu,
    String? lyDoTuChoi,
    String? nguoiNhanId,
    String? benhNhanId,
    String? soDienThoai,
    String? email,
    String? benhVienId,
  }) async {
    final khoa = (tenKhoa ?? '').trim();
    final moTaKhoa = khoa.isEmpty ? 'lịch hẹn khám' : 'lịch hẹn $khoa';

    final ngay = dinhDangNgay(ngayKham);
    final gio = (gioKham ?? '').trim();
    final thoiGianKham = [ngay, gio].where((e) => e.isNotEmpty).join(' • ');
    final thoiGianCau = thoiGianKham.isEmpty ? '' : ' vào $thoiGianKham';

    final String tieuDe;
    final String noiDung;

    if (daDuyet) {
      tieuDe = 'Lịch hẹn đã được xác nhận';
      final sttCau = (soThuTu != null && soThuTu > 0) ? ' Số thứ tự của bạn là $soThuTu.' : '';
      noiDung = 'Bệnh viện đã xác nhận $moTaKhoa$thoiGianCau.$sttCau '
          'Vui lòng có mặt trước giờ khám 15 phút và xuất trình mã QR khi tới quầy tiếp đón.';
    } else {
      tieuDe = 'Lịch hẹn chưa được duyệt';
      final lyDo = (lyDoTuChoi ?? '').trim();
      final lyDoCau = lyDo.isEmpty ? '' : ' Lý do: $lyDo.';
      noiDung = 'Rất tiếc, $moTaKhoa$thoiGianCau chưa được duyệt.$lyDoCau '
          'Bạn có thể đặt lịch khám ở khung giờ khác hoặc liên hệ CSKH để được hỗ trợ.';
    }

    await guiThongBaoChoBenhNhan(
      tieuDe: tieuDe,
      noiDung: noiDung,
      loai: 'lich_hen',
      nguoiNhanId: nguoiNhanId,
      benhNhanId: benhNhanId,
      soDienThoai: soDienThoai,
      email: email,
      benhVienId: benhVienId,
      lichHenId: lichHenId,
      tenKhoa: tenKhoa,
      duLieuThem: {
        'trang_thai_lich_hen': daDuyet ? 'da_duyet' : 'tu_choi',
        if (soThuTu != null) 'so_thu_tu': soThuTu,
        if ((lyDoTuChoi ?? '').trim().isNotEmpty) 'ly_do_tu_choi': lyDoTuChoi!.trim(),
        if ((hoTen ?? '').trim().isNotEmpty) 'ho_ten': hoTen!.trim(),
        if (gio.isNotEmpty) 'gio_kham': gio,
        if (ngay.isNotEmpty) 'ngay_kham': ngay,
      },
    );
  }

  /// Thông báo trạng thái khám theo thao tác của nhân viên trên hàng chờ
  /// (màn hình "Tiếp theo", "Đợi / Gọi lại", "+ Chèn số", "Vắng mặt").
  ///
  /// Nhờ gom về đúng một hàm + đúng collection `ThongBaoHeThong`, phần Bệnh
  /// nhân KHÔNG cần sửa gì thêm khi nhân viên thao tác: chỉ cần
  /// [streamThongBaoCuaToi] là mọi thông báo mới tự hiện ra.
  ///
  /// Bảng mã trạng thái dùng trong project:
  /// - `'2'` Đã xác nhận  → số được chèn/gọi lại vào hàng chờ
  /// - `'5'` Hoàn thành   → bệnh nhân đã khám xong
  /// - `'6'` Vắng mặt     → bệnh nhân xin đợi nhưng không quay lại
  /// - `'7'` Xin đợi      → số được cho qua lượt (đợi)
  static Future<void> guiThongBaoTrangThaiKham({
    required String lichHenId,
    required String trangThaiId,
    Map<String, dynamic>? duLieuLichHen,
    String? benhVienId,
    String? ghiChu,
  }) async {
    final maTrangThai = trangThaiId.trim();
    final dinhDanh = dinhDanhTuLichHen(duLieuLichHen);
    final soThuTu = _docSoNguyen(dinhDanh['soThuTu']);
    final soCau = (soThuTu != null && soThuTu > 0) ? 'Số $soThuTu' : 'Lượt khám';

    final phong = (dinhDanh['phongKham'] ?? '').trim();
    final khoa = (dinhDanh['tenKhoa'] ?? '').trim();
    final noiKham = phong.isNotEmpty ? phong : (khoa.isNotEmpty ? khoa : 'phòng khám');

    final ghiChuCau = (ghiChu ?? '').trim().isEmpty ? '' : ' ${ghiChu!.trim()}';

    late String tieuDe;
    late String noiDung;
    String? trangThaiLichHen;

    switch (maTrangThai) {
      case '5':
        tieuDe = 'Đã khám xong';
        noiDung = 'Bạn đã hoàn thành lượt khám tại $noiKham ($soCau). '
            'Cảm ơn bạn đã sử dụng dịch vụ, chúc bạn nhiều sức khoẻ!$ghiChuCau';
        trangThaiLichHen = 'da_kham';
        break;
      case '6':
        tieuDe = 'Ghi nhận vắng mặt';
        noiDung = 'Hệ thống ghi nhận $soCau vắng mặt vì chưa quay lại sau khi xin đợi. '
            'Nếu cần hỗ trợ, vui lòng liên hệ quầy tiếp đón.$ghiChuCau';
        trangThaiLichHen = 'vang_mat';
        break;
      case '7':
        tieuDe = 'Đã ghi nhận xin đợi';
        noiDung = 'Bạn đã xin đợi tại $noiKham ($soCau). Khi quay lại, vui lòng báo '
            'nhân viên để được chèn lại $soCau vào hàng chờ.$ghiChuCau';
        trangThaiLichHen = 'xin_doi';
        break;
      case '2':
        tieuDe = 'Đã chèn lại vào hàng chờ';
        noiDung = '$soCau của bạn đã được đưa trở lại hàng chờ tại $noiKham. '
            'Vui lòng theo dõi màn hình để vào phòng khám khi được gọi tên.$ghiChuCau';
        trangThaiLichHen = 'dang_cho';
        break;
      default:
        return;
    }

    await guiThongBaoChoBenhNhan(
      tieuDe: tieuDe,
      noiDung: noiDung,
      loai: 'hang_cho',
      nguoiNhanId: dinhDanh['nguoiNhanId'],
      benhNhanId: dinhDanh['benhNhanId'],
      soDienThoai: dinhDanh['soDienThoai'],
      email: dinhDanh['email'],
      benhVienId: benhVienId ?? (duLieuLichHen?['benh_vien_id'] ?? '').toString(),
      lichHenId: lichHenId,
      tenKhoa: khoa,
      duLieuThem: {
        'trang_thai_lich_hen': trangThaiLichHen,
        'trang_thai_id': maTrangThai,
        if (soThuTu != null) 'so_thu_tu': soThuTu,
        if (phong.isNotEmpty) 'phong_kham': phong,
      },
    );
  }

  /// Đọc số nguyên an toàn từ giá trị Firestore (có thể là int, double, String)
  static int? _docSoNguyen(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final asInt = int.tryParse(value);
    if (asInt != null) return asInt;
    return double.tryParse(value)?.toInt();
  }

  /// Trích định danh bệnh nhân + thông tin buổi khám từ document `LichHen`.
  static Map<String, String> dinhDanhTuLichHen(Map<String, dynamic>? data) {
    final d = data ?? const <String, dynamic>{};

    String lay(List<String> keys) {
      for (final key in keys) {
        final value = (d[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return {
      'nguoiNhanId': lay(const ['uid', 'nguoi_dung_id', 'nguoi_dung_uid', 'ma_nguoi_dung']),
      'benhNhanId': lay(const ['benh_nhan_id', 'benhNhanId', 'ma_benh_nhan']),
      'soDienThoai': lay(const ['so_dien_thoai', 'sdt', 'phone', 'dien_thoai']),
      'email': lay(const ['email', 'mail']),
      'hoTen': lay(const ['ho_ten', 'hoTen', 'ten_benh_nhan', 'patient_name']),
      'tenKhoa': lay(const ['ten_khoa', 'tenKhoa', 'khoa']),
      'phongKham': lay(const ['ten_phong', 'phong_kham', 'tenPhong', 'phongKham']),
      'soThuTu': lay(const ['so_thu_tu', 'stt']),
    };
  }

  // ===========================================================================
  // 4. TIỆN ÍCH HIỂN THỊ
  // ===========================================================================

  /// Chuỗi thời gian hiển thị cho 1 thông báo (Hôm nay / Hôm qua / dd/MM/yyyy)
  static String hienThiThoiGian(Map<String, dynamic> item) {
    final raw = item['thoi_gian'] ?? item['ngay_tao'] ?? item['ngayTao'];
    DateTime? thoiGian;
    if (raw is Timestamp) {
      thoiGian = raw.toDate().toLocal();
    } else if (raw is DateTime) {
      thoiGian = raw.toLocal();
    } else if (raw is String) {
      thoiGian = DateTime.tryParse(raw)?.toLocal();
    }

    if (thoiGian == null) {
      final fallback = (item['thoi_gian_hien_thi'] ?? item['thoiGian'] ?? '').toString().trim();
      return fallback.isEmpty ? 'Vừa xong' : fallback;
    }

    final now = DateTime.now();
    final homNay = DateTime(now.year, now.month, now.day);
    final ngayThongBao = DateTime(thoiGian.year, thoiGian.month, thoiGian.day);
    final soNgay = homNay.difference(ngayThongBao).inDays;
    final gioPhut = DateFormat('HH:mm').format(thoiGian);

    if (soNgay == 0) return 'Hôm nay • $gioPhut';
    if (soNgay == 1) return 'Hôm qua • $gioPhut';
    return DateFormat('dd/MM/yyyy • HH:mm').format(thoiGian);
  }

  /// Chuẩn hoá ngày khám (Timestamp / String / DateTime) về dd/MM/yyyy
  static String dinhDangNgay(Object? value) {
    if (value == null) return '';
    DateTime? thoiGian;
    if (value is Timestamp) {
      thoiGian = value.toDate().toLocal();
    } else if (value is DateTime) {
      thoiGian = value.toLocal();
    } else if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return '';
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        thoiGian = parsed.toLocal();
      } else {
        return raw;
      }
    }

    if (thoiGian == null) return value.toString();
    return DateFormat('dd/MM/yyyy').format(thoiGian);
  }

  // ===========================================================================
  // 5. BỘ LỌC NỘI BỘ
  // ===========================================================================

  /// 1 document trong `ThongBaoHeThong` có phải thông báo dành cho bệnh nhân này?
  static bool _laThongBaoCuaBenhNhan(
    Map<String, dynamic> data,
    Set<String> dinhDanhNguoiNhan, {
    bool choPhepXemTatCa = false,
  }) {
    final vaiTro = (data['vai_tro_nhan'] ?? '').toString().trim().toLowerCase();
    final nguoiNhanId = (data['nguoi_nhan_id'] ?? data['benh_nhan_id'] ?? '').toString().trim();
    final soDienThoai = (data['so_dien_thoai'] ?? data['sdt'] ?? '').toString().trim().toLowerCase();
    final email = (data['email'] ?? '').toString().trim().toLowerCase();

    // Chỉ nhận thông báo hướng tới bệnh nhân: gắn vai_tro_nhan = 'benh_nhan'
    // hoặc có định danh người nhận cụ thể. Thông báo nội bộ của Lễ tân/CSKH
    // (vai_tro_nhan = 'cskh' | 'le_tan') sẽ không lọt sang phần Bệnh nhân.
    final laHuongBenhNhan = vaiTro == vaiTroBenhNhan ||
        nguoiNhanId.isNotEmpty ||
        soDienThoai.isNotEmpty;
    if (!laHuongBenhNhan) return false;

    final khongGanDinhDanh = nguoiNhanId.isEmpty && soDienThoai.isEmpty && email.isEmpty;
    if (khongGanDinhDanh) {
      // Thông báo phát chung cho mọi bệnh nhân
      return vaiTro == vaiTroBenhNhan || vaiTro == vaiTroTatCa;
    }

    if (dinhDanhNguoiNhan.isEmpty) {
      // Chưa có định danh bệnh nhân: chỉ hiện khi bật chế độ xem thử
      return choPhepXemTatCa && vaiTro == vaiTroBenhNhan;
    }

    if (nguoiNhanId.isNotEmpty && dinhDanhNguoiNhan.contains(nguoiNhanId.toLowerCase())) {
      return true;
    }
    if (soDienThoai.isNotEmpty && dinhDanhNguoiNhan.contains(soDienThoai)) return true;
    if (email.isNotEmpty && dinhDanhNguoiNhan.contains(email)) return true;
    return false;
  }
}
