import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/hospital_service.dart';
import '../utils/search_helper.dart';

class HospitalProvider with ChangeNotifier {
  final HospitalService _service = HospitalService();

  // ==========================================
  // 1. TRẠNG THÁI DỮ LIỆU
  // ==========================================
  List<Map<String, dynamic>> _hospitals = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  int _totalHospitalCount = 0;
  int _currentFilteredCount = 0;
  int _fetchToken = 0;
  String? _locationMessage; // Thông báo vị trí đang dùng (GPS hoặc đã lưu)

  // ✅ Danh sách ID chuyên khoa đang được chọn để lọc
  List<String> _selectedSpecialtyIds = [];

  // ==========================================
  // 2. DỮ LIỆU TRA CỨU (LOOKUP)
  // ==========================================
  List<Map<String, dynamic>> _coSoList = [];
  List<Map<String, dynamic>> _bhytList = [];
  List<Map<String, dynamic>> _specialtiesList = [];
  bool _isLookupLoading = true;

  // ==========================================
  // 3. BỘ LỌC HIỆN TẠI
  // ==========================================
  String? _selectedCoSoId;
  String? _selectedBhytId;
  double _currentMinRating = 0;
  double _currentMaxRating = 5.0;

  Position? _userSavedLocation;
  double? _currentMinDistance;
  double? _currentMaxDistance;

  // ==========================================
  // 4. GETTERS
  // ==========================================
  List<Map<String, dynamic>> get hospitals => _hospitals;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  int get totalHospitalCount => _totalHospitalCount;
  int get currentFilteredCount => _currentFilteredCount;
  String? get locationMessage => _locationMessage;

  List<Map<String, dynamic>> get coSoList => _coSoList;
  List<Map<String, dynamic>> get bhytList => _bhytList;
  List<Map<String, dynamic>> get specialtiesList => _specialtiesList;
  bool get isLookupLoading => _isLookupLoading;

  String? get selectedCoSoId => _selectedCoSoId;
  String? get selectedBhytId => _selectedBhytId;
  double get currentMinRating => _currentMinRating;
  double get currentMaxRating => _currentMaxRating;
  double? get currentMinDistance => _currentMinDistance;
  double? get currentMaxDistance => _currentMaxDistance;

  // ✅ Getter cho danh sách ID chuyên khoa
  List<String> get selectedSpecialtyIds => _selectedSpecialtyIds;

  // ==========================================
  // 5. HÀM KHỞI TẠO
  // ==========================================
  Future<void> init() async {
    _isLookupLoading = true;
    notifyListeners();

    try {
      // 1. Tải danh sách Cơ sở, BHYT và Chuyên khoa
      _coSoList = await _service.getCoSoList();
      _bhytList = await _service.getBhytList();
      _specialtiesList = await _service.getSpecialtiesList();

      // 2. Lấy tổng số lượng bệnh viện đang hợp tác
      _totalHospitalCount = await _service.getFilteredHospitalCount() ?? 0;
      _currentFilteredCount = _totalHospitalCount;
      debugPrint(_currentFilteredCount.toString());

      // 3. ✅ QUAN TRỌNG: Đặt về giá trị mặc định để hiển thị TẤT CẢ
      _selectedCoSoId = null;
      _selectedBhytId = null;
      _currentMinRating = 0;
      _currentMinDistance = null;
      _currentMaxDistance = null;
      _selectedSpecialtyIds.clear(); // ✅ Reset danh sách chuyên khoa

      _isLookupLoading = false;
      notifyListeners();

      // 4. Tải danh sách bệnh viện ngay lần đầu
      fetchAndFilterHospitals();
    } catch (e) {
      _errorMessage = 'Lỗi tải dữ liệu khởi tạo: $e';
      _isLookupLoading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // 6. HÀM TẢI VÀ LỌC DỮ LIỆU
  // ==========================================
  Future<void> fetchAndFilterHospitals({
    String? coSoId,
    String? bhytId,
    double? minRating,
    double? maxRating,
    double? minDistance,
    double? maxDistance,
    List<String>? specialtyIds,
  }) async {
    // Cập nhật bộ lọc nếu có giá trị mới truyền vào
    if (coSoId != null) _selectedCoSoId = coSoId;
    if (bhytId != null) _selectedBhytId = bhytId;
    if (minRating != null) _currentMinRating = minRating;
    if (maxRating != null) _currentMaxRating = maxRating;
    if (minDistance != null) _currentMinDistance = minDistance;
    if (maxDistance != null) _currentMaxDistance = maxDistance;
    if (specialtyIds != null) _selectedSpecialtyIds = specialtyIds;

    // Mỗi lần gọi có 1 "số thứ tự". Kết quả của lần gọi cũ (về trễ) sẽ bị bỏ.
    final token = ++_fetchToken;

    _isLoading = true;
    _errorMessage = null;
    _hospitals.clear();
    _lastDocument = null;
    _hasMore = true;
    notifyListeners();

    try {
      final minRatingArg = _currentMinRating > 0 ? _currentMinRating : null;
      final maxRatingArg = _currentMaxRating < 5.0 ? _currentMaxRating : null;

      final hasDistanceFilter =
          (_currentMinDistance ?? 0) > 0 || (_currentMaxDistance ?? 50) < 50;

      // ✅ Có bộ lọc nào đang bật không?
      final hasAnyFilter =
          hasDistanceFilter ||
          (_selectedCoSoId ?? '').isNotEmpty ||
          (_selectedBhytId ?? '').isNotEmpty ||
          minRatingArg != null ||
          maxRatingArg != null ||
          _selectedSpecialtyIds.isNotEmpty;

      // 1. Lấy trang đầu tiên
      final first = await _service.getHospitalsPage(
        coSoId: _selectedCoSoId,
        bhytId: _selectedBhytId,
        minRating: minRatingArg,
        maxRating: maxRatingArg,
        savedUserLocation: _userSavedLocation,
        minDistance: _currentMinDistance,
        maxDistance: _currentMaxDistance,
        specialtyIds: _selectedSpecialtyIds,
        lastDocument: null,
      );
      if (token != _fetchToken) return;

      final hospitals = List.of(first.hospitals);
      var lastDoc = first.lastDocument;
      var hasMore = first.hasMore;
      _locationMessage = first.locationSourceMessage;

      var guard = 0; // chống lặp vô hạn
      while (hasAnyFilter && hasMore && guard++ < 100) {
        final next = await _service.getHospitalsPage(
          coSoId: _selectedCoSoId,
          bhytId: _selectedBhytId,
          minRating: minRatingArg,
          maxRating: maxRatingArg,
          savedUserLocation: _userSavedLocation,
          minDistance: _currentMinDistance,
          maxDistance: _currentMaxDistance,
          specialtyIds: _selectedSpecialtyIds,
          lastDocument: lastDoc,
        );
        if (token != _fetchToken) return;

        hospitals.addAll(next.hospitals);
        final noProgress =
            next.lastDocument == null || next.lastDocument == lastDoc;
        lastDoc = next.lastDocument ?? lastDoc;
        hasMore = next.hasMore && !noProgress;
      }

      // 3. Tính tổng số
      int total;
      if (!hasMore) {
        total = hospitals.length;
      } else {
        // Không lọc, còn trang sau -> hỏi server tổng số
        final serverCount = await _service.getFilteredHospitalCount(
          coSoId: _selectedCoSoId,
          bhytId: _selectedBhytId,
          minRating: minRatingArg,
          maxRating: maxRatingArg,
          specialtyIds: _selectedSpecialtyIds.isNotEmpty
              ? _selectedSpecialtyIds
              : null,
        );
        if (token != _fetchToken) return;
        total = (serverCount == null || serverCount < hospitals.length)
            ? hospitals.length
            : serverCount;
      }

      _hospitals = hospitals;
      _lastDocument = lastDoc;
      _hasMore = hasMore;
      _currentFilteredCount = total;
    } catch (e) {
      if (token == _fetchToken) _errorMessage = e.toString();
    } finally {
      if (token == _fetchToken) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ==========================================
  // 7. CÁC HÀM CẬP NHẬT TRẠNG THÁI (SETTERS)
  // ==========================================
  void setSelectedCoSoId(String? id) {
    _selectedCoSoId = id;
    notifyListeners();
  }

  void setSelectedBhytId(String? id) {
    _selectedBhytId = id;
    notifyListeners();
  }

  void setMinRating(double rating) {
    _currentMinRating = rating;
    notifyListeners();
  }

  void setUserSavedLocation(Position? location) {
    _userSavedLocation = location;
    notifyListeners();
  }

  // ✅ Setter mới để cập nhật danh sách chuyên khoa từ UI
  void setSelectedSpecialtyIds(List<String> ids) {
    _selectedSpecialtyIds = ids;
    notifyListeners();
  }

  // ==========================================
  // 8. HÀM ĐẶT LẠI BỘ LỌC
  // ==========================================
  void resetFilters() {
    _selectedCoSoId = null;
    _selectedBhytId = null;
    _currentMinRating = 0;
    _currentMaxRating = 5.0;
    _currentMinDistance = null;
    _currentMaxDistance = null;
    _selectedSpecialtyIds.clear(); // ✅ Xóa sạch danh sách chuyên khoa đã chọn

    _currentFilteredCount = _totalHospitalCount;
    notifyListeners(); // ✅ Báo UI cập nhật ngay lập tức
    fetchAndFilterHospitals(); // ✅ Tải lại toàn bộ danh sách với bộ lọc mặc định
  }

  // ==========================================
  // 9. HÀM TẢI THÊM (PAGINATION)
  // ==========================================
  Future<void> loadMoreHospitals() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _service.getHospitalsPage(
        coSoId: _selectedCoSoId,
        bhytId: _selectedBhytId,
        minRating: _currentMinRating > 0 ? _currentMinRating : null,
        maxRating: _currentMaxRating < 5.0 ? _currentMaxRating : null,
        savedUserLocation: _userSavedLocation,
        minDistance: _currentMinDistance,
        maxDistance: _currentMaxDistance,
        specialtyIds:
            _selectedSpecialtyIds, // ✅ Giữ nguyên bộ lọc chuyên khoa khi load thêm
        lastDocument: _lastDocument,
      );

      _hospitals.addAll(result.hospitals);
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;
      _locationMessage = result.locationSourceMessage;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ==========================================
  // 10. HÀM TÌM KIẾM
  // ==========================================
  Future<void> searchHospitalsByKeyword(String keyword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final allHospitals = await _service.getHospitals();
      final filteredHospitals = searchHospitals(allHospitals, keyword);
      _hospitals = filteredHospitals;
      _currentFilteredCount = filteredHospitals.length;
      _hasMore = false; // Khi tìm kiếm theo từ khóa, không có phân trang
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
