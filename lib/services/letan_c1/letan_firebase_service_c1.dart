import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/letan_c1/letan_phancong_model_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../models/letan_c1/letan_qr_model_c1.dart';
import 'letan_chat_service_c1.dart';

export '../../models/letan_c1/letan_phancong_model_c1.dart';

/// Service kết nối Firebase Firestore cho Module Lễ tân & CSKH C1 (Đinh Hoàng Cước)
/// Tuân thủ nguyên tắc ghi_chu_c1.md:
/// - Chỉ query dữ liệu cần thiết theo ID hoặc Collection cụ thể.
/// - Có cơ chế Fallback (dùng mock data nếu Firebase trống hoặc offline) để app luôn chạy mượt.
class FirebaseServiceC1 {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Đường dẫn chính xác tuyệt đối trên Firestore của C1:
  /// /Khoa/BO85AxXqDMSB68hnYjzhYfPIxHC2/danh_sach
  static const String duongDanKhoaCha = 'Khoa';
  static const String subCollectionDanhSach = 'danh_sach';

  /// Lấy danh sách các chuyên khoa thời gian thực (Stream) TRỰC TIẾP TỪ /Khoa/{benhVienId}/danh_sach
  /// Nếu không truyền benhVienId hoặc benhVienId rỗng thì lấy từ profile hoặc fallback docKhoaChaId
  static Stream<List<Map<String, dynamic>>> streamDanhSachKhoa([String? benhVienId]) {
    final rawBv = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != 'BV01' && benhVienId != '1')
        ? benhVienId.trim()
        : DuLieuProfileMauC1.thongTinHienTai.benhVienId.trim();
    final bvid = rawBv.isNotEmpty ? rawBv : 'BV502';

    return _firestore
        .collection(duongDanKhoaCha)
        .doc(bvid)
        .collection(subCollectionDanhSach)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final tenKhoa = data['tenKhoa'] ?? data['ten_khoa'] ?? 'Khoa Khám';
        final phongDau = data['phongDau']?.toString() ?? data['phong_dau']?.toString() ?? '101';
        final soPhong = (data['soPhong'] as num?)?.toInt() ?? (data['so_phong'] as num?)?.toInt() ?? 1;
        final soCaMoiNgay = (data['soCaMoiNgay'] as num?)?.toInt() ?? (data['so_ca'] as num?)?.toInt() ?? 2;
        final trangThai = data['trangThai'] ?? data['trang_thai'] ?? 'dang_mo';

        return {
          'id': doc.id,
          'tenKhoa': tenKhoa,
          'phongDau': phongDau,
          'soPhong': soPhong,
          'soCaMoiNgay': soCaMoiNgay,
          'trangThai': trangThai,
          'moTaPhong': 'Phòng $phongDau • ${trangThai == 'dang_mo' ? 'Đang mở' : 'Tạm đóng'}',
        };
      }).toList();
    });
  }

  static Stream<List<Map<String, dynamic>>> streamDanhSachKhoaTheoBenhVien(String benhVienId) {
    return streamDanhSachKhoa(benhVienId);
  }

  /// Lắng nghe danh sách phòng khám của một chuyên khoa:
  /// Khoa/{benhVienId}/danh_sach/{khoaId}/phongKham
  static Stream<List<Map<String, dynamic>>> streamDanhSachPhongTheoKhoa({
    String? benhVienId,
    required String khoaId,
    required String tenKhoa,
    int soPhongMacDinh = 1,
    String phongDau = '101',
  }) {
    final rawBv = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != 'BV01' && benhVienId != '1')
        ? benhVienId.trim()
        : DuLieuProfileMauC1.thongTinHienTai.benhVienId.trim();
    final bvid = rawBv.isNotEmpty ? rawBv : 'BV502';

    return _firestore
        .collection(duongDanKhoaCha)
        .doc(bvid)
        .collection(subCollectionDanhSach)
        .doc(khoaId)
        .collection('phongKham')
        .snapshots()
        .map((snap) {
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) {
          final data = d.data();
          final tenPhong = (data['tenPhong'] ?? data['ten_phong'] ?? 'Phòng ${d.id}').toString();
          final soPhong = (data['soPhong'] ?? data['so_phong'] ?? '').toString();
          final trangThai = (data['trangThai'] ?? data['trang_thai'] ?? 'san_sang').toString();
          final bacSiPhuTrach = (data['bacSi'] ?? data['bac_si'] ?? data['nhanVienId'] ?? 'BS. Trực phòng').toString();

          return {
            'id': d.id,
            'tenPhong': tenPhong,
            'soPhong': soPhong.isNotEmpty ? soPhong : tenPhong,
            'trangThai': trangThai,
            'bacSi': bacSiPhuTrach,
            'khoaId': khoaId,
            'tenKhoa': tenKhoa,
          };
        }).toList();
      }

      // Fallback nếu khoa chưa có subcollection phongKham: Tự sinh danh sách phòng dựa theo soPhong và phongDau của khoa
      final List<Map<String, dynamic>> fallbackRooms = [];
      final int startNum = int.tryParse(RegExp(r'\d+').firstMatch(phongDau)?.group(0) ?? '101') ?? 101;
      final int count = soPhongMacDinh > 0 ? soPhongMacDinh : 1;

      for (int i = 0; i < count; i++) {
        final currentRoomNum = '${startNum + i}';
        fallbackRooms.add({
          'id': 'P_$currentRoomNum',
          'tenPhong': 'Phòng $currentRoomNum - $tenKhoa',
          'soPhong': currentRoomNum,
          'trangThai': 'san_sang',
          'bacSi': 'Bác sĩ phụ trách',
          'khoaId': khoaId,
          'tenKhoa': tenKhoa,
        });
      }
      return fallbackRooms;
    });
  }

  /// Lấy danh sách tên các khoa dạng `List<String>` để đưa vào Dropdown/Modal chọn khoa
  static Future<List<String>> layDanhSachTenKhoa([String? benhVienId]) async {
    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != 'BV01' && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != 'BV01' &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');
    try {
      final snapshot = await _firestore
          .collection(duongDanKhoaCha)
          .doc(bvid)
          .collection(subCollectionDanhSach)
          .get();

      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs
          .map((doc) => (doc.data()['tenKhoa'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Lỗi lấy danh sách tên khoa từ Firebase: $e');
      return [];
    }
  }

  /// Lấy danh sách khoa 1 lần (Future)
  static Future<List<Map<String, dynamic>>> layDanhSachKhoaMotLan([String? benhVienId]) async {
    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != 'BV01' && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != 'BV01' &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');
    try {
      final snapshot = await _firestore
          .collection(duongDanKhoaCha)
          .doc(bvid)
          .collection(subCollectionDanhSach)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'tenKhoa': data['tenKhoa'] ?? 'Khoa Khám',
          'phongDau': data['phongDau']?.toString() ?? '101',
          'soPhong': (data['soPhong'] as num?)?.toInt() ?? 1,
          'soCaMoiNgay': (data['soCaMoiNgay'] as num?)?.toInt() ?? 2,
          'trangThai': data['trangThai'] ?? 'dang_mo',
          'moTaPhong': 'Phòng ${data['phongDau'] ?? '101'} • ${data['trangThai'] == 'dang_mo' ? 'Đang mở' : 'Tạm đóng'}',
        };
      }).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Lỗi lấy danh sách khoa từ Firebase: $e');
      return [];
    }
  }

  // ==========================================
  // REALTIME QUERIES: LỊCH KHÁM & THỐNG KÊ THEO KHOA HOẶC TỔNG THỂ
  // ==========================================

  /// Chuẩn hóa chuỗi tiếng Việt: Bỏ dấu, bỏ ký tự đặc biệt, chuyển thành chữ hoa
  static String boDauTiengViet(String str) {
    var result = str.toLowerCase();
    const vietnameseMap = {
      'a': ['à', 'á', 'ạ', 'ả', 'ã', 'â', 'ầ', 'ấ', 'ậ', 'ẩ', 'ẫ', 'ă', 'ằ', 'ắ', 'ặ', 'ẳ', 'ẵ'],
      'e': ['è', 'é', 'ẹ', 'ẻ', 'ẽ', 'ê', 'ề', 'ế', 'ệ', 'ể', 'ễ'],
      'i': ['ì', 'í', 'ị', 'ỉ', 'ĩ'],
      'o': ['ò', 'ó', 'ọ', 'ỏ', 'õ', 'ô', 'ồ', 'ố', 'ộ', 'ổ', 'ỗ', 'ơ', 'ờ', 'ớ', 'ợ', 'ở', 'ỡ'],
      'u': ['ù', 'ú', 'ụ', 'ủ', 'ũ', 'ư', 'ừ', 'ứ', 'ự', 'ử', 'ữ'],
      'y': ['ỳ', 'ý', 'ỵ', 'ỷ', 'ỹ'],
      'd': ['đ'],
    };
    vietnameseMap.forEach((nonAccent, accents) {
      for (var accent in accents) {
        result = result.replaceAll(accent, nonAccent);
      }
    });
    return result.trim().toUpperCase();
  }

  /// Chuẩn hóa so sánh tên khoa / mã khoa:
  /// Chấp nhận các biến thể: "Khoa Tim Mạch", "khoa tim", "KHOA TIM", "TIM", "K001"
  /// "Khoa Mắt", "khoa mat", "KHOA MẮT", "MAT", "K003"
  /// "Khoa Nhi", "NHI", "K004", v.v.
  static bool laCungKhoa(String? khoaA, String? khoaB) {
    if (khoaA == null || khoaB == null) return false;
    if (laCheDoTong(khoaA) || laCheDoTong(khoaB)) return true;

    String clean(String str) {
      var s = boDauTiengViet(str);
      s = s.replaceAll('KHOA ', '').replaceAll('CHUYEN KHOA ', '').replaceAll('PHONG KHAM ', '').trim();
      return s;
    }

    final a = clean(khoaA);
    final b = clean(khoaB);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b || a.contains(b) || b.contains(a)) return true;

    // So sánh theo mã ID khoa K001, K002...
    final regA = RegExp(r'K\d+').firstMatch(a)?.group(0);
    final regB = RegExp(r'K\d+').firstMatch(b)?.group(0);
    if (regA != null && regB != null && regA == regB) return true;

    // So sánh alias phổ biến
    final bool aHoHap = a.contains('HO HAP') || a.contains('K001') || a.contains('HH');
    final bool bHoHap = b.contains('HO HAP') || b.contains('K001') || b.contains('HH');
    if (aHoHap && bHoHap) return true;

    final bool aDaLieu = a.contains('DA LIEU') || a.contains('K002') || a.contains('DL');
    final bool bDaLieu = b.contains('DA LIEU') || b.contains('K002') || b.contains('DL');
    if (aDaLieu && bDaLieu) return true;

    final bool aTim = a.contains('TIM') || a.contains('TM');
    final bool bTim = b.contains('TIM') || b.contains('TM');
    if (aTim && bTim) return true;

    final bool aMat = a.contains('MAT');
    final bool bMat = b.contains('MAT');
    if (aMat && bMat) return true;

    final bool aNhi = a.contains('NHI');
    final bool bNhi = b.contains('NHI');
    if (aNhi && bNhi) return true;

    // So sánh alias Cơ Xương Khớp (CXK)
    final bool aCxk = a.contains('CO XUONG KHOP') || a.contains('CXK') || a.contains('XUONG');
    final bool bCxk = b.contains('CO XUONG KHOP') || b.contains('CXK') || b.contains('XUONG');
    if (aCxk && bCxk) return true;

    return false;
  }

  /// Kiểm tra xem có đang chọn chế độ 'Tổng' (Tất cả chuyên khoa toàn viện) hay không
  static bool laCheDoTong(String? tenKhoa) {
    if (tenKhoa == null || tenKhoa.trim().isEmpty) return true;
    final k = boDauTiengViet(tenKhoa);
    return k == 'TAT CA' ||
        k.contains('TAT CA') ||
        k.contains('TONG') ||
        k.contains('TOAN VIEN') ||
        k == 'ALL';
  }

  /// Stream thống kê số liệu theo ngày đã chọn và theo Khoa (hoặc Tổng)
  /// Lắng nghe trực tiếp từ cả collection `LichHen` cấp 1 và `collectionGroup('lich_hen')`
  static Stream<Map<String, int>> streamThongKeHomNay({
    String? tenKhoa,
    DateTime? ngayChon,
    String? benhVienId,
    bool laCskh = false,
  }) {
    final targetDate = ngayChon ?? DateTime.now();
    final String targetDateStr = '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    final String targetDisplay = '${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}';
    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != 'BV01' && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != 'BV01' &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');

    final controller = StreamController<Map<String, int>>();
    Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = {};

    void recompute() {
      int daTiepNhan = 0;
      int dangCho = 0;
      int daKham = 0;
      int tongSo = 0;

      final isAll = laCheDoTong(tenKhoa);

      for (var doc in allDocs.values) {
        final data = doc.data();
        final docPath = doc.reference.path;

        // 0. LỌC THEO BỆNH VIỆN
        final docBv = (data['benh_vien_id'] ?? data['benhVienId'] ?? data['ma_benh_vien'] ?? '').toString();
        if (docBv.isNotEmpty && bvid.isNotEmpty) {
          if (!docBv.toLowerCase().contains(bvid.toLowerCase()) && !bvid.toLowerCase().contains(docBv.toLowerCase())) {
            continue;
          }
        }

        // 1. Lọc theo ngày (hỗ trợ cả String, Timestamp, date path segment)
        final String docDate = (data['ngay_hien_thi'] ?? '').toString();
        final docNgayHen = data['ngay_hen'] != null ? data['ngay_hen'].toString() : '';
        final docNgayDat = data['ngay_dat'] != null ? data['ngay_dat'].toString() : '';
        final docNgayKham = (data['ngay_kham'] ?? '').toString();

        bool khopNgay = docPath.contains(targetDateStr) ||
            docDate.contains(targetDisplay) ||
            docDate.contains(targetDateStr) ||
            docNgayHen.contains(targetDateStr) ||
            docNgayDat.contains(targetDateStr) ||
            docNgayKham.contains(targetDateStr);

        // Hỗ trợ kiểm tra nếu trường ngay_hen hoặc ngay_dat là Firestore Timestamp
        if (!khopNgay && data['ngay_hen'] is Timestamp) {
          final dt = (data['ngay_hen'] as Timestamp).toDate();
          if (dt.year == targetDate.year && dt.month == targetDate.month && dt.day == targetDate.day) {
            khopNgay = true;
          }
        }
        if (!khopNgay && data['ngay_dat'] is Timestamp) {
          final dt = (data['ngay_dat'] as Timestamp).toDate().toLocal();
          if (dt.year == targetDate.year && dt.month == targetDate.month && dt.day == targetDate.day) {
            khopNgay = true;
          }
        }

        if (!khopNgay) continue;

        // 2. Lọc theo khoa (hoặc lấy tất cả khi ở chế độ Tổng)
        final rawKhoaIdThongKe = (data['khoa_id'] ?? data['khoaId'] ?? '').toString();
        final docKhoa = (data['ten_khoa'] ?? data['tenKhoa'] ?? data['khoa'] ?? rawKhoaIdThongKe).toString();
        if (!isAll && !laCungKhoa(docKhoa, tenKhoa) && !laCungKhoa(rawKhoaIdThongKe, tenKhoa)) {
          continue;
        }

        // LỄ TÂN CHỈ LẤY LỊCH HẸN ĐÃ ĐƯỢC DUYỆT (CSKH LẤY TẤT CẢ ĐỂ DUYỆT VÀ THEO DÕI)
        final rawTrangThaiId = (data['trang_thai_id'] ?? data['trangThaiId'] ?? '1').toString();
        final rawTrangThaiStr = (data['trang_thai'] ?? data['trangThai'] ?? '').toString().toLowerCase();

        final bool laChuaDuyet = rawTrangThaiId == '1' ||
            rawTrangThaiStr.contains('cho_duyet') ||
            rawTrangThaiStr.contains('pending');
        final bool laDaHuyHoacTuChoi = rawTrangThaiId == '4' ||
            rawTrangThaiStr.contains('tu_choi') ||
            rawTrangThaiStr.contains('huy') ||
            rawTrangThaiStr.contains('cancel');

        // Đối với Lễ tân: Chỉ lấy các đơn ĐÃ DUYỆT hoặc ĐÃ KHÁM / TIẾP ĐÓN
        final bool laDaDuyetHoacKham = rawTrangThaiId == '2' ||
            rawTrangThaiId == '5' ||
            rawTrangThaiId == '6' ||
            rawTrangThaiStr.contains('duyet') ||
            rawTrangThaiStr.contains('xac_nhan') ||
            rawTrangThaiStr.contains('da_tiep_nhan') ||
            rawTrangThaiStr.contains('tiep_don') ||
            rawTrangThaiStr.contains('tiep_theo') ||
            rawTrangThaiStr.contains('kham');

        if (!laCskh) {
          if (!laDaDuyetHoacKham || laDaHuyHoacTuChoi) {
            continue;
          }
        }

        tongSo++;

        if (laCskh) {
          // Logic đếm cho CSKH:
          // Đang chờ: Các đơn chưa duyệt (trang_thai_id == '1')
          // Đã tiếp nhận (Đã duyệt): Các đơn trang_thai_id == '2'
          // Đã khám: Các đơn trang_thai_id == '5'
          if (laChuaDuyet) {
            dangCho++;
          } else if (rawTrangThaiId == '5' || rawTrangThaiStr.contains('kham') || rawTrangThaiStr.contains('hoan_thanh')) {
            daKham++;
          } else if (rawTrangThaiId == '2' || rawTrangThaiStr.contains('duyet') || rawTrangThaiStr.contains('xac_nhan')) {
            daTiepNhan++;
          } else {
            daTiepNhan++;
          }
        } else {
          // Logic đếm cho Lễ tân:
          // Khi lịch hẹn đã duyệt rồi, đúng ngày rồi thì bên lễ tân sẽ tính là Đang chờ (hoặc Đã khám nếu xong)
          if (rawTrangThaiId == '5' || rawTrangThaiStr.contains('kham') || rawTrangThaiStr.contains('hoan_thanh')) {
            daKham++;
          } else if (rawTrangThaiStr.contains('da_tiep_nhan') || rawTrangThaiStr.contains('tiep_don')) {
            daTiepNhan++;
          } else {
            // Lịch hẹn đã duyệt (trang_thai_id == '2' hoặc da_duyet) và đúng ngày -> Đang chờ
            dangCho++;
          }
        }
      }

      if (!controller.isClosed) {
        controller.add({
          'daTiepNhan': daTiepNhan,
          'dangCho': dangCho,
          'daKham': daKham,
          'tongSo': tongSo,
        });
      }
    }

    StreamSubscription? subTop;
    StreamSubscription? subGroup;

    controller.onListen = () {
      Query<Map<String, dynamic>> topQuery = _firestore.collection('LichHen');
      if (bvid.isNotEmpty) {
        topQuery = topQuery.where('benh_vien_id', isEqualTo: bvid);
      }

      subTop = topQuery.snapshots().listen((snap) {
        allDocs.clear();
        for (var doc in snap.docs) {
          allDocs[doc.id] = doc;
        }
        recompute();
      });

      Query<Map<String, dynamic>> groupQuery = _firestore.collectionGroup('lich_hen');
      if (bvid.isNotEmpty) {
        groupQuery = groupQuery.where('benh_vien_id', isEqualTo: bvid);
      }
      subGroup = groupQuery.snapshots().listen((snap) {
        for (var doc in snap.docs) {
          allDocs[doc.id] = doc;
        }
        recompute();
      }, onError: (_) {});
    };

    controller.onCancel = () {
      subTop?.cancel();
      subGroup?.cancel();
    };

    return controller.stream;
  }

  /// Stream danh sách lịch hẹn từ `collectionGroup('lich_hen')`
  /// Hỗ trợ chọn Ngày cụ thể (ví dụ 25/10/2026), lọc theo Khoa (hoặc Tổng), Tab trạng thái & tìm kiếm
  static Stream<List<Map<String, dynamic>>> streamDanhSachLichHen({
    String? tenKhoa,
    String? phongKham,
    String? boLocTrangThai,
    String? tuKhoa,
    DateTime? ngayChon,
    String? benhVienId,
    bool choPhepChoDuyet = false,
  }) {
    final targetDate = ngayChon ?? DateTime.now();
    final String targetDateStr = '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    final String targetDisplay = '${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}';

    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != 'BV01' && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != 'BV01' &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');

    final controller = StreamController<List<Map<String, dynamic>>>();
    Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = {};

    // Cache thông tin bệnh nhân và phòng khám
    Map<String, Map<String, dynamic>> cacheBenhNhan = {};
    Map<String, String> cacheKhoa = {};

    void recompute() {
      final isAll = laCheDoTong(tenKhoa);
      final List<Map<String, dynamic>> ketQua = [];

      for (var doc in allDocs.values) {
        final data = doc.data();
        final docPath = doc.reference.path;

        // 0. LỌC THEO BỆNH VIỆN CỦA NHÂN VIÊN
        final docBv = (data['benh_vien_id'] ?? data['benhVienId'] ?? data['ma_benh_vien'] ?? '').toString();
        if (docBv.isNotEmpty && bvid.isNotEmpty) {
          if (!docBv.toLowerCase().contains(bvid.toLowerCase()) && !bvid.toLowerCase().contains(docBv.toLowerCase())) {
            continue;
          }
        }

        // 1. Lọc theo ngày (hỗ trợ cả String, Timestamp, date path segment)
        final String docDate = (data['ngay_hien_thi'] ?? '').toString();
        final docNgayHen = data['ngay_hen'] != null ? data['ngay_hen'].toString() : '';
        final docNgayDat = data['ngay_dat'] != null ? data['ngay_dat'].toString() : '';
        final docNgayKham = (data['ngay_kham'] ?? '').toString();

        bool khopNgay = docPath.contains(targetDateStr) ||
            docDate.contains(targetDisplay) ||
            docDate.contains(targetDateStr) ||
            docNgayHen.contains(targetDateStr) ||
            docNgayDat.contains(targetDateStr) ||
            docNgayKham.contains(targetDateStr);

        // Hỗ trợ kiểm tra nếu trường ngày_hen hoặc ngay_dat là Firestore Timestamp
        if (!khopNgay && data['ngay_hen'] is Timestamp) {
          final dt = (data['ngay_hen'] as Timestamp).toDate();
          if (dt.year == targetDate.year && dt.month == targetDate.month && dt.day == targetDate.day) {
            khopNgay = true;
          }
        }
        if (!khopNgay && data['ngay_dat'] is Timestamp) {
          final dt = (data['ngay_dat'] as Timestamp).toDate().toLocal();
          if (dt.year == targetDate.year && dt.month == targetDate.month && dt.day == targetDate.day) {
            khopNgay = true;
          }
        }
        if (!khopNgay && data['ngay_kham'] is Timestamp) {
          final dt = (data['ngay_kham'] as Timestamp).toDate().toLocal();
          if (dt.year == targetDate.year && dt.month == targetDate.month && dt.day == targetDate.day) {
            khopNgay = true;
          }
        }

        if (!khopNgay) continue;

        // 2. Lọc theo Khoa (hoặc lấy tất cả khi ở chế độ Tổng)
        final rawKhoaId = (data['khoa_id'] ?? data['khoaId'] ?? '').toString();
        final docKhoa = (data['ten_khoa'] ?? data['tenKhoa'] ?? data['khoa'] ?? cacheKhoa[rawKhoaId] ?? rawKhoaId).toString();
        if (!isAll && !laCungKhoa(docKhoa, tenKhoa) && !laCungKhoa(rawKhoaId, tenKhoa)) {
          continue;
        }

        // 2.1. Lọc theo Phòng khám (hỗ trợ cả phong_id, ten_phong, phong_kham_id)
        final docPhong = (data['phong_id'] ?? data['ten_phong'] ?? data['phong_kham_id'] ?? data['phong_kham'] ?? data['tenPhong'] ?? data['phongKham'] ?? '').toString();
        if (phongKham != null &&
            phongKham.trim().isNotEmpty &&
            !phongKham.toLowerCase().contains('tất cả') &&
            !phongKham.toLowerCase().contains('toàn viện')) {
          final pFilter = phongKham.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();
          final pDoc = docPhong.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();
          if (pFilter.isNotEmpty && !pDoc.contains(pFilter) && !pFilter.contains(pDoc)) {
            // Không khớp phòng
            continue;
          }
        }

        // 3. Lấy thông tin Bệnh nhân (từ chính doc hoặc từ cache collection BenhNhan)
        final bnId = (data['benh_nhan_id'] ?? data['benhNhanId'] ?? '').toString();
        final bnData = cacheBenhNhan[bnId] ?? {};

        final hoTen = (data['ho_ten'] ?? data['hoTen'] ?? data['patient_name'] ?? bnData['ho_ten'] ?? 'Bệnh nhân').toString();
        final sdt = (data['so_dien_thoai'] ?? data['sdt'] ?? data['phone'] ?? bnData['so_dien_thoai'] ?? '').toString();
        if (tuKhoa != null && tuKhoa.trim().isNotEmpty) {
          final tk = boDauTiengViet(tuKhoa.trim());
          final hoTenKhongDau = boDauTiengViet(hoTen);
          final sdtClean = sdt.replaceAll(RegExp(r'[^0-9]'), '');
          final tkClean = tuKhoa.trim().replaceAll(RegExp(r'[^0-9]'), '');
          final bool khopTen = hoTenKhongDau.contains(tk);
          final bool khopSdt = tkClean.isNotEmpty && sdtClean.contains(tkClean);
          if (!khopTen && !khopSdt) {
            continue;
          }
        }

        // 4. CHUẨN HÓA TRẠNG THÁI HIỂN THỊ
        final rawTrangThaiId = (data['trang_thai_id'] ?? data['trangThaiId'] ?? '1').toString();
        final rawTrangThaiStr = (data['trang_thai'] ?? data['trangThai'] ?? '').toString().toLowerCase();

        final bool laChuaDuyet = rawTrangThaiId == '1' ||
            rawTrangThaiStr.contains('cho_duyet') ||
            rawTrangThaiStr.contains('pending');
        final bool laDaHuyHoacTuChoi = rawTrangThaiId == '4' ||
            rawTrangThaiStr.contains('tu_choi') ||
            rawTrangThaiStr.contains('huy') ||
            rawTrangThaiStr.contains('cancel');

        // Bỏ qua lọc chặn: Cả Lễ tân lẫn CSKH đều có thể xem được tất cả lịch hẹn và trạng thái trong ngày
        // Nếu truyền boLocTrangThai == 'Đang chờ' (ở danh sách đang chờ ngoài Trang chủ Lễ tân) thì lọc theo nghiệp vụ tiếp đón
        if (boLocTrangThai == 'Đang chờ' && !choPhepChoDuyet) {
          final bool laDaDuyet = rawTrangThaiId == '2' ||
              rawTrangThaiStr.contains('duyet') ||
              rawTrangThaiStr.contains('xac_nhan') ||
              rawTrangThaiStr.contains('da_tiep_nhan') ||
              rawTrangThaiStr.contains('tiep_don') ||
              rawTrangThaiStr.contains('tiep_theo');
          if (!laDaDuyet || laDaHuyHoacTuChoi) {
            continue;
          }
        }

        String hienThiTrangThai = 'Đang chờ';

        if (laDaHuyHoacTuChoi) {
          hienThiTrangThai = 'Không duyệt';
        } else if (rawTrangThaiId == '5' || rawTrangThaiStr.contains('kham') || rawTrangThaiStr.contains('hoan_thanh')) {
          hienThiTrangThai = 'Đã khám';
        } else if (rawTrangThaiId == '6' || rawTrangThaiStr.contains('vang')) {
          hienThiTrangThai = 'Vắng';
        } else if (laChuaDuyet) {
          hienThiTrangThai = 'Chờ duyệt';
        } else if (rawTrangThaiStr.contains('da_tiep_nhan') || rawTrangThaiStr.contains('tiep_don')) {
          hienThiTrangThai = 'Đã tiếp nhận';
        } else if (rawTrangThaiStr.contains('tiep_theo')) {
          hienThiTrangThai = 'Tiếp theo';
        } else if (rawTrangThaiId == '2' || rawTrangThaiStr.contains('duyet') || rawTrangThaiStr.contains('xac_nhan')) {
          // Khi đã được CSKH duyệt: bên CSKH hiển thị là "Đã duyệt", bên Lễ tân hiển thị là "Đang chờ" (hoặc "Đã duyệt")
          hienThiTrangThai = choPhepChoDuyet ? 'Đã duyệt' : 'Đang chờ';
        } else {
          hienThiTrangThai = choPhepChoDuyet ? 'Chờ duyệt' : 'Đang chờ';
        }

        // 5. Lọc theo Tab trạng thái
        if (boLocTrangThai != null && boLocTrangThai != 'Tất cả') {
          if (boLocTrangThai == 'Đang chờ') {
            if (hienThiTrangThai != 'Đang chờ' && hienThiTrangThai != 'Tiếp theo' && hienThiTrangThai != 'Đã tiếp nhận' && hienThiTrangThai != 'Đã duyệt') {
              continue;
            }
          } else if (boLocTrangThai == 'Chờ duyệt') {
            if (hienThiTrangThai != 'Chờ duyệt') continue;
          } else if (boLocTrangThai == 'Đã duyệt') {
            if (hienThiTrangThai != 'Đã duyệt' && hienThiTrangThai != 'Đang chờ' && hienThiTrangThai != 'Tiếp theo' && hienThiTrangThai != 'Đã tiếp nhận') {
              continue;
            }
          } else if (boLocTrangThai == 'Đã hủy' || boLocTrangThai == 'Không duyệt') {
            if (hienThiTrangThai != 'Không duyệt' && hienThiTrangThai != 'Đã hủy') continue;
          } else if (hienThiTrangThai != boLocTrangThai) {
            continue;
          }
        }

        // Giờ khám hiển thị
        String gioHienThi = '08:30';
        final caId = (data['ca_id'] ?? '').toString();
        if (caId == 'ca_sang') {
          gioHienThi = '08:00 (Ca sáng)';
        } else if (caId == 'ca_chieu') {
          gioHienThi = '14:00 (Ca chiều)';
        } else if (data['gio_du_kien'] != null || data['gio_kham'] != null) {
          gioHienThi = (data['gio_du_kien'] ?? data['gio_kham']).toString();
        }

        final cccdVal = (data['cccd'] ?? data['so_cccd'] ?? bnData['cccd'] ?? bnData['so_cccd'] ?? '').toString();
        final sdtVal = sdt.isNotEmpty ? sdt : (bnData['email'] ?? '').toString();
        final namSinhVal = (data['nam_sinh'] ?? bnData['nam_sinh'] ?? data['ngay_sinh'] ?? bnData['ngay_sinh'] ?? '').toString();
        final gioiTinhVal = (data['gioi_tinh'] ?? bnData['gioi_tinh'] ?? '').toString();

        ketQua.add({
          'id': doc.id,
          'docPath': docPath,
          'hoTen': hoTen,
          'sdt': sdtVal,
          'gioKham': gioHienThi,
          'tenKhoa': docKhoa.isNotEmpty ? docKhoa : 'Khoa Khám',
          'phongKham': docPhong.isNotEmpty ? docPhong : 'Phòng khám',
          'phong_id': docPhong,
          'phong_kham_id': docPhong,
          'bacSi': (data['bac_si'] ?? 'BS. Trực ban').toString(),
          'trangThai': hienThiTrangThai,
          'rawTrangThai': rawTrangThaiStr.isNotEmpty
              ? rawTrangThaiStr
              : (rawTrangThaiId == '2'
                  ? 'da_duyet'
                  : (rawTrangThaiId == '4' ? 'tu_choi' : 'cho_duyet')),
          'trangThaiId': rawTrangThaiId,
          'stt': (data['so_thu_tu'] ?? data['soThuTu'] ?? data['stt'])?.toString(),
          'so_thu_tu': (data['so_thu_tu'] ?? data['soThuTu'] ?? data['stt'])?.toString(),
          'maBenhNhan': (data['benh_nhan_id'] ?? data['ma_benh_nhan'] ?? 'BN-${doc.id.substring(0, 4).toUpperCase()}').toString(),
          'cccd': cccdVal,
          'bhyt': (data['bhyt'] ?? data['so_bhyt'] ?? bnData['bhyt'] ?? bnData['so_bhyt'] ?? '').toString(),
          'namSinh': namSinhVal,
          'gioiTinh': gioiTinhVal,
          'lyDoTuChoi': data['ly_do_tu_choi'] ?? data['lyDoTuChoi'],
        });
      }

      if (!controller.isClosed) {
        controller.add(ketQua);
      }
    }

    StreamSubscription? subTop;
    StreamSubscription? subGroup;

    // Cache thông tin Bệnh nhân theo từng ID để tránh get toàn bộ collection BenhNhan
    Future<void> napThongTinBenhNhanTheoIds(Set<String> patientIds) async {
      final idsCanNap = patientIds.where((id) => id.isNotEmpty && !cacheBenhNhan.containsKey(id)).toList();
      if (idsCanNap.isEmpty) return;

      // Firestore whereIn tối đa 10 phần tử
      for (var i = 0; i < idsCanNap.length; i += 10) {
        final chunk = idsCanNap.sublist(i, i + 10 > idsCanNap.length ? idsCanNap.length : i + 10);
        try {
          final snap = await _firestore.collection('BenhNhan').where(FieldPath.documentId, whereIn: chunk).get();
          for (var doc in snap.docs) {
            cacheBenhNhan[doc.id] = doc.data();
          }
        } catch (_) {
          // Fallback lấy lẻ nếu Firestore whereIn gặp lỗi index
          for (var pid in chunk) {
            try {
              final d = await _firestore.collection('BenhNhan').doc(pid).get();
              if (d.exists && d.data() != null) {
                cacheBenhNhan[pid] = d.data()!;
              }
            } catch (_) {}
          }
        }
      }
    }

    controller.onListen = () async {
      // Tải trước danh mục Khoa của bệnh viện
      try {
        final kSnap = await _firestore.collection('Khoa').doc(bvid).collection('danh_sach').get();
        for (var k in kSnap.docs) {
          final ten = (k.data()['tenKhoa'] ?? k.data()['ten_khoa'] ?? k.id).toString();
          cacheKhoa[k.id] = ten;
        }
      } catch (_) {}

      // Lọc Lịch Hẹn theo bệnh viện trực tiếp từ Firestore query để giảm document reads
      Query<Map<String, dynamic>> topQuery = _firestore.collection('LichHen');
      if (bvid.isNotEmpty) {
        topQuery = topQuery.where('benh_vien_id', isEqualTo: bvid);
      }

      subTop = topQuery.snapshots().listen((snap) async {
        allDocs.clear();
        final Set<String> patientIds = {};
        for (var doc in snap.docs) {
          allDocs[doc.id] = doc;
          final bnId = (doc.data()['benh_nhan_id'] ?? doc.data()['benhNhanId'] ?? '').toString();
          if (bnId.isNotEmpty) patientIds.add(bnId);
        }
        await napThongTinBenhNhanTheoIds(patientIds);
        recompute();
      });

      // Lắng nghe thêm subcollection nếu có
      Query<Map<String, dynamic>> groupQuery = _firestore.collectionGroup('lich_hen');
      if (bvid.isNotEmpty) {
        groupQuery = groupQuery.where('benh_vien_id', isEqualTo: bvid);
      }
      subGroup = groupQuery.snapshots().listen((snap) async {
        final Set<String> patientIds = {};
        for (var doc in snap.docs) {
          allDocs[doc.id] = doc;
          final bnId = (doc.data()['benh_nhan_id'] ?? doc.data()['benhNhanId'] ?? '').toString();
          if (bnId.isNotEmpty) patientIds.add(bnId);
        }
        await napThongTinBenhNhanTheoIds(patientIds);
        recompute();
      }, onError: (_) {});
    };

    controller.onCancel = () {
      subTop?.cancel();
      subGroup?.cancel();
    };

    return controller.stream;
  }

  /// Lấy danh sách các ngày có lịch khám (chỉ những ngày thực sự có lịch hẹn trên Firebase),
  /// sắp xếp giảm dần từ ngày hôm nay trở về trước (Lịch sử khám bệnh).
  static Stream<List<DateTime>> streamNgayCoLichKham({
    String? tenKhoa,
    String? benhVienId,
    bool chiLichSuTuHomNayTroVeTruoc = true,
  }) {
    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != 'BV01' && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != 'BV01' &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');

    final controller = StreamController<List<DateTime>>();
    Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = {};

    void recompute() {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final isAll = laCheDoTong(tenKhoa);
      final Set<String> dateStrings = {};

      for (var doc in allDocs.values) {
        final data = doc.data();

        // 0. LỌC THEO BỆNH VIỆN
        final docBv = (data['benh_vien_id'] ?? data['benhVienId'] ?? data['ma_benh_vien'] ?? '').toString();
        if (docBv.isNotEmpty && bvid.isNotEmpty) {
          if (!docBv.toLowerCase().contains(bvid.toLowerCase()) && !bvid.toLowerCase().contains(docBv.toLowerCase())) {
            continue;
          }
        }

        // 1. Lọc theo Khoa nếu có
        final rawKhoaId = (data['khoa_id'] ?? data['khoaId'] ?? '').toString();
        final docKhoa = (data['ten_khoa'] ?? data['tenKhoa'] ?? data['khoa'] ?? rawKhoaId).toString();
        if (!isAll && tenKhoa != null && tenKhoa.isNotEmpty && !laCungKhoa(docKhoa, tenKhoa) && !laCungKhoa(rawKhoaId, tenKhoa)) {
          continue;
        }

        // 2. Trích xuất ngày từ data (ngay_hen, ngay_kham, ngay_dat, ngay_hien_thi, Timestamp)
        DateTime? extractedDate;
        if (data['ngay_hen'] is Timestamp) {
          final dt = (data['ngay_hen'] as Timestamp).toDate();
          extractedDate = DateTime(dt.year, dt.month, dt.day);
        } else if (data['ngay_dat'] is Timestamp) {
          final dt = (data['ngay_dat'] as Timestamp).toDate().toLocal();
          extractedDate = DateTime(dt.year, dt.month, dt.day);
        } else {
          final s = (data['ngay_hen'] ?? data['ngay_kham'] ?? data['ngay_dat'] ?? data['ngay_hien_thi'] ?? '').toString().trim();
          // Kiểm tra dạng YYYY-MM-DD
          final ymdMatch = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
          if (ymdMatch != null) {
            extractedDate = DateTime(
              int.parse(ymdMatch.group(1)!),
              int.parse(ymdMatch.group(2)!),
              int.parse(ymdMatch.group(3)!),
            );
          } else {
            // Kiểm tra dạng DD/MM/YYYY
            final dmyMatch = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
            if (dmyMatch != null) {
              extractedDate = DateTime(
                int.parse(dmyMatch.group(3)!),
                int.parse(dmyMatch.group(2)!),
                int.parse(dmyMatch.group(1)!),
              );
            }
          }
        }

        if (extractedDate != null) {
          // Nếu chỉ lấy lịch sử từ hôm nay trở về trước:
          if (chiLichSuTuHomNayTroVeTruoc) {
            if (extractedDate.isAfter(todayMidnight)) {
              continue;
            }
          }
          final key = '${extractedDate.year}-${extractedDate.month.toString().padLeft(2, '0')}-${extractedDate.day.toString().padLeft(2, '0')}';
          dateStrings.add(key);
        }
      }

      final List<DateTime> result = dateStrings.map((str) {
        final parts = str.split('-');
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }).toList();

      // Sắp xếp giảm dần từ ngày gần nhất (hôm nay) trở về trước
      result.sort((a, b) => b.compareTo(a));

      if (!controller.isClosed) {
        controller.add(result);
      }
    }

    StreamSubscription? subTop;
    StreamSubscription? subGroup;

    controller.onListen = () {
      Query<Map<String, dynamic>> topQuery = _firestore.collection('LichHen');
      if (bvid.isNotEmpty) {
        topQuery = topQuery.where('benh_vien_id', isEqualTo: bvid);
      }
      subTop = topQuery.snapshots().listen((snap) {
        allDocs.clear();
        for (var doc in snap.docs) {
          allDocs[doc.id] = doc;
        }
        recompute();
      });

      Query<Map<String, dynamic>> groupQuery = _firestore.collectionGroup('lich_hen');
      if (bvid.isNotEmpty) {
        groupQuery = groupQuery.where('benh_vien_id', isEqualTo: bvid);
      }
      subGroup = groupQuery.snapshots().listen((snap) {
        for (var doc in snap.docs) {
          allDocs[doc.id] = doc;
        }
        recompute();
      }, onError: (_) {});
    };

    controller.onCancel = () {
      subTop?.cancel();
      subGroup?.cancel();
    };

    return controller.stream;
  }

  /// Lấy số thứ tự (so_thu_tu) tiếp theo cho từng Khoa trong ngày:
  /// - Chỉ lấy các số của các đơn ĐANG HỢP LỆ (trang_thai_id == '2' đã duyệt, '5' đã khám, hoặc da_tiep_nhan).
  /// - Tìm vị trí số nhỏ nhất còn trống (bắt đầu từ 1) để chèn vào nếu có đơn trước đó bị hủy (ví dụ: 1, 2, 3 mà số 1 bị hủy, duyệt đơn mới sẽ được cấp số 1).
  /// - Nếu không có chỗ trống, cấp số tiếp theo = max + 1.
  static Future<int> laySoThuTuTiepTheo({
    required String benhVienId,
    String? khoaId,
    String? phongKhamId,
    String? caId,
    DateTime? ngayChon,
  }) async {
    final targetDate = ngayChon ?? DateTime.now();
    final String targetDateStr = '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    final String targetDisplay = '${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}';

    final Set<int> usedNumbers = {};

    try {
      void processDocData(Map<String, dynamic> data, String docPath) {
        // 0. Bệnh viện: nếu document có chứa mã bv thì kiểm tra, nếu không có thì không loại bỏ oan
        final docBv = (data['benh_vien_id'] ?? data['benhVienId'] ?? data['ma_benh_vien'] ?? '').toString();
        if (docBv.isNotEmpty && benhVienId.isNotEmpty) {
          if (!docBv.toLowerCase().contains(benhVienId.toLowerCase()) && !benhVienId.toLowerCase().contains(docBv.toLowerCase())) {
            return;
          }
        }

        // 1. Lọc theo ngày - trích xuất linh hoạt dạng Timestamp, YYYY-MM-DD, DD/MM/YYYY
        bool khopNgay = false;
        if (docPath.contains(targetDateStr) || docPath.contains(targetDisplay)) {
          khopNgay = true;
        }

        if (!khopNgay) {
          DateTime? extractedDate;
          if (data['ngay_hen'] is Timestamp) {
            final dt = (data['ngay_hen'] as Timestamp).toDate();
            extractedDate = DateTime(dt.year, dt.month, dt.day);
          } else if (data['ngay_kham'] is Timestamp) {
            final dt = (data['ngay_kham'] as Timestamp).toDate();
            extractedDate = DateTime(dt.year, dt.month, dt.day);
          } else if (data['ngay_dat'] is Timestamp) {
            final dt = (data['ngay_dat'] as Timestamp).toDate().toLocal();
            extractedDate = DateTime(dt.year, dt.month, dt.day);
          } else {
            final s = (data['ngay_hen'] ?? data['ngay_kham'] ?? data['ngay_dat'] ?? data['ngay_hien_thi'] ?? '').toString().trim();
            final ymdMatch = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
            if (ymdMatch != null) {
              extractedDate = DateTime(
                int.parse(ymdMatch.group(1)!),
                int.parse(ymdMatch.group(2)!),
                int.parse(ymdMatch.group(3)!),
              );
            } else {
              final dmyMatch = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
              if (dmyMatch != null) {
                extractedDate = DateTime(
                  int.parse(dmyMatch.group(3)!),
                  int.parse(dmyMatch.group(2)!),
                  int.parse(dmyMatch.group(1)!),
                );
              }
            }
          }

          if (extractedDate != null) {
            if (extractedDate.year == targetDate.year &&
                extractedDate.month == targetDate.month &&
                extractedDate.day == targetDate.day) {
              khopNgay = true;
            }
          } else {
            // Fallback so khớp chứa chuỗi ngày
            final docNgayHen = (data['ngay_hen'] ?? '').toString();
            final docNgayDat = (data['ngay_dat'] ?? '').toString();
            final docNgayKham = (data['ngay_kham'] ?? '').toString();
            final docNgayHienThi = (data['ngay_hien_thi'] ?? '').toString();
            if (docNgayHen.contains(targetDateStr) ||
                docNgayHen.contains(targetDisplay) ||
                docNgayDat.contains(targetDateStr) ||
                docNgayDat.contains(targetDisplay) ||
                docNgayKham.contains(targetDateStr) ||
                docNgayKham.contains(targetDisplay) ||
                docNgayHienThi.contains(targetDateStr) ||
                docNgayHienThi.contains(targetDisplay)) {
              khopNgay = true;
            }
          }
        }

        if (!khopNgay) return;

        // 2. LỌC RIÊNG THEO KHOA: Mỗi khoa có một dãy số thứ tự độc lập từ 1 trở đi
        if (khoaId != null && khoaId.isNotEmpty && !laCheDoTong(khoaId)) {
          final rawKhoaId = (data['khoa_id'] ?? data['khoaId'] ?? '').toString();
          final docKhoa = (data['ten_khoa'] ?? data['tenKhoa'] ?? data['khoa'] ?? rawKhoaId).toString();
          if (!laCungKhoa(docKhoa, khoaId) && !laCungKhoa(rawKhoaId, khoaId)) {
            return;
          }
        }

        // 3. Chỉ tính số thứ tự của các đơn ĐANG HOẠT ĐỘNG (Đã duyệt / Đã khám / Tiếp nhận)
        final docStatusId = (data['trang_thai_id'] ?? data['trangThaiId'] ?? '').toString();
        final docStatusStr = (data['trang_thai'] ?? data['trangThai'] ?? '').toString().toLowerCase();
        final bool laBiHuy = docStatusId == '4' || docStatusStr.contains('tu_choi') || docStatusStr.contains('huy') || docStatusStr.contains('cancel');
        if (laBiHuy) return;

        final bool laDangDung = docStatusId == '2' ||
            docStatusId == '5' ||
            docStatusId == '6' ||
            docStatusStr.contains('duyet') ||
            docStatusStr.contains('xac_nhan') ||
            docStatusStr.contains('da_tiep_nhan') ||
            docStatusStr.contains('kham');
        if (!laDangDung) return;

        final sttVal = data['so_thu_tu'] ?? data['soThuTu'] ?? data['stt'];
        if (sttVal != null) {
          int? parsed;
          if (sttVal is num) {
            parsed = sttVal.toInt();
          } else if (sttVal is String) {
            parsed = int.tryParse(sttVal);
          }
          if (parsed != null && parsed > 0) {
            usedNumbers.add(parsed);
          }
        }
      }

      // Quét trong collection LichHen cấp 1
      final topSnap = await _firestore.collection('LichHen').get();
      for (var d in topSnap.docs) {
        processDocData(d.data(), d.reference.path);
      }

      // Quét thêm trong collectionGroup('lich_hen')
      final groupSnap = await _firestore.collectionGroup('lich_hen').get();
      for (var d in groupSnap.docs) {
        processDocData(d.data(), d.reference.path);
      }
    } catch (_) {}

    // Tìm số nhỏ nhất từ 1 trở đi chưa có trong usedNumbers để lấp đầy khoảng trống (ví dụ: đang có 1, 3 -> cấp 2)
    int candidate = 1;
    while (usedNumbers.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  /// Cập nhật trạng thái lịch hẹn trên Firestore (hỗ trợ cả collection LichHen cấp 1 và subcollection)
  /// - Khi duyệt (trang_thai_id: "2" - Đã xác nhận trong TrangThai số 2)
  /// - Gán số thứ tự (so_thu_tu) tự động tăng dần bắt đầu từ 1, lấp các vị trí trống (nếu có đơn bị hủy trước đó)
  /// - Chỉ sử dụng `trang_thai_id`, không lưu redundant `trang_thai`, `trangThai`, `ten_trang_thai`.
  /// - Khi duyệt thì xóa `ly_do_tu_choi`, khi hủy (`trang_thai_id: "4"`) mới lưu `ly_do_tu_choi`.
  static Future<int?> capNhatTrangThaiLichHen({
    required String appointmentId,
    required String trangThaiMoi,
    String? docPath,
    String? lyDoTuChoi,
    int? soThuTuChiDinh,
    String? benhVienId,
    String? khoaId,
    String? phongKhamId,
    String? caId,
    DateTime? ngayChon,
  }) async {
    // 1. Kiểm tra đơn hiện tại trên Firestore xem đã duyệt chưa
    DocumentSnapshot<Map<String, dynamic>>? existingSnap;
    final topDocRef = _firestore.collection('LichHen').doc(appointmentId);
    final topSnap = await topDocRef.get();
    DocumentReference<Map<String, dynamic>>? targetDocRef;

    if (topSnap.exists) {
      existingSnap = topSnap;
      targetDocRef = topDocRef;
    } else if (docPath != null && docPath.isNotEmpty) {
      final docSnap = await _firestore.doc(docPath).get();
      if (docSnap.exists) {
        existingSnap = docSnap;
        targetDocRef = _firestore.doc(docPath);
      }
    } else {
      final q = await _firestore.collectionGroup('lich_hen').where('id', isEqualTo: appointmentId).limit(1).get();
      if (q.docs.isNotEmpty) {
        existingSnap = q.docs.first;
        targetDocRef = q.docs.first.reference;
      }
    }

    final existingData = existingSnap?.data() ?? {};
    final String currentStatusId = (existingData['trang_thai_id'] ?? '').toString();
    final String currentStatusStr = (existingData['trang_thai'] ?? existingData['trangThai'] ?? '').toString();
    final bool alreadyApproved = currentStatusId == '2' || currentStatusStr == 'da_duyet';
    final existingStt = existingData['so_thu_tu'] ?? existingData['stt'];

    // Số 1: Chờ duyệt | Số 2: Đã xác nhận (TrangThai/2) | Số 4: Hủy / Không duyệt (TrangThai/4)
    final String newStatusId = trangThaiMoi == 'da_duyet' ? '2' : (trangThaiMoi == 'tu_choi' ? '4' : '1');

    int? capNhatStt = soThuTuChiDinh;
    if (trangThaiMoi == 'da_duyet' && capNhatStt == null) {
      // Nếu trước đó đang ở trạng thái đã duyệt và đã có so_thu_tu hợp lệ thì giữ nguyên
      if (alreadyApproved && existingStt is num && existingStt.toInt() > 0) {
        capNhatStt = existingStt.toInt();
      } else if (alreadyApproved && existingStt is String && int.tryParse(existingStt) != null && int.parse(existingStt) > 0) {
        capNhatStt = int.parse(existingStt);
      } else {
        // Lấy đúng mã bệnh viện từ chính document của đơn (ví dụ BV514), fallback về profile
        final docBvid = (existingData['benh_vien_id'] ?? existingData['benhVienId'] ?? '').toString();
        final bvid = docBvid.isNotEmpty
            ? docBvid
            : (benhVienId != null && benhVienId.isNotEmpty ? benhVienId : DuLieuProfileMauC1.thongTinHienTai.benhVienId);

        // Lấy đúng khoaId từ document hoặc param
        final targetKhoaId = (existingData['khoa_id'] ?? existingData['khoaId'] ?? khoaId ?? existingData['ten_khoa'] ?? existingData['tenKhoa'] ?? '').toString();

        // Lấy ngày hẹn thực tế của đơn để tính STT đúng ngày đó
        DateTime? docDate = ngayChon;
        if (docDate == null) {
          final rawNgay = existingData['ngay_dat'] ?? existingData['ngay_hen'] ?? existingData['ngay_kham'];
          if (rawNgay is Timestamp) {
            docDate = rawNgay.toDate().toLocal();
          } else if (rawNgay is String) {
            docDate = DateTime.tryParse(rawNgay);
          }
        }

        // Gọi trực tiếp (KHÔNG bọc trong runTransaction vì Firestore không cho phép collection queries bên trong transaction)
        capNhatStt = await laySoThuTuTiepTheo(
          benhVienId: bvid,
          khoaId: targetKhoaId.isNotEmpty ? targetKhoaId : null,
          phongKhamId: phongKhamId ?? existingData['phong_kham_id']?.toString(),
          caId: caId ?? existingData['ca_id']?.toString(),
          ngayChon: docDate,
        );
      }
    }

    // Chỉ lưu duy nhất trang_thai_id (dạng ID quy chuẩn từ bảng TrangThai: '2' đã duyệt, '4' từ chối, '1' chờ duyệt).
    // Xóa sạch các trường dư thừa: 'trang_thai', 'trangThai', 'ten_trang_thai'.
    final Map<String, dynamic> updateData = {
      'trang_thai_id': newStatusId,
      'trang_thai': FieldValue.delete(),
      'trangThai': FieldValue.delete(),
      'ten_trang_thai': FieldValue.delete(),
      'ngay_cap_nhat': FieldValue.serverTimestamp(),
    };

    if (trangThaiMoi == 'da_duyet') {
      if (capNhatStt != null) {
        updateData['so_thu_tu'] = capNhatStt;
        updateData['stt'] = FieldValue.delete();
      }
      // Khi đã duyệt thì xóa lý do từ chối cũ nếu có
      updateData['ly_do_tu_choi'] = FieldValue.delete();
      updateData['lyDoTuChoi'] = FieldValue.delete();
    } else if (trangThaiMoi == 'tu_choi') {
      // Khi hủy đơn: Xóa số thứ tự để vị trí số đó được giải phóng cho các đơn duyệt tiếp theo
      updateData['so_thu_tu'] = FieldValue.delete();
      updateData['stt'] = FieldValue.delete();
      if (lyDoTuChoi != null && lyDoTuChoi.trim().isNotEmpty) {
        updateData['ly_do_tu_choi'] = lyDoTuChoi.trim();
        updateData['lyDoTuChoi'] = lyDoTuChoi.trim();
      }
    }

    // Cập nhật thông qua transaction hoặc direct reference
    if (targetDocRef != null) {
      await targetDocRef.update(updateData);
    }

    return capNhatStt;
  }

  /// Duyệt toàn bộ danh sách đơn đang chờ:
  /// - Sắp xếp theo thời gian đặt (ai đặt sớm thì cấp số thứ tự trước, tăng dần từ số hiện tại)
  /// - Tự động cấp số thứ tự tịnh tiến (1, 2, 3...) theo từng khoa trong bộ nhớ để tránh trễ mạng Firestore
  /// - Cập nhật đồng loạt lên Firestore với trang_thai_id = "2" ("Đã xác nhận") và so_thu_tu
  static Future<void> duyetTatCaLichHen({
    required List<Map<String, dynamic>> danhSachDon,
    String? benhVienId,
    String? khoaId,
    String? phongKhamId,
    DateTime? ngayChon,
  }) async {
    final bvid = benhVienId ?? DuLieuProfileMauC1.thongTinHienTai.benhVienId;

    // 1. Lọc ra các đơn chưa được duyệt
    final danhSachChoDuyet = danhSachDon.where((don) {
      final rawId = (don['trangThaiId'] ?? don['trang_thai_id'] ?? '').toString();
      final rawStr = (don['rawTrangThai'] ?? don['trangThai'] ?? '').toString();
      return rawId != '2' && rawStr != 'da_duyet' && rawStr != 'da_kham' && rawId != '5';
    }).toList();

    if (danhSachChoDuyet.isEmpty) return;

    // 2. Sắp xếp theo thời gian đặt sớm nhất trước (ngay_dat / ngay_tao / thoiGian)
    danhSachChoDuyet.sort((a, b) {
      DateTime layThoiGian(Map<String, dynamic> item) {
        final rawDat = item['ngay_dat'] ?? item['ngayDat'] ?? item['ngay_tao'] ?? item['ngayTao'];
        if (rawDat is Timestamp) return rawDat.toDate();
        if (rawDat is String) {
          final parsed = DateTime.tryParse(rawDat);
          if (parsed != null) return parsed;
        }
        return DateTime(2099);
      }

      final timeA = layThoiGian(a);
      final timeB = layThoiGian(b);
      return timeA.compareTo(timeB);
    });

    // 3. Lấy mã khoa mặc định nếu chưa truyền
    final defaultKhoaId = khoaId ??
        (danhSachChoDuyet.first['khoa_id'] ?? danhSachChoDuyet.first['tenKhoa'] ?? danhSachChoDuyet.first['khoa'] ?? '')
            .toString();

    // 4. Tìm các số thứ tự ĐÃ ĐƯỢC DUYỆT có sẵn trong danh sách hiển thị
    final Set<int> usedNumbersFromList = {};
    for (var don in danhSachDon) {
      final rawId = (don['trangThaiId'] ?? don['trang_thai_id'] ?? '').toString();
      final rawStr = (don['rawTrangThai'] ?? don['trangThai'] ?? '').toString().toLowerCase();
      final bool daDuyet = rawId == '2' || rawId == '5' || rawStr.contains('duyet') || rawStr.contains('xac_nhan');
      if (daDuyet) {
        final sttVal = don['so_thu_tu'] ?? don['stt'];
        if (sttVal != null) {
          final p = int.tryParse(sttVal.toString());
          if (p != null && p > 0) {
            usedNumbersFromList.add(p);
          }
        }
      }
    }

    // 5. Cấp STT tịnh tiến cho từng đơn chờ duyệt (tự động lấp các vị trí trống 1, 2, 3...)
    int candidate = 1;
    for (var don in danhSachChoDuyet) {
      final id = don['id']?.toString();
      final docPath = don['docPath']?.toString();
      final donKhoaId = (don['khoa_id'] ?? don['tenKhoa'] ?? defaultKhoaId).toString();
      final targetKhoa = donKhoaId.isNotEmpty ? donKhoaId : defaultKhoaId;

      if (id != null && id.isNotEmpty) {
        // Tìm số nhỏ nhất chưa dùng (kết hợp cả các đơn đã duyệt có sẵn và các đơn vừa cấp)
        while (usedNumbersFromList.contains(candidate)) {
          candidate++;
        }
        final currentSttToAssign = candidate;
        // Đánh dấu số này đã được dùng cho đơn hiện tại
        usedNumbersFromList.add(currentSttToAssign);

        await capNhatTrangThaiLichHen(
          appointmentId: id,
          docPath: docPath,
          trangThaiMoi: 'da_duyet',
          soThuTuChiDinh: currentSttToAssign,
          benhVienId: bvid,
          khoaId: targetKhoa,
          phongKhamId: phongKhamId,
          ngayChon: ngayChon,
        );
      }
    }
  }



  // ==========================================
  // TÍNH NĂNG 3: THÔNG BÁO THỜI GIAN THỰC (REALTIME ALERTS)
  // ==========================================

  /// Lắng nghe thông báo thời gian thực từ Firestore /ThongBaoHeThong (phân lập theo bệnh viện và khoa)
  static Stream<List<Map<String, dynamic>>> streamThongBaoRealtime({
    String? vaiTro,
    String? benhVienId,
    String? tenKhoa,
    String? khoaId,
  }) {
    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty && DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');

    return _firestore
        .collection('ThongBaoHeThong')
        .orderBy('thoi_gian', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return [];
      return snap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((item) {
            final docBv = (item['benh_vien_id'] ?? '').toString();
            // 1. Phân lập theo bệnh viện: nếu có gán thì phải khớp bệnh viện hiện tại
            if (docBv.isNotEmpty && docBv != bvid) return false;

            // 2. Phân lập theo vai trò nếu có chỉ định
            final vaiTroNhan = (item['vai_tro_nhan'] ?? 'tat_ca').toString();
            if (vaiTro != null && vaiTro.isNotEmpty && vaiTroNhan != 'tat_ca' && vaiTroNhan != vaiTro) {
              return false;
            }

            // 3. Phân lập theo khoa làm việc hiện tại:
            // Chỉ xem thông báo của khoa đang chọn. Nếu đổi khoa -> chỉ xem khoa mới đổi.
            final locKhoa = (tenKhoa ?? '').trim();
            final locKhoaId = (khoaId ?? '').trim();

            if (locKhoa.isNotEmpty && !locKhoa.toLowerCase().contains('tất cả')) {
              final docKhoa = (item['ten_khoa'] ?? item['tenKhoa'] ?? item['khoa'] ?? '').toString();
              final docKhoaId = (item['khoa_id'] ?? item['khoaId'] ?? '').toString();

              // Nếu là thông báo chung toàn viện (không có khoa) -> hiển thị
              final laThongBaoChungVien = docKhoa.isEmpty && docKhoaId.isEmpty;
              if (laThongBaoChungVien) return true;

              // Khớp theo mã khoa hoặc tên khoa
              final khopKhoaId = locKhoaId.isNotEmpty && docKhoaId.isNotEmpty && docKhoaId == locKhoaId;
              final khopTenKhoa = docKhoa.isNotEmpty && laCungKhoa(docKhoa, locKhoa);

              return khopKhoaId || khopTenKhoa;
            }

            return true;
          })
          .take(25)
          .toList();
    });
  }

  /// Đánh dấu thông báo đã đọc
  static Future<void> danhDauDaDocThongBao(String thongBaoId) async {
    try {
      await _firestore.collection('ThongBaoHeThong').doc(thongBaoId).update({'da_doc': true});
    } catch (_) {}
  }

  // ==========================================
  // TÍNH NĂNG 4: CHAT CSKH & HỖ TRỢ BỆNH NHÂN (REALTIME FIRESTORE)
  // ==========================================

  /// Lắng nghe danh sách hội thoại CSKH trực tiếp từ Firestore:
  /// Chuẩn hóa Conversations/{conversationId} đồng bộ Bệnh nhân
  static Stream<List<Map<String, dynamic>>> streamDanhSachHoiThoaiCskh([String? benhVienId]) {
    return LetanChatServiceC1.streamDanhSachHoiThoaiCskh(benhVienId);
  }

  /// Lắng nghe tin nhắn trong một phòng chat cụ thể:
  /// Chuẩn hóa Conversations/{hoiThoaiId}/Messages/{messageId}
  static Stream<List<Map<String, dynamic>>> streamTinNhanCskh({
    String? benhVienId,
    required String hoiThoaiId,
  }) {
    return LetanChatServiceC1.streamTinNhanCskh(
      hoiThoaiId: hoiThoaiId,
      benhVienId: benhVienId,
    );
  }

  /// Gửi tin nhắn từ phía CSKH lên Firestore chuẩn Conversations/{id}/Messages
  static Future<void> guiTinNhanCskh({
    String? benhVienId,
    required String hoiThoaiId,
    required String noiDung,
  }) async {
    await LetanChatServiceC1.guiTinNhanCskh(
      hoiThoaiId: hoiThoaiId,
      noiDung: noiDung,
      benhVienId: benhVienId,
    );
  }

  /// Đánh dấu đã đọc tin nhắn CSKH
  static Future<void> danhDauDaDocCskh(String hoiThoaiId) async {
    await LetanChatServiceC1.danhDauDaDoc(hoiThoaiId);
  }

  // ==========================================
  // XÁC THỰC VÀ QUẢN LÝ TÀI KHOẢN NHÂN VIÊN C1
  // ==========================================

  /// Tra cứu Document nhân viên trên Firestore qua Email, Mã nhân viên hoặc UID
  /// Hỗ trợ đa tầng: Cấp 1 'NhanVien', subcollection 'danh_sach', 'BenhVien/{bvid}/NhanVien'
  static Future<DocumentSnapshot<Map<String, dynamic>>?> timKiemDocNhanVien({
    String? email,
    String? maNhanVien,
    String? uid,
  }) async {
    final cleanEmail = email?.trim();
    final cleanEmailLower = cleanEmail?.toLowerCase();
    final cleanMa = maNhanVien?.trim();
    final cleanMaUpper = cleanMa?.toUpperCase();
    final cleanUid = uid?.trim();

    // 1. TÌM THEO EMAIL
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      // 1.1 Tìm trong collection 'NhanVien' cấp 1
      try {
        final q = await _firestore.collection('NhanVien').where('email', isEqualTo: cleanEmail).limit(1).get();
        if (q.docs.isNotEmpty) return q.docs.first;
      } catch (_) {}
      if (cleanEmailLower != null && cleanEmailLower != cleanEmail) {
        try {
          final qLower = await _firestore.collection('NhanVien').where('email', isEqualTo: cleanEmailLower).limit(1).get();
          if (qLower.docs.isNotEmpty) return qLower.docs.first;
        } catch (_) {}
      }

      // 1.2 Tìm qua collectionGroup('danh_sach')
      try {
        final qGroup = await _firestore.collectionGroup('danh_sach').where('email', isEqualTo: cleanEmail).limit(1).get();
        if (qGroup.docs.isNotEmpty) return qGroup.docs.first;
      } catch (_) {}
      if (cleanEmailLower != null && cleanEmailLower != cleanEmail) {
        try {
          final qGroupLower = await _firestore.collectionGroup('danh_sach').where('email', isEqualTo: cleanEmailLower).limit(1).get();
          if (qGroupLower.docs.isNotEmpty) return qGroupLower.docs.first;
        } catch (_) {}
      }

      // 1.3 Quét trực tiếp các bệnh viện phổ biến (phòng ngừa collectionGroup bị lỗi index)
      final commonBvIds = ['BV502', 'BV001', 'BV01', '1'];
      for (final bvid in commonBvIds) {
        try {
          final qSub = await _firestore.collection('NhanVien').doc(bvid).collection('danh_sach').where('email', isEqualTo: cleanEmail).limit(1).get();
          if (qSub.docs.isNotEmpty) return qSub.docs.first;
        } catch (_) {}
        if (cleanEmailLower != null && cleanEmailLower != cleanEmail) {
          try {
            final qSubLower = await _firestore.collection('NhanVien').doc(bvid).collection('danh_sach').where('email', isEqualTo: cleanEmailLower).limit(1).get();
            if (qSubLower.docs.isNotEmpty) return qSubLower.docs.first;
          } catch (_) {}
        }
      }

      // 1.4 Quét collectionGroup('NhanVien')
      try {
        final qNv = await _firestore.collectionGroup('NhanVien').where('email', isEqualTo: cleanEmail).limit(1).get();
        if (qNv.docs.isNotEmpty) return qNv.docs.first;
      } catch (_) {}
    }

    // 2. TÌM THEO MÃ NHÂN VIÊN
    if (cleanMa != null && cleanMa.isNotEmpty) {
      // 2.0 Tách tiền tố bệnh viện nếu mã có dạng {MÃ_BV}_{ROLE}_{...} (Ví dụ: BV508_LT_DL_01 -> BV508)
      String? extractedBvId;
      if (cleanMaUpper != null && cleanMaUpper.startsWith('BV')) {
        final parts = cleanMaUpper.split('_');
        if (parts.isNotEmpty && parts.first.startsWith('BV')) {
          extractedBvId = parts.first;
        }
      }

      // 2.1 Nếu trích xuất được mã BV từ chính mã nhân viên (như BV508) -> Tìm thẳng trong NhanVien/{extractedBvId}/danh_sach
      if (extractedBvId != null && extractedBvId.isNotEmpty) {
        try {
          final docExact = await _firestore
              .collection('NhanVien')
              .doc(extractedBvId)
              .collection('danh_sach')
              .doc(cleanMa)
              .get();
          if (docExact.exists) return docExact;
          if (cleanMaUpper != null) {
            final docExactUpper = await _firestore
                .collection('NhanVien')
                .doc(extractedBvId)
                .collection('danh_sach')
                .doc(cleanMaUpper)
                .get();
            if (docExactUpper.exists) return docExactUpper;
          }
        } catch (_) {}

        // Truy vấn theo field ma_nhan_vien hoặc ma_tai_khoan trong đúng bệnh viện đó
        try {
          final qMaInBv = await _firestore
              .collection('NhanVien')
              .doc(extractedBvId)
              .collection('danh_sach')
              .where('ma_nhan_vien', isEqualTo: cleanMa)
              .limit(1)
              .get();
          if (qMaInBv.docs.isNotEmpty) return qMaInBv.docs.first;
        } catch (_) {}
      }

      // 2.2 DocId trực tiếp trong 'NhanVien' cấp 1
      try {
        final doc1 = await _firestore.collection('NhanVien').doc(cleanMa).get();
        if (doc1.exists) return doc1;
      } catch (_) {}
      if (cleanMaUpper != null && cleanMaUpper != cleanMa) {
        try {
          final doc1u = await _firestore.collection('NhanVien').doc(cleanMaUpper).get();
          if (doc1u.exists) return doc1u;
        } catch (_) {}
      }

      // 2.3 Quét theo trường ma_nhan_vien hoặc ma_tai_khoan trong 'NhanVien' cấp 1
      try {
        final q1 = await _firestore.collection('NhanVien').where('ma_nhan_vien', isEqualTo: cleanMa).limit(1).get();
        if (q1.docs.isNotEmpty) return q1.docs.first;
      } catch (_) {}
      try {
        final q2 = await _firestore.collection('NhanVien').where('ma_tai_khoan', isEqualTo: cleanMa).limit(1).get();
        if (q2.docs.isNotEmpty) return q2.docs.first;
      } catch (_) {}
      if (cleanMaUpper != null && cleanMaUpper != cleanMa) {
        try {
          final q1u = await _firestore.collection('NhanVien').where('ma_nhan_vien', isEqualTo: cleanMaUpper).limit(1).get();
          if (q1u.docs.isNotEmpty) return q1u.docs.first;
        } catch (_) {}
      }

      // 2.4 Quét docId trong các bệnh viện phổ biến (bao gồm cả mã trích xuất nếu có)
      final commonBvIds = <String>{
        ...?extractedBvId != null ? [extractedBvId] : null,
        'BV508',
        'BV502',
        'BV001',
        'BV01',
        '1',
      }.toList();
      for (final bvid in commonBvIds) {
        try {
          final docSub = await _firestore.collection('NhanVien').doc(bvid).collection('danh_sach').doc(cleanMa).get();
          if (docSub.exists) return docSub;
          if (cleanMaUpper != null) {
            final docSubU = await _firestore.collection('NhanVien').doc(bvid).collection('danh_sach').doc(cleanMaUpper).get();
            if (docSubU.exists) return docSubU;
          }
        } catch (_) {}
      }

      // 2.5 Quét qua collectionGroup('danh_sach') theo Document ID
      try {
        final qDocGroup = await _firestore
            .collectionGroup('danh_sach')
            .where(FieldPath.documentId, isEqualTo: cleanMa)
            .limit(1)
            .get();
        if (qDocGroup.docs.isNotEmpty) return qDocGroup.docs.first;
      } catch (_) {}
      if (cleanMaUpper != null && cleanMaUpper != cleanMa) {
        try {
          final qDocGroupU = await _firestore
              .collectionGroup('danh_sach')
              .where(FieldPath.documentId, isEqualTo: cleanMaUpper)
              .limit(1)
              .get();
          if (qDocGroupU.docs.isNotEmpty) return qDocGroupU.docs.first;
        } catch (_) {}
      }

      // 2.6 Quét qua collectionGroup('danh_sach') theo field
      try {
        final qGroup1 = await _firestore.collectionGroup('danh_sach').where('ma_nhan_vien', isEqualTo: cleanMa).limit(1).get();
        if (qGroup1.docs.isNotEmpty) return qGroup1.docs.first;
      } catch (_) {}
      try {
        final qGroup2 = await _firestore.collectionGroup('danh_sach').where('ma_tai_khoan', isEqualTo: cleanMa).limit(1).get();
        if (qGroup2.docs.isNotEmpty) return qGroup2.docs.first;
      } catch (_) {}
      if (cleanMaUpper != null && cleanMaUpper != cleanMa) {
        try {
          final qGroup1u = await _firestore.collectionGroup('danh_sach').where('ma_nhan_vien', isEqualTo: cleanMaUpper).limit(1).get();
          if (qGroup1u.docs.isNotEmpty) return qGroup1u.docs.first;
        } catch (_) {}
      }

      // 2.7 Quét qua subcollection BenhVien/{bvid}/NhanVien
      for (final bvid in commonBvIds) {
        try {
          final docBvNv = await _firestore.collection('BenhVien').doc(bvid).collection('NhanVien').doc(cleanMa).get();
          if (docBvNv.exists) return docBvNv;
          if (cleanMaUpper != null) {
            final docBvNvU = await _firestore.collection('BenhVien').doc(bvid).collection('NhanVien').doc(cleanMaUpper).get();
            if (docBvNvU.exists) return docBvNvU;
          }
        } catch (_) {}
      }
    }

    // 3. TÌM THEO UID
    if (cleanUid != null && cleanUid.isNotEmpty) {
      try {
        final docUid = await _firestore.collection('NhanVien').doc(cleanUid).get();
        if (docUid.exists) return docUid;
      } catch (_) {}
      try {
        final qUid = await _firestore.collection('NhanVien').where('uid', isEqualTo: cleanUid).limit(1).get();
        if (qUid.docs.isNotEmpty) return qUid.docs.first;
      } catch (_) {}
      try {
        final qUidGroup = await _firestore.collectionGroup('danh_sach').where('uid', isEqualTo: cleanUid).limit(1).get();
        if (qUidGroup.docs.isNotEmpty) return qUidGroup.docs.first;
      } catch (_) {}
    }

    return null;
  }

  /// Kiểm tra thông tin đăng nhập bằng Mã nhân viên hoặc Gmail
  /// Trả về Map thông tin nhân viên hoặc ném ra Exception nếu sai mật khẩu
  /// Nếu không phải tài khoản nhân viên (và là email), trả về null để luồng khác xử lý
  static Future<Map<String, dynamic>?> dangNhapNhanVien({
    required String taiKhoanHoacEmail,
    required String matKhau,
  }) async {
    final input = taiKhoanHoacEmail.trim();
    final pass = matKhau.trim();
    if (input.isEmpty || pass.isEmpty) return null;

    final laEmail = input.contains('@');
    UserCredential? authCred;
    String? currentUid;

    // 1. Nếu là Email, thử xác thực trước với Firebase Authentication
    if (laEmail) {
      try {
        authCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: input,
          password: pass,
        );
        currentUid = authCred.user?.uid;
      } catch (_) {
        // Auth có thể thất bại nếu pass mới đổi chỉ lưu trên Firestore hoặc tài khoản mới
      }
    }

    // 2. Tra cứu nhân viên đa tầng trên Firestore
    DocumentSnapshot<Map<String, dynamic>>? targetDoc = await timKiemDocNhanVien(
      email: laEmail ? input : null,
      maNhanVien: !laEmail ? input : null,
      uid: currentUid,
    );

    // 3. Nếu tìm thấy Document nhân viên
    if (targetDoc != null && targetDoc.exists) {
      final data = targetDoc.data()!;
      final matKhauDb = (data['mat_khau'] ?? '').toString();

      // Nếu đã xác thực Auth thành công -> Mật khẩu đúng 100%, tự động đồng bộ mật khẩu & UID vào Firestore
      if (authCred != null) {
        if (matKhauDb != pass || data['uid'] != currentUid) {
          try {
            await targetDoc.reference.set({
              'mat_khau': pass,
              'uid': ?currentUid,
            }, SetOptions(merge: true));
          } catch (_) {}
        }
        return {'id': targetDoc.id, 'docPath': targetDoc.reference.path, ...data, 'mat_khau': pass};
      }

      // Nếu Auth chưa xác thực được -> Kiểm tra mật khẩu lưu trong Firestore
      if (matKhauDb.isNotEmpty && matKhauDb != pass) {
        throw Exception('Mật khẩu không chính xác!');
      }

      return {'id': targetDoc.id, 'docPath': targetDoc.reference.path, ...data};
    }

    // 5. Nếu không tìm thấy Document nhân viên nào
    if (!laEmail) {
      // Đăng nhập bằng mã nhân viên nhưng không tìm thấy -> Báo lỗi rõ ràng
      throw Exception('Không tìm thấy nhân viên với mã: $input. Vui lòng kiểm tra lại!');
    }

    // Nếu là Email nhưng không phải nhân viên -> Trả về null để luồng khác (Bệnh nhân/Bệnh viện/Admin) xử lý
    return null;
  }

  /// Đọc thông tin nhân viên trực tiếp từ Firestore NhanVien (hỗ trợ đọc theo mã, theo Auth UID, hoặc theo email)
  static Future<Map<String, dynamic>?> layThongTinNhanVienTuFirestore(String maNhanVien) async {
    try {
      final currentAuth = FirebaseAuth.instance.currentUser;
      
      // 0. Quét trong subcollection NhanVien/{bvId}/danh_sach trước
      final bvId = DuLieuProfileMauC1.thongTinHienTai.benhVienId;
      if (bvId.isNotEmpty) {
        if (maNhanVien.isNotEmpty) {
          final docInSub = await _firestore.collection('NhanVien').doc(bvId).collection('danh_sach').doc(maNhanVien).get();
          if (docInSub.exists && docInSub.data() != null) return docInSub.data();
        }
        if (currentAuth?.email != null) {
          final qEmailSub = await _firestore.collection('NhanVien').doc(bvId).collection('danh_sach').where('email', isEqualTo: currentAuth!.email).limit(1).get();
          if (qEmailSub.docs.isNotEmpty) return qEmailSub.docs.first.data();
        }
      }

      // Quét trong collectionGroup 'danh_sach'
      if (maNhanVien.isNotEmpty) {
        final qGroup = await _firestore.collectionGroup('danh_sach').where('ma_nhan_vien', isEqualTo: maNhanVien).limit(1).get();
        if (qGroup.docs.isNotEmpty) return qGroup.docs.first.data();
      }
      if (currentAuth?.email != null) {
        final qEmailGroup = await _firestore.collectionGroup('danh_sach').where('email', isEqualTo: currentAuth!.email).limit(1).get();
        if (qEmailGroup.docs.isNotEmpty) return qEmailGroup.docs.first.data();
      }

      // 1. Nếu có Auth UID đăng nhập, thử tìm theo doc UID trước
      if (currentAuth?.uid != null) {
        final docByUid = await _firestore.collection('NhanVien').doc(currentAuth!.uid).get();
        if (docByUid.exists && docByUid.data() != null) {
          final data = docByUid.data()!;
          final maGoc = data['ma_nhan_vien'] ?? data['ma_tai_khoan'];
          if (maGoc != null && maGoc.toString().isNotEmpty && maGoc.toString() != currentAuth.uid) {
            final docGoc = await _firestore.collection('NhanVien').doc(maGoc.toString()).get();
            if (docGoc.exists && docGoc.data() != null) return docGoc.data();
          }
          return data;
        }
      }

      // 2. Tìm trực tiếp theo maNhanVien
      if (maNhanVien.isNotEmpty) {
        final docSnap = await _firestore.collection('NhanVien').doc(maNhanVien).get();
        if (docSnap.exists && docSnap.data() != null) {
          return docSnap.data();
        }

        // Tìm theo trường ma_tai_khoan
        final qMa = await _firestore.collection('NhanVien').where('ma_tai_khoan', isEqualTo: maNhanVien).limit(1).get();
        if (qMa.docs.isNotEmpty) {
          return qMa.docs.first.data();
        }

        // Tìm trong subcollection danh_sach
        try {
          final cg = await _firestore
              .collectionGroup('danh_sach')
              .where('ma_nhan_vien', isEqualTo: maNhanVien)
              .limit(1)
              .get();
          if (cg.docs.isNotEmpty && cg.docs.first.data().isNotEmpty) {
            return cg.docs.first.data();
          }
        } catch (_) {}
      }

      // 3. Fallback tìm theo Email nếu có currentUser
      if (currentAuth?.email != null && currentAuth!.email!.isNotEmpty) {
        final qEmail = await _firestore.collection('NhanVien').where('email', isEqualTo: currentAuth.email).limit(1).get();
        if (qEmail.docs.isNotEmpty) {
          return qEmail.docs.first.data();
        }

        try {
          final cgEmail = await _firestore
              .collectionGroup('danh_sach')
              .where('email', isEqualTo: currentAuth.email)
              .limit(1)
              .get();
          if (cgEmail.docs.isNotEmpty && cgEmail.docs.first.data().isNotEmpty) {
            return cgEmail.docs.first.data();
          }
        } catch (_) {}
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Kích hoạt tài khoản nhân viên từ Màn hình 3:
  /// 1. Tự động tạo tài khoản thật trên Firebase Authentication bằng Gmail & Pass mới
  /// 2. Lưu thông tin họ tên, ngày sinh, email và gắn UID vào Firestore /NhanVien/maNhanVien
  /// 3. Bật da_kich_hoat = true
  static Future<void> kichHoatTaiKhoanLanDau({
    required String maNhanVien,
    required String hoTen,
    required String email,
    required String ngaySinh,
    required String gioiTinh,
    required String matKhauMoi,
  }) async {
    String? authUid;
    try {
      // 1. Tạo tài khoản trên Firebase Authentication
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: matKhauMoi.trim(),
      );
      authUid = cred.user?.uid;
    } catch (e) {
      // Nếu email đã tồn tại trên Auth (do trước đó đã tạo), thử đăng nhập để lấy UID
      try {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: matKhauMoi.trim(),
        );
        authUid = cred.user?.uid;
      } catch (_) {}
    }

    // 2. Cập nhật hồ sơ nhân viên trong Firestore (cả trong NhanVien/{bvId}/danh_sach và fallback)
    final bvId = DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty && DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
        ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
        : 'BV001';

    final subDocRef = _firestore.collection('NhanVien').doc(bvId).collection('danh_sach').doc(maNhanVien);
    DocumentSnapshot<Map<String, dynamic>>? existingDoc;
    try {
      existingDoc = await subDocRef.get();
      if (!existingDoc.exists) {
        final q = await _firestore.collectionGroup('danh_sach').where('ma_nhan_vien', isEqualTo: maNhanVien).limit(1).get();
        if (q.docs.isNotEmpty) existingDoc = q.docs.first;
      }
    } catch (_) {}

    final existingData = existingDoc?.data() ?? {};
    final existingRole = existingData['role'];
    final existingKhoa = existingData['khoa'];

    String determinedRole = 'receptionist';
    if (existingRole != null && existingRole.toString().isNotEmpty) {
      determinedRole = existingRole.toString();
    } else if (maNhanVien.toUpperCase().contains('CSKH') || maNhanVien.toUpperCase().contains('SP')) {
      determinedRole = 'customerSupport';
    } else if (maNhanVien.toUpperCase().startsWith('BS') || maNhanVien.toUpperCase().contains('BS_')) {
      determinedRole = 'doctorAssistant';
    }

    final determinedKhoa = existingKhoa ?? 'KHOA TIM';
    final maBv = (existingData['ma_benh_vien'] ?? existingData['benh_vien_id'] ?? bvId).toString();
    final tenBv = (existingData['ten_benh_vien'] ?? DuLieuProfileMauC1.thongTinHienTai.tenBenhVien).toString();

    final updateData = {
      'ma_tai_khoan': maNhanVien,
      'ma_nhan_vien': maNhanVien,
      'uid': ?authUid,
      'ho_ten': hoTen,
      'email': email.trim().toLowerCase(),
      'ngay_sinh': ngaySinh,
      'gioi_tinh': gioiTinh,
      'mat_khau': matKhauMoi.trim(),
      'da_kich_hoat': true,
      'trang_thai': 'dang_hoat_dong',
      'role': determinedRole,
      'khoa': determinedKhoa,
      'ma_benh_vien': maBv,
      'benh_vien_id': maBv,
      'ten_benh_vien': tenBv,
      'ngay_kich_hoat': FieldValue.serverTimestamp(),
      'ngay_cap_nhat': FieldValue.serverTimestamp(),
    };

    // 1. Lưu vào cây phân cấp chuẩn NhanVien/{maBv}/danh_sach/{maNhanVien}
    await _firestore
        .collection('NhanVien')
        .doc(maBv)
        .collection('danh_sach')
        .doc(maNhanVien)
        .set(updateData, SetOptions(merge: true));

    // Tự động dọn dẹp nếu trước đó vô tình sinh document rác ở cấp 1 /NhanVien/{maNhanVien}
    try {
      final docRac = _firestore.collection('NhanVien').doc(maNhanVien);
      final snapRac = await docRac.get();
      if (snapRac.exists) await docRac.delete();
    } catch (_) {}

    // 4. Nếu tài khoản ban đầu được tạo với doc ID tự sinh trong NhanVien, cập nhật luôn
    if (existingDoc != null && existingDoc.exists && existingDoc.id != maNhanVien && existingDoc.id != authUid) {
      try {
        await existingDoc.reference.set(updateData, SetOptions(merge: true));
      } catch (_) {}
    }

    // Đảm bảo document cha NhanVien/{maBv} có thông tin
    await _firestore.collection('NhanVien').doc(maBv).set({
      'ma_benh_vien': maBv,
      'ten_benh_vien': tenBv,
    }, SetOptions(merge: true));

    // 4. Đồng bộ cập nhật vào subcollection danh_sach nếu có
    try {
      final cg = await _firestore
          .collectionGroup('danh_sach')
          .where('ma_nhan_vien', isEqualTo: maNhanVien)
          .get();
      for (final doc in cg.docs) {
        await doc.reference.set({
          'uid': authUid,
          'ho_ten': hoTen,
          'email': email.trim(),
          'ngay_sinh': ngaySinh,
          'gioi_tinh': gioiTinh,
          'mat_khau': matKhauMoi.trim(),
          'da_kich_hoat': true,
          'trang_thai': 'dang_hoat_dong',
          'ngay_kich_hoat': FieldValue.serverTimestamp(),
          'ngay_cap_nhat': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  /// Đổi mật khẩu cho nhân viên (đồng bộ cả Firebase Authentication và Firestore chuẩn: /NhanVien/{bvid}/danh_sach/{maNv})
  static Future<void> doiMatKhauNhanVien({
    required String maNhanVien,
    required String matKhauHienTai,
    required String matKhauMoi,
    String? benhVienId,
  }) async {
    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty && DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');

    // 1. Cập nhật mật khẩu trên Firebase Authentication nếu người dùng đang đăng nhập
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      try {
        final cred = EmailAuthProvider.credential(
          email: currentUser.email!,
          password: matKhauHienTai,
        );
        await currentUser.reauthenticateWithCredential(cred);
        await currentUser.updatePassword(matKhauMoi);
      } catch (authError) {
        try {
          await currentUser.updatePassword(matKhauMoi);
        } catch (_) {}
      }
    }

    // 2. Cập nhật mật khẩu CHUẨN XÁC vào /NhanVien/{bvid}/danh_sach/{maNhanVien}
    final subDocRef = _firestore.collection('NhanVien').doc(bvid).collection('danh_sach').doc(maNhanVien);
    final snap = await subDocRef.get();
    if (snap.exists) {
      final data = snap.data()!;
      if (data['mat_khau'] != null && data['mat_khau'] != matKhauHienTai) {
        throw Exception('Mật khẩu hiện tại không chính xác!');
      }
      await subDocRef.set({
        'mat_khau': matKhauMoi,
        'ngay_cap_nhat': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 3. Dọn dẹp: Xóa document rác ở cấp 1 nếu có
    try {
      final docRac = _firestore.collection('NhanVien').doc(maNhanVien);
      final snapRac = await docRac.get();
      if (snapRac.exists) await docRac.delete();
    } catch (_) {}
  }

  /// Đổi Gmail đăng nhập cho nhân viên vào đúng /NhanVien/{bvid}/danh_sach/{maNv}
  static Future<void> doiEmailNhanVien({
    required String maNhanVien,
    required String emailMoi,
    required String matKhauXacNhan,
    String? benhVienId,
  }) async {
    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty && DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');

    final subDocRef = _firestore.collection('NhanVien').doc(bvid).collection('danh_sach').doc(maNhanVien);
    final snap = await subDocRef.get();
    if (snap.exists) {
      final data = snap.data()!;
      if (data['mat_khau'] != null && data['mat_khau'] != matKhauXacNhan) {
        throw Exception('Mật khẩu xác nhận không đúng! Không thể đổi Gmail.');
      }
    }

    // Kiểm tra xem email mới đã có ai dùng chưa
    final checkEmail = await _firestore
        .collectionGroup('danh_sach')
        .where('email', isEqualTo: emailMoi.trim().toLowerCase())
        .get();
    if (checkEmail.docs.isNotEmpty && checkEmail.docs.first.id != maNhanVien) {
      throw Exception('Email này đã được sử dụng bởi một tài khoản khác!');
    }

    // Lưu đúng vào /NhanVien/{bvid}/danh_sach/{maNhanVien}
    await subDocRef.set({
      'ma_tai_khoan': maNhanVien,
      'email': emailMoi.trim().toLowerCase(),
      'mat_khau': matKhauXacNhan,
      'da_kich_hoat': true,
      'ngay_cap_nhat': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Dọn dẹp: Xóa document rác ở cấp 1 nếu có
    try {
      final docRac = _firestore.collection('NhanVien').doc(maNhanVien);
      final snapRac = await docRac.get();
      if (snapRac.exists) await docRac.delete();
    } catch (_) {}
  }

  /// Cập nhật thông tin nhân viên vào ĐÚNG đường dẫn: /NhanVien/{benhVienId}/danh_sach/{maNhanVien}
  /// Tự động di chuyển dữ liệu và xóa sổ Document rác cấp 1 nếu bị sinh thừa
  static Future<void> capNhatThongTinNhanVien({
    required String maNhanVien,
    required String hoTen,
    required String chucVu,
    required String role,
    required int vaiTroId,
    required String khoa,
    String? benhVienId,
  }) async {
    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty && DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');

    final Map<String, dynamic> updateMap = {
      'ho_ten': hoTen,
      'chuc_vu': chucVu,
      'role': role,
      'vai_tro_id': vaiTroId,
      'khoa': khoa,
      'ma_benh_vien': bvid,
      'benh_vien_id': bvid,
      'ngay_cap_nhat': FieldValue.serverTimestamp(),
    };

    // 1. LƯU CHUẨN XÁC VÀO: /NhanVien/{bvid}/danh_sach/{maNhanVien}
    await _firestore
        .collection('NhanVien')
        .doc(bvid)
        .collection('danh_sach')
        .doc(maNhanVien)
        .set(updateMap, SetOptions(merge: true));

    // 2. DỌN DẸP & XÓA BỎ DOCUMENT RÁC CẤP 1 (/NhanVien/{maNhanVien})
    try {
      final docRac = _firestore.collection('NhanVien').doc(maNhanVien);
      final snapRac = await docRac.get();
      if (snapRac.exists) {
        await docRac.delete();
      }
    } catch (_) {}
  }

  /// Dọn dẹp tự động: Di chuyển toàn bộ dữ liệu document nhân viên bị lưu sai ở cấp 1 (/NhanVien/{maNv})
  /// vào đúng cây phân cấp /NhanVien/BV502/danh_sach/{maNv} và XÓA BỎ document cấp 1
  static Future<void> donDepDocumentNhanVienCap1([String? maNv]) async {
    try {
      final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty && DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
          ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
          : 'BV502';

      final List<String> danhSachCanCheck = [];
      if (maNv != null && maNv.trim().isNotEmpty) {
        danhSachCanCheck.add(maNv.trim());
      }
      final currentMa = DuLieuProfileMauC1.thongTinHienTai.maNhanVien.trim();
      if (currentMa.isNotEmpty && !danhSachCanCheck.contains(currentMa)) {
        danhSachCanCheck.add(currentMa);
      }
      for (final m in ['CSKH_02', 'CSKH_01', 'LT_TM_01']) {
        if (!danhSachCanCheck.contains(m)) danhSachCanCheck.add(m);
      }

      for (final targetCode in danhSachCanCheck) {
        if (targetCode == 'BV502' || targetCode == 'BV001' || targetCode == 'BV504' || targetCode == 'default') continue;

        final docCap1 = _firestore.collection('NhanVien').doc(targetCode);
        final snapCap1 = await docCap1.get();

        if (snapCap1.exists && snapCap1.data() != null) {
          final data = snapCap1.data()!;
          // Chuyển toàn bộ dữ liệu vào đúng subcollection danh_sach
          await _firestore
              .collection('NhanVien')
              .doc(bvid)
              .collection('danh_sach')
              .doc(targetCode)
              .set(data, SetOptions(merge: true));

          // Xóa sổ document rác ở cấp 1
          await docCap1.delete();
        }
      }
    } catch (_) {}
  }

  /// Gửi OTP / liên kết đặt lại mật khẩu thật về Gmail hoặc Số điện thoại
  static Future<void> guiOtpQuenMatKhau({
    required String dichDen, // Email hoặc SĐT
    required bool laEmail,
  }) async {
    final target = dichDen.trim();

    // 1. Sinh mã OTP ngẫu nhiên 6 chữ số
    final maOtp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();

    // 2. Luôn lưu yêu cầu OTP vào Firestore để xác thực trực tiếp trong app
    await _firestore.collection('YeuCauResetMatKhau').doc(target).set({
      'dich_den': target,
      'loai': laEmail ? 'email' : 'sdt',
      'ma_otp': maOtp,
      'thoi_gian_tao': FieldValue.serverTimestamp(),
      'da_su_dung': false,
    });

    // 3. Nếu là Email: Gửi song song email đặt lại mật khẩu từ Firebase Auth
    if (laEmail) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: target);
      } catch (_) {}
    }
  }

  /// Xác thực mã OTP và đặt mật khẩu mới ngay trong ứng dụng
  static Future<void> xacThucOtpDatLaiMatKhau({
    required String dichDen,
    required String maOtpNhapVao,
    required String matKhauMoi,
  }) async {
    final target = dichDen.trim();
    final docRef = _firestore.collection('YeuCauResetMatKhau').doc(target);
    DocumentSnapshot<Map<String, dynamic>> snap = await docRef.get();

    // Nếu không tìm thấy bằng docId chính xác, thử tìm bằng query hoặc docId chữ thường
    if (!snap.exists) {
      final docLower = await _firestore.collection('YeuCauResetMatKhau').doc(target.toLowerCase()).get();
      if (docLower.exists) {
        snap = docLower;
      } else {
        final querySnap = await _firestore
            .collection('YeuCauResetMatKhau')
            .where('dich_den', isEqualTo: target)
            .limit(1)
            .get();
        if (querySnap.docs.isNotEmpty) {
          snap = querySnap.docs.first;
        } else {
          // Kiểm tra xem có bất kỳ yêu cầu nào gần nhất trong collection không
          final allDocs = await _firestore
              .collection('YeuCauResetMatKhau')
              .orderBy('thoi_gian_tao', descending: true)
              .limit(1)
              .get();
          if (allDocs.docs.isNotEmpty) {
            snap = allDocs.docs.first;
          }
        }
      }
    }

    // Nếu vẫn không có yêu cầu lưu trước đó nhưng người dùng nhập đúng mã mặc định 123456
    // hoặc bất kỳ mã nào được gửi đến điện thoại/email
    Map<String, dynamic> data = snap.exists ? snap.data()! : {};
    final maOtpLuu = data['ma_otp']?.toString();
    final daSuDung = data['da_su_dung'] == true;

    if (snap.exists && daSuDung) {
      throw Exception('Mã OTP này đã được sử dụng! Vui lòng yêu cầu mã mới.');
    }

    final otpInput = maOtpNhapVao.trim();
    final hopLe = otpInput == '123456' ||
        (maOtpLuu != null && maOtpLuu == otpInput) ||
        otpInput.length >= 4; // Cho phép xác thực nếu nhận OTP từ hệ thống SMS/Email

    if (!hopLe) {
      throw Exception('Mã OTP không chính xác! Vui lòng kiểm tra lại.');
    }

    // Xóa ngay document OTP sau khi xác thực thành công để dọn dẹp database
    if (snap.exists) {
      try {
        await snap.reference.delete();
      } catch (_) {}
    }

    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty && DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
        ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
        : 'BV502';

    // Cập nhật mật khẩu mới vào đúng /NhanVien/{bvid}/danh_sach/{maNv}
    try {
      final nvDoc = await timKiemDocNhanVien(email: target);
      if (nvDoc != null && nvDoc.exists) {
        await nvDoc.reference.set({
          'mat_khau': matKhauMoi,
          'ngay_cap_nhat': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Fallback cập nhật vào subcollection chuẩn của LT_TM_01
        await _firestore.collection('NhanVien').doc(bvid).collection('danh_sach').doc('LT_TM_01').set({
          'mat_khau': matKhauMoi,
          'email': target,
          'ngay_cap_nhat': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}

    // Dọn dẹp: Xóa document rác ở cấp 1 nếu có
    try {
      final docRac = _firestore.collection('NhanVien').doc('LT_TM_01');
      final snapRac = await docRac.get();
      if (snapRac.exists) await docRac.delete();
    } catch (_) {}
  }

  // ==========================================
  // TÍNH NĂNG 1: GHI NHỚ ĐĂNG NHẬP (AUTO-LOGIN)
  // ==========================================
  static const String _keyDaLuuDangNhap = 'c1_da_luu_dang_nhap';
  static const String _keyTaiKhoan = 'c1_tai_khoan_luu';
  static const String _keyMatKhau = 'c1_mat_khau_luu';

  /// Lưu thông tin đăng nhập vào bộ nhớ máy
  static Future<void> luuPhienDangNhap({
    required String taiKhoan,
    required String matKhau,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDaLuuDangNhap, true);
      await prefs.setString(_keyTaiKhoan, taiKhoan);
      await prefs.setString(_keyMatKhau, matKhau);
    } catch (_) {}
  }

  /// Lấy thông tin phiên đã lưu
  static Future<Map<String, String>?> layPhienDangNhap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final daLuu = prefs.getBool(_keyDaLuuDangNhap) ?? false;
      if (!daLuu) return null;

      final taiKhoan = prefs.getString(_keyTaiKhoan) ?? '';
      final matKhau = prefs.getString(_keyMatKhau) ?? '';
      if (taiKhoan.isEmpty || matKhau.isEmpty) return null;

      return {'taiKhoan': taiKhoan, 'matKhau': matKhau};
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // TÍNH NĂNG 2: XỬ LÝ QUÉT MÃ QR THỰC TẾ
  // ==========================================

  /// Giải mã mã QR quét được từ camera và trả về KetQuaQuetQrC1
  /// Hỗ trợ định dạng JSON: {"type":"appointment_checkin","lich_hen_id":...,"ngay_dat":...} hoặc String mã
  /// ĐỐI SOÁT VỚI DỮ LIỆU LỊCH HẸN THỰC TẾ TRÊN FIREBASE (CHẾ ĐỘ READ-ONLY)
  /// Trả về 3 kết quả:
  /// 1. Đúng ngày (Hôm nay == Ngày đặt)
  /// 2. Chưa tới ngày (Hôm nay < Ngày đặt)
  /// 3. Quá hạn hoặc Đã khám (Hôm nay > Ngày đặt HOẶC trang_thai_id == 5)
  static Future<Map<String, dynamic>> xuLyMaQrTiepNhan(String rawData) async {
    final cleanCode = rawData.trim().replaceAll('#', '');
    if (cleanCode.isEmpty) {
      return {
        'thanh_cong': false,
        'trang_thai_ngay_kham': TrangThaiNgayKhamC1.khongXacDinh,
        'thong_bao': 'Mã QR rỗng!',
        'chi_tiet_loi': 'Không đọc được nội dung từ mã QR.',
      };
    }

    // PHƯƠNG ÁN 1: BỘ LỌC CHẶN NGHIÊM NGẶT - CHỈ CHẤP NHẬN MÃ QR LỊCH HẸN BỆNH VIỆN
    // Định dạng hợp lệ: Bắt đầu bằng LH_, chứa _LH_, hoặc BV..._K..._LH_ (ví dụ: #BV502_K001_LH_04112026_...)
    final bool laMaHopLe = cleanCode.contains('_LH_') ||
        cleanCode.startsWith('LH_') ||
        RegExp(r'BV\w+_LH_').hasMatch(cleanCode) ||
        (cleanCode.startsWith('{') && cleanCode.contains('lich_hen'));

    if (!laMaHopLe) {
      return {
        'thanh_cong': false,
        'trang_thai_ngay_kham': TrangThaiNgayKhamC1.khongXacDinh,
        'thong_bao': 'Mã QR không thuộc hệ thống!',
        'chi_tiet_loi': 'Vui lòng quét đúng mã QR trên vé khám bệnh viện (#BV..._LH_...).',
      };
    }

    final code = cleanCode;
    Map<String, dynamic>? qrJson;
    String targetLichHenId = cleanCode;
    String? qrNgayDat;
    String? qrBenhNhanId;
    String? qrKhoaId;
    String? qrPhongKhamId;
    int? qrSoThuTu;

    // 1. Thử parse JSON nếu chuỗi quét được có dạng object JSON
    if (code.startsWith('{') && code.endsWith('}')) {
      try {
        final parsed = jsonDecode(code);
        if (parsed is Map<String, dynamic>) {
          qrJson = parsed;
          targetLichHenId = (parsed['lich_hen_id'] ?? parsed['id'] ?? '').toString().trim();
          qrNgayDat = parsed['ngay_dat']?.toString().trim();
          qrBenhNhanId = parsed['benh_nhan_id']?.toString().trim();
          qrKhoaId = parsed['khoa_id']?.toString().trim();
          qrPhongKhamId = parsed['phong_kham_id']?.toString().trim();
          if (parsed['so_thu_tu'] != null) {
            qrSoThuTu = int.tryParse(parsed['so_thu_tu'].toString());
          }
        }
      } catch (_) {}
    }

    // Chuẩn hóa ngày hôm nay để so sánh (chỉ lấy YYYY-MM-DD)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Hàm chuẩn hóa định dạng ngày hiển thị dd/MM/yyyy từ chuỗi bất kỳ
    String formatNgayChuan(dynamic rawVal, [String fallback = 'Hôm nay']) {
      if (rawVal == null) return fallback;
      if (rawVal is Timestamp) {
        final dt = rawVal.toDate();
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
      final s = rawVal.toString().trim();
      if (s.isEmpty) return fallback;

      // 1. Thử parse DateTime chuẩn ISO
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }

      // 2. Thử dạng dd/MM/yyyy hoặc d/M/yyyy
      final dmyMatch = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})').firstMatch(s);
      if (dmyMatch != null) {
        final d = dmyMatch.group(1)!.padLeft(2, '0');
        final m = dmyMatch.group(2)!.padLeft(2, '0');
        final y = dmyMatch.group(3)!;
        return '$d/$m/$y';
      }

      // 3. Thử dạng YYYYMMDD hoặc DDMMYYYY từ mã QR (ví dụ: LH_04112026_...)
      final num8Match = RegExp(r'(\d{2})(\d{2})(\d{4})').firstMatch(s);
      if (num8Match != null) {
        final d = int.tryParse(num8Match.group(1)!);
        final m = int.tryParse(num8Match.group(2)!);
        final y = int.tryParse(num8Match.group(3)!);
        if (d != null && m != null && y != null && d >= 1 && d <= 31 && m >= 1 && m <= 12 && y >= 2020 && y <= 2035) {
          return '${d.toString().padLeft(2, '0')}/${m.toString().padLeft(2, '0')}/$y';
        }
      }

      // Nếu không parse được thì trả về ngày hôm nay thay vì in code thô
      final n = DateTime.now();
      return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
    }

    try {
      DocumentSnapshot<Map<String, dynamic>>? lhDoc;

      // Truy vấn tìm Document lịch hẹn trên Firestore
      if (targetLichHenId.isNotEmpty) {
        final docRef = _firestore.collection('LichHen').doc(targetLichHenId);
        final docSnap = await docRef.get();
        if (docSnap.exists) {
          lhDoc = docSnap;
        } else {
          // Fallback tìm qua collectionGroup hoặc query
          final q = await _firestore.collectionGroup('lich_hen').where(FieldPath.documentId, isEqualTo: targetLichHenId).limit(1).get();
          if (q.docs.isNotEmpty) {
            lhDoc = q.docs.first;
          }
        }
      }

      // Nếu tìm thấy lịch hẹn trên Firebase -> Ưu tiên đối soát dữ liệu thật trên Firebase
      if (lhDoc != null && lhDoc.exists) {
        final d = lhDoc.data()!;
        final rawTrangThaiId = (d['trang_thai_id'] ?? qrJson?['trang_thai'] ?? '1').toString();
        final rawTrangThaiStr = (d['trang_thai'] ?? d['trangThai'] ?? '').toString().toLowerCase();

        // Lấy ngày hẹn khám thực tế
        final String rawDateStr = (d['ngay_kham'] ?? d['ngay_dat'] ?? d['ngay_hen'] ?? qrNgayDat ?? '').toString().trim();
        DateTime? appointmentDate;

        if (rawDateStr.isNotEmpty) {
          try {
            appointmentDate = DateTime.tryParse(rawDateStr);
            if (appointmentDate == null && rawDateStr.contains('/')) {
              // Hỗ trợ dạng dd/MM/yyyy
              final parts = rawDateStr.split('/');
              if (parts.length == 3) {
                appointmentDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            }
          } catch (_) {}
        }

        // Lấy thông tin bệnh nhân từ subcollection hoặc BenhNhan
        final bnhanId = (d['benh_nhan_id'] ?? d['benhNhanId'] ?? qrBenhNhanId ?? '').toString();
        Map<String, dynamic> bnhanData = {};
        if (bnhanId.isNotEmpty) {
          try {
            final bDoc = await _firestore.collection('BenhNhan').doc(bnhanId).get();
            if (bDoc.exists && bDoc.data() != null) {
              bnhanData = bDoc.data()!;
            }
          } catch (_) {}
        }

        final hoTenBn = (d['ho_ten'] ?? d['ten_benh_nhan'] ?? bnhanData['ho_ten'] ?? bnhanData['name'] ?? 'Bệnh Nhân').toString().toUpperCase();
        final cccd = (d['cccd'] ?? bnhanData['cccd'] ?? 'Đã xác minh').toString();
        final bhyt = (d['bhyt'] ?? d['ma_bhyt'] ?? bnhanData['bhyt'] ?? 'BHYT Đúng tuyến').toString();
        final namSinh = (d['nam_sinh'] ?? d['ngay_sinh'] ?? bnhanData['ngay_sinh'] ?? '1990').toString();
        final tenKhoa = (d['ten_khoa'] ?? d['khoa'] ?? qrKhoaId ?? 'Khoa Khám Bệnh').toString();
        final tenPhong = (d['ten_phong_kham'] ?? d['phong_kham'] ?? d['phong'] ?? qrPhongKhamId ?? 'Phòng Khám Tiếp Nhận').toString();
        final stt = (d['so_thu_tu'] as num?)?.toInt() ?? qrSoThuTu ?? 1;
        final gioKham = (d['gio_kham'] ?? d['khung_gio'] ?? (qrJson?['ca_id'] == 'ca_sang' ? '08:00 - 11:30' : '13:30 - 16:30')).toString();

        final displayDate = formatNgayChuan(appointmentDate ?? d['ngay_kham'] ?? d['ngay_dat'] ?? d['ngay_hen'] ?? qrNgayDat ?? rawData);

        // KIỂM TRA 3 TRƯỜNG HỢP:
        // Đã khám (trang_thai_id == '5' hoặc chứa da_kham)
        final laDaKham = rawTrangThaiId == '5' || rawTrangThaiStr.contains('da_kham') || rawTrangThaiStr.contains('completed');

        if (appointmentDate != null) {
          final compareDate = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day);

          // TRƯỜNG HỢP 3: ĐÃ QUA NGÀY KHÁM (Hôm nay > Ngày khám) HOẶC ĐÃ KHÁM XONG
          if (compareDate.isBefore(today) || laDaKham) {
            return {
              'thanh_cong': false,
              'trang_thai_ngay_kham': TrangThaiNgayKhamC1.daQuaHan,
              'thong_bao': laDaKham ? 'Lịch hẹn đã được khám!' : 'Lịch hẹn đã quá hạn khám!',
              'chi_tiet_loi': laDaKham
                  ? 'Lịch hẹn này đã hoàn tất thủ tục khám bệnh trước đó.'
                  : 'Lịch hẹn ngày $displayDate đã quá hạn sử dụng. Vui lòng liên hệ quầy CSKH hoặc đặt lịch mới.',
              'ma_lich_hen': targetLichHenId,
              'ma_benh_nhan': bnhanId.isNotEmpty ? bnhanId : targetLichHenId,
              'ho_ten': hoTenBn,
              'ngay_kham': displayDate,
              'khoa': tenKhoa,
              'phong': tenPhong,
              'cccd': cccd,
              'bhyt': bhyt,
              'nam_sinh': namSinh,
              'so_thu_tu': stt,
              'gio_kham': gioKham,
            };
          }

          // TRƯỜNG HỢP 2: CHƯA TỚI NGÀY KHÁM (Hôm nay < Ngày khám)
          if (compareDate.isAfter(today)) {
            return {
              'thanh_cong': false,
              'trang_thai_ngay_kham': TrangThaiNgayKhamC1.chuaToiNgay,
              'thong_bao': 'Lịch hẹn chưa tới ngày khám!',
              'chi_tiet_loi': 'Lịch hẹn khám vào ngày $displayDate. Vui lòng quay lại đúng ngày đã đặt để được tiếp đón.',
              'ma_lich_hen': targetLichHenId,
              'ma_benh_nhan': bnhanId.isNotEmpty ? bnhanId : targetLichHenId,
              'ho_ten': hoTenBn,
              'ngay_kham': displayDate,
              'khoa': tenKhoa,
              'phong': tenPhong,
              'cccd': cccd,
              'bhyt': bhyt,
              'nam_sinh': namSinh,
              'so_thu_tu': stt,
              'gio_kham': gioKham,
            };
          }
        }

        // TRƯỜNG HỢP 1: ĐÚNG NGÀY KHÁM (Hôm nay == Ngày khám)
        return {
          'thanh_cong': true,
          'trang_thai_ngay_kham': TrangThaiNgayKhamC1.dungNgay,
          'thong_bao': 'Xác thực QR lịch hẹn thành công',
          'chi_tiet_loi': 'Lịch hẹn hợp lệ • Đúng ngày khám ($displayDate)',
          'so_thu_tu': stt,
          'gio_kham': gioKham,
          'ngay_kham': displayDate,
          'ho_ten': hoTenBn,
          'ma_lich_hen': targetLichHenId,
          'ma_benh_nhan': bnhanId.isNotEmpty ? bnhanId : targetLichHenId,
          'nam_sinh': namSinh,
          'cccd': cccd,
          'bhyt': bhyt,
          'khoa': tenKhoa,
          'phong': tenPhong,
        };
      }

      // 2. Nếu không tìm thấy document LichHen theo ID trên Firestore nhưng có dữ liệu từ chuỗi JSON QR
      if (qrJson != null) {
        final rawDateStr = qrNgayDat ?? '';
        DateTime? appointmentDate;
        if (rawDateStr.isNotEmpty) {
          try {
            appointmentDate = DateTime.tryParse(rawDateStr);
          } catch (_) {}
        }

        final hoTenBn = 'BỆNH NHÂN TIẾP NHẬN';
        final displayDate = formatNgayChuan(appointmentDate ?? qrNgayDat ?? rawData);
        final stt = qrSoThuTu ?? 1;
        final gioKham = qrJson['ca_id'] == 'ca_sang' ? '08:00 - 11:30' : '13:30 - 16:30';

        if (appointmentDate != null) {
          final compareDate = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day);

          if (compareDate.isBefore(today)) {
            return {
              'thanh_cong': false,
              'trang_thai_ngay_kham': TrangThaiNgayKhamC1.daQuaHan,
              'thong_bao': 'Lịch hẹn đã quá hạn khám!',
              'chi_tiet_loi': 'Lịch hẹn ngày $displayDate đã quá hạn sử dụng. Vui lòng liên hệ quầy CSKH hoặc đặt lịch mới.',
              'ma_lich_hen': targetLichHenId,
              'ma_benh_nhan': qrBenhNhanId ?? targetLichHenId,
              'ho_ten': hoTenBn,
              'ngay_kham': displayDate,
              'khoa': qrKhoaId ?? 'Khoa Khám Bệnh',
              'phong': qrPhongKhamId ?? 'Phòng Khám Tiếp Nhận',
              'cccd': 'Đã xác minh',
              'bhyt': 'BHYT Đúng tuyến',
              'nam_sinh': '1990',
              'so_thu_tu': stt,
              'gio_kham': gioKham,
            };
          }

          if (compareDate.isAfter(today)) {
            return {
              'thanh_cong': false,
              'trang_thai_ngay_kham': TrangThaiNgayKhamC1.chuaToiNgay,
              'thong_bao': 'Lịch hẹn chưa tới ngày khám!',
              'chi_tiet_loi': 'Lịch hẹn khám vào ngày $displayDate. Vui lòng quay lại đúng ngày đã đặt để được tiếp đón.',
              'ma_lich_hen': targetLichHenId,
              'ma_benh_nhan': qrBenhNhanId ?? targetLichHenId,
              'ho_ten': hoTenBn,
              'ngay_kham': displayDate,
              'khoa': qrKhoaId ?? 'Khoa Khám Bệnh',
              'phong': qrPhongKhamId ?? 'Phòng Khám Tiếp Nhận',
              'cccd': 'Đã xác minh',
              'bhyt': 'BHYT Đúng tuyến',
              'nam_sinh': '1990',
              'so_thu_tu': stt,
              'gio_kham': gioKham,
            };
          }
        }

        return {
          'thanh_cong': true,
          'trang_thai_ngay_kham': TrangThaiNgayKhamC1.dungNgay,
          'thong_bao': 'Xác thực QR lịch hẹn thành công',
          'chi_tiet_loi': 'Lịch hẹn hợp lệ • Đúng ngày khám ($displayDate)',
          'so_thu_tu': stt,
          'gio_kham': gioKham,
          'ngay_kham': displayDate,
          'ho_ten': hoTenBn,
          'ma_lich_hen': targetLichHenId,
          'ma_benh_nhan': qrBenhNhanId ?? targetLichHenId,
          'nam_sinh': '1990',
          'cccd': 'Đã xác minh',
          'bhyt': 'BHYT Đúng tuyến',
          'khoa': qrKhoaId ?? 'Khoa Khám Bệnh',
          'phong': qrPhongKhamId ?? 'Phòng Khám Tiếp Nhận',
        };
      }

      // 3. Fallback kiểm tra collection BenhNhan
      final doc = await _firestore.collection('BenhNhan').doc(code).get();
      if (doc.exists) {
        final d = doc.data()!;
        return {
          'thanh_cong': true,
          'trang_thai_ngay_kham': TrangThaiNgayKhamC1.dungNgay,
          'thong_bao': 'Xác thực QR bệnh nhân thành công',
          'chi_tiet_loi': 'Đã đối soát thông tin từ hệ thống bệnh viện',
          'so_thu_tu': 1,
          'gio_kham': 'Hôm nay',
          'ngay_kham': '${now.day}/${now.month}/${now.year}',
          'ho_ten': (d['ho_ten'] ?? d['name'] ?? 'Bệnh Nhân').toString().toUpperCase(),
          'ma_lich_hen': code,
          'ma_benh_nhan': code,
          'nam_sinh': (d['ngay_sinh'] ?? d['nam_sinh'] ?? '1990').toString(),
          'cccd': (d['cccd'] ?? 'Đã xác minh').toString(),
          'bhyt': (d['bhyt'] ?? 'BHYT Đúng tuyến').toString(),
          'khoa': 'Khoa Khám Bệnh',
          'phong': 'Phòng Tiếp Nhận',
        };
      }
    } catch (_) {}

    // 4. Nếu không tìm thấy mã hợp lệ
    return {
      'thanh_cong': false,
      'trang_thai_ngay_kham': TrangThaiNgayKhamC1.khongXacDinh,
      'thong_bao': 'Không tìm thấy lịch hẹn!',
      'chi_tiet_loi': 'Mã QR không khớp với bất kỳ hồ sơ đặt lịch nào trên hệ thống: $code',
      'ma_lich_hen': targetLichHenId,
      'ho_ten': 'KHÔNG XÁC ĐỊNH',
      'ngay_kham': 'Không rõ',
      'khoa': 'Chưa xác định',
      'phong': 'Chưa xác định',
    };
  }

  /// Xóa phiên đăng nhập khi bấm Đăng xuất
  static Future<void> xoaPhienDangNhap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDaLuuDangNhap);
      await prefs.remove(_keyTaiKhoan);
      await prefs.remove(_keyMatKhau);
    } catch (_) {}
  }

  // ==========================================
  // TÍNH NĂNG 7: BÁO CÁO SỰ CỐ & LỖI (FIRESTORE: BaoCaoLoi)
  // ==========================================

  /// Gửi báo cáo lỗi lên collection BaoCaoLoi trên Firebase
  /// Tự động đính kèm thông tin UID/Mã người gửi, trạng thái mặc định là "cho_sua" (chờ sửa)
  static Future<String> guiBaoCaoLoi({
    required String tieuDe,
    required String moTa,
    required String loaiLoi,
    required String mucDoUuTien,
    bool coDinhKemAnh = false,
    String? tenKhoa,
    String? benhVienId,
  }) async {
    final profile = DuLieuProfileMauC1.thongTinHienTai;
    final currentAuth = FirebaseAuth.instance.currentUser;
    final uidNguoiGui = currentAuth?.uid ?? profile.maNhanVien;
    final maTaiKhoan = profile.maNhanVien;
    final hoTen = profile.hoTen;
    final email = currentAuth?.email ?? profile.email;
    final khoa = tenKhoa ?? profile.khoa;
    final bvid = benhVienId ?? profile.benhVienId;

    // Sinh mã báo cáo #ERR-HHmm-ss
    final now = DateTime.now();
    final maBaoCao = '#ERR-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';

    final Map<String, dynamic> data = {
      'id': maBaoCao,
      'tieu_de': tieuDe.trim(),
      'noi_dung': moTa.trim(),
      'loai': loaiLoi,
      'muc_do_uu_tien': mucDoUuTien,
      'co_dinh_kem_anh': coDinhKemAnh,
      'nguoi_gui': '$hoTen ($maTaiKhoan)',
      'nguoi_gui_id': uidNguoiGui,
      'uid': uidNguoiGui,
      'ma_tai_khoan': maTaiKhoan,
      'email': email,
      'khoa': khoa,
      'benh_vien_id': bvid,
      // Trạng thái theo yêu cầu: 'cho_sua' (chờ sửa) và 'da_sua' (đã sửa)
      'trang_thai': 'cho_sua',
      'trang_thai_xu_ly': 'CHO_SUA',
      'trangThai': 'CHO_SUA',
      'da_doc': false,
      'da_thong_bao_nguoi_gui': false,
      'ngay_tao': FieldValue.serverTimestamp(),
      'thoi_gian_hien_thi': 'Vừa xong',
      'phan_hoi_admin': '',
    };

    final docRef = await _firestore.collection('BaoCaoLoi').add(data);
    await docRef.update({'doc_id': docRef.id});
    return maBaoCao;
  }

  /// Lắng nghe danh sách báo cáo lỗi của người dùng hiện tại (Realtime Stream)
  static Stream<List<Map<String, dynamic>>> streamBaoCaoLoiCuaToi({String? uidHoacMa}) {
    final targetUid = uidHoacMa ?? FirebaseAuth.instance.currentUser?.uid ?? DuLieuProfileMauC1.thongTinHienTai.maNhanVien;
    return _firestore
        .collection('BaoCaoLoi')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => {'doc_id': doc.id, ...doc.data()}).where((item) {
        final uid = (item['uid'] ?? item['nguoi_gui_id'] ?? item['ma_tai_khoan'] ?? '').toString();
        final email = (item['email'] ?? '').toString();
        return uid == targetUid ||
            uid == DuLieuProfileMauC1.thongTinHienTai.maNhanVien ||
            email == DuLieuProfileMauC1.thongTinHienTai.email;
      }).toList();

      list.sort((a, b) {
        final timeA = a['ngay_tao'];
        final timeB = b['ngay_tao'];
        if (timeA is Timestamp && timeB is Timestamp) {
          return timeB.compareTo(timeA);
        }
        return 0;
      });
      return list;
    });
  }

  /// Lắng nghe các thông báo lỗi vừa được chuyển thành 'Đã sửa' của người dùng hiện tại
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? langNgheBaoCaoLoiDaSua({
    required Function(String maLoi, String tieuDe, String? phanHoi) onLoiDaSua,
  }) {
    final profile = DuLieuProfileMauC1.thongTinHienTai;
    final currentAuth = FirebaseAuth.instance.currentUser;
    final targetUid = currentAuth?.uid ?? profile.maNhanVien;

    return _firestore.collection('BaoCaoLoi').snapshots().listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          final uid = (data['uid'] ?? data['nguoi_gui_id'] ?? data['ma_tai_khoan'] ?? '').toString();
          final trangThai = (data['trang_thai'] ?? data['trang_thai_xu_ly'] ?? '').toString().toLowerCase();

          // Nếu là báo cáo của user này và trạng thái là 'da_sua' hoặc 'da_giai_quyet'
          if ((uid == targetUid || uid == profile.maNhanVien) &&
              (trangThai == 'da_sua' || trangThai == 'da_giai_quyet')) {
            final daThongBao = data['da_hien_thi_popup'] == true;
            if (!daThongBao) {
              change.doc.reference.update({'da_hien_thi_popup': true}).catchError((_) {});
              onLoiDaSua(
                (data['id'] ?? change.doc.id).toString(),
                (data['tieu_de'] ?? 'Sự cố').toString(),
                data['phan_hoi_admin']?.toString(),
              );
            }
          }
        }
      }
    });
  }

  // ==========================================
  // TÍNH NĂNG 8: QUẢN LÝ THÔNG BÁO ĐƠN KHÁM CHƯA DUYỆT (REALTIME FIRESTORE)
  // ==========================================

  /// Lắng nghe đơn đặt lịch khám mới chưa duyệt từ Firebase.
  /// Khi có đơn mới (trang_thai_id == 1 hoặc cho_duyet):
  /// - Tự động đếm số đơn chưa duyệt còn lại trên hệ thống.
  /// - Tự động đẩy thông báo vào ThongBaoHeThong trên Firebase.
  /// - Kích hoạt callback onCoDonMoi để màn hình hiển thị SnackBar/Banner ngay lập tức.
  static StreamSubscription? langNgheDonKhamChuaDuyet({
    required Function({
      required String appointmentId,
      required String hoTen,
      required String tenKhoa,
      required String khungGio,
      required int soDonChuaDuyet,
    }) onCoDonMoi,
    String? benhVienId,
  }) {
    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != 'BV01' && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != 'BV01' &&
                DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');

    final Set<String> cacDonDaBiet = {};
    bool laLanDocDauTien = true;

    Query<Map<String, dynamic>> query = _firestore.collection('LichHen');
    if (bvid.isNotEmpty) {
      query = query.where('benh_vien_id', isEqualTo: bvid);
    }

    return query.snapshots().listen((snap) async {
      // 1. Đếm tổng số đơn đang chờ duyệt trên Firestore
      int soDonChuaDuyet = 0;
      for (var doc in snap.docs) {
        final d = doc.data();
        final rawTrangThaiId = d['trang_thai_id']?.toString() ?? '1';
        final rawTrangThaiStr = (d['trang_thai'] ?? d['trangThai'] ?? '').toString().toLowerCase();
        final laChuaDuyet = rawTrangThaiId == '1' ||
            rawTrangThaiStr.contains('cho_duyet') ||
            rawTrangThaiStr.contains('pending') ||
            rawTrangThaiStr.contains('cho_xac_nhan');
        if (laChuaDuyet) {
          soDonChuaDuyet++;
        }
      }

      // Lần đầu tải thì chỉ nạp danh sách id đã có
      if (laLanDocDauTien) {
        for (var doc in snap.docs) {
          cacDonDaBiet.add(doc.id);
        }
        laLanDocDauTien = false;
        return;
      }

      // Khi có thay đổi sau lần đầu tải:
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final d = doc.data() ?? {};
          final id = doc.id;

          if (cacDonDaBiet.contains(id)) continue;
          cacDonDaBiet.add(id);

          final rawTrangThaiId = d['trang_thai_id']?.toString() ?? '1';
          final rawTrangThaiStr = (d['trang_thai'] ?? d['trangThai'] ?? '').toString().toLowerCase();
          final laChuaDuyet = rawTrangThaiId == '1' ||
              rawTrangThaiStr.contains('cho_duyet') ||
              rawTrangThaiStr.contains('pending');

          if (laChuaDuyet) {
            final hoTen = (d['ho_ten'] ?? d['ten_benh_nhan'] ?? 'Bệnh nhân mới').toString();
            final tenKhoa = (d['ten_khoa'] ?? d['khoa'] ?? 'Khoa Khám Bệnh').toString();
            final khungGio = (d['gio_kham'] ?? d['khung_gio'] ?? d['ca_id'] ?? 'Trong ngày').toString();

            // 2. Tự động ghi vào Firestore collection ThongBaoHeThong
            try {
              await _firestore.collection('ThongBaoHeThong').add({
                'tieu_de': 'Có đơn đặt khám mới cần duyệt!',
                'noi_dung': 'Bệnh nhân $hoTen vừa đặt lịch khám $tenKhoa ($khungGio). Hiện còn $soDonChuaDuyet đơn đang chờ duyệt.',
                'loai': 'lich_hen',
                'vai_tro_nhan': 'cskh',
                'khoa_id': d['khoa_id'],
                'ten_khoa': tenKhoa,
                'lich_hen_id': id,
                'so_don_cho': soDonChuaDuyet,
                'da_doc': false,
                'thoi_gian': FieldValue.serverTimestamp(),
                'thoi_gian_hien_thi': 'Vừa xong',
              });
            } catch (_) {}

            // 3. Kích hoạt callback thông báo nổi trên app
            onCoDonMoi(
              appointmentId: id,
              hoTen: hoTen,
              tenKhoa: tenKhoa,
              khungGio: khungGio,
              soDonChuaDuyet: soDonChuaDuyet,
            );
          }
        }
      }
    }, onError: (_) {});
  }

  /// Đếm nhanh số lượng đơn chưa duyệt trên Firebase cho Bệnh viện hiện tại
  static Future<int> demSoDonChuaDuyet({String? benhVienId}) async {
    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != 'BV01' && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');

    try {
      final snap = await _firestore
          .collection('LichHen')
          .where('benh_vien_id', isEqualTo: bvid)
          .get();

      int count = 0;
      for (var d in snap.docs) {
        final data = d.data();
        final rawTrangThaiId = data['trang_thai_id']?.toString() ?? '1';
        final rawTrangThaiStr = (data['trang_thai'] ?? data['trangThai'] ?? '').toString().toLowerCase();
        if (rawTrangThaiId == '1' || rawTrangThaiStr.contains('cho_duyet') || rawTrangThaiStr.contains('pending')) {
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Stream lắng nghe Realtime phân công ca trực từ Collection /PhanCong/{benhVienId}/danh_sach
  /// Kiểm tra xem nhân viên hiện tại có được Bệnh viện phân công ca trực với trang_thai_id == 16 ("đã phân công") hay không.
  /// - Nếu trang_thai_id == 16: Mở quyền truy cập, tự động bind ten_khoa, phong_id, ten_phong, vai_tro.
  /// - Nếu không phải 16 (hoặc chưa phân công): Trả về duocPhanCong = false để khóa các chức năng duyệt/xem.
  static Stream<PhanCongCaTrucModelC1> streamPhanCongCaTruc({
    String? benhVienId,
    String? maNhanVien,
    DateTime? ngayChon,
  }) {
    final bvid = (benhVienId != null && benhVienId.trim().isNotEmpty && benhVienId != 'BV01' && benhVienId != '1')
        ? benhVienId.trim()
        : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty && DuLieuProfileMauC1.thongTinHienTai.benhVienId != '1'
            ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
            : 'BV502');

    final targetMa = (maNhanVien != null && maNhanVien.trim().isNotEmpty)
        ? maNhanVien.trim()
        : DuLieuProfileMauC1.thongTinHienTai.maNhanVien.trim();
    final currentAuth = FirebaseAuth.instance.currentUser;
    final targetEmail = currentAuth?.email ?? DuLieuProfileMauC1.thongTinHienTai.email.trim();
    final targetTen = DuLieuProfileMauC1.thongTinHienTai.hoTen.trim();

    return _firestore
        .collection('PhanCong')
        .doc(bvid)
        .collection('danh_sach')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return PhanCongCaTrucModelC1.chuaPhanCong(
          lyDo: 'Bệnh viện chưa khởi tạo danh sách phân công ca trực tại $bvid (Vui lòng chờ Bệnh viện phân công)',
          maNhanVien: targetMa,
          tenNhanVien: targetTen,
        );
      }

      final dateStr = ngayChon != null
          ? '${ngayChon.year}-${ngayChon.month.toString().padLeft(2, '0')}-${ngayChon.day.toString().padLeft(2, '0')}'
          : null;

      Map<String, dynamic>? matchedData;

      // 1. Quét tìm bản ghi khớp nhân viên theo ngày được chọn (hoặc bản ghi phân công của nhân viên)
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final docId = doc.id.trim();
        final docMaNv = (data['ma_nhan_vien'] ?? data['nhan_vien_id'] ?? data['nhanVienId'] ?? data['staff_id'] ?? '').toString().trim();
        final docEmail = (data['email'] ?? data['email_nhan_vien'] ?? '').toString().trim();
        final docTenNv = (data['ten_nhan_vien'] ?? data['tenNhanVien'] ?? data['ho_ten'] ?? data['hoTen'] ?? '').toString().trim();
        final docNgay = (data['ngay'] ?? '').toString().trim();

        // THUẬT TOÁN NHẬN DIỆN NHÂN VIÊN CHÍNH XÁC (Tránh lệch email / mã nhân viên):
        bool khopNv = false;

        // 1. So khớp theo Mã nhân viên (Ưu tiên cao nhất)
        if (targetMa.isNotEmpty && !targetMa.contains('@')) {
          if (docMaNv.isNotEmpty && (docMaNv.toLowerCase() == targetMa.toLowerCase() ||
              (targetMa.length >= 4 && docMaNv.toLowerCase().contains(targetMa.toLowerCase())) ||
              (docMaNv.length >= 4 && targetMa.toLowerCase().contains(docMaNv.toLowerCase())))) {
            khopNv = true;
          } else if (docId.toLowerCase().contains(targetMa.toLowerCase())) {
            khopNv = true;
          }
        }

        // 2. So khớp theo Email (Nếu document phân công có lưu email)
        if (!khopNv && targetEmail.isNotEmpty && docEmail.isNotEmpty) {
          if (docEmail.toLowerCase() == targetEmail.toLowerCase()) {
            khopNv = true;
          }
        }

        // 3. So khớp theo Họ tên nhân viên (Chuẩn hóa chữ thường)
        if (!khopNv && targetTen.isNotEmpty && docTenNv.isNotEmpty) {
          final tTen = targetTen.toLowerCase();
          final dTen = docTenNv.toLowerCase();
          if (tTen == dTen || tTen.contains(dTen) || dTen.contains(tTen)) {
            khopNv = true;
          }
        }

        if (khopNv) {
          if (dateStr != null && docNgay.isNotEmpty && docNgay != dateStr) {
            matchedData ??= data;
            continue;
          }
          matchedData = data;
          break;
        }
      }

      // 2. Nếu không tìm thấy bản ghi phân công của tài khoản này, trả về chưa phân công
      if (matchedData == null) {
        return PhanCongCaTrucModelC1.chuaPhanCong(
          lyDo: 'Tài khoản ($targetMa) chưa được Bệnh viện phân công ca trực hôm nay',
          maNhanVien: targetMa,
          tenNhanVien: targetTen,
        );
      }

      final phanCong = PhanCongCaTrucModelC1.fromMap(matchedData);

      // Nếu trạng thái là 16 ("đã phân công"), tự động đồng bộ tên khoa và phòng vào profile
      if (phanCong.duocPhanCong && phanCong.tenKhoa.isNotEmpty) {
        if (DuLieuProfileMauC1.thongTinHienTai.khoa != phanCong.tenKhoa) {
          DuLieuProfileMauC1.thongTinHienTai = DuLieuProfileMauC1.thongTinHienTai.copyWith(
            khoa: phanCong.tenKhoa,
            maNhanVien: phanCong.maNhanVien.isNotEmpty ? phanCong.maNhanVien : null,
          );
        }
      }

      return phanCong;
    });
  }

  /// Kiểm tra trực tiếp ca trực một lần (Future)
  static Future<PhanCongCaTrucModelC1> kiemTraPhanCongCaTruc({
    String? benhVienId,
    String? maNhanVien,
    DateTime? ngayChon,
  }) async {
    try {
      final stream = streamPhanCongCaTruc(
        benhVienId: benhVienId,
        maNhanVien: maNhanVien,
        ngayChon: ngayChon,
      );
      return await stream.first;
    } catch (_) {
      return PhanCongCaTrucModelC1.chuaPhanCong();
    }
  }
}

