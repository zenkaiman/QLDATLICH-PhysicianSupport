import 'package:flutter/material.dart';

import '../../mock/mock_c1/dulieu_mau_cskh_c1.dart';
import '../../models/letan_c1/cskh_model_c1.dart';
import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'cskh_duyetdon_khoa_screen_c1.dart';

/// MÀN HÌNH 4: CHI TIẾT ĐOẠN CHAT HỖ TRỢ BỆNH NHÂN (CSKH)
/// Kết nối thời gian thực Firestore /HoiThoaiCskh/{benhVienId}/danh_sach/{hoiThoaiId}/tin_nhan
class CskhChatChitietScreenC1 extends StatefulWidget {
  final HoiThoaiCskhModelC1 hoiThoai;

  const CskhChatChitietScreenC1({
    super.key,
    required this.hoiThoai,
  });

  @override
  State<CskhChatChitietScreenC1> createState() => _CskhChatChitietScreenC1State();
}

class _CskhChatChitietScreenC1State extends State<CskhChatChitietScreenC1> {
  final TextEditingController _noiDungController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _guiTinNhan([String? noiDungGui]) async {
    final text = noiDungGui ?? _noiDungController.text.trim();
    if (text.isEmpty) return;

    AppDesignSystemC1.hapticLight();
    if (noiDungGui == null) {
      _noiDungController.clear();
    }

    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;
    await FirebaseServiceC1.guiTinNhanCskh(
      benhVienId: bvid,
      hoiThoaiId: widget.hoiThoai.id,
      noiDung: text,
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;

    return ValueListenableBuilder<bool>(
      valueListenable: AppDesignSystemC1.isDarkMode,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF5F5F7),
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark),
                _buildCardThongTinBenhNhan(isDark),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirebaseServiceC1.streamTinNhanCskh(
                      benhVienId: bvid,
                      hoiThoaiId: widget.hoiThoai.id,
                    ),
                    builder: (context, snapshot) {
                      List<TinNhanCskhModelC1> danhSachTin;

                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        danhSachTin = snapshot.data!.map((m) {
                          return TinNhanCskhModelC1(
                            id: m['id'] ?? '',
                            hoiThoaiId: widget.hoiThoai.id,
                            noiDung: (m['noi_dung'] ?? '').toString(),
                            thoiGian: (m['gio_hien_thi'] ?? 'Vừa xong').toString(),
                            laCskhGui: m['la_cskh_gui'] == true,
                          );
                        }).toList();
                      } else {
                        danhSachTin = DuLieuCskhKhoaC1.layTinNhanTheoHoiThoai(widget.hoiThoai.id);
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: danhSachTin.length,
                        itemBuilder: (context, index) {
                          final item = danhSachTin[index];
                          return _buildBongBongTinNhan(item, isDark);
                        },
                      );
                    },
                  ),
                ),
                _buildThanhGoiYNhanh(isDark),
                _buildThanhNhapTinNhan(isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  // Header chi tiết chat
  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CskhDuyetdonKhoaScreenC1()),
                );
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.hoiThoai.vietTat,
              style: const TextStyle(
                color: Color(0xFF0284C7),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.hoiThoai.hoTen,
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${widget.hoiThoai.tuoi} tuổi • ${widget.hoiThoai.khoa}',
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'BHYT',
              style: TextStyle(
                color: Color(0xFF0284C7),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Thẻ thông tin hồ sơ bệnh nhân
  Widget _buildCardThongTinBenhNhan(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF082F49).withValues(alpha: 0.4) : const Color(0xFFE8F4FD),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFBAE6FD),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.badge_outlined, size: 15, color: Color(0xFF0284C7)),
              SizedBox(width: 6),
              Text(
                'Thông tin bệnh nhân',
                style: TextStyle(
                  color: Color(0xFF0284C7),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'BHYT: ${widget.hoiThoai.maBhyt} • Lịch khám gần nhất: 18/09',
            style: TextStyle(
              color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF334155),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  // Bong bóng tin nhắn Chat
  Widget _buildBongBongTinNhan(TinNhanCskhModelC1 item, bool isDark) {
    final isMe = item.laCskhGui;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isMe
                ? const Color(0xFF0284C7)
                : (isDark ? AppDesignSystemC1.darkSurface : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            border: isMe ? null : Border.all(color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.noiDung,
                style: TextStyle(
                  color: isMe ? Colors.white : (isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E)),
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.thoiGian,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : const Color(0xFF8E8E93),
                      fontSize: 10.5,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_rounded, size: 12, color: Colors.white70),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Thanh gợi ý trả lời nhanh
  void _moModalDanhSachMauCau(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final danhMuc = DuLieuCskhKhoaC1.danhMucTraLoiNhanh;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mẫu câu trả lời nhanh CSKH',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: danhMuc.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final item = danhMuc[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFFE0F2FE),
                        child: Icon(Icons.quickreply_rounded, size: 16, color: Color(0xFF0284C7)),
                      ),
                      title: Text(
                        item['tieuDe'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        item['noiDung'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        final noiDung = item['noiDung'] ?? '';
                        _noiDungController.text = noiDung;
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThanhGoiYNhanh(bool isDark) {
    final danhMuc = DuLieuCskhKhoaC1.danhMucTraLoiNhanh;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mẫu câu phản hồi nhanh:',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: () => _moModalDanhSachMauCau(isDark),
                child: const Row(
                  children: [
                    Icon(Icons.format_list_bulleted_rounded, size: 13, color: Color(0xFF0284C7)),
                    SizedBox(width: 4),
                    Text(
                      'Tất cả mẫu',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: danhMuc.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = danhMuc[index];
                return InkWell(
                  onTap: () {
                    final noiDung = item['noiDung'] ?? '';
                    _noiDungController.text = noiDung;
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0C2444) : const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item['tieuDe'] ?? '',
                      style: const TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Thanh nhập tin nhắn
  Widget _buildThanhNhapTinNhan(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _noiDungController,
                decoration: InputDecoration(
                  hintText: 'Nhập phản hồi cho bệnh nhân...',
                  hintStyle: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFFAEAEB2),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _guiTinNhan(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _guiTinNhan(),
            icon: const Icon(Icons.send_rounded),
            color: const Color(0xFF0284C7),
          ),
        ],
      ),
    );
  }
}
