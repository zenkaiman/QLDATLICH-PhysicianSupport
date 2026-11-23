import 'package:geolocator/geolocator.dart';

class UserLocationResult {
  final Position? position;
  final String message;

  const UserLocationResult({required this.position, required this.message});
}

class LocationService {
  /// getUserLocation: lấy vị trí người dùng, ưu tiên GPS, không được thì dùng vị trí đã lưu.
  Future<Position?> getUserLocation(Position? savedLocation) async {
    return (await getUserLocationWithSource(savedLocation)).position;
  }

  /// getUserLocationWithSource: lấy vị trí kèm thông báo nguồn vị trí; GPS tắt, bị từ chối quyền hoặc lỗi thì dùng vị trí đã lưu.
  Future<UserLocationResult> getUserLocationWithSource(
    Position? savedLocation,
  ) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _savedLocationResult(savedLocation);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _savedLocationResult(savedLocation);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _savedLocationResult(savedLocation);
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return UserLocationResult(
        position: position,
        message: 'Đang dùng vị trí hiện tại của bạn',
      );
    } catch (e) {
      return _savedLocationResult(savedLocation);
    }
  }

  /// calculateDistanceInKm: tính khoảng cách giữa hai điểm, trả về đơn vị km.
  double calculateDistanceInKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final distanceInMeters = Geolocator.distanceBetween(
      lat1,
      lon1,
      lat2,
      lon2,
    );
    return distanceInMeters / 1000;
  }

  /// _savedLocationResult: dựng kết quả từ vị trí đã lưu kèm thông báo (chưa có vị trí thì bộ lọc khoảng cách không áp dụng).
  UserLocationResult _savedLocationResult(Position? savedLocation) {
    return UserLocationResult(
      position: savedLocation,
      message: savedLocation == null
          ? 'Chưa xác định được vị trí; bộ lọc khoảng cách chưa áp dụng'
          : 'Không lấy được GPS, đang dùng vị trí đã lưu',
    );
  }
}