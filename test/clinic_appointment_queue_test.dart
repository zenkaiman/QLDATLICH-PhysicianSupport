import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qldatlich/support_doctor/clinic_firestore_service.dart';

void main() {
  group('STT lấy đủ lịch hẹn Firestore', () {
    final queueDay = DateTime(2026, 11, 23);

    test('không bỏ lịch có ngay_dat dạng Firestore Timestamp', () {
      final update = clinicAppointmentQueueFromFirestore(
        appointments: <(String, Map<String, Object?>)>[
          (
            'BV1_K1_LH_23112026_00001',
            <String, Object?>{
              'benh_vien_id': 'BV1',
              'phong_kham_id': 'PK1',
              'trang_thai_id': '2',
              'so_thu_tu': 1,
              'ngay_dat': Timestamp.fromDate(DateTime(2026, 11, 23, 9)),
            },
          ),
          (
            'BV1_K1_LH_23112026_00002',
            <String, Object?>{
              'benh_vien_id': 'BV1',
              'phong_kham_id': 'PK1',
              'trang_thai_id': 2,
              'so_thu_tu': 2,
              'ngay_dat': Timestamp.fromDate(DateTime(2026, 11, 23, 10)),
            },
          ),
        ],
        hospitalId: 'BV1',
        roomId: 'PK1',
        day: queueDay,
      );

      expect(update.numbers, <int>[1, 2]);
      expect(update.appointmentIdByNumber.keys, containsAll(<int>[1, 2]));
    });

    test('đọc ngày từ định dạng cũ dd/MM/yyyy và tên trường ngay_kham', () {
      final day = clinicAppointmentDay('legacy-appointment', <String, Object?>{
        'ngay_kham': '23/11/2026',
      });

      expect(day, DateTime(2026, 11, 23));
    });

    test('fallback từ mã lịch mới dùng định dạng DDMMYYYY', () {
      final day = clinicAppointmentDay(
        'BV1_K1_LH_23112026_00001',
        <String, Object?>{},
      );

      expect(day, DateTime(2026, 11, 23));
    });

    test('ưu tiên đúng trường so_thu_tu của Firebase, không lấy alias cũ', () {
      expect(
        clinicAppointmentNumber(<String, Object?>{
          'so_thu_tu': '27',
          'stt': 8,
        }),
        27,
      );
      expect(
        clinicAppointmentNumber(<String, Object?>{
          'so_thu_tu': null,
          'stt': 8,
        }),
        isNull,
        reason: 'khóa chuẩn có mặt thì không thay bằng một STT khác',
      );
    });

    test('nhận số nguyên dạng số hoặc chuỗi, không làm tròn số thập phân', () {
      expect(clinicAppointmentNumber(<String, Object?>{'so_thu_tu': 12}), 12);
      expect(clinicAppointmentNumber(<String, Object?>{'so_thu_tu': '12'}), 12);
      expect(
        clinicAppointmentNumber(<String, Object?>{'so_thu_tu': 12.5}),
        isNull,
      );
    });
  });
}
