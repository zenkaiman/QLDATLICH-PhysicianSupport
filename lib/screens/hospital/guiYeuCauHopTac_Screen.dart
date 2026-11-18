import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../config/app_routes.dart';
import '../../config/app_session.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/email_service.dart';
import '../../services/hospital_sync_service.dart';
import 'guiDonThanhCong_Screen.dart';

class GuiYeuCauHopTacScreen extends StatefulWidget {
  final String? initialTenBenhVien;
  final String? initialDiaChi;

  const GuiYeuCauHopTacScreen({
    super.key,
    this.initialTenBenhVien,
    this.initialDiaChi,
  });

  @override
  State<GuiYeuCauHopTacScreen> createState() => _GuiYeuCauHopTacScreenState();
}

class _GuiYeuCauHopTacScreenState extends State<GuiYeuCauHopTacScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _tenBenhVienCtrl;
  late final TextEditingController _maCoSoCtrl;
  late final TextEditingController _maSoThueCtrl;
  late final TextEditingController _diaChiCtrl;

  // Tọa độ GPS của thiết bị
  double? _viDo;
  double? _kinhDo;
  bool _dangLayViTri = false;
  String _viTriStatus = 'Chưa xác định tọa độ GPS';

  String _coSo = 'Tu_nhan'; // 'Cong_lap' hoặc 'Tu_nhan' theo collection CoSo
  String _bhyt = 'Co_BHYT'; // 'Co_BHYT' hoặc 'Khong_BHYT' theo collection BHYT
  String _tenFileDinhKem = 'giay_phep_byt.pdf';
  String _dungLuongFile = '62.0 KB • Đã tải lên';
  Uint8List? _fileBytes;
  String? _pickedFilePath;
  bool _isSubmitting = false;
  String _submittingStatus = '';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final currentFbUser = FirebaseAuth.instance.currentUser;
    final tenBv =
        widget.initialTenBenhVien ??
        auth.hospital?.tenBenhVien ??
        (currentFbUser?.displayName?.isNotEmpty == true
            ? currentFbUser!.displayName!
            : '');
    final diaChi = widget.initialDiaChi ?? auth.hospital?.diaChi ?? '';

    _tenBenhVienCtrl = TextEditingController(text: tenBv);
    _maCoSoCtrl = TextEditingController(text: 'BV-79-102');
    _maSoThueCtrl = TextEditingController(text: '0312891201');
    _diaChiCtrl = TextEditingController(text: diaChi);

    if (auth.hospital?.coSo == 'Cong_lap' || auth.hospital?.coSo == 'Tu_nhan') {
      _coSo = auth.hospital!.coSo!;
    }
    if (auth.hospital?.bhyt == 'Co_BHYT' ||
        auth.hospital?.bhyt == 'Khong_BHYT') {
      _bhyt = auth.hospital!.bhyt!;
    }

    // Lấy tọa độ có sẵn nếu tài khoản đã từng lưu
    _viDo = auth.hospital?.viDo;
    _kinhDo = auth.hospital?.kinhDo;
    if (_viDo != null && _kinhDo != null) {
      _viTriStatus =
          'Đã có tọa độ: ${_viDo!.toStringAsFixed(5)}, ${_kinhDo!.toStringAsFixed(5)}';
    }

    // Tự động yêu cầu định vị GPS từ thiết bị khi mở màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layViTriTuThietBi(isAuto: true);
    });
  }

  @override
  void dispose() {
    _tenBenhVienCtrl.dispose();
    _maCoSoCtrl.dispose();
    _maSoThueCtrl.dispose();
    _diaChiCtrl.dispose();
    super.dispose();
  }

  /// Tra cứu hoặc sinh chuẩn mã bệnh viện (luôn có định dạng BVxxx, ví dụ BV502, BV503)
  Future<String> _resolveHospitalId() async {
    final auth = context.read<AuthProvider>();
    final curUser = FirebaseAuth.instance.currentUser;
    final curUid = curUser?.uid ?? '';
    final curEmail = curUser?.email ?? '';

    // 1. Kiểm tra từ AuthProvider hoặc AppSession nếu đã chuẩn BVxxx
    final candidate =
        (auth.hospital?.maBenhVien ??
                auth.hospital?.uid ??
                AppSession.benhVienId)
            .trim();
    if (candidate.startsWith('BV') &&
        RegExp(r'^BV\d+$', caseSensitive: false).hasMatch(candidate)) {
      return candidate.toUpperCase();
    }

    // 2. Tra cứu trong Firestore collection 'BenhVien' theo auth_uid hoặc email
    final firestore = FirebaseFirestore.instance;
    try {
      if (curUid.isNotEmpty) {
        final snapAuth = await firestore
            .collection('BenhVien')
            .where('auth_uid', isEqualTo: curUid)
            .limit(1)
            .get();
        if (snapAuth.docs.isNotEmpty) {
          final doc = snapAuth.docs.first;
          final docId = doc.id;
          final maBv = doc.data()['ma_benh_vien']?.toString() ?? docId;
          if (maBv.startsWith('BV')) {
            return maBv.toUpperCase();
          }
          if (docId.startsWith('BV')) {
            return docId.toUpperCase();
          }
        }
      }

      if (curEmail.isNotEmpty) {
        final snapEmail = await firestore
            .collection('BenhVien')
            .where('email', isEqualTo: curEmail)
            .limit(1)
            .get();
        for (final doc in snapEmail.docs) {
          final docId = doc.id;
          final maBv = doc.data()['ma_benh_vien']?.toString() ?? docId;
          if (maBv.startsWith('BV')) {
            return maBv.toUpperCase();
          }
          if (docId.startsWith('BV')) {
            return docId.toUpperCase();
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Tra cứu ID bệnh viện thất bại: $e');
    }

    // 3. Tự động sinh ID BV mới nếu chưa có
    try {
      final genData = await AuthService().generateHospitalId();
      final genMa = genData['ma_benh_vien']?.toString() ?? 'BV503';
      return genMa.toUpperCase();
    } catch (_) {
      return 'BV503';
    }
  }

  /// Lấy vị trí GPS thực tế từ thiết bị để quy ra vĩ độ & kinh độ
  Future<void> _layViTriTuThietBi({bool isAuto = false}) async {
    if (_dangLayViTri) return;

    setState(() {
      _dangLayViTri = true;
      _viTriStatus = 'Đang lấy vị trí GPS từ thiết bị...';
    });

    try {
      // 1. Kiểm tra dịch vụ định vị (Location Service)
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _dangLayViTri = false;
          _viTriStatus = 'Dịch vụ GPS trên thiết bị chưa được bật';
        });
        if (!isAuto && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Vui lòng bật định vị GPS trên thiết bị để lấy tọa độ',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 2. Kiểm tra và yêu cầu quyền truy cập vị trí
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _dangLayViTri = false;
            _viTriStatus = 'Quyền truy cập vị trí bị từ chối';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _dangLayViTri = false;
          _viTriStatus = 'Quyền vị trí bị chặn trong Cài đặt thiết bị';
        });
        return;
      }

      // 3. Lấy tọa độ GPS (thử getCurrentPosition, nếu timeout thử getLastKnownPosition)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        debugPrint(
          '⚠️ getCurrentPosition chậm hoặc lỗi, thử getLastKnownPosition: $e',
        );
        position = await Geolocator.getLastKnownPosition();
      }

      if (!mounted) return;

      if (position != null) {
        final pos = position;
        setState(() {
          _viDo = pos.latitude;
          _kinhDo = pos.longitude;
          _dangLayViTri = false;
          _viTriStatus =
              'Đã định vị: ${_viDo!.toStringAsFixed(5)}, ${_kinhDo!.toStringAsFixed(5)}';
        });

        if (!isAuto && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Đã lấy tọa độ GPS: Vĩ độ ${_viDo!.toStringAsFixed(5)}, Kinh độ ${_kinhDo!.toStringAsFixed(5)}',
              ),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _dangLayViTri = false;
          _viTriStatus = 'Không lấy được tọa độ GPS từ thiết bị';
        });
      }
    } catch (e) {
      debugPrint('Lỗi khi định vị thiết bị: $e');
      if (!mounted) return;
      setState(() {
        _dangLayViTri = false;
        _viTriStatus = 'Lỗi định vị: $e';
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.article_rounded;
    }
    return Icons.description_rounded;
  }

  Color _getFileColor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return const Color(0xFFE11D48);
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png')) {
      return const Color(0xFF16A34A);
    }
    return const Color(0xFF0284C7);
  }

  Uint8List _generateSamplePdfBytes({
    required String tenBenhVien,
    required String maHoSo,
    String? maCoSo,
    String? maSoThue,
    String? diaChi,
  }) {
    final now = DateTime.now();
    final ngayStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final safeTen = tenBenhVien.isNotEmpty ? tenBenhVien : 'Benh vien hop tac';
    final safeHoSo = maHoSo.isNotEmpty ? maHoSo : '#HS-BV-2026';
    final safeCs = (maCoSo != null && maCoSo.isNotEmpty)
        ? maCoSo
        : 'CS-BYT-2026';
    final safeMst = (maSoThue != null && maSoThue.isNotEmpty)
        ? maSoThue
        : '0102030405';
    final safeDc = (diaChi != null && diaChi.isNotEmpty) ? diaChi : 'Viet Nam';

    final content =
        '''%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length 430 >>
stream
BT
/F1 16 Tf
50 730 Td
(BO Y TE - HE THONG MEDICONNECT) Tj
/F1 13 Tf
0 -30 Td
(GIAY PHEP HOAT DONG CO SO Y TE & DANG KY HOP TAC) Tj
/F1 11 Tf
0 -35 Td
(Ten co so: $safeTen) Tj
0 -22 Td
(Ma ho so: $safeHoSo) Tj
0 -22 Td
(Ma co so BYT: $safeCs) Tj
0 -22 Td
(Ma so thue: $safeMst) Tj
0 -22 Td
(Dia chi: $safeDc) Tj
0 -22 Td
(Ngay nop don: $ngayStr) Tj
0 -22 Td
(Trang thai: Dang cho xet duyet boi Ban Quan Tri) Tj
ET
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
xref
0 6
0000000000 65535 f
0000000010 00000 n
0000000060 00000 n
0000000117 00000 n
0000000227 00000 n
0000000710 00000 n
trailer
<< /Size 6 /Root 1 0 R >>
startxref
793
%%EOF
''';
    return Uint8List.fromList(utf8.encode(content));
  }

  Future<void> _chonTepTuThietBi() async {
    try {
      List<PlatformFile> files = [];
      try {
        files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
        );
      } catch (err) {
        debugPrint('⚠️ Không thể mở custom type, fallback sang any: $err');
        files = await FilePicker.pickFiles(type: FileType.any);
      }

      if (files.isNotEmpty) {
        final file = files.first;
        Uint8List? bytes;
        try {
          bytes = await file.readAsBytes();
        } catch (_) {}
        if (bytes == null || bytes.isEmpty) {
          if (file.path != null && file.path!.isNotEmpty) {
            try {
              bytes = await File(file.path!).readAsBytes();
            } catch (_) {}
          }
        }

        final sizeBytes =
            file.lengthSync() ?? (await file.length()) ?? bytes?.length ?? 0;
        final sizeText = _formatFileSize(sizeBytes);

        setState(() {
          _tenFileDinhKem = file.name;
          _dungLuongFile = '$sizeText • Đã chọn từ thiết bị';
          _fileBytes = bytes;
          _pickedFilePath = file.path;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Đã chọn tệp: ${file.name} ($sizeText)'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0284C7),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Lỗi mở trình chọn tệp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể truy cập tệp tin: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _doiFileDinhKem() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Cập nhật giấy phép hoạt động y tế',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chọn tệp giấy phép từ bộ nhớ máy hoặc dùng tài liệu mẫu:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            // Nút nổi bật: Truy cập tệp tin của máy
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _chonTepTuThietBi();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF0284C7),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.file_upload_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tải lên từ tệp tin của máy',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Mở bộ nhớ máy (PDF, Word, Ảnh JPG/PNG)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            const Text(
              'Hoặc chọn nhanh tệp mẫu có sẵn:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              title: const Text(
                'giay_phep_kinh_doanh_byt_2026.pdf',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('128 KB • Giấy phép kinh doanh BYT mẫu'),
              onTap: () {
                final sampleBytes = _generateSamplePdfBytes(
                  tenBenhVien: _tenBenhVienCtrl.text.trim(),
                  maHoSo: '#HS-BYT-2026',
                  maCoSo: _maCoSoCtrl.text.trim(),
                  maSoThue: _maSoThueCtrl.text.trim(),
                  diaChi: _diaChiCtrl.text.trim(),
                );
                setState(() {
                  _tenFileDinhKem = 'giay_phep_kinh_doanh_byt_2026.pdf';
                  _dungLuongFile =
                      '${_formatFileSize(sampleBytes.length)} • Tệp PDF chuẩn BYT';
                  _fileBytes = sampleBytes;
                  _pickedFilePath = null;
                });
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description,
                  color: Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              title: const Text(
                'chung_chi_hanh_nghe_coso.pdf',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('128 KB • Chứng chỉ hành nghề cơ sở mẫu'),
              onTap: () {
                final sampleBytes = _generateSamplePdfBytes(
                  tenBenhVien: _tenBenhVienCtrl.text.trim(),
                  maHoSo: '#CCHN-COSO-2026',
                  maCoSo: _maCoSoCtrl.text.trim(),
                  maSoThue: _maSoThueCtrl.text.trim(),
                  diaChi: _diaChiCtrl.text.trim(),
                );
                setState(() {
                  _tenFileDinhKem = 'chung_chi_hanh_nghe_coso.pdf';
                  _dungLuongFile =
                      '${_formatFileSize(sampleBytes.length)} • Chứng chỉ cơ sở mẫu';
                  _fileBytes = sampleBytes;
                  _pickedFilePath = null;
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guiYeuCau() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final String hospitalBvId = await _resolveHospitalId();
      final int? parsedId = int.tryParse(
        hospitalBvId.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      final int idNumber = parsedId ?? 502;
      final curAuthUid = FirebaseAuth.instance.currentUser?.uid ?? hospitalBvId;
      final randSuffix = Random().nextInt(900) + 100;
      final maHoSo = '#HS-BV-2026$randSuffix';

      // Nếu chưa có tọa độ, thử lấy nhanh trước khi gửi
      if (_viDo == null || _kinhDo == null) {
        try {
          final pos =
              await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.low,
                  timeLimit: Duration(seconds: 4),
                ),
              );
          _viDo = pos.latitude;
          _kinhDo = pos.longitude;
        } catch (_) {}
      }

      // 1. Chuẩn bị dữ liệu tệp để upload lên Firebase Storage
      Uint8List fileData;
      String fileName = _tenFileDinhKem.trim();
      if (fileName.isEmpty) fileName = 'giay_phep_byt.pdf';

      if (_fileBytes != null && _fileBytes!.isNotEmpty) {
        fileData = _fileBytes!;
      } else {
        fileData = _generateSamplePdfBytes(
          tenBenhVien: _tenBenhVienCtrl.text.trim(),
          maHoSo: maHoSo,
          maCoSo: _maCoSoCtrl.text.trim(),
          maSoThue: _maSoThueCtrl.text.trim(),
          diaChi: _diaChiCtrl.text.trim(),
        );
        if (!fileName.toLowerCase().endsWith('.pdf')) {
          fileName = '$fileName.pdf';
        }
        _fileBytes = fileData;
      }

      String contentType = 'application/pdf';
      final lower = fileName.toLowerCase();
      if (lower.endsWith('.pdf')) {
        contentType = 'application/pdf';
      } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      } else if (lower.endsWith('.png')) {
        contentType = 'image/png';
      } else if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
        contentType = 'application/msword';
      }

      // 2. Upload file lên Firebase Storage
      // Đường dẫn chuẩn: giay_phep_hop_tac/{hospitalBvId}/{timestamp}_{safeName}
      String? fileDownloadUrl;
      final safeUid = hospitalBvId.replaceAll(RegExp(r'[^\w\-]'), '_');
      final safeName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final storagePath =
          'giay_phep_hop_tac/$safeUid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'hospitalId': hospitalBvId,
          'hospitalName': _tenBenhVienCtrl.text.trim(),
          'maHoSo': maHoSo,
          'originalName': fileName,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      try {
        setState(
          () => _submittingStatus = 'Đang tải tệp lên máy chủ lưu trữ...',
        );
        debugPrint(
          '📤 [STORAGE] Đang tải file lên Firebase Storage: $storagePath (${fileData.length} bytes)...',
        );

        UploadTask uploadTask;
        if (_pickedFilePath != null &&
            _pickedFilePath!.isNotEmpty &&
            File(_pickedFilePath!).existsSync()) {
          uploadTask = storageRef.putFile(File(_pickedFilePath!), metadata);
        } else {
          uploadTask = storageRef.putData(fileData, metadata);
        }

        uploadTask.snapshotEvents.listen((TaskSnapshot snap) {
          if (snap.totalBytes > 0 && mounted) {
            final progress = (snap.bytesTransferred / snap.totalBytes * 100)
                .toInt();
            setState(() {
              _submittingStatus =
                  'Đang tải tệp: $progress% (${_formatFileSize(snap.bytesTransferred)}/${_formatFileSize(snap.totalBytes)})';
            });
          }
        });

        final timeoutSec = max(
          90,
          (fileData.length / (1024 * 1024) * 8).toInt(),
        );
        final snapshot = await uploadTask.timeout(
          Duration(seconds: timeoutSec),
        );
        fileDownloadUrl = await snapshot.ref.getDownloadURL().timeout(
          const Duration(seconds: 30),
        );
        debugPrint(
          '✅ [STORAGE] Tải file lên Firebase Storage thành công: $fileDownloadUrl',
        );
      } catch (storageError) {
        debugPrint('⚠️ [STORAGE] Upload Firebase Storage: $storageError');
        final errStr = storageError.toString().toLowerCase();
        if (errStr.contains('object-not-found') ||
            errStr.contains('does not exist') ||
            errStr.contains('404')) {
          throw Exception(
            'Dự án Firebase chưa kích hoạt dịch vụ Storage (Bucket chưa được tạo). Vui lòng vào Firebase Console > Storage > bấm "Bắt đầu" (Get started).',
          );
        } else if (errStr.contains('unauthorized') ||
            errStr.contains('permission-denied') ||
            errStr.contains('permission denied')) {
          throw Exception(
            'Bị từ chối quyền truy cập Firebase Storage. Vui lòng kiểm tra Storage Rules trên Firebase Console.',
          );
        } else {
          throw Exception(
            'Không thể tải tệp lên Firebase Storage ($storageError). Vui lòng kiểm tra kết nối mạng hoặc thử lại.',
          );
        }
      }

      final coSo = _coSo;
      final bhyt = _bhyt;
      final bool coBhyt = (bhyt == 'Co_BHYT');
      final String loaiHinh = coSo == 'Cong_lap' ? 'Công lập' : 'Tư nhân';

      final dataToSave = <String, dynamic>{
        'id': idNumber,
        'ma_benh_vien': hospitalBvId,
        'benh_vien_id': hospitalBvId,
        'uid': hospitalBvId,
        'auth_uid': curAuthUid,
        'ten_benh_vien': _tenBenhVienCtrl.text.trim(),
        'ma_co_so_byt': _maCoSoCtrl.text.trim(),
        'so_giay_phep': _maCoSoCtrl.text.trim(),
        'ma_so_thue': _maSoThueCtrl.text.trim(),
        'dia_chi': _diaChiCtrl.text.trim(),
        'vi_do': _viDo,
        'kinh_do': _kinhDo,
        'co_so': coSo, // ✅ Khớp collection CoSo: Cong_lap / Tu_nhan
        'bhyt': bhyt, // ✅ Khớp collection BHYT: Co_BHYT / Khong_BHYT
        'co_bhyt': coBhyt,
        'loai_hinh': loaiHinh,
        'chuyen_khoa_ids':
            <String>[], // ✅ Khởi tạo mảng rỗng chuẩn, không để null
        'ten_cac_khoa': <String>[],
        'file_giay_phep': fileName,
        'file_giay_phep_url': fileDownloadUrl,
        'file_url': fileDownloadUrl,
        'dung_luong_file': _dungLuongFile.isNotEmpty
            ? _dungLuongFile
            : _formatFileSize(fileData.length),
        'dung_luong_bytes': fileData.length,
        'loai_file': contentType,
        'storage_path': storagePath,
        'ngay_tai_file': FieldValue.serverTimestamp(),
        'ma_ho_so': maHoSo,
        'da_gui_don': true,
        'trang_thai_hop_tac_id': TrangThaiId.choDuyet, // 1: Chờ duyệt
        'trangThai': 'CHO_DUYET',
        'trang_thai': 'cho_duyet',
        'da_xac_thuc': false,
        'ngay_gui_don': FieldValue.serverTimestamp(),
        'thoi_gian_gui_str': DateTime.now().toIso8601String(),
        'da_bi_tu_choi': false,
        'da_gui_mail_tu_choi': false,
        'da_gui_mail_phe_duyet': false,
        if (FirebaseAuth.instance.currentUser?.email != null)
          'email': FirebaseAuth.instance.currentUser!.email,
      };
      if (fileData.length < 350 * 1024) {
        // Lưu dự phòng chuỗi Base64 trực tiếp vào Firestore
        try {
          dataToSave['file_giay_phep_base64'] = base64Encode(fileData);
        } catch (_) {}
      }

      // 1. Lưu trực tiếp vào doc BenhVien/{hospitalBvId} (luôn là dạng BVxxx)
      await FirebaseFirestore.instance
          .collection('BenhVien')
          .doc(hospitalBvId)
          .set(dataToSave, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));

      // 2. Lưu vào collection YeuCauHopTac/{hospitalBvId} để Admin quản lý phê duyệt
      try {
        await FirebaseFirestore.instance
            .collection('YeuCauHopTac')
            .doc(hospitalBvId)
            .set(dataToSave, SetOptions(merge: true))
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('⚠️ Lưu YeuCauHopTac: $e');
      }

      // Xóa các document rác mang ID Auth UID nếu có trong BenhVien hoặc YeuCauHopTac
      if (curAuthUid.isNotEmpty &&
          curAuthUid != hospitalBvId &&
          !curAuthUid.startsWith('BV')) {
        try {
          await FirebaseFirestore.instance
              .collection('BenhVien')
              .doc(curAuthUid)
              .delete();
          await FirebaseFirestore.instance
              .collection('YeuCauHopTac')
              .doc(curAuthUid)
              .delete();
        } catch (_) {}
      }

      // Cập nhật AppSession
      AppSession.benhVienId = hospitalBvId;

      // Đồng bộ dọn dẹp các tài liệu cũ trong nền
      HospitalSyncService.chuanHoaVaDonDepYeuCauHopTac().catchError((_) {});

      // Gửi đúng 1 email xác nhận tiếp nhận hồ sơ yêu cầu hợp tác đến Gmail của bệnh viện
      final emailGui =
          (dataToSave['email'] ??
                  FirebaseAuth.instance.currentUser?.email ??
                  '')
              .toString()
              .trim();
      if (emailGui.isNotEmpty) {
        EmailService.guiEmailXacNhanGuiYeuCauHopTac(
          emailNguoiNhan: emailGui,
          tenBenhVien: _tenBenhVienCtrl.text.trim(),
          maBenhVien: hospitalBvId,
          maHoSo: maHoSo,
        ).catchError((_) => false);
      }

      if (!mounted) return;

      // 3. Chuyển sang màn hình Đã Gửi Đơn Thành Công
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GuiDonThanhCongScreen(
            maHoSo: maHoSo,
            tenBenhVien: _tenBenhVienCtrl.text.trim(),
            loaiHinh: loaiHinh,
            coBhyt: coBhyt,
            hospitalUid: hospitalBvId,
            extraData: dataToSave,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gửi hồ sơ lên hệ thống: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted && _isSubmitting) {
        setState(() {
          _isSubmitting = false;
          _submittingStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: InkWell(
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (route) => false,
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: true,
        title: const Text(
          'Gửi Yêu Cầu Hợp Tác',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Tên bệnh viện (Không thể sửa)
                          _buildLabelWithRequired('Tên bệnh viện'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _tenBenhVienCtrl,
                            readOnly: true,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                            decoration:
                                _inputDecoration(
                                  hintText: 'Tên bệnh viện',
                                ).copyWith(
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Mã cơ sở (BYT) & Mã số thuế
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabelWithRequired('Mã cơ sở (BYT)'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _maCoSoCtrl,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: _inputDecoration(
                                        hintText: 'VD: BV-79-102',
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Nhập mã cơ sở';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabelWithRequired('Mã số thuế'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _maSoThueCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: _inputDecoration(
                                        hintText: 'VD: 0312891201',
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Nhập MST';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 3. Địa chỉ cơ sở
                          _buildLabelWithRequired('Địa chỉ cơ sở'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _diaChiCtrl,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: _inputDecoration(
                              hintText:
                                  'Số nhà, tên đường, phường/xã, quận/huyện, tỉnh/TP',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Vui lòng nhập địa chỉ bệnh viện';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Tọa độ GPS cơ sở (Kinh độ & Vĩ độ từ thiết bị)
                          _buildSectionHeaderWithNote(
                            title: 'Tọa độ GPS cơ sở',
                            note: _viDo != null && _kinhDo != null
                                ? 'Đã định vị'
                                : 'Từ thiết bị',
                          ),
                          const SizedBox(height: 8),
                          _buildLocationCard(),
                          const SizedBox(height: 18),

                          // 4. Cơ sở y tế (Spinner lựa chọn theo collection CoSo)
                          _buildSectionHeaderWithNote(
                            title: 'Cơ sở y tế (Loại hình)',
                            note: '(Theo danh mục CoSo)',
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _coSo,
                            isExpanded: true,
                            decoration:
                                _inputDecoration(
                                  hintText: 'Chọn loại hình cơ sở',
                                ).copyWith(
                                  prefixIcon: const Icon(
                                    Icons.business_outlined,
                                    size: 20,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF64748B),
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            items: const [
                              DropdownMenuItem(
                                value: 'Cong_lap',
                                child: Text(
                                  'Công lập (Bệnh viện Nhà nước)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Tu_nhan',
                                child: Text(
                                  'Tư nhân (Bệnh viện / Phòng khám Tư)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _coSo = val);
                              }
                            },
                          ),
                          const SizedBox(height: 18),

                          // 5. Khám chữa bệnh BHYT (Spinner lựa chọn theo collection BHYT)
                          _buildSectionHeaderWithNote(
                            title: 'Khám chữa bệnh BHYT',
                            note: '(Theo danh mục BHYT)',
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _bhyt,
                            isExpanded: true,
                            decoration:
                                _inputDecoration(
                                  hintText: 'Chọn chính sách BHYT',
                                ).copyWith(
                                  prefixIcon: const Icon(
                                    Icons.health_and_safety_outlined,
                                    size: 20,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF64748B),
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            items: const [
                              DropdownMenuItem(
                                value: 'Co_BHYT',
                                child: Row(
                                  children: [
                                    Text(
                                      'Có BHYT',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1E293B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '(Tiếp nhận KCB BHYT)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Khong_BHYT',
                                child: Row(
                                  children: [
                                    Text(
                                      'Không BHYT',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1E293B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '(Dịch vụ 100%)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _bhyt = val);
                              }
                            },
                          ),
                          const SizedBox(height: 18),

                          // 6. Giấy phép hoạt động y tế (Đính kèm)
                          _buildLabel('Giấy phép hoạt động y tế (Đính kèm)'),
                          const SizedBox(height: 8),
                          _buildAttachedFileCard(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Nút Gửi đơn xác nhận & Đăng ký
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _guiYeuCau,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      _submittingStatus.isNotEmpty
                                          ? _submittingStatus
                                          : 'Đang xử lý hồ sơ...',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.near_me_outlined, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Gửi Đơn Xác Nhận & Đăng Ký',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildLabelWithRequired(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          '*',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeaderWithNote({
    required String title,
    required String note,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        Text(
          note,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  /// Khung hiển thị và kích hoạt lấy vị trí GPS từ thiết bị
  Widget _buildLocationCard() {
    final hasCoords = _viDo != null && _kinhDo != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasCoords ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCoords ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasCoords
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasCoords
                  ? Icons.location_on_rounded
                  : Icons.location_searching_rounded,
              size: 22,
              color: hasCoords
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasCoords
                      ? 'Vĩ độ: ${_viDo!.toStringAsFixed(6)}'
                      : 'Chưa có tọa độ GPS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: hasCoords
                        ? const Color(0xFF166534)
                        : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasCoords
                      ? 'Kinh độ: ${_kinhDo!.toStringAsFixed(6)}'
                      : _viTriStatus,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: hasCoords
                        ? const Color(0xFF15803D)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (_dangLayViTri)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF0284C7),
              ),
            )
          else
            TextButton.icon(
              onPressed: () => _layViTriTuThietBi(isAuto: false),
              icon: Icon(
                hasCoords ? Icons.refresh_rounded : Icons.my_location_rounded,
                size: 16,
                color: const Color(0xFF0284C7),
              ),
              label: Text(
                hasCoords ? 'Định vị lại' : 'Lấy vị trí',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0284C7),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _buildAttachedFileCard() {
    final fileColor = _getFileColor(_tenFileDinhKem);
    final fileIcon = _getFileIcon(_tenFileDinhKem);

    return InkWell(
      onTap: _doiFileDinhKem,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF93C5FD),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fileColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(fileIcon, size: 22, color: fileColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tenFileDinhKem,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dungLuongFile,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _doiFileDinhKem,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Đổi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
