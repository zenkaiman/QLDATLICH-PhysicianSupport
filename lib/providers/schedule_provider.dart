import 'package:flutter/material.dart';

class ScheduleProvider extends ChangeNotifier {
  List<DateTime> _schedule = const [];

  List<DateTime> get schedule => _schedule;

  /// setSchedule: cập nhật giá trị state.
  void setSchedule(List<DateTime> dates) {
    _schedule = dates;
    notifyListeners();
  }
}
