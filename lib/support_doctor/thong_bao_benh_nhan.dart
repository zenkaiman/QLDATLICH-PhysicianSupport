import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_session.dart';

/// GỬI THÔNG BÁO SANG PHẦN BỆNH NHÂN — chỉ nằm trong module Support Doctor.
///
/// Nguyên tắc: module này CHỈ GHI dữ liệu lên Firestore, không phụ thuộc và
/// không cần sửa bất kỳ dòng code nào ở phần Bệnh nhân.
///
/// Mỗi thông báo là 1 document trong `ThongBaoHeThong` — đúng collection mà
/// phần Bệnh nhân đang lắng nghe realtime — với:
/// - `vai_tro_nhan` = `benh_nhan`
/// - định danh người nhận lấy từ chính document `LichHen`
///   (`uid` / `benh_nhan_id` / `so_dien_thoai` / `email`)
/// - `loai_thong_bao_id` = `benh_vien_thong_bao` + `ma_loai_thong_bao`
///   để tra cứu danh mục loại thông báo `LoaiThongBao/benh_vien_thong_bao`
///
/// Nhờ vậy bệnh nhân chỉ cần màn hình thông báo sẵn có là nhận được các cập
/// nhật: khám xong, xin đợi, chèn lại số, vắng mặt.
class ThongBaoBenhNhanService {
  ThongBaoBenhNhanService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection thông báo dùng chung với phần Bệnh nhân
  static const String collectionThongBao = 'ThongBaoHeThong';

  /// Danh mục loại thông báo: LoaiThongBao/benh_vien_thong_bao
  static const String collectionLoaiThongBao = 'LoaiThongBao';
  static const String docBenhVienThongBao = 'benh_vien_thong_bao';

  static const String vaiTroBenhNhan = 'benh_nhan';

  /// Mã loại thông báo (khớp `ma` khai báo trong LoaiThongBao)
  static const String maKhamXong = 'kham_xong';
  static const String maXinDoi = 'xin_doi';
  static const String maChenSo = 'chen_so';
  static const String maVangMat = 'vang_mat';

  static Map<String, LoaiThongBaoMau>? _danhMucCache;

  /// Xoá cache danh mục (gọi khi vừa sửa cấu hình trên Firestore)
  static void xoaCache() {
    _danhMucCache = null;
  }

  // ===========================================================================
  // 1. GỬI THEO THAO TÁC HÀNG CHỜ
  // ===========================================================================

  /// Ánh xạ trạng thái lịch hẹn (ghi bởi hàng chờ) sang thông báo cho bệnh nhân:
  /// - `5` Hoàn thành  → “Đã khám xong”
  /// - `7` Xin đợi     → “Đã ghi nhận xin đợi” (kèm số)
  /// - `2` Đã xác nhận → “Đã chèn lại vào hàng chờ” (kèm số)
  /// - `6` Vắng mặt    → “Ghi nhận vắng mặt”
  static Future<void> guiThongBaoTrangThaiKham({
    required String lichHenId,
    required String trangThaiId,
    Map<String, dynamic>? duLieuLichHen,
    String? ghiChu,
  }) async {
    final maTrangThai = trangThaiId.trim();
    final duLieu = duLieuLichHen ?? const <String, dynamic>{};

    final soThuTu = _docSoNguyen(duLieu['so_thu_tu'] ?? duLieu['stt']);
    final soCau = (soThuTu != null && soThuTu > 0) ? 'Số $soThuTu' : 'Lượt khám';

    final khoa = _docChuoi(duLieu, const ['ten_khoa', 'tenKhoa', 'khoa']);
    final phong = _docChuoi(duLieu, const ['ten_phong', 'phong_kham', 'tenPhong', 'phongKham']);
    final hoTen = _docChuoi(duLieu, const ['ho_ten', 'hoTen', 'ten_benh_nhan', 'patient_name']);
    final noiKham = phong.isNotEmpty ? phong : (khoa.isNotEmpty ? khoa : 'phòng khám');
    final ghiChuCau = (ghiChu ?? '').trim().isEmpty ? '' : ' ${ghiChu!.trim()}';

    late String maLoai;
    late String tieuDeMacDinh;
    late String noiDungMacDinh;
    late String trangThaiLichHen;

    switch (maTrangThai) {
      case '5':
        maLoai = maKhamXong;
        tieuDeMacDinh = 'Đã khám xong';
        noiDungMacDinh = 'Bạn đã hoàn thành lượt khám tại $noiKham ($soCau). '
            'Cảm ơn bạn đã sử dụng dịch vụ, chúc bạn nhiều sức khoẻ!$ghiChuCau';
        trangThaiLichHen = 'da_kham';
        break;
      case '7':
        maLoai = maXinDoi;
        tieuDeMacDinh = 'Đã ghi nhận xin đợi';
        noiDungMacDinh = 'Bạn đã xin đợi tại $noiKham ($soCau). Khi quay lại, vui lòng '
            'báo nhân viên để được chèn lại $soCau vào hàng chờ.$ghiChuCau';
        trangThaiLichHen = 'xin_doi';
        break;
      case '2':
        maLoai = maChenSo;
        tieuDeMacDinh = 'Đã chèn lại vào hàng chờ';
        noiDungMacDinh = '$soCau của bạn đã được đưa trở lại hàng chờ tại $noiKham. '
            'Vui lòng theo dõi màn hình để vào phòng khám khi được gọi tên.$ghiChuCau';
        trangThaiLichHen = 'dang_cho';
        break;
      case '6':
        maLoai = maVangMat;
        tieuDeMacDinh = 'Ghi nhận vắng mặt';
        noiDungMacDinh = 'Hệ thống ghi nhận $soCau vắng mặt vì chưa quay lại sau khi xin đợi. '
            'Nếu cần hỗ trợ, vui lòng liên hệ quầy tiếp đón.$ghiChuCau';
        trangThaiLichHen = 'vang_mat';
        break;
      default:
        return;
    }

    // Cấu hình loại thông báo (LoaiThongBao/benh_vien_thong_bao)
    final danhMuc = await _layDanhMuc();
    final mauLoai = danhMuc[maLoai];
    if (mauLoai != null && !mauLoai.bat) return; // loại bị tắt trên Firestore

    final bien = <String, String>{
      'so_thu_tu': (soThuTu != null && soThuTu > 0) ? '$soThuTu' : '',
      'khoa': khoa,
      'phong': phong,
      'ho_ten': hoTen,
      'ghi_chu': (ghiChu ?? '').trim(),
    };

    final tieuDeMau = mauLoai?.tieuDe ?? '';
    final noiDungMau = mauLoai?.noiDung ?? '';
    final tieuDe = tieuDeMau.isNotEmpty ? _apDungMau(tieuDeMau, bien) : tieuDeMacDinh;
    final noiDung = noiDungMau.isNotEmpty ? _apDungMau(noiDungMau, bien) : noiDungMacDinh;

    await _ghiThongBao(
      tieuDe: tieuDe,
      noiDung: noiDung,
      loai: 'hang_cho',
      maLoaiThongBao: maLoai,
      duLieuLichHen: duLieu,
      lichHenId: lichHenId,
      duLieuThem: <String, dynamic>{
        'trang_thai_id': maTrangThai,
        'trang_thai_lich_hen': trangThaiLichHen,
        if (soThuTu != null) 'so_thu_tu': soThuTu,
        if (khoa.isNotEmpty) 'ten_khoa': khoa,
        if (phong.isNotEmpty) 'phong_kham': phong,
      },
    );
  }

  // ===========================================================================
  // 2. GHI DOCUMENT THÔNG BÁO
  // ===========================================================================

  /// Ghi 1 thông báo dành cho bệnh nhân vào `ThongBaoHeThong`.
  ///
  /// `benh_vien_id` ưu tiên lấy theo phiên làm việc hiện tại (AppSession) —
  /// đúng giá trị mà phần Bệnh nhân dùng để lọc — nếu trống mới lấy từ
  /// document `LichHen`.
  static Future<void> _ghiThongBao({
    required String tieuDe,
    required String noiDung,
    required String loai,
    required String maLoaiThongBao,
    required Map<String, dynamic> duLieuLichHen,
    String? lichHenId,
    Map<String, dynamic> duLieuThem = const {},
  }) async {
    final benhVienIdCuaLich = _docChuoi(
      duLieuLichHen,
      const ['benh_vien_id', 'benhVienId', 'ma_benh_vien'],
    );
    final benhVienId = AppSession.benhVienId.trim().isNotEmpty
        ? AppSession.benhVienId.trim()
        : benhVienIdCuaLich;

    final data = <String, dynamic>{
      ...duLieuThem,
      'tieu_de': tieuDe,
      'noi_dung': noiDung,
      'loai': loai,
      'vai_tro_nhan': vaiTroBenhNhan,
      // Tham chiếu danh mục loại thông báo trên Firestore
      'loai_thong_bao_id': docBenhVienThongBao,
      'ma_loai_thong_bao': maLoaiThongBao,
      // Định danh người nhận (phần Bệnh nhân khớp theo bất kỳ trường nào có)
      'nguoi_nhan_id': _docChuoi(
        duLieuLichHen,
        const ['uid', 'nguoi_dung_id', 'nguoi_dung_uid', 'ma_nguoi_dung'],
      ),
      'benh_nhan_id': _docChuoi(
        duLieuLichHen,
        const ['benh_nhan_id', 'benhNhanId', 'ma_benh_nhan'],
      ),
      'so_dien_thoai': _docChuoi(
        duLieuLichHen,
        const ['so_dien_thoai', 'sdt', 'phone', 'dien_thoai'],
      ),
      'email': _docChuoi(duLieuLichHen, const ['email', 'mail']),
      if (benhVienId.isNotEmpty) 'benh_vien_id': benhVienId,
      'da_doc': false,
      'thoi_gian': FieldValue.serverTimestamp(),
      'thoi_gian_hien_thi': 'Vừa xong',
    };

    final maLichHen = (lichHenId ?? '').trim();
    if (maLichHen.isNotEmpty) data['lich_hen_id'] = maLichHen;

    try {
      await _firestore.collection(collectionThongBao).add(data);
    } catch (_) {
      // Lỗi mạng/thiếu quyền không được làm hỏng thao tác hàng chờ
    }
  }

  // ===========================================================================
  // 3. ĐỌC DANH MỤC LoaiThongBao/benh_vien_thong_bao
  // ===========================================================================

  /// Đọc danh mục loại thông báo (cache trong phiên).
  ///
  /// Hỗ trợ cả 2 kiểu lưu:
  /// - Field dạng mảng/object chứa các loại: `danh_sach`, `items`, `loai`, …
  /// - Subcollection `LoaiThongBao/benh_vien_thong_bao/danh_sach/{ma_loai}`
  static Future<Map<String, LoaiThongBaoMau>> _layDanhMuc() async {
    final cache = _danhMucCache;
    if (cache != null) return cache;

    final ketQua = <String, LoaiThongBaoMau>{};
    try {
      final doc = await _firestore
          .collection(collectionLoaiThongBao)
          .doc(docBenhVienThongBao)
          .get();

      var data = doc.data() ?? <String, dynamic>{};

      // Kiểu subcollection danh_sach/{ma_loai}
      try {
        final sub = await doc.reference.collection('danh_sach').get();
        if (sub.docs.isNotEmpty) {
          data = <String, dynamic>{
            ...data,
            'danh_sach': <Map<String, dynamic>>[
              for (final item in sub.docs)
                <String, dynamic>{
                  'ma': (item.data()['ma'] ?? item.id).toString(),
                  ...item.data(),
                },
            ],
          };
        }
      } catch (_) {}

      void themMau(Map<String, dynamic> map, String maMacDinh) {
        final ma = _docChuoi(map, const ['ma', 'code', 'ma_loai', 'id']);
        final key = (ma.isNotEmpty ? ma : maMacDinh).trim().toLowerCase();
        if (key.isEmpty) return;

        final batRaw = map['bat'] ?? map['kich_hoat'] ?? map['enable'] ?? map['enabled'] ?? map['active'];
        var bat = true;
        if (batRaw is bool) {
          bat = batRaw;
        } else if (batRaw != null) {
          final value = batRaw.toString().trim().toLowerCase();
          bat = !(value == 'false' || value == '0' || value == 'tat' || value == 'off');
        }
        final trangThai = _docChuoi(map, const ['trang_thai', 'status']).toLowerCase();
        if (trangThai == 'tat' || trangThai == 'inactive' || trangThai == 'off') bat = false;

        ketQua[key] = LoaiThongBaoMau(
          ma: key,
          tieuDe: _docChuoi(map, const ['tieu_de', 'tieude', 'title', 'ten_hien_thi']),
          noiDung: _docChuoi(
            map,
            const ['noi_dung', 'noi_dung_mau', 'noidung', 'content', 'message', 'mo_ta'],
          ),
          bat: bat,
        );
      }

      void quet(Object? value, String key) {
        if (value is Map) {
          final map = <String, dynamic>{};
          value.forEach((k, v) => map[k.toString()] = v);
          final laMotLoai = map.containsKey('ma') ||
              map.containsKey('tieu_de') ||
              map.containsKey('noi_dung') ||
              map.containsKey('title');
          if (laMotLoai) {
            themMau(map, key);
          } else {
            map.forEach((k, v) => quet(v, k));
          }
        } else if (value is List) {
          for (var i = 0; i < value.length; i++) {
            final item = value[i];
            if (item is Map) {
              final map = <String, dynamic>{};
              item.forEach((k, v) => map[k.toString()] = v);
              themMau(map, '$key$i');
            }
          }
        }
      }

      data.forEach((key, value) {
        if (key == 'ma' || key == 'ten' || key == 'tieu_de' || key == 'noi_dung') return;
        quet(value, key);
      });
    } catch (_) {
      // Không đọc được danh mục → chạy với câu mặc định
    }

    _danhMucCache = ketQua;
    return ketQua;
  }

  // ===========================================================================
  // 4. TIỆN ÍCH
  // ===========================================================================

  static String _apDungMau(String mau, Map<String, String> bien) {
    var ketQua = mau;
    bien.forEach((key, value) {
      ketQua = ketQua.replaceAll('{$key}', value);
    });
    return ketQua
        .replaceAll(RegExp(r'\{[a-zA-Z0-9_]+\}'), '')
        .replaceAll('  ', ' ')
        .trim();
  }

  static String _docChuoi(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = (map[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static int? _docSoNguyen(Object? raw) {
    if (raw is num) return raw.toInt();
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  }
}

/// Nội dung hiển thị của 1 loại thông báo (khai báo trên Firestore)
class LoaiThongBaoMau {
  const LoaiThongBaoMau({
    required this.ma,
    this.tieuDe = '',
    this.noiDung = '',
    this.bat = true,
  });

  final String ma;

  /// Tiêu đề (có thể chứa placeholder {so_thu_tu}, {khoa}, {phong}, …)
  final String tieuDe;

  /// Mẫu nội dung (có thể chứa placeholder)
  final String noiDung;

  /// `false` → không gửi loại thông báo này
  final bool bat;
}
