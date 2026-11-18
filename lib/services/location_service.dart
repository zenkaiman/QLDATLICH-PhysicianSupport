import 'package:geolocator/geolocator.dart';

class UserLocationResult {
  final Position? position;
  final String message;

  const UserLocationResult({required this.position, required this.message});
}

class LocationService {
  /// Lấy vị trí người dùng: Ưu tiên GPS, nếu tắt thì lấy vị trí đã lưu
  Future<Position?> getUserLocation(Position? savedLocation) async {
    return (await getUserLocationWithSource(savedLocation)).position;
  }

  Future<UserLocationResult> getUserLocationWithSource(
    Position? savedLocation,
  ) async {
    try {
      // 1. Kiểm tra dịch vụ định vị có bật không
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _savedLocationResult(savedLocation);
      }

      // 2. Kiểm tra quyền truy cập
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _savedLocationResult(savedLocation);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _savedLocationResult(savedLocation);
      }

      // 3. Nếu mọi thứ OK, lấy vị trí hiện tại
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

  UserLocationResult _savedLocationResult(Position? savedLocation) {
    return UserLocationResult(
      position: savedLocation,
      message: savedLocation == null
          ? 'Chưa xác định được vị trí; bộ lọc khoảng cách chưa áp dụng'
          : 'Không lấy được GPS, đang dùng vị trí đã lưu',
    );
  }

  /// Tính khoảng cách giữa 2 điểm (Trả về đơn vị km)
  double calculateDistanceInKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    double distanceInMeters = Geolocator.distanceBetween(
      lat1,
      lon1,
      lat2,
      lon2,
    );
    return distanceInMeters / 1000; // Đổi sang km
  }
}
