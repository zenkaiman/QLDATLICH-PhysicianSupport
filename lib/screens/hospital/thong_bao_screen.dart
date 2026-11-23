import 'package:flutter/material.dart';

import '../../models/thong_bao_model.dart';
import '../../services/thong_bao_service.dart';
import 'thong_bao_ui.dart';

/// Màn hình danh sách Thông báo hệ thống bệnh viện (đặc biệt là kích hoạt nhân sự)
class ThongBaoScreen extends StatefulWidget {
  final String benhVienId;
  final VoidCallback? onChuyenTabPhanCong;

  const ThongBaoScreen({
    super.key,
    required this.benhVienId,
    this.onChuyenTabPhanCong,
  });

  /// Phương thức tiện ích mở ThongBaoScreen dưới dạng Modal Bottom Sheet hoặc Full Screen
  static Future<void> showModal(
    BuildContext context, {
    required String benhVienId,
    VoidCallback? onChuyenTabPhanCong,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ThongBaoScreen(
            benhVienId: benhVienId,
            onChuyenTabPhanCong: onChuyenTabPhanCong,
          ),
        ),
      ),
    );
  }

  @override
  State<ThongBaoScreen> createState() => _ThongBaoScreenState();
}

class _ThongBaoScreenState extends State<ThongBaoScreen> {
  int _selectedFilterTab = 0; // 0: Tất cả, 1: Chưa đọc

  void _moChiTiet(ThongBaoModel tb) {
    // Đánh dấu đã đọc khi xem chi tiết
    if (!tb.daDoc) {
      ThongBaoService.instance.danhDauDaDoc(widget.benhVienId, tb.id);
    }

    showDialog(
      context: context,
      builder: (ctx) => DialogChiTietThongBao(
        thongBao: tb,
        onDenPhanCong: () {
          // Đóng màn hình thông báo và chuyển sang tab phân công trực
          if (widget.onChuyenTabPhanCong != null) {
            Navigator.of(context).maybePop();
            widget.onChuyenTabPhanCong!();
          } else {
            Navigator.of(context).maybePop();
          }
        },
      ),
    );
  }

  void _danhDauTatCaDaDoc(List<ThongBaoModel> danhSach) {
    final ids = danhSach.where((e) => !e.daDoc).map((e) => e.id).toList();
    if (ids.isNotEmpty) {
      ThongBaoService.instance.danhDauTatCaDaDoc(widget.benhVienId, ids);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đánh dấu tất cả thông báo là đã đọc.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Thông Báo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: Color(0xFF334155)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: StreamBuilder<List<ThongBaoModel>>(
        stream: ThongBaoService.instance.streamThongBao(widget.benhVienId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            );
          }

          final allList = snapshot.data ?? [];
          final unreadList = allList.where((tb) => !tb.daDoc).toList();
          final displayList =
              _selectedFilterTab == 1 ? unreadList : allList;

          return Column(
            children: [
              // Thanh bộ lọc Tất cả / Chưa đọc + Đánh dấu đã đọc tất cả
              ThongBaoFilterBar(
                selectedTab: _selectedFilterTab,
                tongSo: allList.length,
                soChuaDoc: unreadList.length,
                onTabChanged: (val) {
                  setState(() => _selectedFilterTab = val);
                },
                onDanhDauTatCa: () => _danhDauTatCaDaDoc(allList),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Danh sách thông báo
              Expanded(
                child: displayList.isEmpty
                    ? ThongBaoEmptyState(
                        filterChuaDoc: _selectedFilterTab == 1,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          final item = displayList[index];
                          return ThongBaoItemWidget(
                            thongBao: item,
                            onTap: () => _moChiTiet(item),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
