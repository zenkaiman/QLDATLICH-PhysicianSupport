import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../models/phong_kham_model.dart';

class HospitalPageResult {
  final List<Map<String, dynamic>> hospitals;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final String? locationSourceMessage;

  HospitalPageResult({
    required this.hospitals,
    required this.lastDocument,
    required this.hasMore,
    this.locationSourceMessage,
  });
}

class HospitalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  final int _pageSize = 15;

  // ✅ 1. THÊM CÁC BIẾN CÒN THIẾU
  final Map<String, int> _tongSoCache = {};
  static const String _colPhongKham = 'PhongKham'; // Tên collection phòng khám

  /// Cache thời gian khám (phút / bệnh nhân): "bv|khoa|phong" -> phút.
  final Map<String, int> _thoiGianKhamCache = {};

  static const _fCoSo = 'co_so';
  static const _fBhyt = 'bhyt';
  static const _fRating = 'diem_danh_gia_tb';
  static const _fTotalReviews = 'tong_so_danh_gia';
  static const _fSpecialties = 'chuyen_khoa_ids';
  static const _fStatus = 'trang_thai_hop_tac_id';

  // ✅ 2. THÊM HÀM HỖ TRỢ ÉP KIỂU CÒN THIẾU
  static int? _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

  /// Chỉ chấp nhận số phút > 0.
  static int? _soPhutHopLe(dynamic v) {
    final n = _toInt(v);
    return (n != null && n > 0) ? n : null;
  }

  Future<List<Map<String, dynamic>>> getCoSoList() async {
    final snapshot = await _firestore.collection('CoSo').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> getBhytList() async {
    final snapshot = await _firestore.collection('BHYT').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Query<Map<String, dynamic>> _buildHospitalQuery({
    String? coSoId,
    String? bhytId,
    double? minRating,
    double? maxRating,
    List<String>? specialtyIds,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('BenhVien');

    query = query.where(_fStatus, isEqualTo: 10);

    if (coSoId != null && coSoId.isNotEmpty) {
      final coSoValue = (coSoId == 'Cong_lap') ? 'Công lập' : 'Tư nhân';
      query = query.where(_fCoSo, isEqualTo: coSoValue);
    }

    if (bhytId != null && bhytId.isNotEmpty) {
      final bhytValue = (bhytId == 'Co_BHYT') ? 'Có BHYT' : 'Không BHYT';
      query = query.where(_fBhyt, isEqualTo: bhytValue);
    }

    if (minRating != null && minRating > 0) {
      query = query.where(_fRating, isGreaterThanOrEqualTo: minRating);
    }

    // Lưu ý: Nếu dùng cả minRating và maxRating, Firestore có thể yêu cầu tạo Composite Index
    if (maxRating != null) {
      query = query.where(_fRating, isLessThanOrEqualTo: maxRating);
    }

    if (specialtyIds != null && specialtyIds.isNotEmpty) {
      query = query.where(
        _fSpecialties,
        arrayContainsAny: specialtyIds.take(10).toList(),
      );
    }

    return query;
  }

  Future<int?> getFilteredHospitalCount({
    String? coSoId,
    String? bhytId,
    double? minRating,
    double? maxRating,
    List<String>? specialtyIds,
  }) async {
    try {
      final query = _buildHospitalQuery(
        coSoId: coSoId,
        bhytId: bhytId,
        minRating: minRating,
        maxRating: maxRating,
        specialtyIds: specialtyIds,
      );
      final snapshot = await query.count().get();
      return snapshot.count;
    } catch (e) {
      debugPrint('❌ Lỗi khi đếm số lượng bệnh viện: $e');
      return null;
    }
  }

  Future<HospitalPageResult> getHospitalsPage({
    String? coSoId,
    String? bhytId,
    double? minRating,
    double? maxRating,
    Position? savedUserLocation,
    double? minDistance,
    double? maxDistance,
    DocumentSnapshot? lastDocument,
    List<String>? specialtyIds,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _buildHospitalQuery(
        coSoId: coSoId,
        bhytId: bhytId,
        minRating: minRating,
        maxRating: maxRating,
        specialtyIds: specialtyIds,
      );

      final hasDistanceFilter = minDistance != null || maxDistance != null;
      final locationResult = hasDistanceFilter
          ? await _locationService.getUserLocationWithSource(savedUserLocation)
          : null;
      final currentUserLocation = locationResult?.position;
      final applyDistanceFilter =
          currentUserLocation != null && hasDistanceFilter;

      query = query
          .orderBy(_fRating, descending: true)
          .orderBy(_fTotalReviews, descending: true)
          .orderBy(FieldPath.documentId);

      List<Map<String, dynamic>> finalPageResults = [];
      DocumentSnapshot? currentCursor = lastDocument;
      bool hasMoreInFirestore = true;

      final fetchBuffer = applyDistanceFilter
          ? (_pageSize * 3).clamp(30, 100)
          : _pageSize;

      while (finalPageResults.length < _pageSize && hasMoreInFirestore) {
        Query<Map<String, dynamic>> pageQuery = query;
        if (currentCursor != null) {
          pageQuery = pageQuery.startAfterDocument(currentCursor);
        }

        final snapshot = await pageQuery.limit(fetchBuffer).get();
        if (snapshot.docs.isEmpty) {
          hasMoreInFirestore = false;
          break;
        }

        List<Map<String, dynamic>> validCandidates = [];

        for (final doc in snapshot.docs) {
          currentCursor = doc;
          final hospital = {...doc.data(), 'id': doc.id};

          final rating = (hospital[_fRating] as num?)?.toDouble() ?? 0.0;
          if (maxRating != null && rating > maxRating) continue;

          if (applyDistanceFilter) {
            final lat = hospital['vi_do'];
            final lon = hospital['kinh_do'];

            if (lat is num && lon is num) {
              final distance = _locationService.calculateDistanceInKm(
                currentUserLocation!.latitude,
                currentUserLocation!.longitude,
                lat.toDouble(),
                lon.toDouble(),
              );
              hospital['distance_km'] = distance;

              if ((minDistance != null && distance < minDistance) ||
                  (maxDistance != null && distance > maxDistance)) {
                continue;
              }
            } else {
              continue;
            }
          }

          validCandidates.add(hospital);
        }

        if (applyDistanceFilter) {
          validCandidates.sort((a, b) {
            final distA = (a['distance_km'] as num).toDouble();
            final distB = (b['distance_km'] as num).toDouble();
            return distA.compareTo(distB);
          });
        }

        for (var candidate in validCandidates) {
          finalPageResults.add(candidate);
          if (finalPageResults.length == _pageSize) break;
        }
      }

      return HospitalPageResult(
        hospitals: finalPageResults,
        lastDocument: currentCursor,
        hasMore: hasMoreInFirestore,
        locationSourceMessage: locationResult?.message,
      );
    } catch (e) {
      debugPrint('❌ Lỗi khi tải danh sách bệnh viện: $e');
      throw Exception('Lỗi khi tải danh sách bệnh viện: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSpecialtiesList() async {
    try {
      final snapshot = await _firestore.collection('chuyen_khoa').get();
      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      debugPrint('❌ Lỗi khi tải danh sách chuyên khoa: $e');
      throw Exception('Lỗi khi tải danh sách chuyên khoa: $e');
    }
  }

  Future<Map<String, dynamic>?> getKhoaById(String kId, String bvId) async {
    try {
      final doc = await _firestore
          .collection('Khoa')
          .doc(bvId)
          .collection('danh_sach')
          .doc(kId)
          .get();

      if (doc.exists) {
        return {...doc.data()!, 'id': doc.id};
      }

      return null;
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy thông tin khoa: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getHospitals() async {
    final snapshot = await _firestore
        .collection('BenhVien')
        .where(_fStatus, isEqualTo: 10)
        .get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  /// Lấy thông tin của 1 bệnh viện dựa trên Document ID
  Future<Map<String, dynamic>?> getHospitalById(String id) async {
    try {
      final doc = await _firestore.collection('BenhVien').doc(id).get();

      if (doc.exists) {
        return {...doc.data()!, 'id': doc.id};
      }

      return null; // Không tìm thấy
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy thông tin bệnh viện: $e');
      return null;
    }
  }

  /// Lấy thông tin của 1 bệnh viện dựa trên Document ID
  Future<Map<String, dynamic>?> getPhongKhamById(String id) async {
    try {
      final doc = await _firestore.collection('BenhVien').doc(id).get();

      if (doc.exists) {
        return {...doc.data()!, 'id': doc.id};
      }

      return null; // Không tìm thấy
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy thông tin bệnh viện: $e');
      return null;
    }
  }

  Future<List<PhongKhamModel>> getPhongKhamList({
    required String hospitalId,
    required String khoaId,
  }) async {
    try {
      // 1. Thử lấy từ subcollection PhongKham/{hospitalId}/danh_sach/{khoaId}/danh_sach
      final subSnapshot = await _firestore
          .collection('PhongKham')
          .doc(hospitalId)
          .collection('danh_sach')
          .doc(khoaId)
          .collection('danh_sach')
          .get();

      if (subSnapshot.docs.isNotEmpty) {
        debugPrint('✅ Tìm thấy ${subSnapshot.docs.length} phòng khám (subcollection).');
        return subSnapshot.docs.map((doc) {
          return PhongKhamModel.fromMap(doc.data(), doc.id);
        }).toList()
          ..sort((a, b) => a.tenPhong.compareTo(b.tenPhong));
      }

      // 2. Dự phòng: Tìm trực tiếp trong root collection PhongKham
      final rootSnap = await _firestore
          .collection(_colPhongKham)
          .where('hospitalId', isEqualTo: hospitalId)
          .where('khoaId', isEqualTo: khoaId)
          .get();

      debugPrint('✅ Tìm thấy ${rootSnap.docs.length} phòng khám (root collection).');
      return rootSnap.docs.map((doc) {
        return PhongKhamModel.fromMap(doc.data(), doc.id);
      }).toList()
        ..sort((a, b) => a.tenPhong.compareTo(b.tenPhong));
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy danh sách phòng khám: $e');
      throw Exception('Lỗi khi lấy danh sách phòng khám: $e');
    }
  }

  Future<int?> getThoiGianKhamPhong({
    required String hospitalId,
    required String khoaId,
    required String phongKhamId,
  }) async {
    final cacheKey = '$hospitalId|$khoaId|$phongKhamId';
    final cached = _thoiGianKhamCache[cacheKey];
    if (cached != null) return cached;

    int? minutes;

    try {
      // 1. Theo ID document của phòng khám
      if (phongKhamId.isNotEmpty) {
        final doc = await _firestore
            .collection(_colPhongKham)
            .doc(phongKhamId)
            .get();

        if (doc.exists) {
          final data = doc.data() ?? <String, dynamic>{};
          final thuocKhoa =
              data['hospitalId']?.toString() == hospitalId &&
              data['khoaId']?.toString() == khoaId;

          if (thuocKhoa) {
            minutes = _soPhutHopLe(data['thoiGianKham'] ?? data['thoi_gian_kham']);
          } else {
            debugPrint(
              '⚠️ PhongKham/$phongKhamId không thuộc $hospitalId/$khoaId',
            );
          }
        }

        // 2. phongKhamId có thể là tên phòng (vd. "NGT003") thay vì ID document
        if (minutes == null && !doc.exists) {
          final byName = await _firestore
              .collection(_colPhongKham)
              .where('hospitalId', isEqualTo: hospitalId)
              .where('khoaId', isEqualTo: khoaId)
              .where('tenPhong', isEqualTo: phongKhamId)
              .limit(1)
              .get();

          if (byName.docs.isNotEmpty) {
            final data = byName.docs.first.data();
            minutes = _soPhutHopLe(data['thoiGianKham'] ?? data['thoi_gian_kham']);
          }
        }
      }

      // 3. Dự phòng: thời gian khám cấu hình ở cấp khoa
      if (minutes == null && hospitalId.isNotEmpty && khoaId.isNotEmpty) {
        final khoaDoc = await _firestore
            .collection('Khoa')
            .doc(hospitalId)
            .collection('danh_sach')
            .doc(khoaId)
            .get();

        final data = khoaDoc.data();
        if (data != null) {
          minutes = _soPhutHopLe(data['thoi_gian_kham'] ?? data['thoiGianKham']);
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi lấy thời gian khám của phòng $phongKhamId: $e');
      return null;
    }

    if (minutes != null) {
      debugPrint('✅ Thời gian khám $hospitalId/$khoaId/$phongKhamId = $minutes phút');
      _thoiGianKhamCache[cacheKey] = minutes;
    } else {
      debugPrint(
        '⚠️ Không tìm thấy thời gian khám cho $hospitalId/$khoaId/$phongKhamId',
      );
    }
    return minutes;
  }
}