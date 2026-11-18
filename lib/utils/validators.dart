// ───────────────────────── Kiểm tra email ─────────────────────────

// Định dạng email: không cho dấu chấm liền nhau / đầu / cuối, tên miền không bắt đầu
// hay kết thúc bằng dấu gạch ngang, đuôi tên miền từ 2 chữ cái trở lên.
final RegExp _emailRegex = RegExp(
  r'^[a-zA-Z0-9]+([._%+\-][a-zA-Z0-9]+)*@([a-zA-Z0-9]+(-[a-zA-Z0-9]+)*\.)+[a-zA-Z]{2,}$',
);

// Tên miền phổ biến: dùng để phát hiện gõ nhầm (gailm.com -> gmail.com).
const List<String> _popularEmailDomains = [
  'gmail.com',
  'yahoo.com',
  'yahoo.com.vn',
  'outlook.com',
  'hotmail.com',
  'icloud.com',
  'live.com',
  'msn.com',
  'me.com',
  'aol.com',
  'protonmail.com',
  'zoho.com',
];

// Tên miền hợp lệ khác: không bị coi là gõ nhầm dù giống tên miền phổ biến.
// Nếu một tên miền thật bị báo nhầm, thêm nó vào danh sách này.
const List<String> _safeEmailDomains = [
  'mail.com',
  'email.com',
  'ymail.com',
  'rocketmail.com',
  'gmx.com',
  'proton.me',
  'pm.me',
  'yandex.com',
];

// Khoảng cách chỉnh sửa giữa hai chuỗi (số lần thêm / xóa / sửa ký tự).
int _editDistance(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final current = <int>[i];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final best = [
        prev[j] + 1,
        current[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      current.add(best);
    }
    prev = current;
  }
  return prev[b.length];
}

// Gợi ý email đúng khi tên miền giống tên miền phổ biến nhưng bị gõ sai.
// Trả về null nếu tên miền không có vẻ gõ sai.
String? suggestEmailDomain(String email) {
  final parts = email.trim().split('@');
  if (parts.length != 2) return null;

  final domain = parts[1].toLowerCase();
  if (_popularEmailDomains.contains(domain) ||
      _safeEmailDomains.contains(domain)) {
    return null;
  }

  String? best;
  var bestDistance = 99;
  for (final popular in _popularEmailDomains) {
    final distance = _editDistance(domain, popular);
    final limit = popular.length >= 9 ? 2 : 1;
    if (distance <= limit && distance < bestDistance) {
      best = popular;
      bestDistance = distance;
    }
  }
  return best == null ? null : '${parts[0]}@$best';
}

String? validatePassword(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập mật khẩu';
  }
  if (value.contains(' ')) {
    return 'Mật khẩu không được chứa dấu cách';
  }
  if (value.length < 6) {
    return 'Mật khẩu phải có ít nhất 6 ký tự';
  }

  return null; // ✅ Dòng này bắt buộc phải có để báo hợp lệ
}

// Kiểm tra email: không rỗng, đúng định dạng, tên miền không gõ nhầm.
String? validateEmail(String? value) {
  final email = (value ?? '').trim();

  if (email.isEmpty) return 'Vui lòng nhập email';
  if (email.length > 254 || !_emailRegex.hasMatch(email)) {
    return 'Email không hợp lệ (VD: abc@gmail.com)';
  }

  final suggestion = suggestEmailDomain(email);
  if (suggestion != null) {
    return 'Email có thể bị gõ sai. Ý bạn là $suggestion?';
  }
  return null;
}

// ───────────────────────── Kiểm tra số điện thoại ─────────────────────────

// Kiểm tra số điện thoại: bỏ khoảng trắng / dấu chấm / gạch ngang, rồi cần 9-11 chữ số.
String? validatePhone(String? value) {
  final phone = (value ?? '').replaceAll(RegExp(r'[\s.\-]'), '');

  if (phone.isEmpty) return 'Vui lòng nhập số điện thoại';
  if (!RegExp(r'^[0-9]{9,11}$').hasMatch(phone)) {
    return 'Số điện thoại không hợp lệ';
  }
  return null;
}
