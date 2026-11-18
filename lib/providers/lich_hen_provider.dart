import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/lichhen_model.dart';
import '../services/lichhen_service.dart';

/// LichHenProvider: quản lý trạng thái tình trạng ca, danh sách lịch hẹn, lịch hẹn của tôi và hàng chờ thời gian thực.
class LichHenProvider extends ChangeNotifier {
  final LichHenService _service = LichHenService();

  final Map<String, List<CaSlotModel>> _slotsCache = {};
  final Set<String> _loadingSlotKeys = {};
  final Map<String, String> _slotErrors = {};

  final Map<String, List<LichHenModel>> _lichHenCache = {};
  final Set<String> _loadingLichHenKeys = {};
  final Map<String, String> _lichHenErrors = {};
  List<LichHenModel> _activeQueue = [];
  bool _queueLoaded = false;
  String? _queueError;

  StreamSubscription<List<LichHenModel>>? _queueSubscription;
  bool _isListeningToQueue = false;

  List<LichHenModel> _myBookings = [];
  bool _isLoadingMyBookings = false;
  String? _myBookingsError;
  int _myBookingsToken = 0;

  static const Set<String> _historyStatusIds = {'5', '6'};

  /// makeKey: tạo khóa cache theo bệnh viện, khoa, phòng, ngày và ca (nếu có).
  static String makeKey({
    required DateTime ngay,
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
    String? caId,
  }) {
    return [
      benhVienId,
      khoaId,
      phongKhamId,
      LichHenService.ngayId(ngay),
      if (caId != null) caId,
    ].join('|');
  }

  /// slotsOf: lấy danh sách tình trạng ca đã cache theo khóa.
  List<CaSlotModel> slotsOf(String key) => _slotsCache[key] ?? const [];

  /// hasLoadedSlots: kiểm tra tình trạng ca của khóa đã được tải chưa.
  bool hasLoadedSlots(String key) => _slotsCache.containsKey(key);

  /// isLoadingSlots: kiểm tra tình trạng ca của khóa có đang được tải không.
  bool isLoadingSlots(String key) => _loadingSlotKeys.contains(key);

  /// slotsErrorOf: lấy thông báo lỗi khi tải tình trạng ca của khóa.
  String? slotsErrorOf(String key) => _slotErrors[key];

  /// loadSlots: tải tình trạng các ca (còn x/y chỗ) của một phòng khám trong một ngày.
  Future<void> loadSlots({
    required DateTime ngay,
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
    int soBenhNhanToiDa = 0,
    bool force = false,
  }) async {
    final key = makeKey(
      ngay: ngay,
      benhVienId: benhVienId,
      khoaId: khoaId,
      phongKhamId: phongKhamId,
    );

    if (_loadingSlotKeys.contains(key)) return;
    if (!force && _slotsCache.containsKey(key)) return;

    _loadingSlotKeys.add(key);
    _slotErrors.remove(key);
    notifyListeners();

    try {
      _slotsCache[key] = await _service.getCaSlotsTheoPhong(
        ngay: ngay,
        benhVienId: benhVienId,
        khoaId: khoaId,
        phongKhamId: phongKhamId,
        soBenhNhanToiDa: soBenhNhanToiDa,
      );
    } catch (e) {
      debugPrint('Lỗi khi tải tình trạng ca: $e');
      _slotErrors[key] = 'Không thể tải lịch khám của ngày này.';
    } finally {
      _loadingSlotKeys.remove(key);
      notifyListeners();
    }
  }

  /// lichHenOf: lấy danh sách lịch hẹn đã cache theo khóa.
  List<LichHenModel> lichHenOf(String key) => _lichHenCache[key] ?? const [];

  /// hasLoadedLichHen: kiểm tra danh sách lịch hẹn của khóa đã được tải chưa.
  bool hasLoadedLichHen(String key) => _lichHenCache.containsKey(key);

  /// isLoadingLichHen: kiểm tra danh sách lịch hẹn của khóa có đang được tải không.
  bool isLoadingLichHen(String key) => _loadingLichHenKeys.contains(key);

  /// lichHenErrorOf: lấy thông báo lỗi khi tải danh sách lịch hẹn của khóa.
  String? lichHenErrorOf(String key) => _lichHenErrors[key];

  @override
  void dispose() {
    stopListeningQueue();
    super.dispose();
  }

  /// loadLichHenList: tải danh sách lịch hẹn của một phòng khám trong một ngày (và ca nếu có).
  Future<void> loadLichHenList({
    required DateTime ngay,
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
    String? caId,
    bool force = false,
  }) async {
    final key = makeKey(
      ngay: ngay,
      benhVienId: benhVienId,
      khoaId: khoaId,
      phongKhamId: phongKhamId,
      caId: caId,
    );

    if (_loadingLichHenKeys.contains(key)) return;
    if (!force && _lichHenCache.containsKey(key)) return;

    _loadingLichHenKeys.add(key);
    _lichHenErrors.remove(key);
    notifyListeners();

    try {
      _lichHenCache[key] = await _service.getDanhSachLichHen(
        ngay: ngay,
        benhVienId: benhVienId,
        khoaId: khoaId,
        phongKhamId: phongKhamId,
        caId: caId,
      );
    } catch (e) {
      debugPrint('Lỗi khi tải danh sách lịch hẹn: $e');
      _lichHenErrors[key] = 'Không thể tải danh sách lịch hẹn.';
    } finally {
      _loadingLichHenKeys.remove(key);
      notifyListeners();
    }
  }

  List<LichHenModel> get myBookings => _myBookings;
  bool get isLoadingMyBookings => _isLoadingMyBookings;
  String? get myBookingsError => _myBookingsError;
  List<LichHenModel> get activeQueue => _activeQueue;
  bool get isListeningToQueue => _isListeningToQueue;
  bool get queueLoaded => _queueLoaded;
  String? get queueError => _queueError;

  /// activeBookings: lịch hẹn chưa kết thúc (chờ duyệt, đã xác nhận, đã hủy, đến trễ).
  List<LichHenModel> get activeBookings => _myBookings
      .where((b) => !_historyStatusIds.contains(b.trangThaiId))
      .toList();

  /// historyBookings: lịch hẹn đã kết thúc (hoàn thành, vắng mặt).
  List<LichHenModel> get historyBookings => _myBookings
      .where((b) => _historyStatusIds.contains(b.trangThaiId))
      .toList();

  /// activeBookingsOf: lịch hẹn chưa kết thúc của một hồ sơ (null là tất cả hồ sơ).
  List<LichHenModel> activeBookingsOf(String? profileId) => profileId == null
      ? activeBookings
      : activeBookings.where((b) => b.profileKey == profileId).toList();

  /// historyBookingsOf: lịch hẹn đã kết thúc của một hồ sơ (null là tất cả hồ sơ).
  List<LichHenModel> historyBookingsOf(String? profileId) => profileId == null
      ? historyBookings
      : historyBookings.where((b) => b.profileKey == profileId).toList();

  /// loadMyBookings: tải tất cả lịch hẹn của bệnh nhân.
  Future<void> loadMyBookings(String benhNhanId) async {
    final token = ++_myBookingsToken;
    _isLoadingMyBookings = true;
    _myBookingsError = null;
    notifyListeners();

    try {
      final result = await _service.getLichHenCuaBenhNhan(benhNhanId);
      if (token != _myBookingsToken) return;
      _myBookings = result;
    } catch (e) {
      if (token != _myBookingsToken) return;
      _myBookingsError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (token == _myBookingsToken) {
        _isLoadingMyBookings = false;
        notifyListeners();
      }
    }
  }

  /// huyLichHen: hủy lịch hẹn, tải lại danh sách lịch hẹn và xóa cache số chỗ.
  Future<void> huyLichHen({
    required String benhNhanId,
    required String lichHenId,
    String? lyDoHuy,
  }) async {
    await _service.huyLichHenTheoId(
      benhNhanId: benhNhanId,
      lichHenId: lichHenId,
      lyDoHuy: lyDoHuy,
    );

    final token = ++_myBookingsToken;
    try {
      final result = await _service.getLichHenCuaBenhNhan(benhNhanId);
      if (token == _myBookingsToken) _myBookings = result;
    } catch (e) {
      debugPrint('Không tải lại được lịch hẹn sau khi hủy: $e');
    }

    clearCache();
  }

  /// xoaLichHen: xóa lịch hẹn đã hủy rồi tải lại danh sách lịch hẹn.
  Future<void> xoaLichHen({
    required String benhNhanId,
    required String lichHenId,
  }) async {
    await _service.xoaLichHenTheoId(
      benhNhanId: benhNhanId,
      lichHenId: lichHenId,
    );

    final token = ++_myBookingsToken;
    try {
      final result = await _service.getLichHenCuaBenhNhan(benhNhanId);
      if (token == _myBookingsToken) _myBookings = result;
    } catch (e) {
      debugPrint('Không tải lại được lịch hẹn sau khi xóa: $e');
    }
    notifyListeners();
  }

  /// clearMyBookings: xóa lịch hẹn của tôi khi đăng xuất để không lộ dữ liệu tài khoản trước.
  void clearMyBookings() {
    _myBookingsToken++;
    _myBookings = [];
    _myBookingsError = null;
    _isLoadingMyBookings = false;
    notifyListeners();
  }

  /// clearCache: xóa cache số chỗ và danh sách lịch hẹn để lần sau tải lại dữ liệu mới.
  void clearCache() {
    _slotsCache.clear();
    _lichHenCache.clear();
    _slotErrors.clear();
    _lichHenErrors.clear();
    notifyListeners();
  }

  /// startListeningQueue: bắt đầu lắng nghe hàng chờ thời gian thực của một phòng khám.
  void startListeningQueue({
    required DateTime ngay,
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
  }) {
    _queueSubscription?.cancel();
    _isListeningToQueue = true;
    _queueLoaded = false;
    _queueError = null;
    _activeQueue = [];
    notifyListeners();

    _queueSubscription = _service
        .listenToQueue(
          ngay: ngay,
          benhVienId: benhVienId,
          khoaId: khoaId,
          phongKhamId: phongKhamId,
        )
        .listen(
          (queue) {
            _activeQueue = queue;
            _queueLoaded = true;
            _queueError = null;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Lỗi khi lắng nghe hàng chờ: $e');
            _queueError =
                'Không tải được hàng chờ. Vui lòng kéo xuống để thử lại.';
            notifyListeners();
          },
        );
  }

  /// stopListeningQueue: ngừng lắng nghe hàng chờ và xóa dữ liệu hàng chờ.
  void stopListeningQueue() {
    _queueSubscription?.cancel();
    _queueSubscription = null;
    _isListeningToQueue = false;
    _queueLoaded = false;
    _queueError = null;
    _activeQueue = [];
    notifyListeners();
  }
}