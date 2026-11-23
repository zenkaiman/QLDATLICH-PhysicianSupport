import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/nhan_vien_model.dart';

class XuatPdfService {
  /// Bảng chuyển đổi bỏ dấu tiếng Việt dự phòng khi không tải được font Unicode trực tuyến
  static String boDauTiengViet(String str) {
    var result = str;
    const a = 'aàảãáạăằẳẵắặâầẩẫấậ';
    const d = 'dđ';
    const e = 'eèẻẽéẹêềểễếệ';
    const i = 'iìỉĩíị';
    const o = 'oòỏõóọôồổỗốộơờởỡớợ';
    const u = 'uùủũúụưừửữứự';
    const y = 'yỳỷỹýỵ';
    const A = 'AÀẢÃÁẠĂẰẲẴẮẶÂẦẨẪẤẬ';
    const D = 'DĐ';
    const E = 'EÈẺẼÉẸÊỀỂỄẾỆ';
    const I = 'IÌỈĨÍỊ';
    const O = 'OÒỎÕÓỌÔỒỔỖỐỘƠỜỞỠỚỢ';
    const U = 'UÙỦŨÚỤƯỪỬỮỨỰ';
    const Y = 'YỲỶỸÝỴ';

    for (int k = 1; k < a.length; k++) {
      result = result.replaceAll(a[k], 'a');
    }
    for (int k = 1; k < d.length; k++) {
      result = result.replaceAll(d[k], 'd');
    }
    for (int k = 1; k < e.length; k++) {
      result = result.replaceAll(e[k], 'e');
    }
    for (int k = 1; k < i.length; k++) {
      result = result.replaceAll(i[k], 'i');
    }
    for (int k = 1; k < o.length; k++) {
      result = result.replaceAll(o[k], 'o');
    }
    for (int k = 1; k < u.length; k++) {
      result = result.replaceAll(u[k], 'u');
    }
    for (int k = 1; k < y.length; k++) {
      result = result.replaceAll(y[k], 'y');
    }
    for (int k = 1; k < A.length; k++) {
      result = result.replaceAll(A[k], 'A');
    }
    for (int k = 1; k < D.length; k++) {
      result = result.replaceAll(D[k], 'D');
    }
    for (int k = 1; k < E.length; k++) {
      result = result.replaceAll(E[k], 'E');
    }
    for (int k = 1; k < I.length; k++) {
      result = result.replaceAll(I[k], 'I');
    }
    for (int k = 1; k < O.length; k++) {
      result = result.replaceAll(O[k], 'O');
    }
    for (int k = 1; k < U.length; k++) {
      result = result.replaceAll(U[k], 'U');
    }
    for (int k = 1; k < Y.length; k++) {
      result = result.replaceAll(Y[k], 'Y');
    }
    return result;
  }

  /// Tạo tài liệu PDF danh sách tài khoản nhân sự
  static Future<Uint8List> taoPdfDanhSachTaiKhoan({
    required String tenBenhVien,
    required String tieuDeTrang,
    required String vaiTroDangLoc,
    required List<TaiKhoanItem> danhSach,
  }) async {
    final pdf = pw.Document();

    pw.Font fontRegular;
    pw.Font fontBold;
    bool coHoTroTiengViet = true;

    try {
      fontRegular = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
    } catch (e) {
      debugPrint('⚠️ Không thể tải Google Fonts, fallback sang font mặc định: $e');
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
      coHoTroTiengViet = false;
    }

    String txt(String s) => coHoTroTiengViet ? s : boDauTiengViet(s);

    final now = DateTime.now();
    final ngayXuatStr = DateFormat('dd/MM/yyyy HH:mm').format(now);

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        theme: theme,
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    txt(tenBenhVien.toUpperCase()),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 11,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    txt('HỆ THỐNG QUẢN LÝ ĐẶT LỊCH KHÁM MEDICONNECT'),
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    txt('Ngày xuất: $ngayXuatStr'),
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    txt('Trang ${context.pageNumber}/${context.pagesCount}'),
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ),
        ),
        build: (context) => [
          // Tiêu đề văn bản
          pw.Center(
            child: pw.Column(
              children: [
                pw.SizedBox(height: 6),
                pw.Text(
                  txt(tieuDeTrang.toUpperCase()),
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    color: PdfColors.blue800,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  txt('Bộ lọc vai trò: $vaiTroDangLoc • Tổng số: ${danhSach.length} tài khoản'),
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 14),
              ],
            ),
          ),

          // Bảng danh sách tài khoản
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
            headerStyle: pw.TextStyle(
              font: fontBold,
              fontSize: 9.5,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blue800,
            ),
            headerHeight: 26,
            cellHeight: 24,
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
            },
            headers: [
              txt('STT'),
              txt('Mã tài khoản'),
              txt('Họ tên nhân sự'),
              txt('Vai trò'),
              txt('Chuyên khoa'),
              txt('Mật khẩu'),
              txt('Trạng thái'),
              txt('Ngày tạo'),
            ],
            data: List.generate(danhSach.length, (index) {
              final item = danhSach[index];
              final ngayTaoStr = item.ngayTao != null
                  ? DateFormat('dd/MM/yyyy').format(item.ngayTao!)
                  : '-';
              final vaiTroStr = item.vaiTro.isNotEmpty ? item.vaiTro : 'Nhân viên';
              final khoaStr = item.khoa.isNotEmpty ? item.khoa : 'Toàn viện';
              final hoTenStr = item.hoTen.isNotEmpty ? item.hoTen : item.maTk;
              final trangThaiStr = item.trangThai.isNotEmpty
                  ? item.trangThai
                  : (item.daKichHoat ? 'Đã kích hoạt' : 'Đợi kích hoạt');

              return [
                '${index + 1}',
                item.maTk,
                txt(hoTenStr),
                txt(vaiTroStr),
                txt(khoaStr),
                item.matKhau,
                txt(trangThaiStr),
                ngayTaoStr,
              ];
            }),
          ),

          pw.SizedBox(height: 18),

          // Ghi chú và chữ ký xác nhận
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        txt('LƯU Ý BẢO MẬT:'),
                        style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.red800),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        txt('• Mật khẩu khởi tạo được cung cấp để nhân viên đăng nhập lần đầu.'),
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        txt('• Nhân sự vui lòng đổi mật khẩu mới ngay khi kích hoạt tài khoản.'),
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 30),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    txt('NGƯỜI XUẤT DANH SÁCH'),
                    style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey900),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    txt('(Ký và ghi rõ họ tên)'),
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.SizedBox(height: 38),
                  pw.Text(
                    txt('Ban Quản Trị Bệnh Viện'),
                    style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.grey800),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Xuất và mở hộp thoại in / tải file PDF
  static Future<void> xuatVaInPdf({
    required String tenBenhVien,
    required String tieuDeTrang,
    required String vaiTroDangLoc,
    required List<TaiKhoanItem> danhSach,
  }) async {
    final cleanTitle = boDauTiengViet(tieuDeTrang)
        .replaceAll(RegExp(r'[^\w\-]'), '_')
        .toLowerCase();
    final fileName = 'danh_sach_tai_khoan_${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    await Printing.layoutPdf(
      name: fileName,
      onLayout: (PdfPageFormat format) async {
        return taoPdfDanhSachTaiKhoan(
          tenBenhVien: tenBenhVien,
          tieuDeTrang: tieuDeTrang,
          vaiTroDangLoc: vaiTroDangLoc,
          danhSach: danhSach,
        );
      },
    );
  }

  /// Chia sẻ hoặc lưu file PDF trực tiếp
  static Future<void> chiaSePdf({
    required String tenBenhVien,
    required String tieuDeTrang,
    required String vaiTroDangLoc,
    required List<TaiKhoanItem> danhSach,
  }) async {
    final pdfBytes = await taoPdfDanhSachTaiKhoan(
      tenBenhVien: tenBenhVien,
      tieuDeTrang: tieuDeTrang,
      vaiTroDangLoc: vaiTroDangLoc,
      danhSach: danhSach,
    );

    final cleanTitle = boDauTiengViet(tieuDeTrang)
        .replaceAll(RegExp(r'[^\w\-]'), '_')
        .toLowerCase();
    final fileName = 'danh_sach_tai_khoan_${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
  }
}
