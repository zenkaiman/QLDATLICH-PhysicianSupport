import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../config/constants.dart';
import 'hospital_sync_service.dart';

class EmailService {
  static final EmailService instance = EmailService._();
  EmailService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cấu hình tài khoản phát thư hệ thống MediConnect (Google SMTP)
  static const String _senderEmail = 'bibiboy3313@gmail.com';
  static const String _appPassword = 'hqnnghqkdhikwfnm';

  // ───────────────────────── ADMIN EMAIL METHODS ─────────────────────────

  /// Gửi email thông báo KHÓA TÀI KHOẢN
  Future<void> sendAccountBlockedEmail({
    required String toEmail,
    required String recipientName,
    required String reason,
    bool isHospital = false,
  }) async {
    final entityType = isHospital ? 'Bệnh viện / Cơ sở Y tế' : 'Bệnh nhân';
    final subject = '[MediConnect] Thông báo tạm khóa tài khoản $entityType';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 20px; color: #1E293B; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.06); border: 1px solid #E2E8F0; }
    .header { background: linear-gradient(135deg, #1D4ED8, #3B82F6); padding: 30px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 22px; font-weight: 800; letter-spacing: 0.5px; }
    .header p { margin: 6px 0 0; font-size: 13px; opacity: 0.9; }
    .body { padding: 28px 24px; line-height: 1.6; }
    .greeting { font-size: 16px; font-weight: 700; margin-bottom: 12px; color: #0F172A; }
    .alert-box { background: #FEE2E2; border-left: 4px solid #DC2626; padding: 14px 18px; border-radius: 8px; margin: 18px 0; }
    .alert-box strong { color: #DC2626; font-size: 14px; }
    .reason-text { margin-top: 6px; font-size: 13.5px; color: #7F1D1D; }
    .footer { background: #F1F5F9; padding: 20px 24px; text-align: center; font-size: 12px; color: #64748B; border-top: 1px solid #E2E8F0; }
    .footer a { color: #1D4ED8; text-decoration: none; font-weight: 600; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>CỔNG QUẢN TRỊ Y TẾ MEDICONNECT</h1>
      <p>Thông báo quan trọng về trạng thái tài khoản</p>
    </div>
    <div class="body">
      <div class="greeting">Kính gửi: $recipientName,</div>
      <p>Hệ thống Quản trị Y tế MediConnect xin thông báo tài khoản <strong>$entityType</strong> liên kết với email này đã bị <strong>tạm khóa / chặn đăng nhập</strong> bởi Quản trị viên.</p>
      
      <div class="alert-box">
        <strong>LÝ DO TẠM KHÓA:</strong>
        <div class="reason-text">$reason</div>
      </div>

      <p>Trong thời gian tài khoản bị tạm khóa, bạn sẽ tạm thời không thể đăng nhập hoặc thực hiện các thao tác trên nền tảng.</p>
      <p>Nếu bạn cho rằng đây là một sự nhầm lẫn hoặc cần giải trình để mở lại tài khoản, vui lòng liên hệ ngay với Bộ phận Hỗ trợ Quản trị qua email <strong>hotro@mediconnect.vn</strong> hoặc Hotline <strong>1900 8888</strong>.</p>
    </div>
    <div class="footer">
      <p>Email này được gửi tự động từ Hệ thống Quản trị Y tế MediConnect.</p>
      <p>© 2026 MediConnect Healthcare System. Hotline hỗ trợ: 1900 8888</p>
    </div>
  </div>
</body>
</html>
''';

    await _queueEmail(
      toEmail: toEmail,
      recipientName: recipientName,
      subject: subject,
      htmlContent: htmlContent,
      type: 'ACCOUNT_BLOCKED',
    );
  }

  /// Gửi email thông báo MỞ KHÓA TÀI KHOẢN
  Future<void> sendAccountUnblockedEmail({
    required String toEmail,
    required String recipientName,
    bool isHospital = false,
  }) async {
    final entityType = isHospital ? 'Bệnh viện / Cơ sở Y tế' : 'Bệnh nhân';
    final subject = '[MediConnect] Tài khoản $entityType của bạn đã được kích hoạt lại';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 20px; color: #1E293B; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.06); border: 1px solid #E2E8F0; }
    .header { background: linear-gradient(135deg, #059669, #10B981); padding: 30px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 22px; font-weight: 800; }
    .body { padding: 28px 24px; line-height: 1.6; }
    .greeting { font-size: 16px; font-weight: 700; margin-bottom: 12px; color: #0F172A; }
    .success-box { background: #D1FAE5; border-left: 4px solid #059669; padding: 14px 18px; border-radius: 8px; margin: 18px 0; color: #065F46; }
    .footer { background: #F1F5F9; padding: 20px 24px; text-align: center; font-size: 12px; color: #64748B; border-top: 1px solid #E2E8F0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>CỔNG QUẢN TRỊ Y TẾ MEDICONNECT</h1>
      <p>Thông báo trạng thái kích hoạt tài khoản</p>
    </div>
    <div class="body">
      <div class="greeting">Kính gửi: $recipientName,</div>
      <div class="success-box">
        <strong>TÀI KHOẢN CỦA BẠN ĐÃ ĐƯỢC KÍCH HOẠT LẠI!</strong>
        <p style="margin: 4px 0 0; font-size: 13.5px;">Quản trị viên đã kiểm tra và tiến hành mở khóa tài khoản $entityType của bạn.</p>
      </div>
      <p>Hiện tại bạn đã có thể đăng nhập bình thường vào ứng dụng MediConnect bằng email và mật khẩu hiện có.</p>
      <p>Chúc bạn có trải nghiệm tốt trên hệ thống chăm sóc sức khỏe của chúng tôi.</p>
    </div>
    <div class="footer">
      <p>Email này được gửi tự động từ Hệ thống Quản trị Y tế MediConnect.</p>
      <p>© 2026 MediConnect Healthcare System. Hotline hỗ trợ: 1900 8888</p>
    </div>
  </div>
</body>
</html>
''';

    await _queueEmail(
      toEmail: toEmail,
      recipientName: recipientName,
      subject: subject,
      htmlContent: htmlContent,
      type: 'ACCOUNT_UNBLOCKED',
    );
  }

  /// Gửi email thông báo XÓA TÀI KHOẢN
  Future<void> sendAccountDeletedEmail({
    required String toEmail,
    required String recipientName,
    bool isHospital = false,
  }) async {
    final entityType = isHospital ? 'Bệnh viện / Cơ sở Y tế' : 'Bệnh nhân';
    final subject = '[MediConnect] Thông báo xóa tài khoản $entityType';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 20px; color: #1E293B; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.06); border: 1px solid #E2E8F0; }
    .header { background: linear-gradient(135deg, #475569, #0F172A); padding: 30px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 22px; font-weight: 800; }
    .body { padding: 28px 24px; line-height: 1.6; }
    .greeting { font-size: 16px; font-weight: 700; margin-bottom: 12px; color: #0F172A; }
    .info-box { background: #F1F5F9; border-left: 4px solid #64748B; padding: 14px 18px; border-radius: 8px; margin: 18px 0; color: #334155; }
    .footer { background: #F1F5F9; padding: 20px 24px; text-align: center; font-size: 12px; color: #64748B; border-top: 1px solid #E2E8F0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>HỆ THỐNG Y TẾ MEDICONNECT</h1>
      <p>Thông báo xóa tài khoản</p>
    </div>
    <div class="body">
      <div class="greeting">Kính gửi: $recipientName,</div>
      <div class="info-box">
        Hồ sơ tài khoản $entityType liên kết với email này đã được Quản trị viên xóa khỏi cơ sở dữ liệu hệ thống theo quy định quản lý.
      </div>
      <p>Toàn bộ thông tin phiên làm việc liên kết đã được thu hồi an toàn. Nếu bạn có bất kỳ thắc mắc hoặc khiếu nại, vui lòng liên hệ <strong>hotro@mediconnect.vn</strong>.</p>
    </div>
    <div class="footer">
      <p>© 2026 MediConnect Healthcare System. Hotline hỗ trợ: 1900 8888</p>
    </div>
  </div>
</body>
</html>
''';

    await _queueEmail(
      toEmail: toEmail,
      recipientName: recipientName,
      subject: subject,
      htmlContent: htmlContent,
      type: 'ACCOUNT_DELETED',
    );
  }

  /// Gửi email thông báo CHẤM DỨT HỢP TÁC BỆNH VIỆN
  Future<void> sendPartnershipCancelledEmail({
    required String toEmail,
    required String hospitalName,
    required String reason,
  }) async {
    final subject = '[MediConnect] Quyết định chấm dứt quan hệ hợp tác cơ sở y tế';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 20px; color: #1E293B; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.06); border: 1px solid #E2E8F0; }
    .header { background: linear-gradient(135deg, #B91C1C, #EF4444); padding: 30px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 20px; font-weight: 800; }
    .body { padding: 28px 24px; line-height: 1.6; }
    .greeting { font-size: 16px; font-weight: 700; margin-bottom: 12px; color: #0F172A; }
    .alert-box { background: #FEE2E2; border-left: 4px solid #B91C1C; padding: 14px 18px; border-radius: 8px; margin: 18px 0; }
    .alert-box strong { color: #B91C1C; font-size: 14px; }
    .footer { background: #F1F5F9; padding: 20px 24px; text-align: center; font-size: 12px; color: #64748B; border-top: 1px solid #E2E8F0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>HỆ THỐNG Y TẾ MEDICONNECT</h1>
      <p>Thông báo quyết định hợp tác</p>
    </div>
    <div class="body">
      <div class="greeting">Kính gửi Ban Giám đốc: $hospitalName,</div>
      <p>Ban Quản trị Nền tảng MediConnect xin trân trọng thông báo quyết định <strong>chấm dứt quan hệ hợp tác</strong> đối với cơ sở y tế.</p>
      
      <div class="alert-box">
        <strong>LÝ DO CHẤM DỨT HỢP TÁC:</strong>
        <div style="margin-top: 6px; color: #991B1B;">$reason</div>
      </div>

      <p>Cơ sở y tế sẽ ngừng xuất hiện trên cổng đặt lịch của bệnh nhân. Trân trọng cảm ơn sự đồng hành của quý cơ sở trong thời gian qua.</p>
    </div>
    <div class="footer">
      <p>© 2026 MediConnect Healthcare System. Email liên hệ pháp chế: phapche@mediconnect.vn</p>
    </div>
  </div>
</body>
</html>
''';

    await _queueEmail(
      toEmail: toEmail,
      recipientName: hospitalName,
      subject: subject,
      htmlContent: htmlContent,
      type: 'PARTNERSHIP_CANCELLED',
    );
  }

  /// Gửi email thông báo KHÔI PHỤC HỢP TÁC BỆNH VIỆN
  Future<void> sendPartnershipRestoredEmail({
    required String toEmail,
    required String hospitalName,
  }) async {
    final subject = '[MediConnect] Thông báo khôi phục quan hệ hợp tác cơ sở y tế';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 20px; color: #1E293B; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.06); border: 1px solid #E2E8F0; }
    .header { background: linear-gradient(135deg, #059669, #10B981); padding: 30px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 20px; font-weight: 800; }
    .body { padding: 28px 24px; line-height: 1.6; }
    .greeting { font-size: 16px; font-weight: 700; margin-bottom: 12px; color: #0F172A; }
    .success-box { background: #D1FAE5; border-left: 4px solid #059669; padding: 14px 18px; border-radius: 8px; margin: 18px 0; color: #065F46; }
    .footer { background: #F1F5F9; padding: 20px 24px; text-align: center; font-size: 12px; color: #64748B; border-top: 1px solid #E2E8F0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>HỆ THỐNG Y TẾ MEDICONNECT</h1>
      <p>Chúc mừng tái ký kết hợp tác y tế</p>
    </div>
    <div class="body">
      <div class="greeting">Kính gửi Ban Giám đốc: $hospitalName,</div>
      <div class="success-box">
        <strong>HỒ SƠ HỢP TÁC ĐÃ ĐƯỢC KHÔI PHỤC THÀNH CÔNG!</strong>
        <p style="margin: 4px 0 0; font-size: 13.5px;">Quản trị viên đã kiểm tra và chấp thuận khôi phục thỏa thuận hợp tác y tế với cơ sở.</p>
      </div>
      <p>Cơ sở y tế đã được mở khóa đăng nhập và hiển thị trở lại trên cổng đặt lịch khám bệnh nhân của hệ thống MediConnect.</p>
      <p>Chúc quý cơ sở y tế hoạt động hiệu quả và phục vụ người bệnh ngày một tốt hơn.</p>
    </div>
    <div class="footer">
      <p>© 2026 MediConnect Healthcare System. Hotline: 1900 8888</p>
    </div>
  </div>
</body>
</html>
''';

    await _queueEmail(
      toEmail: toEmail,
      recipientName: hospitalName,
      subject: subject,
      htmlContent: htmlContent,
      type: 'PARTNERSHIP_RESTORED',
    );
  }

  /// GHI VÀO FIRESTORE (Chuẩn Firebase Trigger Email Extension & EmailLog)
  Future<void> _queueEmail({
    required String toEmail,
    required String recipientName,
    required String subject,
    required String htmlContent,
    required String type,
  }) async {
    if (toEmail.trim().isEmpty || !toEmail.contains('@')) {
      debugPrint('⚠️ Email không hợp lệ để gửi thông báo: "$toEmail"');
      return;
    }

    try {
      // 1. Ghi vào collection 'mail' (Chuẩn Firebase Trigger Email Extension)
      await _firestore.collection('mail').add({
        'to': [toEmail.trim()],
        'message': {
          'subject': subject,
          'html': htmlContent,
        },
        'status': 'PENDING',
        'ngay_tao': FieldValue.serverTimestamp(),
        'loai': type,
        'nguoi_nhan': recipientName,
      });

      // 2. Ghi lịch sử vào collection 'EmailLog' để quản trị viên dễ dàng theo dõi
      await _firestore.collection('EmailLog').add({
        'to': toEmail.trim(),
        'recipient_name': recipientName,
        'subject': subject,
        'type': type,
        'sent_at': FieldValue.serverTimestamp(),
        'status': 'QUEUED_FOR_DELIVERY',
      });

      debugPrint('📧 Đã tạo lệnh gửi email thông báo tới: $toEmail ($subject)');
    } catch (e) {
      debugPrint('❌ Lỗi khi xếp hàng gửi email trên Firebase: $e');
    }
  }

  // ───────────────────────── SMTP & HỢP TÁC EMAIL METHODS ─────────────────────────

  /// Gửi email trực tiếp qua máy chủ Google SMTP (smtp.gmail.com)
  static Future<bool> _guiEmailSmtp({
    required String toEmail,
    required String tieuDe,
    required String noiDungText,
    required String noiDungHtml,
  }) async {
    try {
      final smtpServer = gmail(_senderEmail, _appPassword);
      final message = Message()
        ..from = const Address(_senderEmail, 'Hệ Thống Y Tế MediConnect')
        ..recipients.add(toEmail)
        ..subject = tieuDe
        ..text = noiDungText
        ..html = noiDungHtml;

      final sendReport = await send(message, smtpServer);
      debugPrint('🚀 [EmailService - SMTP] Gửi thư THẬT thành công tới: $toEmail ($sendReport)');
      return true;
    } catch (e) {
      debugPrint('❌ [EmailService - SMTP] Lỗi gửi thư qua Google SMTP: $e');
      return false;
    }
  }

  /// Gửi email xác nhận đã tiếp nhận hồ sơ yêu cầu hợp tác (gửi 1 lần duy nhất khi gửi yêu cầu)
  static Future<bool> guiEmailXacNhanGuiYeuCauHopTac({
    required String emailNguoiNhan,
    required String tenBenhVien,
    required String maBenhVien,
    required String maHoSo,
  }) async {
    final cleanEmail = emailNguoiNhan.trim();
    if (cleanEmail.isEmpty) {
      debugPrint('⚠️ [EmailService] Không có email người nhận để gửi xác nhận tiếp nhận hồ sơ.');
      return false;
    }

    try {
      final String tieuDe =
          '[MediConnect] Đã tiếp nhận hồ sơ yêu cầu hợp tác - $tenBenhVien';

      final now = DateTime.now();
      final thoiGianStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ngày ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      final String noiDungText = '''
Kính gửi Quý đại diện $tenBenhVien,

Ban Quản Trị Hệ thống Y tế MediConnect xin thông báo:
Hệ thống đã tiếp nhận thành công hồ sơ đăng ký hợp tác của cơ sở y tế.

- Mã Hồ Sơ: $maHoSo
- Mã Bệnh Viện: $maBenhVien
- Tên Cơ Sở: $tenBenhVien
- Trạng thái: Chờ xét duyệt
- Thời gian gửi: $thoiGianStr

Ban Quản Trị sẽ tiến hành thẩm định thông tin và phản hồi kết quả trong thời gian sớm nhất. Quý cơ sở có thể theo dõi tiến độ xử lý hồ sơ trực tiếp trên ứng dụng MediConnect.

Trân trọng,
Ban Quản Trị Hệ Thống MediConnect
''';

      final String noiDungHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333333; background-color: #f4f6f8; margin: 0; padding: 20px; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
    .header { background: linear-gradient(135deg, #0284C7, #0D9488); padding: 28px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 22px; font-weight: 700; }
    .content { padding: 30px 24px; }
    .status-badge { display: inline-block; background-color: #FEF3C7; color: #D97706; padding: 6px 14px; border-radius: 20px; font-weight: 700; font-size: 14px; margin-bottom: 20px; border: 1px solid #FDE68A; }
    .info-box { background-color: #F8FAFC; border-left: 4px solid #0284C7; padding: 16px; border-radius: 6px; margin: 20px 0; }
    .footer { background-color: #F8FAFC; padding: 20px 24px; text-align: center; font-size: 13px; color: #64748B; border-top: 1px solid #E2E8F0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>HỆ THỐNG Y TẾ MEDICONNECT</h1>
      <p style="margin: 6px 0 0 0; opacity: 0.9; font-size: 14px;">Xác nhận tiếp nhận hồ sơ hợp tác</p>
    </div>
    <div class="content">
      <div class="status-badge">📋 Trạng thái: Chờ xét duyệt</div>
      <p>Kính gửi Quý đại diện <strong>$tenBenhVien</strong>,</p>
      <p>Ban Quản Trị MediConnect xin thông báo đã tiếp nhận thành công hồ sơ đăng ký hợp tác của cơ sở y tế.</p>
      
      <div class="info-box">
        <p style="margin: 0 0 8px 0;"><strong>Mã Hồ Sơ:</strong> $maHoSo</p>
        <p style="margin: 0 0 8px 0;"><strong>Mã Bệnh Viện:</strong> $maBenhVien</p>
        <p style="margin: 0 0 8px 0;"><strong>Tên Cơ Sở:</strong> $tenBenhVien</p>
        <p style="margin: 0 0 8px 0;"><strong>Trạng thái:</strong> Chờ xét duyệt</p>
        <p style="margin: 0;"><strong>Thời gian gửi:</strong> $thoiGianStr</p>
      </div>

      <p>Hồ sơ của Quý viện đang được chuyển đến bộ phận chuyên môn để thẩm định. Quý cơ sở có thể theo dõi trực tiếp trạng thái trên ứng dụng.</p>
      <p>Trân trọng cảm ơn sự quan tâm và hợp tác của Quý cơ sở y tế!</p>
    </div>
    <div class="footer">
      <p style="margin: 0;">Email tự động gửi từ Hệ thống MediConnect • Vui lòng không trả lời trực tiếp email này.</p>
    </div>
  </div>
</body>
</html>
''';

      final Map<String, dynamic> emailPayload = {
        'to': [cleanEmail],
        'email': cleanEmail,
        'email_nguoi_nhan': cleanEmail,
        'message': {
          'subject': tieuDe,
          'text': noiDungText,
          'html': noiDungHtml,
        },
        'tieu_de': tieuDe,
        'noi_dung': noiDungText,
        'html': noiDungHtml,
        'ten_benh_vien': tenBenhVien,
        'ma_benh_vien': maBenhVien,
        'benh_vien_id': maBenhVien,
        'ma_ho_so': maHoSo,
        'trang_thai_id': TrangThaiId.choDuyet,
        'loai': 'gui_yeu_cau_hop_tac',
        'trang_thai': 'pending',
        'thoi_gian_gui': FieldValue.serverTimestamp(),
        'ngay_tao_str': DateTime.now().toIso8601String(),
      };

      try {
        await _firestore.collection('mail').add(Map<String, dynamic>.from(emailPayload));
      } catch (_) {}

      try {
        await _firestore.collection('EmailLog').add(Map<String, dynamic>.from(emailPayload));
      } catch (_) {}

      final bool smtpResult = await _guiEmailSmtp(
        toEmail: cleanEmail,
        tieuDe: tieuDe,
        noiDungText: noiDungText,
        noiDungHtml: noiDungHtml,
      );

      debugPrint('✅ [EmailService] Kết quả gửi email xác nhận nộp hồ sơ tới $cleanEmail: $smtpResult');
      return smtpResult;
    } catch (e) {
      debugPrint('❌ [EmailService] Lỗi gửi email xác nhận nộp hồ sơ: $e');
      return false;
    }
  }

  /// Gửi và ghi log email thông báo từ chối / hủy hợp tác đến email người đăng ký
  static Future<bool> guiEmailTuChoiHopTac({
    required String emailNguoiNhan,
    required String tenBenhVien,
    required String maBenhVien,
    String? lyDo,
  }) async {
    final cleanEmail = emailNguoiNhan.trim();
    if (cleanEmail.isEmpty) {
      debugPrint('⚠️ [EmailService] Không có email người nhận để gửi thông báo.');
      return false;
    }

    try {
      final String tieuDe =
          '[MediConnect] Thông báo về yêu cầu hợp tác - $tenBenhVien';
      final String lyDoChiTiet = (lyDo != null && lyDo.trim().isNotEmpty)
          ? lyDo.trim()
          : 'Hồ sơ pháp lý chưa đầy đủ hoặc không phù hợp với quy chế hợp tác hiện hành của hệ thống.';

      final now = DateTime.now();
      final thoiGianStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ngày ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      final String noiDungText = '''
Kính gửi đại diện $tenBenhVien,

Ban Quản Trị hệ thống MediConnect xin trân trọng thông báo:
Yêu cầu hợp tác của quý Bệnh viện (Mã: $maBenhVien) đã bị TỪ CHỐI / HỦY HỢP TÁC trên hệ thống.

- Mã Bệnh Viện: $maBenhVien
- Tên Cơ Sở: $tenBenhVien
- Trạng thái: Từ chối / Hủy hợp tác
- Lý do: $lyDoChiTiet
- Thời gian xử lý: $thoiGianStr

Quý Bệnh viện vui lòng mở ứng dụng MediConnect để kiểm tra lại thông tin, hoàn thiện hồ sơ và thực hiện gửi lại yêu cầu hợp tác mới từ đầu.

Trân trọng,
Ban Quản Trị Hệ Thống MediConnect
''';

      final String noiDungHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333333; background-color: #f4f6f8; margin: 0; padding: 20px; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
    .header { background: linear-gradient(135deg, #EF4444, #DC2626); padding: 28px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 22px; font-weight: 700; }
    .content { padding: 30px 24px; }
    .status-badge { display: inline-block; background-color: #FEE2E2; color: #DC2626; padding: 6px 14px; border-radius: 20px; font-weight: 700; font-size: 14px; margin-bottom: 20px; }
    .info-box { background-color: #F8FAFC; border-left: 4px solid #EF4444; padding: 16px; border-radius: 6px; margin: 20px 0; }
    .footer { background-color: #F8FAFC; padding: 20px 24px; text-align: center; font-size: 13px; color: #64748B; border-top: 1px solid #E2E8F0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>HỆ THỐNG Y TẾ MEDICONNECT</h1>
      <p style="margin: 6px 0 0 0; opacity: 0.9; font-size: 14px;">Thông báo về yêu cầu hợp tác</p>
    </div>
    <div class="content">
      <div class="status-badge">Trạng thái: Từ Chối / Hủy Hợp Tác</div>
      <p>Kính gửi Quý đại diện <strong>$tenBenhVien</strong>,</p>
      <p>Ban Quản Trị MediConnect xin thông báo yêu cầu đăng ký hợp tác của cơ sở y tế đã được xử lý với kết quả <strong>KHÔNG ĐƯỢC CHẤP THUẬN HOẶC ĐÃ HỦY HỢP TÁC</strong>.</p>
      
      <div class="info-box">
        <p style="margin: 0 0 8px 0;"><strong>Mã Bệnh Viện:</strong> $maBenhVien</p>
        <p style="margin: 0 0 8px 0;"><strong>Tên Cơ Sở:</strong> $tenBenhVien</p>
        <p style="margin: 0 0 8px 0;"><strong>Trạng thái:</strong> Từ chối hợp tác</p>
        <p style="margin: 0 0 8px 0;"><strong>Lý do:</strong> $lyDoChiTiet</p>
        <p style="margin: 0;"><strong>Thời gian:</strong> $thoiGianStr</p>
      </div>

      <p>Quý cơ sở y tế có thể mở ứng dụng MediConnect để bổ sung, điều chỉnh thông tin và <strong>gửi lại đơn yêu cầu hợp tác mới từ đầu</strong>.</p>
      
      <p>Trân trọng cảm ơn sự quan tâm của Quý viện đối với hệ thống của chúng tôi.</p>
    </div>
    <div class="footer">
      <p style="margin: 0;">Email tự động gửi từ Hệ thống MediConnect • Vui lòng không trả lời trực tiếp email này nếu không cần thiết.</p>
    </div>
  </div>
</body>
</html>
''';

      // 1. Tạo dữ liệu gửi mail theo đúng chuẩn Firebase Extension 'Trigger Email'
      final Map<String, dynamic> emailPayload = {
        'to': [cleanEmail],
        'email': cleanEmail,
        'email_nguoi_nhan': cleanEmail,
        'message': {
          'subject': tieuDe,
          'text': noiDungText,
          'html': noiDungHtml,
        },
        'tieu_de': tieuDe,
        'noi_dung': noiDungText,
        'html': noiDungHtml,
        'ten_benh_vien': tenBenhVien,
        'ma_benh_vien': maBenhVien,
        'benh_vien_id': maBenhVien,
        'ly_do': lyDoChiTiet,
        'trang_thai_id': TrangThaiId.huyHopTac, // 9: Hủy hợp tác
        'loai': 'tu_choi_hop_tac',
        'trang_thai': 'pending',
        'thoi_gian_gui': FieldValue.serverTimestamp(),
        'ngay_tao_str': DateTime.now().toIso8601String(),
      };

      // Ghi vào collection 'mail' (chuẩn mặc định của Firebase Extension "Trigger Email")
      try {
        await _firestore.collection('mail').add(Map<String, dynamic>.from(emailPayload));
        debugPrint('✅ [EmailService] Đã đẩy email hủy vào collection "mail" cho Firebase Extension');
      } catch (e) {
        debugPrint('⚠️ [EmailService] Lỗi khi ghi collection "mail": $e');
      }

      // Ghi vào collection 'EmailLog'
      try {
        await _firestore.collection('EmailLog').add(Map<String, dynamic>.from(emailPayload));
        debugPrint('✅ [EmailService] Đã ghi nhận EmailLog hủy hợp tác tới: $cleanEmail');
      } catch (e) {
        debugPrint('⚠️ [EmailService] Lỗi khi ghi collection "EmailLog": $e');
      }

      // 2. Gửi email THẬT trực tiếp qua Google SMTP tới hộp thư Gmail của bệnh viện
      final bool smtpResult = await _guiEmailSmtp(
        toEmail: cleanEmail,
        tieuDe: tieuDe,
        noiDungText: noiDungText,
        noiDungHtml: noiDungHtml,
      );

      // 3. Ghi thêm vào collection ThongBao
      try {
        await _firestore.collection('ThongBao').add({
          'benh_vien_id': maBenhVien,
          'ma_benh_vien': maBenhVien,
          'tieu_de': 'Yêu cầu hợp tác bị từ chối / hủy',
          'noi_dung':
              'Hồ sơ hợp tác của $tenBenhVien đã bị từ chối/hủy. Vui lòng kiểm tra email $cleanEmail và gửi lại hồ sơ.',
          'loai': 'hop_tac',
          'trang_thai_id': TrangThaiId.huyHopTac,
          'da_doc': false,
          'thoi_gian': FieldValue.serverTimestamp(),
          'ngay_tao_str': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      debugPrint('✅ [EmailService] Kết quả gửi email hủy/từ chối tới $cleanEmail: $smtpResult');
      return smtpResult;
    } catch (e) {
      debugPrint('❌ [EmailService] Lỗi khi gửi email thông báo: $e');
      return false;
    }
  }

  /// Gửi và ghi log email thông báo phê duyệt hợp tác (mã 10) đến email người đăng ký
  static Future<bool> guiEmailPheDuyetHopTac({
    required String emailNguoiNhan,
    required String tenBenhVien,
    required String maBenhVien,
    String? ghiChu,
  }) async {
    final cleanEmail = emailNguoiNhan.trim();
    if (cleanEmail.isEmpty) {
      debugPrint('⚠️ [EmailService] Không có email người nhận để gửi thông báo phê duyệt.');
      return false;
    }

    try {
      final String tieuDe =
          '[MediConnect] Chúc mừng! Hồ sơ hợp tác của $tenBenhVien đã được phê duyệt thành công';

      final now = DateTime.now();
      final thoiGianStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ngày ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      final String noiDungText = '''
Kính gửi Quý đại diện $tenBenhVien,

Ban Quản Trị Hệ thống Y tế MediConnect xin trân trọng thông báo:
Hồ sơ đăng ký hợp tác của Quý Bệnh viện (Mã: $maBenhVien) đã được PHÊ DUYỆT CHÍNH THỨC thành công trên hệ thống.

- Mã Bệnh Viện: $maBenhVien
- Tên Cơ Sở: $tenBenhVien
- Trạng thái: Đã được hợp tác
- Thời gian duyệt: $thoiGianStr

Toàn bộ các tính năng quản trị chuyên nghiệp trên ứng dụng MediConnect đã được kích hoạt cho cơ sở của Quý viện:
✓ Quản lý Bác sĩ, Nhân sự và Phân lịch trực ca
✓ Quản lý Danh mục Chuyên khoa & Phòng khám
✓ Cấu hình Ca khám và Khung giờ tiếp nhận
✓ Tiếp nhận & Điều phối Lịch hẹn Bệnh nhân trực tuyến
✓ Thống kê, Báo cáo & Đánh giá chất lượng dịch vụ

Quý Bệnh viện vui lòng mở ứng dụng MediConnect để bắt đầu thiết lập thông tin cơ sở và vận hành dịch vụ ngay bây giờ.

Trân trọng,
Ban Quản Trị Hệ Thống MediConnect
''';

      final String noiDungHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333333; background-color: #f4f6f8; margin: 0; padding: 20px; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
    .header { background: linear-gradient(135deg, #0284C7, #0D9488); padding: 32px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 22px; font-weight: 700; letter-spacing: 0.5px; }
    .content { padding: 32px 24px; }
    .status-badge { display: inline-block; background-color: #DCFCE7; color: #15803D; padding: 6px 16px; border-radius: 20px; font-weight: 700; font-size: 14px; margin-bottom: 20px; border: 1px solid #86EFAC; }
    .info-box { background-color: #F0FDF4; border-left: 4px solid #16A34A; padding: 18px; border-radius: 6px; margin: 20px 0; }
    .feature-list { list-style: none; padding: 0; margin: 16px 0; }
    .feature-list li { padding: 6px 0; color: #475569; font-size: 14px; }
    .feature-list li span { color: #16A34A; font-weight: bold; margin-right: 8px; }
    .footer { background-color: #F8FAFC; padding: 20px 24px; text-align: center; font-size: 13px; color: #64748B; border-top: 1px solid #E2E8F0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>HỆ THỐNG Y TẾ MEDICONNECT</h1>
      <p style="margin: 8px 0 0 0; opacity: 0.95; font-size: 15px;">Thông báo Phê duyệt Hợp tác Cơ sở Y tế</p>
    </div>
    <div class="content">
      <div class="status-badge">🎉 Trạng thái: Đã được hợp tác</div>
      <p>Kính gửi Quý đại diện <strong>$tenBenhVien</strong>,</p>
      <p>Ban Quản Trị Hệ thống MediConnect xin trân trọng thông báo: Yêu cầu đăng ký hợp tác của cơ sở y tế đã được <strong>XÉT DUYỆT THÀNH CÔNG VÀ KÍCH HOẠT HỢP TÁC CHÍNH THỨC</strong>.</p>
      
      <div class="info-box">
        <p style="margin: 0 0 8px 0;"><strong>Mã Bệnh Viện:</strong> $maBenhVien</p>
        <p style="margin: 0 0 8px 0;"><strong>Tên Cơ Sở:</strong> $tenBenhVien</p>
        <p style="margin: 0 0 8px 0;"><strong>Trạng thái:</strong> Đã được hợp tác</p>
        <p style="margin: 0;"><strong>Thời gian duyệt:</strong> $thoiGianStr</p>
      </div>

      <p><strong>Toàn bộ hệ thống tính năng Dashboard Bệnh viện đã sẵn sàng:</strong></p>
      <ul class="feature-list">
        <li><span>✓</span> Quản lý Bác sĩ, Nhân sự và Phân lịch trực ca</li>
        <li><span>✓</span> Quản lý Chuyên khoa, Phòng khám và Dịch vụ khám</li>
        <li><span>✓</span> Quản lý Ca khám bệnh và Tiếp nhận đặt lịch online</li>
        <li><span>✓</span> Thống kê hoạt động, Báo cáo và Đánh giá từ bệnh nhân</li>
      </ul>

      <p>Quý Bệnh viện có thể mở ứng dụng MediConnect ngay bây giờ để bắt đầu vận hành dịch vụ.</p>
      <p>Trân trọng cảm ơn sự đồng hành và hợp tác của Quý viện!</p>
    </div>
    <div class="footer">
      <p style="margin: 0;">Email tự động gửi từ Hệ thống MediConnect • Vui lòng không trả lời trực tiếp email này.</p>
    </div>
  </div>
</body>
</html>
''';

      // 1. Tạo dữ liệu gửi mail theo đúng chuẩn Firebase Extension 'Trigger Email'
      final Map<String, dynamic> emailPayload = {
        'to': [cleanEmail],
        'email': cleanEmail,
        'email_nguoi_nhan': cleanEmail,
        'message': {
          'subject': tieuDe,
          'text': noiDungText,
          'html': noiDungHtml,
        },
        'tieu_de': tieuDe,
        'noi_dung': noiDungText,
        'html': noiDungHtml,
        'ten_benh_vien': tenBenhVien,
        'ma_benh_vien': maBenhVien,
        'benh_vien_id': maBenhVien,
        'trang_thai_id': TrangThaiId.hopTac, // 10: Hợp tác
        'loai': 'phe_duyet_hop_tac',
        'trang_thai': 'pending',
        'thoi_gian_gui': FieldValue.serverTimestamp(),
        'ngay_tao_str': DateTime.now().toIso8601String(),
      };

      // Ghi vào collection 'mail'
      try {
        await _firestore.collection('mail').add(Map<String, dynamic>.from(emailPayload));
        debugPrint('✅ [EmailService] Đã đẩy email phê duyệt vào collection "mail" cho Firebase Extension');
      } catch (e) {
        debugPrint('⚠️ [EmailService] Lỗi khi ghi collection "mail": $e');
      }

      // Ghi vào collection 'EmailLog'
      try {
        await _firestore.collection('EmailLog').add(Map<String, dynamic>.from(emailPayload));
        debugPrint('✅ [EmailService] Đã ghi nhận EmailLog phê duyệt tới: $cleanEmail');
      } catch (e) {
        debugPrint('⚠️ [EmailService] Lỗi khi ghi collection "EmailLog": $e');
      }

      // 2. Gửi email THẬT trực tiếp qua Google SMTP tới hộp thư Gmail của bệnh viện
      final bool smtpResult = await _guiEmailSmtp(
        toEmail: cleanEmail,
        tieuDe: tieuDe,
        noiDungText: noiDungText,
        noiDungHtml: noiDungHtml,
      );

      // 3. Ghi thêm vào collection ThongBao
      try {
        await _firestore.collection('ThongBao').add({
          'benh_vien_id': maBenhVien,
          'ma_benh_vien': maBenhVien,
          'tieu_de': 'Yêu cầu hợp tác đã được phê duyệt 🎉',
          'noi_dung':
              'Chúc mừng $tenBenhVien! Hồ sơ hợp tác đã được phê duyệt thành công. Toàn bộ tính năng quản trị đã được kích hoạt.',
          'loai': 'hop_tac',
          'trang_thai_id': TrangThaiId.hopTac,
          'da_doc': false,
          'thoi_gian': FieldValue.serverTimestamp(),
          'ngay_tao_str': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      debugPrint('✅ [EmailService] Kết quả gửi email phê duyệt tới $cleanEmail: $smtpResult');
      return smtpResult;
    } catch (e) {
      debugPrint('❌ [EmailService] Lỗi khi gửi email thông báo phê duyệt: $e');
      return false;
    }
  }

  /// Thực hiện phê duyệt hợp tác:
  /// - Chuyển trang_thai_hop_tac_id sang 10 ở cả BenhVien và YeuCauHopTac
  /// - Gửi email thông báo phê duyệt và lưu EmailLog
  static Future<void> pheDuyetHopTac({
    required String benhVienId,
    required String tenBenhVien,
    required String email,
  }) async {
    final updateData = <String, dynamic>{
      ...HospitalSyncService.buildStatusFields(TrangThaiId.hopTac),
      'da_gui_mail_phe_duyet': true,
      'da_gui_mail_tu_choi': false,
      'thoi_gian_phe_duyet': FieldValue.serverTimestamp(),
    };

    // 1. Cập nhật collection BenhVien
    await _firestore
        .collection('BenhVien')
        .doc(benhVienId)
        .set(updateData, SetOptions(merge: true));

    // 2. Cập nhật collection YeuCauHopTac
    try {
      await _firestore
          .collection('YeuCauHopTac')
          .doc(benhVienId)
          .set(updateData, SetOptions(merge: true));
    } catch (_) {}

    // 3. Gửi email thông báo
    await guiEmailPheDuyetHopTac(
      emailNguoiNhan: email,
      tenBenhVien: tenBenhVien,
      maBenhVien: benhVienId,
    );
  }

  /// Thực hiện từ chối / hủy hợp tác:
  /// - Chuyển trang_thai_hop_tac_id sang 9 ở cả BenhVien và YeuCauHopTac
  /// - Gửi email thông báo và lưu EmailLog
  static Future<void> tuChoiHoacHuyHopTac({
    required String benhVienId,
    required String tenBenhVien,
    required String email,
    String? lyDo,
  }) async {
    final updateData = <String, dynamic>{
      ...HospitalSyncService.buildStatusFields(TrangThaiId.huyHopTac),
      'ly_do_tu_choi': lyDo ?? 'Hồ sơ chưa đạt yêu cầu / Hủy hợp tác',
      'thoi_gian_tu_choi': FieldValue.serverTimestamp(),
      'da_gui_mail_tu_choi': true,
      'da_gui_mail_phe_duyet': false,
    };

    // 1. Cập nhật collection BenhVien
    await _firestore
        .collection('BenhVien')
        .doc(benhVienId)
        .set(updateData, SetOptions(merge: true));

    // 2. Cập nhật collection YeuCauHopTac
    try {
      await _firestore
          .collection('YeuCauHopTac')
          .doc(benhVienId)
          .set(updateData, SetOptions(merge: true));
    } catch (_) {}

    // 3. Gửi email thông báo
    await guiEmailTuChoiHopTac(
      emailNguoiNhan: email,
      tenBenhVien: tenBenhVien,
      maBenhVien: benhVienId,
      lyDo: lyDo,
    );
  }
}