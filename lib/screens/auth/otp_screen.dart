import 'dart:async';
import 'package:flutter/material.dart';

class OtpScreen extends StatefulWidget {
  final String phone;

  final Future<void> Function(String code) onVerify;
  final VoidCallback onResend;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.onVerify,
    required this.onResend,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _primary = Color(0xFF1E78E0);
  static const _grey = Color(0xFF64748B);
  static const _resendSeconds = 60;

  final _otpCtrl = TextEditingController();
  Timer? _timer;
  bool _isLoading = false;
  int _countdown = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  /// _startCountdown: bắt đầu đếm ngược 60 giây trước khi cho phép gửi lại mã.
  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown <= 1) {
        t.cancel();
      }
      setState(() => _countdown--);
    });
  }

  /// _handleResend: gửi lại mã OTP và khởi động lại bộ đếm.
  void _handleResend() {
    widget.onResend();
    _startCountdown();
  }

  /// _handleVerify: kiểm tra đủ 6 số rồi gọi onVerify để xác thực mã.
  Future<void> _handleVerify() async {
    if (_otpCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ 6 mã số OTP')),
      );
      return;
    }
    setState(() => _isLoading = true);
    await widget.onVerify(_otpCtrl.text.trim());
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _countdown <= 0 && !_isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Xác thực số điện thoại',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Chúng tôi đã gửi mã OTP gồm 6 số đến ${widget.phone}. Vui lòng nhập mã để tiếp tục.',
                style: const TextStyle(fontSize: 15, color: _grey),
              ),

              const SizedBox(height: 32),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  hintStyle: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    letterSpacing: 8,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _primary, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: canResend ? _handleResend : null,
                  child: Text(
                    canResend
                        ? 'Gửi lại mã OTP'
                        : 'Gửi lại mã sau ${_countdown > 0 ? _countdown : 0}s',
                    style: TextStyle(
                      color: canResend ? _primary : _grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Xác nhận',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
