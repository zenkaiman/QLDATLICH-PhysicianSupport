import 'package:flutter/material.dart';

import '../../mock/mock_c1/dulieu_mau_cskh_c1.dart';
import '../../models/letan_c1/cskh_model_c1.dart';
import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'cskh_chat_chitiet_screen_c1.dart';

/// MÀN HÌNH 3: DANH SÁCH TIN NHẮN HỖ TRỢ BỆNH NHÂN (CSKH)
/// Đọc dữ liệu tập trung qua DuLieuCskhKhoaC1, chuẩn bị sẵn sàng cho Firebase.
class CskhDanhsachTinnhanScreenC1 extends StatefulWidget {
  const CskhDanhsachTinnhanScreenC1({super.key});

  @override
  State<CskhDanhsachTinnhanScreenC1> createState() => _CskhDanhsachTinnhanScreenC1State();
}

class _CskhDanhsachTinnhanScreenC1State extends State<CskhDanhsachTinnhanScreenC1> {
  String _tabDangChon = 'tat_ca'; // 'tat_ca', 'chua_doc', 'dang_cho'
  final TextEditingController _timKiemController = TextEditingController();

  List<HoiThoaiCskhModelC1> _locDanhSach(List<HoiThoaiCskhModelC1> nguon) {
    final tuKhoa = _timKiemController.text.trim().toLowerCase();
    return nguon.where((item) {
      final khopTuKhoa = item.hoTen.toLowerCase().contains(tuKhoa) ||
          item.khoa.toLowerCase().contains(tuKhoa) ||
          item.tinNhanCuoi.toLowerCase().contains(tuKhoa);

      if (!khopTuKhoa) return false;

      if (_tabDangChon == 'chua_doc') {
        return item.tinChuaDoc > 0;
      } else if (_tabDangChon == 'dang_cho') {
        return item.dangChoPhanHoi;
      }
      return true;
    }).toList();
  }

  void _moManHinhChat(HoiThoaiCskhModelC1 item) {
    AppDesignSystemC1.hapticLight();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CskhChatChitietScreenC1(hoiThoai: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseServiceC1.streamDanhSachHoiThoaiCskh(bvid),
      builder: (context, snapshot) {
        List<HoiThoaiCskhModelC1> danhSachAll;

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          danhSachAll = snapshot.data!.map((m) => HoiThoaiCskhModelC1.fromMap(m, m['id'])).toList();
        } else {
          danhSachAll = DuLieuCskhKhoaC1.danhSachHoiThoai;
        }

        final danhSachHienThi = _locDanhSach(danhSachAll);

        return Column(
          children: [
            _buildHeader(isDark),
            _buildThanhTimKiem(isDark),
            _buildTabFilter(isDark),
            const SizedBox(height: 10),
            Expanded(
              child: danhSachHienThi.isEmpty
                  ? Center(
                      child: Text(
                        'Không có tin nhắn phù hợp',
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: danhSachHienThi.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = danhSachHienThi[index];
                        return _buildCardChat(item, isDark);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // Header CSKH Online
  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hỗ trợ bệnh nhân',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bệnh viện Đa khoa • Bộ phận CSKH',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFE8F8EE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF34C759).withValues(alpha: isDark ? 0.6 : 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34C759),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Đang online',
                  style: TextStyle(
                    color: Color(0xFF166534),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Ô tìm kiếm
  Widget _buildThanhTimKiem(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA),
          ),
        ),
        child: TextField(
          controller: _timKiemController,
          onChanged: (val) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
            ),
            hintText: 'Tìm bệnh nhân, khoa khám...',
            hintStyle: TextStyle(
              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFFAEAEB2),
              fontSize: 13.5,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
          ),
        ),
      ),
    );
  }

  // 3 Tabs lọc: Tất cả / Chưa đọc / Đang chờ
  Widget _buildTabFilter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildItemFilter('tat_ca', 'Tất cả', isDark),
          const SizedBox(width: 8),
          _buildItemFilter('chua_doc', 'Chưa đọc', isDark),
          const SizedBox(width: 8),
          _buildItemFilter('dang_cho', 'Đang chờ', isDark),
        ],
      ),
    );
  }

  Widget _buildItemFilter(String tabKey, String label, bool isDark) {
    final isSelected = _tabDangChon == tabKey;

    return InkWell(
      onTap: () {
        AppDesignSystemC1.hapticLight();
        setState(() {
          _tabDangChon = tabKey;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0284C7)
              : (isDark ? AppDesignSystemC1.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0284C7)
                : (isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF3A3A3C)),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Card hội thoại bệnh nhân
  Widget _buildCardChat(HoiThoaiCskhModelC1 item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _moManHinhChat(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.vietTat,
                    style: const TextStyle(
                      color: Color(0xFF0284C7),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.hoTen,
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            item.thoiGian,
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.tinNhanCuoi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF3A3A3C),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.tuoi} tuổi • ${item.khoa}',
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.tinChuaDoc > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.tinChuaDoc}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
