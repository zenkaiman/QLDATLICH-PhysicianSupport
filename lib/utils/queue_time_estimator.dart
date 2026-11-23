
class QueueTimeEstimator {
  QueueTimeEstimator({
    this.baseMinutes = 20,
    this.stepMinutes = 5,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int baseMinutes;
  final int stepMinutes;
  final DateTime Function() _clock;

  int? _servingNumber;
  DateTime? _servingSince;


  ({int perPatient, int overrunSteps}) update(
    int currentServing, {
    DateTime? startedAt,
  }) {
    if (currentServing <= 0) {
      reset();
      return (perPatient: baseMinutes, overrunSteps: 0);
    }

    final now = _clock();
    if (_servingNumber != currentServing) {
      _servingNumber = currentServing;
      _servingSince = startedAt ?? now;
    } else if (startedAt != null) {
      _servingSince = startedAt;
    }

    final elapsedSec = now.difference(_servingSince!).inSeconds;
    final baseSec = baseMinutes * 60;
    final stepSec = stepMinutes * 60;

    final steps = elapsedSec > baseSec
        ? ((elapsedSec - baseSec) / stepSec).ceil()
        : 0;

    return (perPatient: baseMinutes + steps * stepMinutes, overrunSteps: steps);
  }

  /// Tổng số phút chờ = số người phía trước x số phút/người.
  int waitMinutes(int peopleAhead, int perPatient) =>
      peopleAhead <= 0 ? 0 : peopleAhead * perPatient;

  void reset() {
    _servingNumber = null;
    _servingSince = null;
  }
}