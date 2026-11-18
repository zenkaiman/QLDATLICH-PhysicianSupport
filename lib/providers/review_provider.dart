import 'package:flutter/foundation.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';

class ReviewProvider extends ChangeNotifier {
  final ReviewService _service = ReviewService();

  List<ReviewModel> _reviews = [];
  bool _isLoading = false;
  String? _error;
  String? _loadedKey;
  int _requestToken = 0;

  // Thống kê nhanh KHOA
  int _deptTotalStatsCount = 0;
  double _deptTotalStatsAvg = 0.0;
  bool _isDeptStatsLoading = false;

  // ✅ Thống kê nhanh BỆNH VIỆN (MỚI)
  int _hospTotalStatsCount = 0;
  double _hospTotalStatsAvg = 0.0;
  bool _isHospStatsLoading = false;

  List<ReviewModel> get reviews => _reviews;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Getters cho KHOA
  int get deptTotalStatsCount => _deptTotalStatsCount;
  double get deptTotalStatsAvg => _deptTotalStatsAvg;
  bool get isDeptStatsLoading => _isDeptStatsLoading;

  // ✅ Getters cho BỆNH VIỆN
  int get hospTotalStatsCount => _hospTotalStatsCount;
  double get hospTotalStatsAvg => _hospTotalStatsAvg;
  bool get isHospStatsLoading => _isHospStatsLoading;

  // ───────────────────────── Thống kê từ danh sách đã tải (UI dùng) ─────────────────────────
  int get totalCount => _reviews.length;

  double get averageRating {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<double>(0, (s, r) => s + r.diemDanhGia);
    return sum / _reviews.length;
  }

  Map<int, int> get countByStar {
    final result = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      final star = r.diemDanhGia;
      if (result.containsKey(star)) result[star] = result[star]! + 1;
    }
    return result;
  }

  List<ReviewModel> reviewsByStar(int star) =>
      _reviews.where((r) => r.diemDanhGia == star).toList();

  // ───────────────────────── Tải dữ liệu ─────────────────────────

  Future<void> fetchReviews({
    required String hospitalId,
    required String khoaId,
    bool force = false,
  }) async {
    final key = '$hospitalId|$khoaId';
    if (!force && key == _loadedKey && _error == null) return;

    final token = ++_requestToken;
    _loadedKey = key;
    _isLoading = true;
    _error = null;
    _reviews = [];
    notifyListeners();

    try {
      final result = await _service.getReviewsByDepartment(
        hospitalId: hospitalId,
        khoaId: khoaId,
      );
      if (token != _requestToken) return;
      _reviews = result;
    } catch (e) {
      if (token != _requestToken) return;
      _error = e is ReviewException ? e.message : 'Không thể tải đánh giá.';
      _loadedKey = null;
    } finally {
      if (token == _requestToken) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ✅ HÀM MỚI: Lấy nhanh thống kê tổng quan của BỆNH VIỆN
  Future<void> fetchHospitalStats({ required String hospitalId }) async {
    _isHospStatsLoading = true;
    notifyListeners();

    try {
      final stats = await _service.getHospitalStats(hospitalId: hospitalId);
      _hospTotalStatsCount = stats['tong_danh_gia'] ?? 0;
      _hospTotalStatsAvg = (stats['diem_trung_binh'] ?? 0.0).toDouble();
    } catch (e) {
      debugPrint('Lỗi khi tải thống kê bệnh viện: $e');
    } finally {
      _isHospStatsLoading = false;
      notifyListeners();
    }
  }

  // ✅ HÀM CŨ: Lấy nhanh thống kê tổng quan của KHOA
  Future<void> fetchDepartmentStats({
    required String hospitalId,
    required String khoaId,
  }) async {
    _isDeptStatsLoading = true;
    notifyListeners();

    try {
      final stats = await _service.getDepartmentStats(
        hospitalId: hospitalId,
        khoaId: khoaId,
      );
      _deptTotalStatsCount = stats['tong_danh_gia'] ?? 0;
      _deptTotalStatsAvg = (stats['diem_trung_binh'] ?? 0.0).toDouble();
    } catch (e) {
      debugPrint('Lỗi khi tải thống kê khoa: $e');
    } finally {
      _isDeptStatsLoading = false;
      notifyListeners();
    }
  }

  void clearReviews() {
    _requestToken++;
    _reviews = [];
    _error = null;
    _isLoading = false;
    _loadedKey = null;
    notifyListeners();
  }
}