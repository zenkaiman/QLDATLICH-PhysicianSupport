import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Kết quả địa chỉ được chọn từ bản đồ kèm tọa độ
class DiaChiMapItem {
  final String diaChiDayDu;
  final String tenNgan;
  final double viDo;
  final double kinhDo;

  const DiaChiMapItem({
    required this.diaChiDayDu,
    required this.tenNgan,
    required this.viDo,
    required this.kinhDo,
  });
}

/// Dịch vụ quy đổi địa chỉ thành tọa độ (Geocoding & Reverse Geocoding)
class GeocodingService {
  /// Danh sách các địa chỉ cơ sở y tế / khu vực phổ biến tại Việt Nam làm dữ liệu mẫu dự phòng
  static const List<DiaChiMapItem> diaChiPhoBien = [
    DiaChiMapItem(
      diaChiDayDu:
          '11 Đường Linh Trung, Phường Linh Trung, Thành phố Thủ Đức, TP. Hồ Chí Minh',
      tenNgan: '11 Linh Trung, Thủ Đức',
      viDo: 10.86012,
      kinhDo: 106.77234,
    ),
    DiaChiMapItem(
      diaChiDayDu:
          '201 Nguyễn Chí Thanh, Phường 12, Quận 5, TP. Hồ Chí Minh',
      tenNgan: 'Bệnh viện Chợ Rẫy (Quận 5)',
      viDo: 10.75782,
      kinhDo: 106.65985,
    ),
    DiaChiMapItem(
      diaChiDayDu:
          '215 Hồng Bàng, Phường 11, Quận 5, TP. Hồ Chí Minh',
      tenNgan: 'Bệnh viện Đại học Y Dược TP.HCM',
      viDo: 10.75545,
      kinhDo: 106.66092,
    ),
    DiaChiMapItem(
      diaChiDayDu:
          '29 Nguyễn Thị Diệu, Phường Võ Thị Sáu, Quận 3, TP. Hồ Chí Minh',
      tenNgan: 'Bệnh viện Da Liễu TP.HCM',
      viDo: 10.77665,
      kinhDo: 106.68832,
    ),
    DiaChiMapItem(
      diaChiDayDu:
          '78 Giải Phóng, Phường Phương Mai, Quận Đống Đa, Hà Nội',
      tenNgan: 'Bệnh viện Bạch Mai (Hà Nội)',
      viDo: 20.99965,
      kinhDo: 105.84152,
    ),
    DiaChiMapItem(
      diaChiDayDu:
          '124 Hải Phòng, Phường Thạch Thang, Quận Hải Châu, TP. Đà Nẵng',
      tenNgan: 'Bệnh viện Đà Nẵng',
      viDo: 16.07231,
      kinhDo: 108.21654,
    ),
  ];

  /// Tìm kiếm địa chỉ: gọi API OpenStreetMap, nếu lỗi hoặc rỗng thì dùng local search & fallback
  static Future<List<DiaChiMapItem>> timKiemDiaChi(String query) async {
    final q = query.trim();
    if (q.isEmpty) return diaChiPhoBien;

    final results = <DiaChiMapItem>[];

    // 1. Thử gọi API Nominatim
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&addressdetails=1&countrycodes=vn&limit=6',
      );
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'QLDatLichHospitalApp/1.0',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes));
        if (list is List && list.isNotEmpty) {
          for (final item in list) {
            final lat =
                double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0;
            final lon =
                double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0;
            final displayName = (item['display_name'] ?? '').toString();
            final name = (item['name'] ??
                    (displayName.contains(',')
                        ? displayName.split(',').first
                        : displayName))
                .toString();

            if (lat != 0.0 && lon != 0.0 && displayName.isNotEmpty) {
              results.add(DiaChiMapItem(
                diaChiDayDu: displayName,
                tenNgan: name,
                viDo: lat,
                kinhDo: lon,
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [GeocodingService] API lookup: $e');
    }

    // 2. Nếu API không trả về kết quả, lọc từ danh sách mẫu
    if (results.isEmpty) {
      final qLower = q.toLowerCase();
      final localMatches = diaChiPhoBien.where((item) {
        return item.diaChiDayDu.toLowerCase().contains(qLower) ||
            item.tenNgan.toLowerCase().contains(qLower);
      }).toList();
      results.addAll(localMatches);
    }

    // 3. Luôn đảm bảo có ít nhất 1 kết quả dựa trên chính chuỗi người dùng đã nhập
    if (results.isEmpty) {
      // Ước tính tọa độ theo từ khóa TP.HCM hoặc Hà Nội
      double lat = 10.86012;
      double lon = 106.77234;
      final qLower = q.toLowerCase();
      if (qLower.contains('hà nội') || qLower.contains('ha noi')) {
        lat = 21.0285;
        lon = 105.8542;
      } else if (qLower.contains('đà nẵng') || qLower.contains('da nang')) {
        lat = 16.0544;
        lon = 108.2022;
      } else if (qLower.contains('quận 1') || qLower.contains('bến thành')) {
        lat = 10.7769;
        lon = 106.7009;
      } else if (qLower.contains('thủ đức') || qLower.contains('linh trung')) {
        lat = 10.86012;
        lon = 106.77234;
      }

      results.add(DiaChiMapItem(
        diaChiDayDu: q,
        tenNgan: q.contains(',') ? q.split(',').first.trim() : q,
        viDo: lat,
        kinhDo: lon,
      ));
    }

    return results;
  }

  /// Tra ngược tọa độ GPS thành địa chỉ (Reverse Geocoding)
  static Future<DiaChiMapItem?> traNguocToaDo(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1',
      );
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'QLDatLichHospitalApp/1.0',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map) {
          final displayName = (data['display_name'] ?? '').toString();
          if (displayName.isNotEmpty) {
            final name = displayName.contains(',')
                ? displayName.split(',').first
                : displayName;
            return DiaChiMapItem(
              diaChiDayDu: displayName,
              tenNgan: name,
              viDo: lat,
              kinhDo: lon,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [GeocodingService] Reverse geocode lookup: $e');
    }

    // Dự phòng khi offline
    return DiaChiMapItem(
      diaChiDayDu:
          'Tọa độ: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)} (Việt Nam)',
      tenNgan: 'Vị trí hiện tại của thiết bị',
      viDo: lat,
      kinhDo: lon,
    );
  }
}
