import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_routes.dart';
import '../../config/app_session.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/email_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/hospital_sync_service.dart';
import 'guiDonThanhCong_Screen.dart';
import 'widgets/dialog_chon_dia_chi_map.dart';

/// Tệp giấy phép / tài liệu hoạt động y tế đính kèm
class TepDinhKemItem {
  final String id;
  final String tenFile;
  final String dungLuong;
  final int dungLuongBytes;
  final Uint8List? bytes;
  final String? path;
  final bool isSample;

  TepDinhKemItem({
    String? id,
    required this.tenFile,
    required this.dungLuong,
    required this.dungLuongBytes,
    this.bytes,
    this.path,
    this.isSample = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}

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

  // Tọa độ GPS & địa chỉ map (lưu ngầm vào Firestore, không hiện trên form)
  double? _viDo;
  double? _kinhDo;
  String? _diaChiMap;
  Timer? _diaChiDebounceTimer;
  bool _dangTimKiemDiaChiForm = false;

  // Ảnh CCCD người đại diện (Mặt trước & Mặt sau)
  Uint8List? _cccdTruocBytes;
  String? _cccdTruocTen;
  Uint8List? _cccdSauBytes;
  String? _cccdSauTen;

  String _coSo = 'Tu_nhan'; // 'Cong_lap' hoặc 'Tu_nhan' theo collection CoSo
  String _bhyt = 'Co_BHYT'; // 'Co_BHYT' hoặc 'Khong_BHYT' theo collection BHYT

  // Danh sách tệp giấy phép / tài liệu đính kèm (hỗ trợ nhiều tệp & xem trước)
  final List<TepDinhKemItem> _danhSachTepDinhKem = [];

  bool _isSubmitting = false;
  String _submittingStatus = '';

  Future<void> _chonAnhCccd(bool isMatTruoc) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isMatTruoc
                    ? 'Chọn ảnh Mặt trước CCCD'
                    : 'Chọn ảnh Mặt sau CCCD',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF0284C7),
                  ),
                ),
                title: const Text(
                  'Chụp ảnh',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Dùng camera thiết bị để chụp ảnh CCCD',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF16A34A),
                  ),
                ),
                title: const Text(
                  'Chọn từ thư viện máy',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Tải ảnh CCCD đã có sẵn từ bộ sưu tập',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          if (isMatTruoc) {
            _cccdTruocBytes = bytes;
            _cccdTruocTen = pickedFile.name;
          } else {
            _cccdSauBytes = bytes;
            _cccdSauTen = pickedFile.name;
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ Lỗi chọn ảnh CCCD: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn ảnh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onFormDiaChiChanged(String val) {
    _diaChiDebounceTimer?.cancel();
    final q = val.trim();
    if (q.length < 3) return;

    _diaChiDebounceTimer = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted) return;
      setState(() => _dangTimKiemDiaChiForm = true);
      try {
        final items = await GeocodingService.timKiemDiaChi(q);
        if (items.isNotEmpty && mounted) {
          final first = items.first;
          setState(() {
            _viDo = first.viDo;
            _kinhDo = first.kinhDo;
            _diaChiMap = first.diaChiDayDu;
            _dangTimKiemDiaChiForm = false;
          });
        } else {
          if (mounted) setState(() => _dangTimKiemDiaChiForm = false);
        }
      } catch (_) {
        if (mounted) setState(() => _dangTimKiemDiaChiForm = false);
      }
    });
  }

  Future<void> _moChonDiaChiMap() async {
    // Mở trực tiếp màn hình chọn bản đồ Google Map toàn diện
    final result = await DialogChonDiaChiMap.show(
      context,
      initialAddress: _diaChiCtrl.text.trim(),
      initialLat: _viDo,
      initialLon: _kinhDo,
    );

    if (result != null && mounted) {
      setState(() {
        _diaChiCtrl.text = result.diaChiDayDu;
        _diaChiMap = result.diaChiDayDu;
        _viDo = result.viDo;
        _kinhDo = result.kinhDo;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Đã chọn vị trí cơ sở thành công từ bản đồ.'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _capNhatToaDoMoi(double lat, double lon) async {
    setState(() {
      _viDo = lat;
      _kinhDo = lon;
    });
    final item = await GeocodingService.traNguocToaDo(lat, lon);
    if (item != null && mounted) {
      setState(() {
        _diaChiCtrl.text = item.diaChiDayDu;
        _diaChiMap = item.diaChiDayDu;
      });
    }
  }

  /// Hộp thoại hỏi người dùng cho phép mở định vị GPS trên màn hình đăng ký
  Future<bool> _hienThiDialogHoiMoDinhViMini() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: Color(0xFF0284C7),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cho phép định vị GPS?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ứng dụng cần sử dụng vị trí thiết bị để tự động ghim vị trí cơ sở y tế trên bản đồ và nhận diện địa chỉ chính xác nhất.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.45,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '• Tự động điền số nhà, tên đường, phường/xã\n• Giúp người bệnh dễ dàng tìm đường đến khám',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF0284C7),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Để sau',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text(
              'Bật định vị',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Kích hoạt định vị GPS cho form đăng ký cơ sở y tế
  Future<void> _dinhViGpsChoFormMini() async {
    final dongY = await _hienThiDialogHoiMoDinhViMini();
    if (!dongY) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng bật dịch vụ định vị (GPS) trên thiết bị.'),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quyền định vị bị từ chối. Bạn có thể tự ghim trên bản đồ.'),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      await _capNhatToaDoMoi(pos.latitude, pos.longitude);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Đã định vị thành công vị trí của bạn!'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lấy tọa độ GPS: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildEmbeddedMapCard() {
    final lat = _viDo ?? 10.86012;
    final lon = _kinhDo ?? 106.77234;
    final center = LatLng(lat, lon);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Khung bản đồ thu nhỏ tương tác trực tiếp
          Container(
            height: 190,
            color: const Color(0xFFE2E8F0),
            child: Stack(
              children: [
                FlutterMap(
                  key: ValueKey('embed_map_${lat}_$lon'),
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 15.5,
                    minZoom: 4,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (tapPos, point) {
                      _capNhatToaDoMoi(point.latitude, point.longitude);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                      fallbackUrl:
                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: center,
                          width: 46,
                          height: 46,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 42,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Nút "Định vị GPS" ở góc trên bên trái
                Positioned(
                  top: 8,
                  left: 8,
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _dinhViGpsChoFormMini,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location_rounded,
                              size: 14,
                              color: Color(0xFF0284C7),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Định vị GPS',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Nút "Mở rộng bản đồ" ở góc trên bên phải
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _moChonDiaChiMap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.open_in_full_rounded,
                              size: 14,
                              color: Color(0xFF0284C7),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Mở rộng',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Nhãn chỉ dẫn chạm ở góc dưới bên trái
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Chạm bản đồ để ghim vị trí',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Chân hiển thị địa chỉ đã chọn
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _diaChiMap?.isNotEmpty == true
                        ? _diaChiMap!
                        : (_diaChiCtrl.text.isNotEmpty
                            ? _diaChiCtrl.text
                            : 'Vị trí cơ sở y tế đã được ghim trên bản đồ'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _moChonDiaChiMap,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'Đổi vị trí',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    _maCoSoCtrl = TextEditingController();
    _maSoThueCtrl = TextEditingController();
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
  }

  @override
  void dispose() {
    _diaChiDebounceTimer?.cancel();
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
          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'doc', 'docx'],
        );
      } catch (err) {
        debugPrint('⚠️ Không thể mở custom type, fallback sang any: $err');
        files = await FilePicker.pickFiles(type: FileType.any);
      }

      if (files.isNotEmpty) {
        final List<TepDinhKemItem> newItems = [];

        for (final file in files) {
          Uint8List? bytes;
          try {
            bytes = await file.readAsBytes();
          } catch (_) {}
          if (bytes == null || bytes.isEmpty) {
            if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
              try {
                bytes = await File(file.path!).readAsBytes();
              } catch (_) {}
            }
          }

          final sizeBytes = file.lengthSync() ?? (await file.length()) ?? bytes?.length ?? 0;
          final sizeText = _formatFileSize(sizeBytes);

          newItems.add(
            TepDinhKemItem(
              tenFile: file.name,
              dungLuong: '$sizeText • Đã tải lên',
              dungLuongBytes: sizeBytes,
              bytes: bytes,
              path: file.path,
              isSample: false,
            ),
          );
        }

        if (newItems.isNotEmpty) {
          setState(() {
            for (final newItem in newItems) {
              _danhSachTepDinhKem.removeWhere((item) => item.tenFile == newItem.tenFile);
              _danhSachTepDinhKem.add(newItem);
            }
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
                      child: Text(
                        'Đã thêm ${newItems.length} tệp tài liệu thành công. Nhấn "Xem" để xem nội dung.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF16A34A),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi mở trình chọn tệp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể truy cập tệp tin: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _doiFileDinhKem() {
    _chonTepTuThietBi();
  }

  /// Xem trước nội dung file tài liệu trước khi gửi
  void _xemNoiDungFile(TepDinhKemItem item) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh tiêu đề xem trước
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _getFileColor(item.tenFile).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getFileIcon(item.tenFile),
                        size: 20,
                        color: _getFileColor(item.tenFile),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.tenFile,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${item.dungLuong} • Xem trước tài liệu',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(ctx).pop(),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
              ),

              // Nội dung hiển thị xem trước tệp
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildPreviewContent(item),
                ),
              ),

              // Chân hộp thoại hành động
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_danhSachTepDinhKem.length > 1)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _xoaTep(item);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                        label: const Text(
                          'Xóa tệp này',
                          style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Đóng xem trước', style: TextStyle(fontWeight: FontWeight.w700)),
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

  /// Khung hiển thị nội dung chi tiết theo định dạng tệp (Ảnh, PDF, Văn bản)
  Widget _buildPreviewContent(TepDinhKemItem item) {
    final lower = item.tenFile.toLowerCase();
    final isImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');

    // 1. Xem trước ảnh (JPG, PNG, WebP)
    if (isImage) {
      if (item.bytes != null && item.bytes!.isNotEmpty) {
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                maxScale: 4.0,
                child: Image.memory(
                  item.bytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in_rounded, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 4),
                  Text(
                    'Dùng cử chỉ chạm hoặc chuột để phóng to / thu nhỏ ảnh',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        );
      }
    }

    // 2. Xem trước tài liệu PDF hoặc giấy tờ hành chính chuẩn BYT
    final tenBv = _tenBenhVienCtrl.text.trim().isNotEmpty
        ? _tenBenhVienCtrl.text.trim()
        : 'Cơ sở Y tế Đăng ký';
    final maCs = _maCoSoCtrl.text.trim().isNotEmpty
        ? _maCoSoCtrl.text.trim()
        : 'BYT-CS-2026';
    final mst = _maSoThueCtrl.text.trim().isNotEmpty
        ? _maSoThueCtrl.text.trim()
        : '0312891201';
    final diaChi = _diaChiCtrl.text.trim().isNotEmpty
        ? _diaChiCtrl.text.trim()
        : 'Thành phố Hồ Chí Minh';
    final loaiHinh = _coSo == 'Cong_lap'
        ? 'Công lập (Bệnh viện Nhà nước)'
        : 'Tư nhân (Bệnh viện / Phòng khám Tư)';
    final bhytStr = _bhyt == 'Co_BHYT'
        ? 'Có khám chữa bệnh BHYT'
        : 'Không BHYT (Dịch vụ 100%)';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quốc hiệu & Tiêu ngữ
          const Center(
            child: Column(
              children: [
                Text(
                  'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Độc lập - Tự do - Hạnh phúc',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                SizedBox(height: 4),
                SizedBox(
                  width: 140,
                  child: Divider(thickness: 1.2, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tên văn bản giấy phép
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Column(
              children: [
                Text(
                  'BỘ Y TẾ - HỆ THỐNG MEDICONNECT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'GIẤY PHÉP HOẠT ĐỘNG & HỒ SƠ HỢP TÁC CƠ SỞ Y TẾ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Thông tin cơ sở y tế
          _buildInfoRow('Tên cơ sở y tế:', tenBv, isBold: true),
          const SizedBox(height: 6),
          _buildInfoRow('Mã cơ sở (BYT):', maCs),
          const SizedBox(height: 6),
          _buildInfoRow('Mã số thuế:', mst),
          const SizedBox(height: 6),
          _buildInfoRow('Địa chỉ cơ sở:', diaChi),
          const SizedBox(height: 6),
          _buildInfoRow('Loại hình:', loaiHinh),
          const SizedBox(height: 6),
          _buildInfoRow('Chính sách BHYT:', bhytStr),
          const SizedBox(height: 6),
          _buildInfoRow('Tên tệp đính kèm:', item.tenFile),
          const SizedBox(height: 6),
          _buildInfoRow('Dung lượng tệp:', item.dungLuong),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Khung mộc dấu chứng thực điện tử
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF43F5E), width: 1.5),
                ),
                child: const Column(
                  children: [
                    Text(
                      'BỘ Y TẾ - CỤC QUẢN LÝ KCB',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '★ ĐÃ TIẾP NHẬN HỒ SƠ HỢP LỆ ★',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFBE123C),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'CHỮ KÝ SỐ ĐIỆN TỬ XÁC NHẬN',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF9F1239),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? const Color(0xFF0F172A) : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  void _xoaTep(TepDinhKemItem item) {
    setState(() {
      _danhSachTepDinhKem.removeWhere((f) => f.id == item.id || f.tenFile == item.tenFile);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã xóa tệp: ${item.tenFile}'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF475569),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _guiYeuCau() async {
    if (!_formKey.currentState!.validate()) return;

    if (_danhSachTepDinhKem.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đính kèm ít nhất một tệp giấy phép hoạt động y tế trước khi gửi đơn.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

      // Nếu chưa có tọa độ từ map, tự động quy đổi từ địa chỉ cơ sở
      if (_viDo == null || _kinhDo == null) {
        try {
          final addressText = _diaChiCtrl.text.trim();
          if (addressText.isNotEmpty) {
            final items = await GeocodingService.timKiemDiaChi(addressText);
            if (items.isNotEmpty) {
              _viDo = items.first.viDo;
              _kinhDo = items.first.kinhDo;
              _diaChiMap = items.first.diaChiDayDu;
            }
          }
        } catch (_) {}
      }

      // Dự phòng tọa độ nếu mạng chưa phân giải kịp
      _viDo ??= 10.776889;
      _kinhDo ??= 106.700806;

      // 1. Chuẩn bị danh sách tệp đính kèm để upload lên Firebase Storage
      final List<Map<String, dynamic>> uploadedFilesData = [];
      String? primaryFileUrl;
      final safeUid = hospitalBvId.replaceAll(RegExp(r'[^\w\-]'), '_');
      String primaryStoragePath = '';
      String primaryContentType = 'application/pdf';

      for (int i = 0; i < _danhSachTepDinhKem.length; i++) {
        final fileItem = _danhSachTepDinhKem[i];
        Uint8List fileData;
        if (fileItem.bytes != null && fileItem.bytes!.isNotEmpty) {
          fileData = fileItem.bytes!;
        } else {
          fileData = _generateSamplePdfBytes(
            tenBenhVien: _tenBenhVienCtrl.text.trim(),
            maHoSo: maHoSo,
            maCoSo: _maCoSoCtrl.text.trim(),
            maSoThue: _maSoThueCtrl.text.trim(),
            diaChi: _diaChiCtrl.text.trim(),
          );
        }

        String fileName = fileItem.tenFile.trim();
        if (fileName.isEmpty) fileName = 'giay_phep_${i + 1}.pdf';

        String contentType = 'application/pdf';
        final lower = fileName.toLowerCase();
        if (lower.endsWith('.pdf')) {
          contentType = 'application/pdf';
        } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
          contentType = 'image/jpeg';
        } else if (lower.endsWith('.png')) {
          contentType = 'image/png';
        } else if (lower.endsWith('.webp')) {
          contentType = 'image/webp';
        } else if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
          contentType = 'application/msword';
        }

        final safeName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
        final storagePath =
            'giay_phep_hop_tac/$safeUid/${DateTime.now().millisecondsSinceEpoch}_${i}_$safeName';
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

        String? thisFileUrl;
        try {
          setState(() {
            _submittingStatus =
                'Đang tải tệp ${i + 1}/${_danhSachTepDinhKem.length}: $fileName...';
          });
          debugPrint('📤 [STORAGE] Tải tệp lên Firebase Storage ($storagePath)...');

          UploadTask uploadTask;
          if (fileItem.path != null &&
              fileItem.path!.isNotEmpty &&
              !kIsWeb &&
              File(fileItem.path!).existsSync()) {
            uploadTask = storageRef.putFile(File(fileItem.path!), metadata);
          } else {
            uploadTask = storageRef.putData(fileData, metadata);
          }

          uploadTask.snapshotEvents.listen((TaskSnapshot snap) {
            if (snap.totalBytes > 0 && mounted) {
              final progress =
                  (snap.bytesTransferred / snap.totalBytes * 100).toInt();
              setState(() {
                _submittingStatus =
                    'Đang tải tệp ${i + 1}/${_danhSachTepDinhKem.length}: $progress% (${_formatFileSize(snap.bytesTransferred)}/${_formatFileSize(snap.totalBytes)})';
              });
            }
          });

          final timeoutSec = max(
            60,
            (fileData.length / (1024 * 1024) * 8).toInt(),
          );
          final snapshot = await uploadTask.timeout(Duration(seconds: timeoutSec));
          thisFileUrl = await snapshot.ref.getDownloadURL().timeout(
            const Duration(seconds: 30),
          );
          debugPrint('✅ [STORAGE] Tải tệp thành công: $thisFileUrl');
        } catch (storageError) {
          debugPrint('⚠️ [STORAGE] Upload Firebase Storage: $storageError');
        }

        if (primaryFileUrl == null && thisFileUrl != null) {
          primaryFileUrl = thisFileUrl;
          primaryStoragePath = storagePath;
          primaryContentType = contentType;
        }

        uploadedFilesData.add({
          'ten_file': fileName,
          'file_url': thisFileUrl ?? '',
          'dung_luong': fileItem.dungLuong,
          'dung_luong_bytes': fileData.length,
          'loai_file': contentType,
          'storage_path': storagePath,
        });
      }

      // Tải ảnh CCCD mặt trước & mặt sau lên Firebase Storage nếu có
      String? cccdMatTruocUrl;
      String? cccdMatSauUrl;

      if (_cccdTruocBytes != null) {
        try {
          setState(() => _submittingStatus = 'Đang tải ảnh CCCD mặt trước...');
          final cccdTruocName = _cccdTruocTen ?? 'cccd_mat_truoc.jpg';
          final cccdTruocExt = cccdTruocName.contains('.')
              ? cccdTruocName.split('.').last
              : 'jpg';
          final cccdTruocPath =
              'YeuCauHopTac/$hospitalBvId/cccd/mat_truoc_${DateTime.now().millisecondsSinceEpoch}.$cccdTruocExt';
          final cccdTruocRef =
              FirebaseStorage.instance.ref().child(cccdTruocPath);
          final snapTruoc = await cccdTruocRef.putData(
            _cccdTruocBytes!,
            SettableMetadata(contentType: 'image/$cccdTruocExt'),
          );
          cccdMatTruocUrl = await snapTruoc.ref.getDownloadURL();
          debugPrint(
            '✅ [STORAGE] Tải CCCD mặt trước thành công: $cccdMatTruocUrl',
          );
        } catch (e) {
          debugPrint('⚠️ [STORAGE] Lỗi tải CCCD mặt trước: $e');
        }
      }

      if (_cccdSauBytes != null) {
        try {
          setState(() => _submittingStatus = 'Đang tải ảnh CCCD mặt sau...');
          final cccdSauName = _cccdSauTen ?? 'cccd_mat_sau.jpg';
          final cccdSauExt = cccdSauName.contains('.')
              ? cccdSauName.split('.').last
              : 'jpg';
          final cccdSauPath =
              'YeuCauHopTac/$hospitalBvId/cccd/mat_sau_${DateTime.now().millisecondsSinceEpoch}.$cccdSauExt';
          final cccdSauRef =
              FirebaseStorage.instance.ref().child(cccdSauPath);
          final snapSau = await cccdSauRef.putData(
            _cccdSauBytes!,
            SettableMetadata(contentType: 'image/$cccdSauExt'),
          );
          cccdMatSauUrl = await snapSau.ref.getDownloadURL();
          debugPrint(
            '✅ [STORAGE] Tải CCCD mặt sau thành công: $cccdMatSauUrl',
          );
        } catch (e) {
          debugPrint('⚠️ [STORAGE] Lỗi tải CCCD mặt sau: $e');
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
        'dia_chi_map': _diaChiMap ?? _diaChiCtrl.text.trim(),
        'vi_do': _viDo,
        'kinh_do': _kinhDo,
        'cccd_mat_truoc_url': cccdMatTruocUrl,
        'cccd_mat_sau_url': cccdMatSauUrl,
        'cccd_mat_truoc_ten': _cccdTruocTen,
        'cccd_mat_sau_ten': _cccdSauTen,
        'has_cccd': (cccdMatTruocUrl != null || cccdMatSauUrl != null),
        'co_so': coSo, // ✅ Khớp collection CoSo: Cong_lap / Tu_nhan
        'bhyt': bhyt, // ✅ Khớp collection BHYT: Co_BHYT / Khong_BHYT
        'co_bhyt': coBhyt,
        'loai_hinh': loaiHinh,
        'chuyen_khoa_ids':
            <String>[], // ✅ Khởi tạo mảng rỗng chuẩn, không để null
        'ten_cac_khoa': <String>[],
        'file_giay_phep': _danhSachTepDinhKem.isNotEmpty
            ? _danhSachTepDinhKem.first.tenFile
            : 'giay_phep_byt.pdf',
        'file_giay_phep_url': primaryFileUrl,
        'file_url': primaryFileUrl,
        'dung_luong_file': _danhSachTepDinhKem.isNotEmpty
            ? _danhSachTepDinhKem.first.dungLuong
            : '',
        'dung_luong_bytes': _danhSachTepDinhKem.isNotEmpty
            ? _danhSachTepDinhKem.first.dungLuongBytes
            : 0,
        'loai_file': primaryContentType,
        'storage_path': primaryStoragePath,
        'danh_sach_file': uploadedFilesData,
        'danh_sach_ten_file':
            _danhSachTepDinhKem.map((f) => f.tenFile).toList(),
        'so_luong_file': _danhSachTepDinhKem.length,
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
      if (_danhSachTepDinhKem.isNotEmpty &&
          _danhSachTepDinhKem.first.bytes != null &&
          _danhSachTepDinhKem.first.bytes!.length < 350 * 1024) {
        // Lưu dự phòng chuỗi Base64 trực tiếp vào Firestore
        try {
          dataToSave['file_giay_phep_base64'] =
              base64Encode(_danhSachTepDinhKem.first.bytes!);
        } catch (_) {}
      }
      if (_cccdTruocBytes != null && _cccdTruocBytes!.length < 250 * 1024) {
        try {
          dataToSave['cccd_mat_truoc_base64'] = base64Encode(_cccdTruocBytes!);
        } catch (_) {}
      }
      if (_cccdSauBytes != null && _cccdSauBytes!.length < 250 * 1024) {
        try {
          dataToSave['cccd_mat_sau_base64'] = base64Encode(_cccdSauBytes!);
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLabelWithRequired('Địa chỉ cơ sở'),
                              TextButton.icon(
                                onPressed: _moChonDiaChiMap,
                                icon: const Icon(
                                  Icons.map_rounded,
                                  size: 16,
                                  color: Color(0xFF0284C7),
                                ),
                                label: const Text(
                                  'Chọn trên Bản đồ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _diaChiCtrl,
                            onChanged: _onFormDiaChiChanged,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: _inputDecoration(
                              hintText:
                                  'Số nhà, tên đường, phường/xã, quận/huyện, tỉnh/TP',
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFF0284C7),
                                  size: 22,
                                ),
                                tooltip: 'Chọn trên Bản đồ',
                                onPressed: _moChonDiaChiMap,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Vui lòng nhập địa chỉ bệnh viện';
                              }
                              return null;
                            },
                          ),
                          if (_dangTimKiemDiaChiForm)
                            const Padding(
                              padding: EdgeInsets.only(top: 6, bottom: 2),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Đang tự động định vị trên bản đồ...',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF0284C7),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Khung bản đồ trực tiếp trên màn hình
                          _buildEmbeddedMapCard(),
                          const SizedBox(height: 16),

                          // Ảnh CCCD người đại diện (Mặt trước & Mặt sau)
                          _buildSectionHeaderWithNote(
                            title: 'Ảnh CCCD người đại diện',
                            note: 'Nhấn để chụp hoặc chọn ảnh *',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildCccdCard(isMatTruoc: true),
                              const SizedBox(width: 12),
                              _buildCccdCard(isMatTruoc: false),
                            ],
                          ),
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

                          // 6. Giấy phép hoạt động y tế (Đính kèm nhiều tệp)
                          _buildAttachedFilesSection(),
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



  /// Thẻ tải và hiển thị ảnh CCCD (Mặt trước / Mặt sau)
  Widget _buildCccdCard({required bool isMatTruoc}) {
    final bytes = isMatTruoc ? _cccdTruocBytes : _cccdSauBytes;
    final title = isMatTruoc ? 'Mặt trước CCCD' : 'Mặt sau CCCD';
    final hasImage = bytes != null;

    return Expanded(
      child: GestureDetector(
        onTap: () => _chonAnhCccd(isMatTruoc),
        child: Container(
          height: 135,
          decoration: BoxDecoration(
            color: hasImage ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasImage
                  ? const Color(0xFF0284C7)
                  : const Color(0xFFCBD5E1),
              width: hasImage ? 1.5 : 1.0,
            ),
            boxShadow: hasImage
                ? [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.65),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF4ADE80),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isMatTruoc) {
                                    _cccdTruocBytes = null;
                                    _cccdTruocTen = null;
                                  } else {
                                    _cccdSauBytes = null;
                                    _cccdSauTen = null;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Đổi ảnh',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Chụp hoặc chọn ảnh',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
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

  Widget _buildAttachedFilesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text(
                      'Giấy phép hoạt động y tế',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '*',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  if (_danhSachTepDinhKem.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_danhSachTepDinhKem.length} tệp',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_danhSachTepDinhKem.isNotEmpty)
              InkWell(
                onTap: _doiFileDinhKem,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: Color(0xFF0284C7)),
                      SizedBox(width: 2),
                      Text(
                        'Thêm tệp',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Khi chưa có tệp đính kèm nào: Hiển thị khung tải lên để người dùng tự thêm
        if (_danhSachTepDinhKem.isEmpty)
          InkWell(
            onTap: _doiFileDinhKem,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFBAE6FD),
                  width: 1.3,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2FE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      color: Color(0xFF0284C7),
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tải lên giấy phép hoạt động y tế',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Chạm để chọn tệp từ máy (PDF, Word, Ảnh JPG/PNG)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Danh sách các tệp do người dùng tải lên
          ..._danhSachTepDinhKem.map((fileItem) {
            final fileColor = _getFileColor(fileItem.tenFile);
            final fileIcon = _getFileIcon(fileItem.tenFile);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFBAE6FD),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: fileColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(fileIcon, size: 20, color: fileColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileItem.tenFile,
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
                              fileItem.dungLuong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Nút "Xem" trước nội dung
                      ElevatedButton.icon(
                        onPressed: () => _xemNoiDungFile(fileItem),
                        icon: const Icon(Icons.visibility_rounded, size: 13),
                        label: const Text(
                          'Xem',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF0F9FF),
                          foregroundColor: const Color(0xFF0284C7),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFBAE6FD)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Nút Xóa tệp (cho phép xóa bất kỳ tệp nào)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: Color(0xFFEF4444),
                        ),
                        tooltip: 'Xóa tệp này',
                        onPressed: () => _xoaTep(fileItem),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Nút thêm tệp phụ
          InkWell(
            onTap: _doiFileDinhKem,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 15,
                    color: Color(0xFF0284C7),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Chọn thêm tệp giấy phép / tài liệu khác',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
