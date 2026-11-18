import '../utils/text_utils.dart';

class _Scored {
  final Map<String, dynamic> hospital;
  final int score;
  final int index;
  _Scored(this.hospital, this.score, this.index);
}

/// Tìm bệnh viện theo tên hoặc địa chỉ.
/// - Không phân biệt hoa/thường, có dấu hay không dấu ("cho ray" tìm ra "Chợ Rẫy")
/// - Nhiều từ: bệnh viện phải chứa TẤT CẢ các từ ("nhi dong" -> "Nhi Đồng 1")
/// - Kết quả sắp theo độ phù hợp: tên trùng/bắt đầu bằng từ khoá lên trước
List<Map<String, dynamic>> searchHospitals(
  List<Map<String, dynamic>> hospitals,
  String keyword,
) {
  final q = normalizeText(keyword);
  if (q.isEmpty) return hospitals;

  final tokens = q.split(' ');
  final results = <_Scored>[];

  for (var i = 0; i < hospitals.length; i++) {
    final h = hospitals[i];
    final name = normalizeText(h['ten_benh_vien']?.toString() ?? '');
    final address = normalizeText(h['dia_chi']?.toString() ?? '');
    final haystack = '$name $address';

    // Phải chứa tất cả các từ khoá (ở tên hoặc địa chỉ)
    if (!tokens.every((t) => haystack.contains(t))) continue;

    var score = 0;
    if (name == q) {
      score += 100;
    } else if (name.startsWith(q)) {
      score += 60;
    } else if (name.contains(q)) {
      score += 40;
    }
    if (tokens.every((t) => name.contains(t))) score += 20; // khớp hết ở tên

    results.add(_Scored(h, score, i));
  }

  // Điểm cao trước; bằng điểm thì giữ nguyên thứ tự ban đầu
  results.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });

  return results.map((r) => r.hospital).toList();
}