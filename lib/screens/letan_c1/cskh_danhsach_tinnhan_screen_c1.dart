import 'package:flutter/material.dart';

import '../../models/conversation_model.dart';
import '../../models/letan_c1/cskh_model_c1.dart';
import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/chat_service.dart';
import 'cskh_chat_chitiet_screen_c1.dart';

/// MÀN HÌNH 3: DANH SÁCH TIN NHẮN HỖ TRỢ BỆNH NHÂN (CSKH)
/// Áp dụng Phương án 2: Dùng trực tiếp ChatService và ConversationModel chuẩn từ phía Bệnh Nhân
class CskhDanhsachTinnhanScreenC1 extends StatefulWidget {
  const CskhDanhsachTinnhanScreenC1({super.key});

  @override
  State<CskhDanhsachTinnhanScreenC1> createState() => _CskhDanhsachTinnhanScreenC1State();
}

class _CskhDanhsachTinnhanScreenC1State extends State<CskhDanhsachTinnhanScreenC1> {
  final ChatService _chatService = ChatService();
  String _tabDangChon = 'tat_ca'; // 'tat_ca', 'chua_doc', 'dang_cho'
  final TextEditingController _timKiemController = TextEditingController();

  List<ConversationModel> _locDanhSach(List<ConversationModel> nguon) {
    final tuKhoa = _timKiemController.text.trim().toLowerCase();
    return nguon.where((item) {
      if (tuKhoa.isNotEmpty) {
        final khopTuKhoa = item.tenBenhNhan.toLowerCase().contains(tuKhoa) ||
            item.tenBenhVien.toLowerCase().contains(tuKhoa) ||
            item.lastMessage.toLowerCase().contains(tuKhoa);
        if (!khopTuKhoa) return false;
      }

      if (_tabDangChon == 'chua_doc') {
        return item.unreadCountSupport > 0 || item.isOpen;
      } else if (_tabDangChon == 'dang_cho') {
        return item.isOpen || item.unreadCountSupport > 0;
      }
      return true;
    }).toList();
  }

  void _moManHinhChat(ConversationModel item) {
    AppDesignSystemC1.hapticLight();
    // Tạo đối tượng tương thích với màn hình chat chi tiết CSKH
    final hoiThoai = HoiThoaiCskhModelC1(
      id: item.id,
      benhNhanId: item.benhNhanId,
      hoTen: item.tenBenhNhan.isNotEmpty ? item.tenBenhNhan : 'Bệnh nhân',
      vietTat: item.initials,
      tinNhanCuoi: item.lastMessage,
      thoiGian: item.lastMessageAt != null
          ? '${item.lastMessageAt!.hour.toString().padLeft(2, '0')}:${item.lastMessageAt!.minute.toString().padLeft(2, '0')}'
          : 'Vừa xong',
      khoa: item.tenBenhVien.isNotEmpty ? item.tenBenhVien : 'CSKH Bệnh viện',
      tuoi: 28,
      maBhyt: '',
      tinChuaDoc: item.unreadCountSupport,
      dangChoPhanHoi: item.isOpen,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CskhChatChitietScreenC1(hoiThoai: hoiThoai),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId.trim();

    return StreamBuilder<List<ConversationModel>>(
      stream: _chatService.streamHospitalConversations(bvid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('❌ [CSKH Screen] Lỗi stream: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    'Lỗi tải tin nhắn từ máy chủ',
                    style: TextStyle(
                      color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1E293B),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF0284C7),
            ),
          );
        }

        final danhSachAll = snapshot.data ?? [];
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 40,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _timKiemController.text.trim().isNotEmpty
                                  ? 'Không tìm thấy cuộc trò chuyện phù hợp'
                                  : 'Chưa có tin nhắn hỗ trợ từ bệnh nhân',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1E293B),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _timKiemController.text.trim().isNotEmpty
                                  ? 'Vui lòng kiểm tra lại từ khóa tìm kiếm'
                                  : 'Khi bệnh nhân liên hệ hỗ trợ, các cuộc hội thoại sẽ hiển thị tại đây',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DuLieuProfileMauC1.thongTinHienTai.tenBenhVien.isNotEmpty
                      ? DuLieuProfileMauC1.thongTinHienTai.tenBenhVien
                      : (DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty
                          ? 'Bệnh viện ${DuLieuProfileMauC1.thongTinHienTai.benhVienId}'
                          : 'Bệnh viện'),
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Tin Nhắn Hỗ Trợ',
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
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
  Widget _buildCardChat(ConversationModel item, bool isDark) {
    final hoTen = item.tenBenhNhan.isNotEmpty ? item.tenBenhNhan : 'Bệnh nhân';
    final tinCuoi = item.lastMessage.isNotEmpty ? item.lastMessage : '...';
    final thoiGianStr = item.lastMessageAt != null
        ? '${item.lastMessageAt!.hour.toString().padLeft(2, '0')}:${item.lastMessageAt!.minute.toString().padLeft(2, '0')}'
        : 'Vừa xong';
    final tenBvHoacKhoa = item.tenBenhVien.isNotEmpty ? item.tenBenhVien : 'CSKH Bệnh viện';
    final unread = item.unreadCountSupport;

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
                    item.initials,
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
                          Expanded(
                            child: Text(
                              hoTen,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            thoiGianStr,
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tinCuoi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF3A3A3C),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tenBvHoacKhoa,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0) ...[
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
                      '$unread',
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
