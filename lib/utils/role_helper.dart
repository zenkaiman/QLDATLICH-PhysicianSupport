import '../config/constants.dart';

class RoleHelper {
  static bool canAccess(Role userRole, Role requiredRole) {
    return userRole == requiredRole || userRole == Role.admin;
  }

  static String getRoleLabel(Role role) {
    return AppConstants.roleNames[role] ?? 'Không xác định';
  }
}

/// Ánh xạ vai trò nhân viên y tế → nhãn hiển thị tiếng Việt.
///
/// Dùng chung cho màn hình đăng nhập và các tab hồ sơ để KHÔNG còn hiện
/// mặc định "Lễ tân" cho mọi tài khoản.
class VaiTroNhanVienHelper {
  VaiTroNhanVienHelper._();

  static const String bacSi = 'bac_si';
  static const String hoTroBacSi = 'ho_tro_bac_si';
  static const String dieuDuong = 'dieu_duong';
  static const String leTan = 'le_tan';
  static const String cskh = 'cskh';
  static const String quanTri = 'quan_tri';
  static const String keToan = 'ke_toan';
  static const String duocSi = 'duoc_si';
  static const String kyThuat = 'ky_thuat';
  static const String khac = 'khac';

  /// Bỏ dấu tiếng Việt để so khớp không phân biệt dấu
  /// ("Lễ Tân Tiếp Đón" → "le tan tiep don")
  static String boDau(String? raw) {
    const coDau = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const khongDau = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final nguon = (raw ?? '').toLowerCase();
    final dem = StringBuffer();
    for (final ky in nguon.split('')) {
      final viTri = coDau.indexOf(ky);
      dem.write(viTri >= 0 ? khongDau[viTri] : ky);
    }
    return dem.toString();
  }

  /// Chuẩn hoá chuỗi vai trò: bỏ dấu, chữ thường, khoảng trắng/gạch nối → gạch dưới
  static String chuanHoa(String? raw) =>
      boDau(raw).trim().replaceAll(RegExp(r'[\s\-]+'), '_');

  static bool _co(List<String> nguon, List<String> khoa) =>
      nguon.any((e) => khoa.any((k) => e.contains(k)));

  /// Mã vai trò chuẩn: bac_si | ho_tro_bac_si | dieu_duong | le_tan | cskh |
  /// quan_tri | ke_toan | duoc_si | ky_thuat | khac
  ///
  /// Đọc được cả `role`, `vai_tro`, `ma_vai_tro`, `ten_vai_tro`;
  /// nếu document không khai báo thì suy ra từ chính mã nhân viên
  /// (VD: BV508_BS_DL_02 → bac_si, BV508_LT_01 → le_tan).
  static String maVaiTro(String? raw, {String? maNhanVien}) {
    final rawValue = chuanHoa(raw);
    final nguon = rawValue.isNotEmpty ? rawValue : chuanHoa(maNhanVien);
    if (nguon.isEmpty) return khac;

    final ds = <String>[nguon];
    if (_co(ds, const ['quan_tri', 'quantri', 'admin', 'qtdn', 'quan_ly', 'quanly'])) return quanTri;
    if (_co(ds, const ['duoc_si', 'duocsi', 'duoc', 'pharmac'])) return duocSi;
    if (_co(ds, const ['ke_toan', 'ketoan', 'account'])) return keToan;
    if (_co(ds, const ['dieu_duong', 'dieuduong', 'nurse'])) return dieuDuong;
    if (_co(ds, const ['ho_tro', 'hotro', 'assistant', 'tro_ly', 'troly'])) return hoTroBacSi;
    if (_co(ds, const ['cskh', 'customer', 'cham_soc', 'chamsoc', 'chăm_sóc'])) return cskh;
    if (_co(ds, const ['le_tan', 'letan', 'reception', 'tiep_don', 'tiepdon'])) return leTan;
    if (_co(ds, const ['ky_thuat', 'kythuat', 'technician', 'ktv'])) return kyThuat;
    if (_co(ds, const ['bac_si', 'bacsi', 'doctor', 'physician', 'thay_thuoc', 'thaythuoc'])) return bacSi;
    if (RegExp(r'(^|[^a-z])bs([^a-z]|$)').hasMatch(nguon)) return bacSi;
    if (RegExp(r'(^|[^a-z])lt([^a-z]|$)').hasMatch(nguon)) return leTan;
    return khac;
  }

  /// Nhãn hiển thị tiếng Việt của vai trò
  static String nhan(String? raw, {String? maNhanVien}) {
    switch (maVaiTro(raw, maNhanVien: maNhanVien)) {
      case bacSi:
        return 'Bác sĩ';
      case hoTroBacSi:
        return 'Hỗ trợ bác sĩ';
      case dieuDuong:
        return 'Điều dưỡng';
      case leTan:
        return 'Lễ tân tiếp đón';
      case cskh:
        return 'Chuyên viên Chăm sóc khách hàng';
      case quanTri:
        return 'Quản trị viên';
      case keToan:
        return 'Kế toán';
      case duocSi:
        return 'Dược sĩ';
      case kyThuat:
        return 'Kỹ thuật viên';
      default:
        return 'Nhân viên y tế';
    }
  }

  /// Suy ra chuyên khoa từ mã nhân viên: BV508_BS_DL_02 → Khoa Da Liễu
  static String chuyenKhoaTuMa(String? maNhanVien) {
    final ma = chuanHoa(maNhanVien).toUpperCase();
    if (ma.isEmpty) return '';

    const bang = <String, String>{
      'TM': 'Khoa Tim Mạch',
      'TIM': 'Khoa Tim Mạch',
      'TIM_MACH': 'Khoa Tim Mạch',
      'DL': 'Khoa Da Liễu',
      'DA_LIEU': 'Khoa Da Liễu',
      'DALIEU': 'Khoa Da Liễu',
      'NHI': 'Khoa Nhi',
      'MAT': 'Khoa Mắt',
      'TMH': 'Khoa Tai Mũi Họng',
      'RHM': 'Khoa Răng Hàm Mặt',
      'NT': 'Khoa Nội Tổng Hợp',
      'NOI': 'Khoa Nội Tổng Hợp',
      'CC': 'Khoa Cấp Cứu',
      'CAP_CUU': 'Khoa Cấp Cứu',
      'SAN': 'Khoa Sản',
      'NGOAI': 'Khoa Ngoại',
      'XN': 'Khoa Xét Nghiệm',
      'XET_NGHIEM': 'Khoa Xét Nghiệm',
      'CDHA': 'Khoa Chẩn Đoán Hình Ảnh',
    };

    for (final token in ma.split(RegExp(r'[_\-\s]+'))) {
      if (token.isEmpty) continue;
      if (RegExp(r'^(BV|BVN|HOSP)\d*$').hasMatch(token)) continue;
      final ten = bang[token];
      if (ten != null && ten.isNotEmpty) return ten;
    }
    return '';
  }

  /// Nhãn đầy đủ: ưu tiên `chuc_vu` khai báo trong document, nếu trống thì
  /// lấy nhãn theo vai trò; kèm chuyên khoa suy ra từ mã nhân viên khi có.
  static String nhanDayDu({
    String? vaiTro,
    String? chucVu,
    String? khoa,
    String? maNhanVien,
  }) {
    final chucVuSach = (chucVu ?? '').trim();
    final nhan = chucVuSach.isNotEmpty
        ? chucVuSach
        : VaiTroNhanVienHelper.nhan(vaiTro, maNhanVien: maNhanVien);
    final khoaSach = (khoa ?? '').trim().isNotEmpty
        ? khoa!.trim()
        : chuyenKhoaTuMa(maNhanVien);
    if (khoaSach.isEmpty || nhan.toLowerCase().contains(khoaSach.toLowerCase())) {
      return nhan;
    }
    return '$nhan – $khoaSach';
  }
}
