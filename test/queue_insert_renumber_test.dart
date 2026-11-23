import 'package:flutter_test/flutter_test.dart';
import 'package:qldatlich/support_doctor/queue_screen.dart';

/// Lỗi gốc: khi khoa chỉ còn 1–3 số trong hàng chờ, bấm “Chèn” thì số vừa
/// chèn được đánh dấu bằng "số tạm ÂM" (‑1, ‑2…) rồi bị chính bước đánh số
/// lại xoá mất (vì lọc `so <= 0`). Kết quả: không có lỗi nào hiện ra nhưng
/// số không vào hàng chờ, hoặc bị đẩy sang mục “SỐ CHỜ TỚI SỐ MỐC”.
///
/// Test khoá lại ba quy tắc:
///  1. số tạm âm phải luôn được đổi thành số thật > 0;
///  2. không được tạo số trùng;
///  3. số vừa chèn phải nằm NGAY SAU số mốc của nó.
List<int> apDung(List<int> order) {
  final renumber = tinhBangDanhSoLai(order: order);
  return <int>[for (final so in order) renumber[so] ?? so];
}

void main() {
  group('Đánh số lại hàng chờ sau khi chèn (khoa chỉ có 1–3 số)', () {
    test('số chèn nằm ngay sau số mốc khi chỉ có 3 số', () {
      // Đang khám 1, tiếp theo 2, hàng chờ [3]; bệnh nhân số 2 xin đợi rồi
      // được chèn lại ngay sau số 1.
      final ketQua = apDung(<int>[1, -1, 2]);
      expect(ketQua, <int>[1, 2, 3]);
    });

    test('chèn lên đầu hàng chờ khi chưa bấm Bắt đầu', () {
      // Hàng chờ [1, 3]; chèn lên đầu (nhập 0).
      final ketQua = apDung(<int>[-1, 1, 3]);
      expect(
        ketQua.first,
        1,
        reason: 'số vừa chèn phải nhận số 1, không phải 0',
      );
      expect(ketQua.toSet().length, ketQua.length, reason: 'không trùng số');
    });

    test('hàng chờ chỉ còn đúng số vừa chèn', () {
      final ketQua = apDung(<int>[-1]);
      expect(ketQua, hasLength(1));
      expect(ketQua.single, greaterThan(0));
    });

    test('không có số tạm thì giữ nguyên hàng chờ', () {
      expect(apDung(<int>[1, 2, 3]), <int>[1, 2, 3]);
    });

    test('mọi số tạm âm đều được đổi thành số thật, không trùng', () {
      final ketQua = apDung(<int>[1, -1, -2, 3]);
      expect(ketQua.every((so) => so > 0), isTrue);
      expect(ketQua.toSet().length, ketQua.length);
      expect(ketQua.first, 1);
      expect(ketQua.last, 3);
    });

    test('giữ đúng vị trí ngay sau số mốc', () {
      // order: đang khám 1, số chèn (-1) đứng ngay sau 1, rồi 2, 3.
      final ketQua = apDung(<int>[1, -1, 2, 3]);
      expect(ketQua, <int>[1, 2, 3, 4]);
    });
  });

  group('waitingAfterInserts: giữ đúng khe chèn', () {
    test('chèn ngay sau số mốc đang có trong hàng chờ', () {
      final ketQua = waitingAfterInserts(
        waiting: <int>[1, 2, 3],
        inserts: <InsertResult>[(number: -1, afterNumber: 2)],
        nextNumber: 0,
      );
      expect(ketQua, <int>[1, 2, -1, 3]);
    });

    test('nhập 0 thì lên đầu hàng chờ', () {
      final ketQua = waitingAfterInserts(
        waiting: <int>[1, 3],
        inserts: <InsertResult>[(number: -1, afterNumber: null)],
        nextNumber: 0,
      );
      expect(ketQua, <int>[-1, 1, 3]);
    });

    test('số mốc là số tiếp theo thì chèn vào đầu hàng chờ', () {
      final ketQua = waitingAfterInserts(
        waiting: <int>[3],
        inserts: <InsertResult>[(number: -1, afterNumber: 2)],
        nextNumber: 2,
      );
      expect(ketQua, <int>[-1, 3]);
    });
  });
}
