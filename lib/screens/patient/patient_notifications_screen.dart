import 'package:flutter/material.dart';

import '../../config/app_routes.dart';
import '../../services/patient_notification_service.dart';

/// Màn hình THÔNG BÁO của phần Bệnh nhân.
///
/// Đọc realtime từ `ThongBaoHeThong` (đúng collection mà Lễ tân/CSKH đang dùng),
/// nhưng chỉ lấy các thông báo hướng tới bệnh nhân đang đăng nhập.
/// Nhờ vậy khi Lễ tân/CSKH duyệt hoặc từ chối lịch hẹn, bệnh nhân thấy ngay
/// thông báo mà không cần tải lại ứng dụng.
class PatientNotificationsScreen extends StatefulWidget {
  const PatientNotificationsScreen({super.key, this.tieuDe = 'Thông báo'});

  final String tieuDe;

  @override
  State<PatientNotificationsScreen> createState() => _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState extends State<PatientNotificationsScreen> {
  static const Color _primary = Color(0xFF0284C7);

  bool _chiHienChuaDoc = false;
  String? _idDangXuLy;

  Future<void> _xuLyKhiBam(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty || _idDangXuLy == id) return;

    setState(() => _idDangXuLy = id);
    if (item['da_doc'] != true) {
      await PatientNotificationService.danhDauDaDoc(id);
    }
    if (!mounted) return;
    setState(() => _idDangXuLy = null);

    final loai = (item['loai'] ?? '').toString();
    if (loai == 'lich_hen' || loai == 'hang_cho') {
      await _hienThiChiTietLichHen(item);
    }
  }

  Future<void> _hienThiChiTietLichHen(Map<String, dynamic> item) async {
    final tieuDe = (item['tieu_de'] ?? 'Thông báo lịch hẹn').toString();
    final noiDung = (item['noi_dung'] ?? '').toString();
    final tenKhoa = (item['ten_khoa'] ?? '').toString();
    final soThuTu = (item['so_thu_tu'] ?? '').toString();
    final lyDo = (item['ly_do_tu_choi'] ?? '').toString();
    final trangThai = (item['trang_thai_lich_hen'] ?? '').toString();
    final phongKham = (item['phong_kham'] ?? '').toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _IconThongBao(
                      loai: (item['loai'] ?? 'lich_hen').toString(),
                      trangThai: trangThai,
                      kichThuoc: 42,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tieuDe,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  noiDung,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 18),
                if (tenKhoa.isNotEmpty) _dongThongTin('Chuyên khoa', tenKhoa),
                if (phongKham.isNotEmpty) _dongThongTin('Phòng khám', phongKham),
                if (soThuTu.isNotEmpty && soThuTu != '0') _dongThongTin('Số thứ tự', soThuTu),
                if (lyDo.isNotEmpty) _dongThongTin('Lý do từ chối', lyDo),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.pushNamed(context, AppRoutes.myAppointments);
                    },
                    icon: const Icon(Icons.event_available_rounded, size: 20),
                    label: const Text(
                      'Xem lịch hẹn của tôi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dongThongTin(String nhan, String giaTri) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              nhan,
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              giaTri,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _danhDauTatCaDaDoc(List<Map<String, dynamic>> danhSach) async {
    await PatientNotificationService.danhDauTatCaDaDoc(danhSach);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tieuDe),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: PatientNotificationService.streamThongBaoCuaToi(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _trangThaiRong(
              icon: Icons.cloud_off_rounded,
              tieuDe: 'Không tải được thông báo',
              moTa: 'Vui lòng kiểm tra kết nối mạng rồi thử lại.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tatCa = snapshot.data ?? const <Map<String, dynamic>>[];

          final soChuaDoc = tatCa.where((e) => e['da_doc'] != true).length;
          final danhSach = _chiHienChuaDoc
              ? tatCa.where((e) => e['da_doc'] != true).toList()
              : tatCa;

          return Column(
            children: [
              _boLoc(
                soChuaDoc: soChuaDoc,
                tongSo: tatCa.length,
                danhSach: tatCa,
              ),
              Expanded(
                child: danhSach.isEmpty
                    ? _trangThaiRong(
                        icon: Icons.notifications_off_outlined,
                        tieuDe: _chiHienChuaDoc ? 'Không có thông báo chưa đọc' : 'Chưa có thông báo nào',
                        moTa: _chiHienChuaDoc
                            ? 'Bạn đã đọc hết thông báo rồi.'
                            : 'Khi lịch hẹn được xác nhận hoặc có cập nhật mới, thông báo sẽ xuất hiện tại đây.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await Future<void>.delayed(const Duration(milliseconds: 400));
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: danhSach.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _theThongBao(danhSach[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _boLoc({
    required int soChuaDoc,
    required int tongSo,
    required List<Map<String, dynamic>> danhSach,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          if (soChuaDoc > 0)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bạn có $soChuaDoc thông báo chưa đọc',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _danhDauTatCaDaDoc(danhSach),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Đọc tất cả',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _nutLoc(
                    nhan: 'Tất cả ($tongSo)',
                    duocChon: !_chiHienChuaDoc,
                    mauChu: _primary,
                    onTap: () => setState(() => _chiHienChuaDoc = false),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _nutLoc(
                    nhan: 'Chưa đọc ($soChuaDoc)',
                    duocChon: _chiHienChuaDoc,
                    mauChu: const Color(0xFFEF4444),
                    onTap: () => setState(() => _chiHienChuaDoc = true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutLoc({
    required String nhan,
    required bool duocChon,
    required Color mauChu,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: duocChon ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: duocChon
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          nhan,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: duocChon ? mauChu : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _theThongBao(Map<String, dynamic> item) {
    final tieuDe = (item['tieu_de'] ?? item['tieuDe'] ?? 'Thông báo').toString();
    final noiDung = (item['noi_dung'] ?? item['noiDung'] ?? '').toString();
    final thoiGian = PatientNotificationService.hienThiThoiGian(item);
    final loai = (item['loai'] ?? 'he_thong').toString();
    final daDoc = item['da_doc'] == true;
    final trangThaiLichHen = (item['trang_thai_lich_hen'] ?? '').toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _xuLyKhiBam(item),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: daDoc ? const Color(0xFFE2E8F0) : const Color(0xFFBAE6FD),
              width: daDoc ? 1 : 1.4,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconThongBao(loai: loai, trangThai: trangThaiLichHen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            tieuDe,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: daDoc ? FontWeight.w600 : FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (!daDoc)
                          Container(
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      noiDung,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          thoiGian,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                        ),
                        if (loai == 'lich_hen' || loai == 'hang_cho') ...[
                          const Spacer(),
                          Text(
                            'Xem chi tiết',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _primary.withValues(alpha: 0.9),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: _primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trangThaiRong({
    required IconData icon,
    required String tieuDe,
    required String moTa,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: _primary),
            ),
            const SizedBox(height: 16),
            Text(
              tieuDe,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              moTa,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon tròn đại diện cho từng loại thông báo / từng trạng thái lịch hẹn
class _IconThongBao extends StatelessWidget {
  const _IconThongBao({
    required this.loai,
    this.trangThai = '',
    this.kichThuoc = 40,
  });

  final String loai;

  /// Trạng thái lịch hẹn: da_duyet | tu_choi | da_kham | vang_mat | xin_doi | dang_cho
  final String trangThai;
  final double kichThuoc;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color mauNen;
    Color mauIcon;

    switch (trangThai) {
      case 'da_duyet':
        icon = Icons.event_available_rounded;
        mauNen = const Color(0xFFDCFCE7);
        mauIcon = const Color(0xFF16A34A);
        break;
      case 'tu_choi':
        icon = Icons.event_busy_rounded;
        mauNen = const Color(0xFFFEE2E2);
        mauIcon = const Color(0xFFEF4444);
        break;
      case 'da_kham':
        icon = Icons.task_alt_rounded;
        mauNen = const Color(0xFFDCFCE7);
        mauIcon = const Color(0xFF16A34A);
        break;
      case 'vang_mat':
        icon = Icons.person_off_rounded;
        mauNen = const Color(0xFFFEE2E2);
        mauIcon = const Color(0xFFEF4444);
        break;
      case 'xin_doi':
        icon = Icons.pause_circle_rounded;
        mauNen = const Color(0xFFFFF7ED);
        mauIcon = const Color(0xFFF59E0B);
        break;
      case 'dang_cho':
        icon = Icons.confirmation_number_rounded;
        mauNen = const Color(0xFFE0F2FE);
        mauIcon = const Color(0xFF0284C7);
        break;
      default:
        if (loai == 'khan_cap') {
          icon = Icons.warning_amber_rounded;
          mauNen = const Color(0xFFFFF7ED);
          mauIcon = const Color(0xFFF59E0B);
        } else if (loai == 'hang_cho') {
          icon = Icons.confirmation_number_rounded;
          mauNen = const Color(0xFFE0F2FE);
          mauIcon = const Color(0xFF0284C7);
        } else if (loai == 'lich_hen') {
          icon = Icons.event_available_rounded;
          mauNen = const Color(0xFFE0F2FE);
          mauIcon = const Color(0xFF0284C7);
        } else {
          icon = Icons.notifications_active_rounded;
          mauNen = const Color(0xFFE0F2FE);
          mauIcon = const Color(0xFF0284C7);
        }
    }

    return Container(
      width: kichThuoc,
      height: kichThuoc,
      decoration: BoxDecoration(color: mauNen, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: kichThuoc * 0.5, color: mauIcon),
    );
  }
}
