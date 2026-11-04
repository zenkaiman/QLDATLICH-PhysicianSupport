import 'package:flutter/material.dart';

class BookingProvider extends ChangeNotifier {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> bookAppointment({
    required String doctorId,
    required String patientId,
    required DateTime date,
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 500));

    _isLoading = false;
    notifyListeners();
  }
}
