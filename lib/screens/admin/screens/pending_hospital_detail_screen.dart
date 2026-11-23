import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../widgets/shared_widgets.dart';
import 'approve_confirm_screen.dart';
import 'reject_screen.dart';
import 'document_viewer_screen.dart';

class PendingHospitalDetailScreen extends StatelessWidget {
  final Map<String, String> hospital;

  const PendingHospitalDetailScreen({super.key, required this.hospital});

  /// Giải mã dữ liệu ảnh Base64 an toàn
  Uint8List? _decodeBase64(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      String clean = trimmed;
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      clean = clean.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(clean);
    } catch (e) {
      debugPrint('Lỗi giải mã Base64: $e');
      return null;
    }
  }

  /// Mở ảnh toàn màn hình với InteractiveViewer để Admin soi rõ số CCCD, dấu mộc, tên
  void _showFullScreenImage(
    BuildContext context, {
    required String title,
    Uint8List? bytes,
    String? imageUrl,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.badge_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Kéo hoặc dùng 2 ngón tay để phóng to/thu nhỏ kiểm tra',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF334155)),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                  minHeight: 240,
                ),
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 5.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: bytes != null
                          ? Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _buildImageError(),
                            )
                          : (imageUrl != null && imageUrl.isNotEmpty)
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (_, child, prog) {
                                    if (prog == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(color: Colors.white),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => _buildImageError(),
                                )
                              : _buildImageError(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Độ phân giải gốc của tệp hồ sơ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
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

  Widget _buildImageError() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded, color: Colors.white54, size: 40),
          SizedBox(height: 8),
          Text(
            'Không thể hiển thị định dạng ảnh này',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Mở vị trí trên Google Maps
  Future<void> _openMap(BuildContext context, String lat, String lng, String address) async {
    Uri uri;
    if (lat.isNotEmpty && lng.isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else if (address.isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có thông tin tọa độ GPS hoặc địa chỉ để mở bản đồ.')),
      );
      return;
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở ứng dụng bản đồ Google Maps.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi mở bản đồ: $e')),
        );
      }
    }
  }

  /// Mở tài liệu / giấy phép
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
              const Text('Thông tin file đính kèm:', style: TextStyle(fontSize: 12, color: kSlate400)),
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
    // 1. Tên bệnh viện & Mã
    final name = hospital['name'] ?? 'Bệnh viện mới';
    final type = hospital['type'] ?? 'Bệnh viện';
    final tag = hospital['tag'] ?? 'BV';
    final code = hospital['code'] ?? hospital['docId'] ?? '';

    // 2. Định danh y tế & Thuế
    final maCoSoByt = hospital['ma_co_so_byt'] ?? '';
    final maSoThue = hospital['ma_so_thue'] ?? '';
    final soGiayPhep = hospital['so_giay_phep'] ?? '';
    final coSo = hospital['co_so'] ?? '';
    final loaiHinh = hospital['loai_hinh'] ?? (coSo.isNotEmpty ? coSo : type);
    final bhyt = hospital['bhyt'] ?? '';

    // 3. Địa chỉ & Bản đồ GPS
    final location = hospital['location'] ?? 'Chưa cập nhật địa chỉ';
    final diaChiMap = hospital['dia_chi_map'] ?? '';
    final viDo = hospital['vi_do'] ?? '';
    final kinhDo = hospital['kinh_do'] ?? '';

    // 4. Ảnh CCCD người đại diện
    final cccdTruocBase64 = hospital['cccd_mat_truoc_base64'] ?? '';
    final cccdTruocUrl = hospital['cccd_mat_truoc_url'] ?? '';
    final cccdSauBase64 = hospital['cccd_mat_sau_base64'] ?? '';
    final cccdSauUrl = hospital['cccd_mat_sau_url'] ?? '';

    final cccdTruocBytes = _decodeBase64(cccdTruocBase64);
    final cccdSauBytes = _decodeBase64(cccdSauBase64);

    final bool coCccdTruoc = cccdTruocBytes != null || cccdTruocUrl.isNotEmpty;
    final bool coCccdSau = cccdSauBytes != null || cccdSauUrl.isNotEmpty;

    // 5. Giấy phép hoạt động y tế
    final docFile = hospital['file_giay_phep']?.isNotEmpty == true
        ? hospital['file_giay_phep']!
        : (hospital['docs'] ?? 'giay_phep_byt.pdf');
    final fileUrl = hospital['file_giay_phep_url']?.isNotEmpty == true
        ? hospital['file_giay_phep_url']!
        : (hospital['file_url'] ?? '');
    final dungLuongFile = hospital['dung_luong_file'] ?? '';
    final loaiFile = hospital['loai_file'] ?? '';

    // 6. Liên hệ & Người đại diện
    final email = hospital['email'] ?? '';
    final phone = hospital['phone'] ?? '';
    final nguoiDaiDien = hospital['nguoi_dai_dien'] ?? '';
    final moTa = hospital['mo_ta'] ?? '';
    final time = hospital['time'] ?? 'Mới gửi yêu cầu';

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER =================
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
                          'Xét Duyệt Hồ Sơ Hợp Tác',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: kSlate900,
                          ),
                        ),
                        Text(
                          'Đối soát toàn bộ thông tin đăng ký cơ sở y tế',
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

            // ================= DANH SÁCH CHI TIẾT =================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- Card Tóm Tắt Tên Bệnh Viện & Badges ---
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kBorder),
                      boxShadow: kCardShadow,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: kPrimaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      loaiHinh.isNotEmpty ? loaiHinh : type,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: kPrimary,
                                      ),
                                    ),
                                  ),
                                  if (bhyt.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: kGreenLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.health_and_safety_rounded, size: 12, color: kGreen),
                                          const SizedBox(width: 4),
                                          Text(
                                            bhyt,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: kGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Mã hồ sơ: $code · $time',
                                style: const TextStyle(fontSize: 11.5, color: kSlate400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- Khối 1: Thông Tin Pháp Lý & Định Danh ---
                  _buildSectionCard(
                    title: 'Thông Tin Pháp Lý & Định Danh',
                    icon: Icons.verified_user_outlined,
                    children: [
                      _buildDetailRow(
                        icon: Icons.local_hospital_outlined,
                        label: 'Tên bệnh viện / Cơ sở',
                        value: name,
                        isHighlight: true,
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailRow(
                              icon: Icons.pin_outlined,
                              label: 'Mã cơ sở (BYT)',
                              value: maCoSoByt.isNotEmpty ? maCoSoByt : 'Chưa nhập',
                              isHighlight: maCoSoByt.isNotEmpty,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailRow(
                              icon: Icons.receipt_long_outlined,
                              label: 'Mã số thuế',
                              value: maSoThue.isNotEmpty ? maSoThue : 'Chưa nhập',
                            ),
                          ),
                        ],
                      ),
                      if (soGiayPhep.isNotEmpty) ...[
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildDetailRow(
                          icon: Icons.badge_outlined,
                          label: 'Số giấy phép hoạt động',
                          value: soGiayPhep,
                        ),
                      ],
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailRow(
                              icon: Icons.category_outlined,
                              label: 'Cơ sở y tế (Loại hình)',
                              value: loaiHinh.isNotEmpty ? loaiHinh : type,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailRow(
                              icon: Icons.shield_outlined,
                              label: 'Khám chữa bệnh BHYT',
                              value: bhyt.isNotEmpty ? bhyt : 'Không áp dụng',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // --- Khối 2: Địa Chỉ & Vị Trí Bản Đồ (GPS) ---
                  _buildSectionCard(
                    title: 'Địa Chỉ Cơ Sở & Vị Trí Bản Đồ (GPS)',
                    icon: Icons.map_outlined,
                    children: [
                      _buildDetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Địa chỉ cơ sở',
                        value: location,
                      ),
                      if (diaChiMap.isNotEmpty && diaChiMap != location) ...[
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildDetailRow(
                          icon: Icons.pin_drop_outlined,
                          label: 'Địa chỉ ghim trên bản đồ',
                          value: diaChiMap,
                        ),
                      ],
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.gps_fixed_rounded, size: 16, color: kPrimary),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Tọa độ định vị GPS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: kSlate700,
                                        ),
                                      ),
                                      Text(
                                        (viDo.isNotEmpty && kinhDo.isNotEmpty)
                                            ? 'Vĩ độ: $viDo · Kinh độ: $kinhDo'
                                            : 'Chưa có tọa độ GPS chi tiết',
                                        style: const TextStyle(fontSize: 11.5, color: kSlate500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                                label: const Text(
                                  'Mở vị trí trên Google Maps',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _openMap(context, viDo, kinhDo, location),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // --- Khối 3: Ảnh CCCD Người Đại Diện ---
                  _buildSectionCard(
                    title: 'Ảnh CCCD Người Đại Diện',
                    icon: Icons.badge_outlined,
                    children: [
                      const Text(
                        'Cơ sở y tế tải lên ảnh 2 mặt CCCD của người đại diện/phụ trách để đối soát nhân thân:',
                        style: TextStyle(fontSize: 12, color: kSlate500, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCccdCard(
                              context: context,
                              label: 'Mặt trước CCCD',
                              hasImage: coCccdTruoc,
                              bytes: cccdTruocBytes,
                              imageUrl: cccdTruocUrl,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCccdCard(
                              context: context,
                              label: 'Mặt sau CCCD',
                              hasImage: coCccdSau,
                              bytes: cccdSauBytes,
                              imageUrl: cccdSauUrl,
                            ),
                          ),
                        ],
                      ),
                      if (coCccdTruoc || coCccdSau) ...[
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 14, color: kPrimary),
                            SizedBox(width: 4),
                            Text(
                              'Chạm vào ảnh để phóng to, soi số CCCD & họ tên',
                              style: TextStyle(fontSize: 11.5, color: kPrimary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // --- Khối 4: Giấy Phép Hoạt Động Y Tế ---
                  _buildSectionCard(
                    title: 'Giấy Phép Hoạt Động Y Tế',
                    icon: Icons.assignment_outlined,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    docFile.isNotEmpty ? docFile : 'Giấy phép hoạt động y tế',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: kSlate900,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (dungLuongFile.isNotEmpty) dungLuongFile,
                                      if (loaiFile.isNotEmpty) loaiFile,
                                      'Tài liệu đính kèm',
                                    ].join(' · '),
                                    style: const TextStyle(fontSize: 11, color: kSlate400),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              onPressed: () => _handleOpenDocument(
                                context,
                                fileUrl.isNotEmpty ? fileUrl : docFile,
                                docFile,
                              ),
                              child: const Text('Xem tệp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // --- Khối 5: Người Đại Diện & Liên Hệ ---
                  _buildSectionCard(
                    title: 'Người Đại Diện & Liên Hệ',
                    icon: Icons.person_pin_outlined,
                    children: [
                      if (nguoiDaiDien.isNotEmpty) ...[
                        _buildDetailRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Họ tên người đại diện',
                          value: nguoiDaiDien,
                          isHighlight: true,
                        ),
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      ],
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
                      if (moTa.isNotEmpty) ...[
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildDetailRow(
                          icon: Icons.notes_rounded,
                          label: 'Giới thiệu / Ghi chú cơ sở',
                          value: moTa,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ================= THANH THAO TÁC DUYỆT & TỪ CHỐI =================
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

  /// Khung hiển thị thẻ CCCD (Mặt trước / Mặt sau)
  Widget _buildCccdCard({
    required BuildContext context,
    required String label,
    required bool hasImage,
    Uint8List? bytes,
    String? imageUrl,
  }) {
    return GestureDetector(
      onTap: hasImage
          ? () => _showFullScreenImage(
                context,
                title: label,
                bytes: bytes,
                imageUrl: imageUrl,
              )
          : null,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasImage ? kPrimary.withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
            width: hasImage ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage) ...[
              if (bytes != null)
                Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderCard(label, isError: true),
                )
              else if (imageUrl != null && imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderCard(label, isError: true),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _buildPlaceholderCard(label),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(String label, {bool isError = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Icons.broken_image_outlined : Icons.add_photo_alternate_outlined,
            size: 28,
            color: isError ? kRed : kSlate400,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: kSlate700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isError ? 'Lỗi tải ảnh' : 'Chưa tải ảnh',
            style: TextStyle(
              fontSize: 10,
              color: isError ? kRed : kSlate400,
            ),
          ),
        ],
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: kSlate900,
                  ),
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
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isHighlight ? kPrimary : kSlate400),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, color: kSlate400, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                  color: isHighlight ? kPrimary : kSlate800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}