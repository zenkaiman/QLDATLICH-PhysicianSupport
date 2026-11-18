import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_session.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/email_service.dart';
import '../../services/hospital_sync_service.dart';
import 'listKhoaDieuTri.dart';
import 'nhanSu_Screen.dart';
import 'phanCong_Screen.dart';
import 'widgets/hospital_bottom_nav.dart';
import 'widgets/hospital_dashboard_tab.dart';
import 'widgets/hospital_header.dart';
import 'widgets/hospital_settings_tab.dart';
import 'widgets/hospital_unverified_view.dart';

/// Màn hình chính của Bệnh viện (Quản trị cơ sở y tế)
class HomeHospitalScreen extends StatefulWidget {
  final int initialTabIndex;
  const HomeHospitalScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HomeHospitalScreen> createState() => _HomeHospitalScreenState();
}

class _HomeHospitalScreenState extends State<HomeHospitalScreen> {
  late int _currentBottomNavIndex;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _yeuCauHopTacSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _benhVienSub;
  String? _currentListeningBvId;
  String? _resolvedHospitalId;
  int? _currentStatusId;
  int? _lastSentStatusId;
  bool _isSendingMail = false;

  @override
  void initState() {
    super.initState();
    _currentBottomNavIndex = widget.initialTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.hospital == null) {
        auth.fetchCurrentUser(preferredRole: 'benh_vien');
      }
      _timVaKhoiTaoHospitalId();
      HospitalSyncService.quetVaChuanHoaBenhVienDaGuiDon();
    });
  }

  @override
  void dispose() {
    _yeuCauHopTacSub?.cancel();
    _benhVienSub?.cancel();
    super.dispose();
  }

  /// Tự động kiểm tra và gửi email thông báo khi trạng thái THAY ĐỔI sang 10 (Được duyệt) hoặc 9 (Hủy/Từ chối)
  /// Tuyệt đối chỉ gửi 1 lần duy nhất, không gửi lại khi người dùng đăng nhập vào app!
  void _kiemTraVaGuiEmailThongBao({
    required String bvid,
    required int statusId,
    required Map<String, dynamic> docData,
    required DocumentReference docRef,
  }) {
    // 1. Kiểm tra Firestore: Nếu đã gửi email phê duyệt rồi thì DỪNG NGAY (khi đăng nhập không gửi lại!)
    if (statusId == TrangThaiId.hopTac && docData['da_gui_mail_phe_duyet'] == true) {
      _lastSentStatusId = statusId;
      return;
    }

    // 2. Kiểm tra Firestore: Nếu đã gửi email từ chối/hủy rồi thì DỪNG NGAY
    if (statusId == TrangThaiId.huyHopTac && docData['da_gui_mail_tu_choi'] == true) {
      _lastSentStatusId = statusId;
      return;
    }

    // 3. Nếu là lần đầu mở app / đăng nhập (_lastSentStatusId == null), chỉ ghi nhớ trạng thái hiện tại, KHÔNG gửi mail
    if (_lastSentStatusId == null) {
      _lastSentStatusId = statusId;
      return;
    }

    if (_isSendingMail) return;

    // Không gửi lại nếu trạng thái chưa thay đổi
    if (_lastSentStatusId == statusId) return;

    if (statusId != TrangThaiId.hopTac && statusId != TrangThaiId.huyHopTac) {
      _lastSentStatusId = statusId;
      return;
    }

    String emailNhan = (docData['email'] ?? '').toString().trim();
    if (emailNhan.isEmpty && mounted) {
      final auth = context.read<AuthProvider>();
      emailNhan = (auth.hospital?.email ?? '').trim();
    }
    if (emailNhan.isEmpty) {
      emailNhan = (FirebaseAuth.instance.currentUser?.email ?? '').trim();
    }
    if (emailNhan.isEmpty) {
      debugPrint('⚠️ [HomeHospital] Không tìm thấy email của bệnh viện $bvid để gửi thông báo.');
      return;
    }

    final String tenBv = (docData['ten_benh_vien'] ??
            docData['tenBenhVien'] ??
            'Bệnh viện')
        .toString();

    _lastSentStatusId = statusId;
    _isSendingMail = true;

    // 1. Phê duyệt hợp tác (Mã 10 - Hợp Tác)
    if (statusId == TrangThaiId.hopTac) {
      debugPrint('🚀 [EMAIL TRIGGER] Đang gửi email Phê Duyệt (10) tới: $emailNhan');
      docRef.set({
        'da_gui_mail_phe_duyet': true,
        'da_gui_mail_tu_choi': false,
      }, SetOptions(merge: true));

      FirebaseFirestore.instance
          .collection('BenhVien')
          .doc(bvid)
          .set({
            'da_gui_mail_phe_duyet': true,
            'da_gui_mail_tu_choi': false,
            'da_xac_thuc': true,
            'da_bi_tu_choi': false,
          }, SetOptions(merge: true))
          .catchError((_) {});

      FirebaseFirestore.instance
          .collection('YeuCauHopTac')
          .doc(bvid)
          .set({
            'da_gui_mail_phe_duyet': true,
            'da_gui_mail_tu_choi': false,
          }, SetOptions(merge: true))
          .catchError((_) {});

      EmailService.guiEmailPheDuyetHopTac(
        emailNguoiNhan: emailNhan,
        tenBenhVien: tenBv,
        maBenhVien: bvid,
      ).then((success) {
        _isSendingMail = false;
        if (mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.mark_email_read_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đã gửi email phê duyệt hợp tác tới $emailNhan',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }).catchError((e) {
        _isSendingMail = false;
        debugPrint('❌ [EMAIL TRIGGER] Lỗi gửi email phê duyệt: $e');
      });
    }
    // 2. Hủy / Từ chối hợp tác (Mã 9 - Hủy Hợp Tác)
    else if (statusId == TrangThaiId.huyHopTac) {
      debugPrint('🚀 [EMAIL TRIGGER] Đang gửi email Hủy/Từ Chối (9) tới: $emailNhan');
      docRef.set({
        'da_gui_mail_tu_choi': true,
        'da_gui_mail_phe_duyet': false,
      }, SetOptions(merge: true));

      FirebaseFirestore.instance
          .collection('BenhVien')
          .doc(bvid)
          .set({
            'da_gui_mail_tu_choi': true,
            'da_gui_mail_phe_duyet': false,
            'da_bi_tu_choi': true,
            'da_gui_don': false,
          }, SetOptions(merge: true))
          .catchError((_) {});

      FirebaseFirestore.instance
          .collection('YeuCauHopTac')
          .doc(bvid)
          .set({
            'da_gui_mail_tu_choi': true,
            'da_gui_mail_phe_duyet': false,
          }, SetOptions(merge: true))
          .catchError((_) {});

      EmailService.guiEmailTuChoiHopTac(
        emailNguoiNhan: emailNhan,
        tenBenhVien: tenBv,
        maBenhVien: bvid,
        lyDo: docData['ly_do_tu_choi']?.toString(),
      ).then((success) {
        _isSendingMail = false;
        if (mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.mark_email_read_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đã gửi email thông báo hủy/từ chối tới $emailNhan',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }).catchError((e) {
        _isSendingMail = false;
        debugPrint('❌ [EMAIL TRIGGER] Lỗi gửi email từ chối: $e');
      });
    }
  }

  /// Lắng nghe realtime từ YeuCauHopTac
  void _langNgheYeuCauHopTac(String bvid) {
    if (bvid.isEmpty) return;

    _yeuCauHopTacSub?.cancel();
    _yeuCauHopTacSub = FirebaseFirestore.instance
        .collection('YeuCauHopTac')
        .doc(bvid)
        .snapshots()
        .listen((snap) {
          if (snap.exists && snap.data() != null) {
            final data = snap.data()!;
            final rawStatus = data['trang_thai_hop_tac_id'];
            if (rawStatus != null) {
              final int newStatus = rawStatus is int
                  ? rawStatus
                  : int.tryParse(rawStatus.toString()) ?? 1;

              // 🛡️ CHẶN HẠ TRẠNG THÁI: Nếu đã là 10 (Hợp tác), không bao giờ bị hạ xuống 1 hoặc 9!
              if (_currentStatusId == TrangThaiId.hopTac && newStatus != TrangThaiId.hopTac) {
                debugPrint('🛡️ [HOME] Bỏ qua hạ trạng thái từ YeuCauHopTac ($newStatus) vì đã được duyệt 10');
                return;
              }

              if (newStatus == TrangThaiId.hopTac) {
                if (_currentStatusId != TrangThaiId.hopTac && mounted) {
                  setState(() => _currentStatusId = TrangThaiId.hopTac);
                }
                HospitalSyncService.dongBoSangBenhVien(bvid, newStatus, data);
                _kiemTraVaGuiEmailThongBao(
                  bvid: bvid,
                  statusId: newStatus,
                  docData: data,
                  docRef: snap.reference,
                );
              } else {
                if (_currentStatusId != newStatus && mounted) {
                  setState(() => _currentStatusId = newStatus);
                }
              }
            }
          }
        });
  }

  /// Lắng nghe realtime từ BenhVien
  void _langNgheBenhVien(String bvid) {
    if (bvid.isEmpty) return;

    _benhVienSub?.cancel();
    _benhVienSub = FirebaseFirestore.instance
        .collection('BenhVien')
        .doc(bvid)
        .snapshots()
        .listen((snap) {
          if (snap.exists && snap.data() != null) {
            final data = snap.data()!;
            final rawStatus = data['trang_thai_hop_tac_id'];
            if (rawStatus != null) {
              final int newStatus = rawStatus is int
                  ? rawStatus
                  : int.tryParse(rawStatus.toString()) ?? 1;

              // 🛡️ CHẶN HẠ TRẠNG THÁI: Nếu đã là 10 (Hợp tác), không bao giờ bị hạ xuống 1 hoặc 9!
              if (_currentStatusId == TrangThaiId.hopTac && newStatus != TrangThaiId.hopTac) {
                debugPrint('🛡️ [HOME] Bỏ qua hạ trạng thái từ BenhVien ($newStatus) vì đã được duyệt 10');
                return;
              }

              if (newStatus == TrangThaiId.hopTac) {
                if (_currentStatusId != TrangThaiId.hopTac && mounted) {
                  setState(() => _currentStatusId = TrangThaiId.hopTac);
                }
                HospitalSyncService.dongBoSangYeuCauHopTac(bvid, newStatus, data);
              } else {
                if (_currentStatusId != newStatus && mounted) {
                  setState(() => _currentStatusId = newStatus);
                }
              }
            }
          }
        });
  }

  /// Khởi tạo đồng bộ 2 chiều realtime cho bệnh viện
  void _khoiTaoDongBoRealtime(String bvid) {
    if (bvid.isEmpty) return;
    if (_currentListeningBvId == bvid &&
        _yeuCauHopTacSub != null &&
        _benhVienSub != null) {
      return;
    }
    _currentListeningBvId = bvid;
    _resolvedHospitalId = bvid;
    AppSession.benhVienId = bvid;

    _langNgheYeuCauHopTac(bvid);
    _langNgheBenhVien(bvid);
  }

  /// Tìm và xác định chính xác Document ID của Bệnh viện (BVxxx)
  Future<void> _timVaKhoiTaoHospitalId() async {
    // 0. Quét dọn collection YeuCauHopTac và BenhVien đưa về mã chuẩn BVxxx
    HospitalSyncService.quetVaChuanHoaBenhVienDaGuiDon().catchError((_) {});

    if (AppSession.benhVienId.startsWith('BV')) {
      _khoiTaoDongBoRealtime(AppSession.benhVienId);
      return;
    }

    final auth = context.read<AuthProvider>();
    final maBv = auth.hospital?.maBenhVien ?? auth.hospital?.uid;
    if (maBv != null && maBv.startsWith('BV')) {
      _khoiTaoDongBoRealtime(maBv);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Tra cứu theo auth_uid trước
        final snapAuth = await FirebaseFirestore.instance
            .collection('BenhVien')
            .where('auth_uid', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (snapAuth.docs.isNotEmpty && snapAuth.docs.first.id.startsWith('BV')) {
          final foundId = snapAuth.docs.first.id;
          if (mounted) {
            setState(() {
              _resolvedHospitalId = foundId;
            });
            _khoiTaoDongBoRealtime(foundId);
          }
          return;
        }

        if (user.email != null && user.email!.isNotEmpty) {
          final snapBv = await FirebaseFirestore.instance
              .collection('BenhVien')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
          for (final doc in snapBv.docs) {
            if (doc.id.startsWith('BV')) {
              final foundId = doc.id;
              if (mounted) {
                setState(() {
                  _resolvedHospitalId = foundId;
                });
                _khoiTaoDongBoRealtime(foundId);
              }
              return;
            }
          }

          final snapYc = await FirebaseFirestore.instance
              .collection('YeuCauHopTac')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
          for (final doc in snapYc.docs) {
            if (doc.id.startsWith('BV')) {
              final foundId = doc.id;
              if (mounted) {
                setState(() {
                  _resolvedHospitalId = foundId;
                });
                _khoiTaoDongBoRealtime(foundId);
              }
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [HomeHospital] Lỗi tìm ID bệnh viện theo email: $e');
      }
    }

    if (!mounted) return;
    final curUid = _getHospitalUid(context);
    if (curUid.isNotEmpty) {
      _khoiTaoDongBoRealtime(curUid);
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>?> _getHospitalStream(
    BuildContext context,
  ) {
    final auth = context.watch<AuthProvider>();
    final user = FirebaseAuth.instance.currentUser;

    final candidate = auth.hospital?.maBenhVien ??
        (_resolvedHospitalId != null && _resolvedHospitalId!.startsWith('BV')
            ? _resolvedHospitalId
            : (AppSession.benhVienId.startsWith('BV') ? AppSession.benhVienId : null));

    final targetId = candidate ?? (_resolvedHospitalId ?? user?.uid ?? '');
    if (targetId.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection('BenhVien')
          .doc(targetId)
          .snapshots();
    }

    return const Stream.empty();
  }

  String _getHospitalUid(BuildContext context) {
    if (_resolvedHospitalId != null && _resolvedHospitalId!.startsWith('BV')) {
      return _resolvedHospitalId!;
    }
    final auth = context.read<AuthProvider>();
    if (auth.hospital?.maBenhVien != null && auth.hospital!.maBenhVien!.startsWith('BV')) {
      return auth.hospital!.maBenhVien!;
    }
    if (AppSession.benhVienId.startsWith('BV')) {
      return AppSession.benhVienId;
    }
    if (auth.hospital?.uid != null && auth.hospital!.uid!.startsWith('BV')) {
      return auth.hospital!.uid!;
    }
    return _resolvedHospitalId ?? (AppSession.benhVienId.isNotEmpty ? AppSession.benhVienId : (FirebaseAuth.instance.currentUser?.uid ?? ''));
  }

  void _thongBaoChuaKichHoat(String chucNang) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Chức năng "$chucNang" sẽ được mở sau khi Admin phê duyệt đơn hợp tác.',
        ),
        backgroundColor: const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hospitalUid = _getHospitalUid(context);

    // Lắng nghe dữ liệu realtime từ Firestore của đúng tài khoản bệnh viện này
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      stream: _getHospitalStream(context),
      builder: (context, snapshot) {
        final authProvider = context.watch<AuthProvider>();
        final data = snapshot.data?.data();

        final realId = snapshot.data?.id ?? _resolvedHospitalId ?? hospitalUid;
        if (realId.isNotEmpty) {
          if (AppSession.benhVienId != realId && realId.startsWith('BV')) {
            AppSession.benhVienId = realId;
          }
          if (_currentListeningBvId != realId) {
            _currentListeningBvId = realId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _khoiTaoDongBoRealtime(realId);
              }
            });
          }
        }

        // Tên bệnh viện động từ Firestore / AuthProvider / fallback
        final tenBenhVien = data?['ten_benh_vien'] ??
            data?['tenBenhVien'] ??
            authProvider.hospital?.tenBenhVien ??
            FirebaseAuth.instance.currentUser?.displayName ??
            'Bệnh viện';

        // Trạng thái hợp tác: Ưu tiên trạng thái đã được phê duyệt (10)
        final int? bvStatus = data?['trang_thai_hop_tac_id'] is int
            ? data!['trang_thai_hop_tac_id']
            : int.tryParse(data?['trang_thai_hop_tac_id']?.toString() ?? '');

        final int? trangThaiId;
        if (bvStatus == TrangThaiId.hopTac ||
            _currentStatusId == TrangThaiId.hopTac ||
            data?['da_xac_thuc'] == true) {
          trangThaiId = TrangThaiId.hopTac;
          if (_currentStatusId != TrangThaiId.hopTac) {
            _currentStatusId = TrangThaiId.hopTac;
          }
        } else if (bvStatus != null) {
          trangThaiId = bvStatus;
        } else {
          trangThaiId = _currentStatusId ?? authProvider.hospital?.trangThaiHopTacId;
        }

        // Trạng thái 9: Bị từ chối hoặc hủy hợp tác
        final bool isBiTuChoiHoacHuy = (trangThaiId == TrangThaiId.huyHopTac);

        // Bệnh viện đã gửi đơn hay chưa:
        // CHỈ ĐƯỢC XEM LÀ ĐÃ GỬI ĐƠN NẾU:
        // 1. data['da_gui_don'] == true HOẶC
        // 2. data['so_giay_phep'] có giá trị hợp lệ HOẶC
        // 3. data['ma_ho_so'] có giá trị hợp lệ
        // Tuyệt đối không dùng trạng thái để gán bừa là đã gửi đơn khi vừa đăng ký mới!
        final bool daGuiDon = !isBiTuChoiHoacHuy &&
            ((data?['da_gui_don'] == true) ||
                (data?['so_giay_phep'] != null &&
                    data!['so_giay_phep'].toString().trim().isNotEmpty) ||
                (data?['ma_ho_so'] != null &&
                    data!['ma_ho_so'].toString().trim().isNotEmpty));

        // Đã được Admin phê duyệt hợp tác hay chưa (10: Hợp tác theo Firebase, hoặc 2: Đã xác nhận)
        final bool daXacThuc =
            (trangThaiId == 10 || trangThaiId == 2) && !isBiTuChoiHoacHuy;

        final String hospitalEmail = (data?['email'] ??
                authProvider.hospital?.email ??
                FirebaseAuth.instance.currentUser?.email ??
                '')
            .toString();

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    // Header chuẩn theo tài khoản đang đăng nhập
                    HospitalHeader(
                      hospitalUid: realId,
                      tenBenhVien: tenBenhVien,
                      daGuiDon: daGuiDon,
                      daXacThuc: daXacThuc,
                      trangThaiId: trangThaiId ?? 0,
                      email: hospitalEmail,
                    ),

                    // Thân trang: chuyển đổi linh hoạt theo trạng thái và tab
                    Expanded(
                      child: !daXacThuc
                          ? HospitalUnverifiedView(
                              hospitalUid: realId,
                              tenBenhVien: tenBenhVien,
                              daGuiDon: daGuiDon,
                              trangThaiId: trangThaiId ?? 0,
                              data: data,
                            )
                          : _buildBodyForCurrentTab(hospitalUid: realId),
                    ),

                    // Thanh điều hướng dưới cùng
                    HospitalBottomNav(
                      currentIndex: _currentBottomNavIndex,
                      daXacThuc: daXacThuc,
                      onTabSelected: (index) {
                        setState(() => _currentBottomNavIndex = index);
                      },
                      onBlockedTabTap: _thongBaoChuaKichHoat,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== GIAO DIỆN THEO TAB KHI ĐÃ HỢP TÁC ====================
  Widget _buildBodyForCurrentTab({required String hospitalUid}) {
    switch (_currentBottomNavIndex) {
      case 1:
        // Tab "Khoa khám": Hiển thị tất cả các khoa khám hiện có
        return const TatCaKhoaTab();
      case 2:
        // Tab "Nhân sự": Danh sách nhân sự & nút Cấp tài khoản
        return NhanSuScreen(benhVienId: hospitalUid);
      case 3:
        // Tab "Phân công": Phân công trực theo phòng khám
        return PhanCongScreen(benhVienId: hospitalUid);
      case 4:
        // Tab "Cài đặt": Thông tin & Đăng xuất
        return HospitalSettingsTab(hospitalUid: hospitalUid);
      case 0:
      default:
        // Tab "Trang chủ": Dashboard thống kê & danh sách khoa
        return HospitalDashboardTab(
          hospitalUid: hospitalUid,
          onXemTatCaKhoa: () => setState(() => _currentBottomNavIndex = 1),
        );
    }
  }
}
