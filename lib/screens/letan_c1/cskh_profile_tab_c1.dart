import 'package:flutter/material.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import 'letan_profile_tab_c1.dart';

/// MÀN HÌNH PROFILE CSKH (KẾ THỪA TỪ LETAN_PROFILE_TAB_C1)
/// Cố định vai trò CSKH và Khoa làm việc do Bệnh viện phân công
class CskhProfileTabC1 extends StatelessWidget {
  final VoidCallback? onDangXuat;

  const CskhProfileTabC1({
    super.key,
    this.onDangXuat,
  });

  @override
  Widget build(BuildContext context) {
    return LetanProfileTabC1(
      onDangXuat: onDangXuat,
      tenKhoaHienTai: DuLieuProfileMauC1.thongTinHienTai.khoa,
    );
  }
}
