import '../utils/text_utils.dart';

/// _Scored: bệnh viện kèm điểm phù hợp và vị trí ban đầu trong danh sách.
class _Scored {
  final Map<String, dynamic> hospital;
  final int score;
  final int index;
  _Scored(this.hospital, this.score, this.index);
}

/// searchHospitals: tìm bệnh viện theo tên hoặc địa chỉ, không phân biệt hoa thường và dấu.
/// Bệnh viện phải chứa tất cả các từ khóa; kết quả xếp theo độ phù hợp (tên trùng hoặc bắt đầu bằng từ khóa lên trước), bằng điểm thì giữ thứ tự ban đầu.
List<Map<String, dynamic>> searchHospitals(
  List<Map<String, dynamic>> hospitals,
  String keyword,
) {
  // Bước 1: chuẩn hóa từ khóa (bỏ dấu, chữ thường); rỗng thì trả về nguyên danh sách.
  final q = normalizeText(keyword);
  if (q.isEmpty) return hospitals;

  // Bước 2: tách từ khóa thành từng từ để so khớp riêng lẻ.
  final tokens = q.split(' ');
  final results = <_Scored>[];

  for (var i = 0; i < hospitals.length; i++) {
    // Bước 3: chuẩn hóa tên và địa chỉ, ghép thành một chuỗi để tìm kiếm.
    final h = hospitals[i];
    final name = normalizeText(h['ten_benh_vien']?.toString() ?? '');
    final address = normalizeText(h['dia_chi']?.toString() ?? '');
    final haystack = '$name $address';

    // Bước 4: loại bệnh viện không chứa đủ tất cả các từ khóa (ở tên hoặc địa chỉ).
    if (!tokens.every((t) => haystack.contains(t))) continue;

    // Bước 5: chấm điểm theo độ phù hợp của tên (trùng hoàn toàn > bắt đầu bằng > có chứa).
    var score = 0;
    if (name == q) {
      score += 100;
    } else if (name.startsWith(q)) {
      score += 60;
    } else if (name.contains(q)) {
      score += 40;
    }

    // Bước 6: cộng thêm điểm nếu tất cả các từ khóa đều nằm trong tên.
    if (tokens.every((t) => name.contains(t))) score += 20;

    results.add(_Scored(h, score, i));
  }

  // Bước 7: sắp xếp điểm cao trước, bằng điểm thì giữ thứ tự ban đầu.
  results.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });

  // Bước 8: trả về danh sách bệnh viện đã sắp xếp.
  return results.map((r) => r.hospital).toList();
}