import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/shared_widgets.dart';
import 'approve_confirm_screen.dart';
import 'reject_screen.dart';
import 'document_viewer_screen.dart';

class PendingHospitalDetailScreen extends StatelessWidget {
  final Map<String, String> hospital;

  const PendingHospitalDetailScreen({super.key, required this.hospital});

  Future<void> _handleOpenDocument(BuildContext context, String fileUrl, String docName) async {
    final cleanUrl = fileUrl.trim();
    if (cleanUrl.isEmpty || cleanUrl == 'Hồ sơ đăng ký hệ thống' || cleanUrl == 'giay_phep_byt.pdf') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: kPrimary, size: 22),
              SizedBox(width: 8),
              Text('Thông tin hồ sơ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          content: Text(
            'Hồ sơ đăng ký của cơ sở: "$docName".\nHiện cơ sở y tế này chưa tải lên liên kết file công khai trên hệ thống.',
            style: const TextStyle(fontSize: 13.5, color: kSlate700, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }

    // Nếu là URL đầy đủ → mở trực tiếp trong app bằng DocumentViewerScreen (có nút quay lại)
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(
            title: docName.isNotEmpty ? docName : 'Tài liệu đăng ký cơ sở',
            url: cleanUrl,
          ),
        ),
      );
      return;
    }

    // Không mở được → hiện thông báo
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.description_outlined, color: kPrimary, size: 22),
              SizedBox(width: 8),
              Text('Tài liệu hồ sơ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Không thể mở liên kết tài liệu.\nThông tin file:', style: TextStyle(fontSize: 12, color: kSlate400)),
              const SizedBox(height: 6),
              SelectableText(
                cleanUrl,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kSlate800),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = hospital['name'] ?? 'Bệnh viện mới';
    final type = hospital['type'] ?? 'Bệnh viện';
    final tag = hospital['tag'] ?? 'BV';
    final code = hospital['code'] ?? hospital['docId'] ?? '';
    final location = hospital['location'] ?? 'Chưa cập nhật địa chỉ';
    final docFile = hospital['docs'] ?? 'Hồ sơ đăng ký hệ thống';
    final fileUrl = hospital['file_url'] ?? '';
    final time = hospital['time'] ?? 'Vừa gửi';
    final email = hospital['email'] ?? '';
    final phone = hospital['phone'] ?? '';
    final soGiayPhep = hospital['so_giay_phep'] ?? '';
    final maSoThue = hospital['ma_so_thue'] ?? '';
    final moTa = hospital['mo_ta'] ?? '';
    final bhyt = hospital['bhyt'] ?? '';
    final nguoiDaiDien = hospital['nguoi_dai_dien'] ?? '';
    final fromCollection = hospital['fromCollection'] ?? 'Hồ sơ đăng ký';

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: Colors.white,
              child: Row(
                children: [
                  const BackCircle(),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi Tiết Đơn Đăng Ký',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: kSlate900,
                          ),
                        ),
                        Text(
                          'Xem xét toàn bộ thông tin cơ sở y tế gửi để xét duyệt',
                          style: TextStyle(fontSize: 12, color: kSlate500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kOrangeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_top_rounded, size: 12, color: kAmber),
                        SizedBox(width: 4),
                        Text(
                          'Chờ duyệt',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: kAmber,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Card tóm tắt đầu hồ sơ
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kBorder),
                      boxShadow: kCardShadow,
                    ),
                    child: Row(
                      children: [
                        AvatarBox(
                          text: tag,
                          bg: kOrangeBg,
                          fg: kAmber,
                          size: 56,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: kSlate900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: kPrimaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      type,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: kPrimary,
                                      ),
                                    ),
                                  ),
                                  if (bhyt.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: kGreenLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        bhyt,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: kGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Nhóm 1: Thông tin cơ sở & liên hệ
                  _buildSectionCard(
                    title: 'Thông Tin Cơ Sở & Liên Hệ',
                    icon: Icons.business_rounded,
                    children: [
                      _buildDetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Địa chỉ cơ sở',
                        value: location,
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildDetailRow(
                        icon: Icons.email_outlined,
                        label: 'Email liên hệ',
                        value: email.isNotEmpty ? email : 'Chưa cập nhật email',
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildDetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Số điện thoại',
                        value: phone.isNotEmpty ? phone : 'Chưa cập nhật số điện thoại',
                      ),
                      if (nguoiDaiDien.isNotEmpty) ...[
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildDetailRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Người đại diện / Phụ trách',
                          value: nguoiDaiDien,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Nhóm 2: Hồ sơ pháp lý & Mã đăng ký
                  _buildSectionCard(
                    title: 'Hồ Sơ Pháp Lý & Mã Định Danh',
                    icon: Icons.verified_user_outlined,
                    children: [
                      _buildDetailRow(
                        icon: Icons.tag_rounded,
                        label: 'Mã hồ sơ / Mã BV',
                        value: code.isNotEmpty ? code : 'Chưa có',
                        isHighlight: true,
                      ),
                      if (soGiayPhep.isNotEmpty) ...[
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildDetailRow(
                          icon: Icons.badge_outlined,
                          label: 'Số giấy phép hoạt động',
                          value: soGiayPhep,
                        ),
                      ],
                      if (maSoThue.isNotEmpty) ...[
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildDetailRow(
                          icon: Icons.receipt_long_outlined,
                          label: 'Mã số thuế doanh nghiệp',
                          value: maSoThue,
                        ),
                      ],
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildDetailRow(
                        icon: Icons.file_present_rounded,
                        label: 'Tài liệu / Giấy tờ đính kèm',
                        value: docFile,
                        isLink: true,
                        onTapLink: () => _handleOpenDocument(context, fileUrl.isNotEmpty ? fileUrl : docFile, docFile),
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildDetailRow(
                        icon: Icons.source_outlined,
                        label: 'Nguồn gửi đơn',
                        value: fromCollection == 'YeuCauHopTac'
                            ? 'Đơn gửi từ màn hình Hợp Tác Y Tế'
                            : 'Đăng ký tài khoản Bệnh Viện mới',
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildDetailRow(
                        icon: Icons.access_time_rounded,
                        label: 'Thời gian gửi đơn',
                        value: time,
                      ),
                    ],
                  ),

                  if (moTa.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // Nhóm 3: Giới thiệu & Mô tả
                    _buildSectionCard(
                      title: 'Giới Thiệu Cơ Sở Y Tế',
                      icon: Icons.notes_rounded,
                      children: [
                        Text(
                          moTa,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: kSlate700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Thanh thao tác Duyệt & Từ chối ở dưới đáy màn hình
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                        label: const Text(
                          'Xác nhận Duyệt',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ApproveConfirmScreen(hospital: hospital),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined, size: 20),
                        label: const Text(
                          'Từ chối',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kRed,
                          side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                          backgroundColor: const Color(0xFFFFF5F5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RejectScreen(hospital: hospital),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: kPrimary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: kSlate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
    bool isLink = false,
    VoidCallback? onTapLink,
  }) {
    final contentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: kSlate400, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                  color: isHighlight
                      ? kPrimary
                      : (isLink ? const Color(0xFF0284C7) : kSlate800),
                  decoration: isLink ? TextDecoration.underline : null,
                  decorationColor: const Color(0xFF0284C7),
                ),
              ),
            ),
            if (isLink) ...[
              const SizedBox(width: 4),
              const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF0284C7)),
            ],
          ],
        ),
      ],
    );

    return InkWell(
      onTap: isLink ? onTapLink : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: isLink ? const Color(0xFF0284C7) : kSlate400),
            const SizedBox(width: 10),
            Expanded(child: contentWidget),
          ],
        ),
      ),
    );
  }
}
