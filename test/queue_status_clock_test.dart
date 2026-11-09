import 'package:flutter_test/flutter_test.dart';

import 'package:qldatlich/support_doctor/queue_screen.dart';
import 'package:qldatlich/support_doctor/room_session_store.dart';

void main() {
  group('formatMayGio (mốc giờ máy lúc bấm nút)', () {
    test('luôn định dạng HH:mm:ss với 2 chữ số', () {
      expect(formatMayGio(DateTime(2026, 11, 9, 8, 42, 7)), '08:42:07');
      expect(formatMayGio(DateTime(2026, 11, 9, 23, 5, 0)), '23:05:00');
      expect(formatMayGio(DateTime(2026, 1, 1, 0, 0, 1)), '00:00:01');
    });

    test('chỉ gồm giờ, không kèm ngày/tháng hay múi giờ', () {
      expect(
        formatMayGio(DateTime.now()),
        matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')),
      );
    });

    test('cùng một mốc thời điểm luôn cho cùng một chuỗi (không tự nhảy)', () {
      final mocGio = DateTime(2026, 11, 9, 8, 42, 7);
      expect(formatMayGio(mocGio), formatMayGio(mocGio));
    });
  });

  group('RoomSessionSnapshot', () {
    test('giữ mốc giờ thay đổi trạng thái khi rời/mở lại phòng', () {
      final snapshot = RoomSessionSnapshot();
      expect(snapshot.statusChangedAt, isNull);
      expect(snapshot.statusChangeLabel, isEmpty);

      final mocGio = DateTime(2026, 11, 9, 8, 42, 7);
      snapshot
        ..statusChangedAt = mocGio
        ..statusChangeLabel = 'Tạm dừng lúc';

      expect(snapshot.statusChangedAt, mocGio);
      expect(snapshot.statusChangeLabel, 'Tạm dừng lúc');
    });
  });
}
