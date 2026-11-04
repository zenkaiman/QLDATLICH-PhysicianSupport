String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập email';
  }

  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  if (!emailRegex.hasMatch(value.trim())) {
    return 'Email không hợp lệ';
  }

  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Vui lòng nhập mật khẩu';
  }

  if (value.length < 6) {
    return 'Mật khẩu phải có ít nhất 6 ký tự';
  }

  return null;
}

String? validatePhone(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập số điện thoại';
  }

  if (!RegExp(r'^[0-9]{9,11}$').hasMatch(value.trim())) {
    return 'Số điện thoại không hợp lệ';
  }

  return null;
}
