/// DANH MỤC TIỆN ÍCH DÙNG CHUNG CHO CSKH (C1)
class DuLieuCskhKhoaC1 {
  // 1. Danh mục lý do từ chối đơn khám
  static const List<String> danhSachLyDoTuChoi = [
    'Phòng khám đã đủ số lượng tiếp nhận tối đa',
    'Bác sĩ chỉ định có lịch mổ / hội chẩn đột xuất',
    'Thông tin thẻ BHYT hoặc thông tin cá nhân chưa khớp',
    'Khác (Nhập lý do gửi riêng cho bệnh nhân...)',
  ];

  // 2. Gợi ý trả lời nhanh cho chat (Canned Responses theo nghiệp vụ thực tế)
  static const List<Map<String, String>> danhMucTraLoiNhanh = [
    {
      'tieuDe': 'Xác nhận lịch hẹn',
      'noiDung': 'Chào bạn, bệnh viện đã xác nhận lịch khám của bạn. Vui lòng đến trước 15 phút tại quầy Lễ tân để quét mã tiếp nhận.',
    },
    {
      'tieuDe': 'Hướng dẫn BHYT',
      'noiDung': 'Khi đi khám, bạn vui lòng mang theo Thẻ BHYT (hoặc ứng dụng VssID) và CCCD gắn chip để được hưởng đầy đủ quyền lợi.',
    },
    {
      'tieuDe': 'Chuẩn bị trước xét nghiệm',
      'noiDung': 'Đối với các xét nghiệm máu và nội soi, bạn cần nhịn ăn sáng tối thiểu 6-8 tiếng và chỉ uống nước lọc.',
    },
    {
      'tieuDe': 'Hướng dẫn đổi giờ khám',
      'noiDung': 'Bạn có thể vào mục "Lịch khám của tôi" trên ứng dụng để chọn lại khung giờ khám mới phù hợp hơn.',
    },
    {
      'tieuDe': 'Khoa tạm kín lịch',
      'noiDung': 'Hiện phòng khám chuyên khoa này trong ca sáng đã đủ số lượng tiếp nhận. Bạn có thể đăng ký ca chiều (từ 13:30) hoặc chuyển sang ngày mai.',
    },
    {
      'tieuDe': 'Cảm ơn & Chào tạm biệt',
      'noiDung': 'Cảm ơn bạn đã liên hệ bộ phận Chăm sóc khách hàng bệnh viện. Chúc bạn một ngày nhiều sức khỏe!',
    },
  ];

  static const List<String> goiYTraLoiNhanh = [
    'Xác nhận lịch hẹn',
    'Hướng dẫn BHYT',
    'Nhịn ăn xét nghiệm',
    'Đổi giờ khám',
    'Khoa kín lịch',
    'Cảm ơn bạn',
  ];
}
