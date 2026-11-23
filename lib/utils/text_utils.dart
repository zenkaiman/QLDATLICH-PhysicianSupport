const _vietnameseGroups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _vietnameseMap = {
  for (final e in _vietnameseGroups.entries)
    for (final c in e.value.split('')) c: e.key,
};

final RegExp _combiningMarks = RegExp(r'[\u0300-\u036f]');

/// "Bệnh viện Chợ Rẫy " -> "benh vien cho ray"
String normalizeText(String input) {
  final lower = input.toLowerCase().replaceAll(_combiningMarks, '');
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    buffer.write(_vietnameseMap[ch] ?? ch);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
