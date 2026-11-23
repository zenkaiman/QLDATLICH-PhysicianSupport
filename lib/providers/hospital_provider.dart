import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/hospital_service.dart';
import '../utils/search_helper.dart';

class HospitalProvider with ChangeNotifier {
  final HospitalService _service = HospitalService();

  List<Map<String, dynamic>> _hospitals = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  int _totalHospitalCount = 0;
  int _currentFilteredCount = 0;
  int _fetchToken = 0;
  String? _locationMessage;

  List<Map<String, dynamic>> _coSoList = [];
  List<Map<String, dynamic>> _bhytList = [];
  List<Map<String, dynamic>> _specialtiesList = [];
  bool _isLookupLoading = true;

  String? _selectedCoSoId;
  String? _selectedBhytId;
  List<String> _selectedSpecialtyIds = [];
  double _currentMinRating = 0;
  double _currentMaxRating = 5.0;

  Position? _userSavedLocation;
  double? _currentMinDistance;
  double? _currentMaxDistance;

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
  List<String> get selectedSpecialtyIds => _selectedSpecialtyIds;
  double get currentMinRating => _currentMinRating;
  double get currentMaxRating => _currentMaxRating;
  double? get currentMinDistance => _currentMinDistance;
  double? get currentMaxDistance => _currentMaxDistance;

  /// init: tải danh sách tra cứu (cơ sở, BHYT, chuyên khoa), đặt lại bộ lọc rồi tải danh sách bệnh viện.
  Future<void> init() async {
    _isLookupLoading = true;
    notifyListeners();

    try {
      _coSoList = await _service.getCoSoList();
      _bhytList = await _service.getBhytList();
      _specialtiesList = await _service.getSpecialtiesList();

      _totalHospitalCount = await _service.getFilteredHospitalCount() ?? 0;
      _currentFilteredCount = _totalHospitalCount;
      debugPrint(_currentFilteredCount.toString());

      _selectedCoSoId = null;
      _selectedBhytId = null;
      _currentMinRating = 0;
      _currentMinDistance = null;
      _currentMaxDistance = null;
      _selectedSpecialtyIds.clear();

      _isLookupLoading = false;
      notifyListeners();

      fetchAndFilterHospitals();
    } catch (e) {
      _errorMessage = 'Lỗi tải dữ liệu khởi tạo: $e';
      _isLookupLoading = false;
      notifyListeners();
    }
  }

  /// fetchAndFilterHospitals: áp dụng bộ lọc mới (nếu có) và tải lại danh sách bệnh viện từ trang đầu.
  /// Khi có bộ lọc sẽ tải liên tục các trang để lọc đủ kết quả; lần gọi cũ về trễ sẽ bị bỏ qua bằng token.
  Future<void> fetchAndFilterHospitals({
    String? coSoId,
    String? bhytId,
    double? minRating,
    double? maxRating,
    double? minDistance,
    double? maxDistance,
    List<String>? specialtyIds,
  }) async {
    if (coSoId != null) _selectedCoSoId = coSoId;
    if (bhytId != null) _selectedBhytId = bhytId;
    if (minRating != null) _currentMinRating = minRating;
    if (maxRating != null) _currentMaxRating = maxRating;
    if (minDistance != null) _currentMinDistance = minDistance;
    if (maxDistance != null) _currentMaxDistance = maxDistance;
    if (specialtyIds != null) _selectedSpecialtyIds = specialtyIds;

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

      final hasAnyFilter =
          hasDistanceFilter ||
          (_selectedCoSoId ?? '').isNotEmpty ||
          (_selectedBhytId ?? '').isNotEmpty ||
          minRatingArg != null ||
          maxRatingArg != null ||
          _selectedSpecialtyIds.isNotEmpty;

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

      var guard = 0;
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

      int total;
      if (!hasMore) {
        total = hospitals.length;
      } else {
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

  /// loadMoreHospitals: tải thêm trang tiếp theo của danh sách bệnh viện.
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
        specialtyIds: _selectedSpecialtyIds,
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

  /// searchHospitalsByKeyword: tìm bệnh viện theo từ khóa trên toàn bộ danh sách (không phân trang).
  Future<void> searchHospitalsByKeyword(String keyword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final allHospitals = await _service.getHospitals();
      final filteredHospitals = searchHospitals(allHospitals, keyword);
      _hospitals = filteredHospitals;
      _currentFilteredCount = filteredHospitals.length;
      _hasMore = false;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// setSelectedCoSoId: đổi cơ sở đang chọn.
  void setSelectedCoSoId(String? id) {
    _selectedCoSoId = id;
    notifyListeners();
  }

  /// setSelectedBhytId: đổi loại BHYT đang chọn.
  void setSelectedBhytId(String? id) {
    _selectedBhytId = id;
    notifyListeners();
  }

  /// setMinRating: đổi mức đánh giá tối thiểu.
  void setMinRating(double rating) {
    _currentMinRating = rating;
    notifyListeners();
  }

  /// setUserSavedLocation: lưu vị trí của người dùng để lọc theo khoảng cách.
  void setUserSavedLocation(Position? location) {
    _userSavedLocation = location;
    notifyListeners();
  }

  /// setSelectedSpecialtyIds: đổi danh sách chuyên khoa đang chọn.
  void setSelectedSpecialtyIds(List<String> ids) {
    _selectedSpecialtyIds = ids;
    notifyListeners();
  }

  /// resetFilters: đặt lại toàn bộ bộ lọc và tải lại danh sách.
  void resetFilters() {
    _selectedCoSoId = null;
    _selectedBhytId = null;
    _currentMinRating = 0;
    _currentMaxRating = 5.0;
    _currentMinDistance = null;
    _currentMaxDistance = null;
    _selectedSpecialtyIds.clear();

    _currentFilteredCount = _totalHospitalCount;
    notifyListeners();
    fetchAndFilterHospitals();
  }
}