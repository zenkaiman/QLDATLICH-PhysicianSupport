import 'dart:convert';
import 'dart:io';
import 'dart:math';

void main() async {
  // 1. Đọc file GeoJSON (danh sách bệnh viện)
  final geoJsonFile = File('hospital.geoJson');
  if (!geoJsonFile.existsSync()) {
    print('❌ Không tìm thấy file: hospital.geoJson');
    return;
  }

  final geoJsonString = await geoJsonFile.readAsString();
  final geoJsonData = jsonDecode(geoJsonString);

  List<dynamic> features = [];
  if (geoJsonData is Map && geoJsonData['features'] is List) {
    features = geoJsonData['features'];
  } else {
    print('❌ Cấu trúc GeoJSON không hợp lệ.');
    return;
  }

  // 2. Đọc file JSON chứa 30 chuyên khoa
  final specialtiesFile = File('specialties.json');
  if (!specialtiesFile.existsSync()) {
    print('❌ Không tìm thấy file: specialties.json');
    print('💡 Hãy export dữ liệu từ Firebase collection "chuyen_khoa" ra file này.');
    return;
  }

  final specialtiesString = await specialtiesFile.readAsString();
  final specialtiesList = jsonDecode(specialtiesString) as List;

  if (specialtiesList.isEmpty) {
    print('❌ File specialties.json rỗng hoặc không hợp lệ.');
    return;
  }

  print('📊 Đã tải ${specialtiesList.length} chuyên khoa từ Firebase.');
  print('📊 Đã tải ${features.length} bệnh viện từ GeoJSON.');

  final random = Random();
  int congLapCount = 0;
  int coBhytCount = 0;

  // 3. Tạo file output
  final outputFile = File('hospital_seeder_output.dart');
  final sink = outputFile.openWrite();

  sink.writeln('// ✅ DỮ LIỆU ĐÃ ĐƯỢC TỰ ĐỘNG GHI VÀO FILE: hospital_seeder_output.dart');
  sink.writeln('// ✅ BAO GỒM 2 TRƯỜNG MỚI: chuyen_khoa_ids và ten_cac_khoa');
  sink.writeln('// ✅ HÃY COPY TOÀN BỘ NỘI DUNG FILE NÀY VÀ DÁN VÀO _hospitals TRONG HospitalSeeder:\n');
  sink.writeln('static final List<Map<String, dynamic>> _hospitals = [');

  for (int i = 0; i < features.length; i++) {
    final feature = features[i];
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final geom = feature['geometry'] as Map<String, dynamic>?;

    final coords = geom?['coordinates'] as List<dynamic>?;
    if (coords == null || coords.length < 2) continue;

    final lon = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();

    // 1. Tên bệnh viện
    String name = props['name'] ?? 'Cơ sở y tế ${i + 1}';
    String cleanName = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanName.isEmpty) cleanName = 'benhvien';

    // 2. Địa chỉ
    String address = props['addr:full'] ?? '';
    if (address.isEmpty) {
      String number = props['addr:housenumber'] != null ? '${props['addr:housenumber']}, ' : '';
      String street = props['addr:street'] ?? 'Đường chưa rõ tên';
      String ward = props['addr:subdistrict'] != null ? '${props['addr:subdistrict']}, ' : '';
      String district = props['addr:district'] != null ? '${props['addr:district']}, ' : '';
      String city = props['addr:city'] ?? props['addr:province'] ?? 'Việt Nam';
      address = '${number}${street}, ${ward}${district}${city}'
          .replaceAll(RegExp(r', ,'), ', ')
          .replaceAll(RegExp(r'  '), ' ')
          .trim();
    }

    // 3. Email
    String email = props['email'] ?? props['contact:email'] ?? '';
    if (email.isEmpty) {
      email = '${cleanName}${i + 1}@gmail.com';
    }

    // 4. Phân bổ ngẫu nhiên
    String coSo = (congLapCount < 350) ? 'Cong_lap' : 'Tu_nhan';
    if (coSo == 'Cong_lap') congLapCount++;

    String bhyt = (coBhytCount < 400) ? 'Co_BHYT' : 'Khong_BHYT';
    if (bhyt == 'Co_BHYT') coBhytCount++;

    // 5. Số liệu ngẫu nhiên
    double rating = 3.0 + (random.nextDouble() * 2.0);
    int reviews = 100 + random.nextInt(201);

    // 6. ✅ RANDOM 3-6 CHUYÊN KHOA TỪ DANH SÁCH 30
    final numSpecialties = random.nextInt(4) + 3; // Random từ 3 đến 6
    final shuffledSpecialties = List<Map<String, dynamic>>.from(
      specialtiesList.map((e) => Map<String, dynamic>.from(e as Map)),
    )..shuffle(random);
    
    final selectedSpecialties = shuffledSpecialties.take(numSpecialties).toList();
    
    // Trích xuất ID và tên
    final specialtyIds = selectedSpecialties.map((s) => s['id'] as String).toList();
    final specialtyNames = selectedSpecialties.map((s) => s['ten_khoa'] as String).toList();

    final maBenhVien = 'BV${(i + 1).toString().padLeft(3, '0')}';

    // Ghi vào file
    sink.writeln("  {");
    sink.writeln("    'ma_benh_vien': '$maBenhVien',");
    sink.writeln("    'ten_benh_vien': '${name.replaceAll("'", "\\'")}',");
    sink.writeln("    'dia_chi': '${address.replaceAll("'", "\\'")}',");
    sink.writeln("    'hinh_anh': '',");
    sink.writeln("    'trang_thai_hop_tac_id': 10,");
    sink.writeln("    'diem_danh_gia_tb': ${rating.toStringAsFixed(1)},");
    sink.writeln("    'tong_so_danh_gia': $reviews,");
    sink.writeln("    'co_so': '$coSo',");
    sink.writeln("    'bhyt': '$bhyt',");
    sink.writeln("    'email': '$email',");
    sink.writeln("    'role': 'benh_vien',");
    sink.writeln("    'da_xac_thuc_email': true,");
    sink.writeln("    'vi_do': $lat,");
    sink.writeln("    'kinh_do': $lon,");
    
    // ✅ GHI 2 TRƯỜNG MỚI: DANH SÁCH CHUYÊN KHOA
    sink.writeln("    'chuyen_khoa_ids': ${jsonEncode(specialtyIds)},");
    sink.writeln("    'ten_cac_khoa': ${jsonEncode(specialtyNames)},");
    
    sink.writeln("  },");
  }

  sink.writeln('];');

  await sink.close();

  print('\n✅ ĐÃ HOÀN TẤT! Dữ liệu đã được ghi vào file: hospital_seeder_output.dart');
  print('📊 Thống kê: $congLapCount Công lập, ${features.length - congLapCount} Tư nhân.');
  print('📊 Thống kê: $coBhytCount Có BHYT, ${features.length - coBhytCount} Không BHYT.');
  print('📊 Mỗi bệnh viện có từ 3-6 chuyên khoa ngẫu nhiên từ 30 chuyên khoa gốc.');
}