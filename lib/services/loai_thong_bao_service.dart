import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Đọc cấu hình loại thông báo từ Firestore `LoaiThongBao/{id}`
/// (mặc định: `LoaiThongBao/benh_vien_thong_bao`).
///
/// Document này là "danh mục loại thông báo" của bệnh viện: mỗi loại có thể
/// khai báo tiêu đề, mẫu nội dung, icon, màu và trạng thái bật/tắt. Code thông
/// báo (gửi từ Lễ tân/CSKH/phòng khám sang bệnh nhân) sẽ đọc document này để
/// lấy nội dung hiển thị, thay vì hard-code trong app.
///
/// Cấu trúc được đọc LINH HOẠT (không phụ thuộc đúng tên trường), ví dụ:
///
/// ```json
/// LoaiThongBao/benh_vien_thong_bao
/// {
///   "ma": "benh_vien_thong_bao",
///   "ten": "Bệnh viện thông báo",
///   "icon": "campaign",
///   "mau": "#0284C7",
///   "bat": true,
///   "danh_sach": [
///     { "ma": "kham_xong", "ten": "Đã khám xong",
///       "tieu_de": "Đã khám xong",
///       "noi_dung": "Bạn đã hoàn thành lượt khám tại {phong} ({so_thu_tu}).",
///       "icon": "check_circle", "mau": "#16A34A", "bat": true },
///     { "ma": "xin_doi", ... },
///     { "ma": "chen_so", ... }
///   ]
/// }
/// ```
///
/// Các khóa được nhận (mỗi nhóm lấy khóa đầu tiên có dữ liệu):
/// - mã: `ma`, `code`, `id`, `ma_loai`
/// - tên: `ten`, `ten_loai`, `name`
/// - tiêu đề: `tieu_de`, `tieude`, `title`, `ten_hien_thi`
/// - nội dung mẫu: `noi_dung`, `noi_dung_mau`, `noidung`, `content`, `message`, `mo_ta`
/// - icon: `icon`, `icon_name`, `bieu_tuong`
/// - màu: `mau`, `mau_sac`, `color`, `color_hex`, `ma_mau`
/// - bật/tắt: `bat`, `kich_hoat`, `enable`, `enabled`, `active`,
///   hoặc `trang_thai` (`hoat_dong`/`active` = bật, `tat`/`inactive` = tắt)
///
/// Danh sách loại con có thể nằm ở: `danh_sach`, `items`, `loai`, `cac_loai`,
/// `ds_loai`, `ds_loai_thong_bao`, `thong_bao`… hoặc bất kỳ field nào là
/// List/Map chứa các object có `ma`/`tieu_de`.
class LoaiThongBaoService {
  LoaiThongBaoService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String collection = 'LoaiThongBao';
  static const String docBenhVienThongBao = 'benh_vien_thong_bao';
  static const String duongDanMacDinh = '$collection/$docBenhVienThongBao';

  /// Mã loại thông báo dùng trong app (khớp `ma` khai báo trên Firestore)
  static const String maKhamXong = 'kham_xong';
  static const String maXinDoi = 'xin_doi';
  static const String maChenSo = 'chen_so';
  static const String maVangMat = 'vang_mat';
  static const String maDuyetLich = 'duyet_lich';
  static const String maTuChoiLich = 'tu_choi_lich';

  static const Map<String, Future<LoaiThongBaoCauHinh>> _cache = {};

  /// Đọc cấu hình (có cache theo phiên để không đọc Firestore mỗi lần gửi).
  /// Dùng [lamMoi] = true để buộc tải lại sau khi sửa trên Firestore.
  static Future<LoaiThongBaoCauHinh> layCauHinh({
    String duongDan = duongDanMacDinh,
    bool lamMoi = false,
  }) {
    if (lamMoi) _cache.remove(duongDan);
    return _cache.putIfAbsent(duongDan, () async {
      try {
        final snap = await _firestore.doc(duongDan).get();
        var data = snap.data() ?? <String, dynamic>{};

        // Hỗ trợ cả trường hợp các loại thông báo nằm trong subcollection
        // `danh_sach` (giống cấu trúc Khoa/{id}/danh_sach của project).
        try {
          final sub = await snap.reference.collection('danh_sach').get();
          if (sub.docs.isNotEmpty) {
            data = <String, dynamic>{
              ...data,
              'danh_sach': [
                for (final doc in sub.docs)
                  <String, dynamic>{
                    'ma': (doc.data()['ma'] ?? doc.id).toString(),
                    ...doc.data(),
                  },
              ],
            };
          }
        } catch (_) {}

        if (data.isEmpty) return LoaiThongBaoCauHinh.macDinh;
        return LoaiThongBaoCauHinh.tuDuLieu(snap.id, data);
      } catch (_) {
        // Không đọc được (mất mạng / thiếu quyền) → dùng cấu hình mặc định
        return LoaiThongBaoCauHinh.macDinh;
      }
    });
  }

  /// Lắng nghe cấu hình realtime (dùng cho màn hình cần đổi màu/icon ngay)
  static Stream<LoaiThongBaoCauHinh> streamCauHinh({
    String duongDan = duongDanMacDinh,
  }) async* {
    try {
      await for (final snap in _firestore.doc(duongDan).snapshots()) {
        final data = snap.data();
        yield data == null
            ? LoaiThongBaoCauHinh.macDinh
            : LoaiThongBaoCauHinh.tuDuLieu(snap.id, data);
      }
    } catch (_) {
      yield LoaiThongBaoCauHinh.macDinh;
    }
  }

  static Future<void> xoaCache() async {
    _cache.clear();
  }
}

/// Cấu hình 1 loại thông báo (dùng cho cả document gốc và từng loại con).
class LoaiThongBaoKieu {
  const LoaiThongBaoKieu({
    required this.ma,
    this.ten = '',
    this.tieuDe = '',
    this.noiDungMau = '',
    this.icon = '',
    this.mauHex = '',
    this.bat = true,
  });

  final String ma;
  final String ten;

  /// Tiêu đề hiển thị (mặc định của loại này)
  final String tieuDe;

  /// Mẫu nội dung, hỗ trợ placeholder: {so_thu_tu}, {khoa}, {phong},
  /// {gio}, {ngay}, {ly_do}, {ho_ten}
  final String noiDungMau;
  final String icon;
  final String mauHex;
  final bool bat;

  IconData get iconData => LoaiThongBaoService.layIcon(icon);
  Color? get mau => LoaiThongBaoService.layMau(mauHex);

  /// Thay placeholder trong mẫu bằng dữ liệu thực tế
  String apDungMau(String mau, Map<String, String> bien) {
    var ketQua = mau;
    bien.forEach((key, value) {
      ketQua = ketQua.replaceAll('{$key}', value).replaceAll('{{$key}}', value);
    });
    // Xoá placeholder còn sót để câu văn không bị "lộ" {…}
    return ketQua.replaceAll(RegExp(r'\{[a-zA-Z0-9_]+\}'), '').replaceAll('  ', ' ').trim();
  }
}

/// Toàn bộ cấu hình đọc từ `LoaiThongBao/{id}`
class LoaiThongBaoCauHinh {
  const LoaiThongBaoCauHinh({
    required this.id,
    required this.goc,
    this.kieuCon = const {},
  });

  final String id;
  final LoaiThongBaoKieu goc;
  final Map<String, LoaiThongBaoKieu> kieuCon;

  static const LoaiThongBaoCauHinh macDinh = LoaiThongBaoCauHinh(
    id: LoaiThongBaoService.docBenhVienThongBao,
    goc: LoaiThongBaoKieu(
      ma: LoaiThongBaoService.docBenhVienThongBao,
      ten: 'Bệnh viện thông báo',
      icon: 'campaign',
    ),
  );

  /// Tìm cấu hình của 1 loại con theo mã
  LoaiThongBaoKieu? kieu(String ma) {
    final key = ma.trim().toLowerCase();
    if (key.isEmpty) return null;
    final found = kieuCon[key];
    if (found != null) return found;
    if (key == goc.ma.trim().toLowerCase()) return goc;
    return null;
  }

  /// Có được phép gửi loại thông báo này không (bật/tắt từ Firestore)
  bool duocPhep(String ma) {
    if (!goc.bat) return false;
    final item = kieu(ma);
    return item == null || item.bat;
  }

  static LoaiThongBaoCauHinh tuDuLieu(String id, Map<String, dynamic> data) {
    final goc = _kieuTuMap(data, maMacDinh: id.isNotEmpty ? id : LoaiThongBaoService.docBenhVienThongBao);
    final con = <String, LoaiThongBaoKieu>{};

    void themKieu(Map<String, dynamic> map, String maMacDinh) {
      final kieu = _kieuTuMap(map, maMacDinh: maMacDinh);
      if (kieu.ma.isEmpty) return;
      con[kieu.ma.trim().toLowerCase()] = kieu;
    }

    void quetGiaTri(Object? value, String key) {
      if (value is Map) {
        final map = <String, dynamic>{};
        value.forEach((k, v) => map[k.toString()] = v);
        if (_coDuLieuLoai(map)) {
          themKieu(map, key);
        } else {
          // Map lồng nhiều tầng: quét tiếp
          map.forEach((k, v) => quetGiaTri(v, k));
        }
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          final item = value[i];
          if (item is Map) {
            final map = <String, dynamic>{};
            item.forEach((k, v) => map[k.toString()] = v);
            themKieu(map, '$key$i');
          }
        }
      }
    }

    data.forEach((key, value) {
      // Bản thân document gốc không tính là loại con
      if (key == 'ma' || key == 'ten' || key == 'tieu_de' || key == 'noi_dung') return;
      quetGiaTri(value, key);
    });

    return LoaiThongBaoCauHinh(id: id, goc: goc, kieuCon: con);
  }

  static bool _coDuLieuLoai(Map<String, dynamic> map) {
    const khoaNhanDang = [
      'ma', 'code', 'id', 'ma_loai',
      'tieu_de', 'tieude', 'title',
      'noi_dung', 'noi_dung_mau', 'content', 'message',
    ];
    return khoaNhanDang.any(map.containsKey);
  }

  static LoaiThongBaoKieu _kieuTuMap(
    Map<String, dynamic> map, {
    required String maMacDinh,
  }) {
    String doc(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final trangThai = doc(const ['trang_thai', 'status', 'state']).toLowerCase();
    final batRaw = map['bat'] ?? map['kich_hoat'] ?? map['enable'] ?? map['enabled'] ?? map['active'];
    bool bat = true;
    if (batRaw is bool) {
      bat = batRaw;
    } else if (batRaw != null) {
      final value = batRaw.toString().trim().toLowerCase();
      bat = !(value == 'false' || value == '0' || value == 'tat' || value == 'off' || value == 'khoa');
    }
    if (trangThai.isNotEmpty) {
      bat = bat && !(trangThai == 'tat' || trangThai == 'inactive' || trangThai == 'off' || trangThai == 'khoa');
    }

    final ma = doc(const ['ma', 'code', 'ma_loai', 'id']);
    return LoaiThongBaoKieu(
      ma: ma.isEmpty ? maMacDinh : ma,
      ten: doc(const ['ten', 'ten_loai', 'name']),
      tieuDe: doc(const ['tieu_de', 'tieude', 'title', 'ten_hien_thi']),
      noiDungMau: doc(const ['noi_dung', 'noi_dung_mau', 'noidung', 'content', 'message', 'mo_ta']),
      icon: doc(const ['icon', 'icon_name', 'bieu_tuong']),
      mauHex: doc(const ['mau', 'mau_sac', 'color', 'color_hex', 'ma_mau']),
      bat: bat,
    );
  }

  /// Tên icon (string) → IconData
  static IconData layIcon(String ten) {
    final key = ten.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    switch (key) {
      case 'eventavailable':
      case 'calendarcheck':
      case 'checkcalendar':
      case 'lichhen':
        return Icons.event_available_rounded;
      case 'eventbusy':
      case 'calendarcancel':
      case 'tuchoi':
        return Icons.event_busy_rounded;
      case 'check':
      case 'checkcircle':
      case 'done':
      case 'taskalt':
      case 'hoanthanh':
      case 'khamxong':
        return Icons.task_alt_rounded;
      case 'pause':
      case 'pausecircle':
      case 'doi':
      case 'xindoi':
        return Icons.pause_circle_rounded;
      case 'personoff':
      case 'vangmat':
        return Icons.person_off_rounded;
      case 'confirmationnumber':
      case 'ticket':
      case 'sothutu':
      case 'number':
      case 'chenso':
        return Icons.confirmation_number_rounded;
      case 'warning':
      case 'warningamber':
      case 'khancap':
        return Icons.warning_amber_rounded;
      case 'campaign':
      case 'loa':
        return Icons.campaign_rounded;
      case 'notifications':
      case 'notification':
      case 'thongbao':
        return Icons.notifications_active_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  /// Màu dạng `#RRGGBB`, `#AARRGGBB`, `RRGGBB` hoặc tên tiếng Việt
  static Color? layMau(String raw) {
    final value = raw.trim().toLowerCase().replaceAll(' ', '');
    if (value.isEmpty) return null;

    const tenMau = <String, Color>{
      'xanh': Color(0xFF0284C7),
      'xanhduong': Color(0xFF0284C7),
      'xanhla': Color(0xFF16A34A),
      'do': Color(0xFFEF4444),
      'vang': Color(0xFFF59E0B),
      'cam': Color(0xFFF97316),
      'tim': Color(0xFF8B5CF6),
      'xam': Color(0xFF64748B),
    };
    final theoCo = tenMau[value.replaceAll('_', '')];
    if (theoCo != null) return theoCo;

    var hex = value.startsWith('#') ? value.substring(1) : value;
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'ff$hex';
    if (hex.length != 8) return null;
    final giaTri = int.tryParse(hex, radix: 16);
    if (giaTri == null) return null;
    return Color(giaTri);
  }
}
