import 'package:flutter/material.dart';

/// LUỒNG GIAO DIỆN TẠM THỜI — KHÔNG ĐỌC / GHI FIREBASE.
///
/// File này cố ý đứng riêng, không import `cloud_firestore`, không gọi service
/// và không chèn vào luồng đăng nhập thật. Dữ liệu được tách thành từng field
/// rõ ràng để sau này chỉ cần thay phần nguồn dữ liệu, còn widget thông báo
/// giữ nguyên.
///
/// Các mã `maNhanVien` / `maKhoa` / `maPhong` / `maBenhVien` là dữ liệu nội
/// bộ trong code: KHÔNG render lên giao diện. UI chỉ hiện tên và câu thông
/// báo, đúng yêu cầu "phân rõ dữ liệu" nhưng "không hiện mã".
class HardcodedDutyAssignment {
  const HardcodedDutyAssignment({
    required this.maNhanVien,
    required this.hoTen,
    required this.maKhoa,
    required this.tenKhoa,
    required this.maPhong,
    required this.tenPhong,
    required this.maBenhVien,
    required this.tenBenhVien,
  });

  /// Mã nhân viên — chỉ để đối chiếu trong code, không hiện trên UI.
  final String maNhanVien;

  /// Tên nhân viên — có thể hiện trên UI.
  final String hoTen;

  /// Mã khoa được phân công — chỉ để đối chiếu trong code.
  final String maKhoa;

  /// Tên khoa được phân công — dùng trong câu thông báo.
  final String tenKhoa;

  /// Mã phòng được phân công — chỉ để đối chiếu trong code.
  final String maPhong;

  /// Tên phòng được phân công — có thể hiện trên UI.
  final String tenPhong;

  /// Mã bệnh viện — chỉ để đối chiếu trong code.
  final String maBenhVien;

  /// Tên bệnh viện — có thể hiện trên UI.
  final String tenBenhVien;

  /// Đổi bản ghi phân công thành ngữ cảnh phòng để đưa vào danh sách chọn.
  HardcodedRoomContext get roomContext => HardcodedRoomContext(
    maKhoa: maKhoa,
    tenKhoa: tenKhoa,
    maPhong: maPhong,
    tenPhong: tenPhong,
    maBenhVien: maBenhVien,
    tenBenhVien: tenBenhVien,
  );
}

/// Một khoa/phòng hardcode mà nhân viên có thể đang cố mở.
///
/// `maKhoa` và `maPhong` được giữ riêng để sau này so sánh với dữ liệu thật
/// thay vì so sánh bằng tên hiển thị.
class HardcodedRoomContext {
  const HardcodedRoomContext({
    required this.maKhoa,
    required this.tenKhoa,
    required this.maPhong,
    required this.tenPhong,
    required this.maBenhVien,
    required this.tenBenhVien,
  });

  final String maKhoa;
  final String tenKhoa;
  final String maPhong;
  final String tenPhong;
  final String maBenhVien;
  final String tenBenhVien;
}

/// Phân công tạm: nhân viên này trực Khoa Tim mạch.
const HardcodedDutyAssignment kHardcodedDutyAssignment =
    HardcodedDutyAssignment(
      maNhanVien: 'BV502_BS_TM_01',
      hoTen: 'BS. Nguyễn Văn A',
      maKhoa: 'BV502_K001',
      tenKhoa: 'Khoa Tim mạch',
      maPhong: 'BV502_K001_HH001',
      tenPhong: 'Phòng Tim mạch 1',
      maBenhVien: 'BV502',
      tenBenhVien: 'Bệnh viện Đa khoa Mẫu',
    );

/// Danh sách khoa/phòng hardcode cho luồng thử giao diện.
///
/// Phần tử đầu cố ý SAI khoa so với [kHardcodedDutyAssignment] để màn hình
/// mở lên là thấy ngay thông báo "không trực khoa này".
const List<HardcodedRoomContext> kHardcodedRooms = <HardcodedRoomContext>[
  HardcodedRoomContext(
    maKhoa: 'BV502_K002',
    tenKhoa: 'Khoa Nhi',
    maPhong: 'BV502_K002_HH001',
    tenPhong: 'Phòng Nhi 1',
    maBenhVien: 'BV502',
    tenBenhVien: 'Bệnh viện Đa khoa Mẫu',
  ),
  HardcodedRoomContext(
    maKhoa: 'BV502_K001',
    tenKhoa: 'Khoa Tim mạch',
    maPhong: 'BV502_K001_HH001',
    tenPhong: 'Phòng Tim mạch 1',
    maBenhVien: 'BV502',
    tenBenhVien: 'Bệnh viện Đa khoa Mẫu',
  ),
  HardcodedRoomContext(
    maKhoa: 'BV502_K003',
    tenKhoa: 'Khoa Nội tổng quát',
    maPhong: 'BV502_K003_HH001',
    tenPhong: 'Phòng Nội 1',
    maBenhVien: 'BV502',
    tenBenhVien: 'Bệnh viện Đa khoa Mẫu',
  ),
];

/// Màn hình của luồng hardcode riêng.
///
/// Chọn một phòng trong danh sách mẫu: nếu `maKhoa` khác với mã khoa được
/// phân công, hiện thông báo kèm TÊN khoa đang trực thật. Nếu trùng, hiện
/// trạng thái đúng khoa. Không có gọi số, không có Firestore, không có
/// `DateTime.now()` và không có hiệu ứng đồng hồ.
class HardcodedDutyNoticeFlow extends StatefulWidget {
  const HardcodedDutyNoticeFlow({super.key});

  @override
  State<HardcodedDutyNoticeFlow> createState() =>
      _HardcodedDutyNoticeFlowState();
}

const Color _primary = Color(0xFF1E78E0);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _amber = Color(0xFFB45309);
const Color _amberBg = Color(0xFFFFF7E6);
const Color _green = Color(0xFF15803D);
const Color _greenBg = Color(0xFFECFDF3);

class _HardcodedDutyNoticeFlowState extends State<HardcodedDutyNoticeFlow> {
  late HardcodedRoomContext _selectedRoom;

  @override
  void initState() {
    super.initState();
    _selectedRoom = kHardcodedRooms.first;
  }

  /// So sánh bằng MÃ, không so sánh bằng tên hiển thị.
  bool get _isWrongDepartment =>
      _selectedRoom.maKhoa != kHardcodedDutyAssignment.maKhoa;

  /// Câu thông báo có nêu rõ đúng khoa đang trực.
  String get _noticeMessage =>
      'Hiện bạn không trực khoa này, bạn đang trực ở '
      '${kHardcodedDutyAssignment.tenKhoa}.';

  void _selectRoom(HardcodedRoomContext room) {
    setState(() => _selectedRoom = room);
  }

  void _backToAssignedRoom() {
    setState(() => _selectedRoom = kHardcodedDutyAssignment.roomContext);
  }

  @override
  Widget build(BuildContext context) {
    final wrongDepartment = _isWrongDepartment;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Thông báo trực khoa'),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DemoBadge(),
                  const SizedBox(height: 14),
                  _ContextCard(
                    hospitalName: kHardcodedDutyAssignment.tenBenhVien,
                    staffName: kHardcodedDutyAssignment.hoTen,
                    selectedRoom: _selectedRoom,
                  ),
                  const SizedBox(height: 18),
                  _NoticeCard(
                    wrongDepartment: wrongDepartment,
                    message: _noticeMessage,
                    assignedDepartmentName: kHardcodedDutyAssignment.tenKhoa,
                    assignedRoomName: kHardcodedDutyAssignment.tenPhong,
                    onBack: _backToAssignedRoom,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'CHỌN KHOA / PHÒNG TRONG DỮ LIỆU MẪU',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _muted,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final room in kHardcodedRooms)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RoomTile(
                        room: room,
                        selected: room.maKhoa == _selectedRoom.maKhoa &&
                            room.maPhong == _selectedRoom.maPhong,
                        isAssigned:
                            room.maKhoa == kHardcodedDutyAssignment.maKhoa,
                        onTap: () => _selectRoom(room),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFBFDBFE)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.badge_outlined, size: 15, color: _primary),
        SizedBox(width: 7),
        Text(
          'Luồng tạm · dữ liệu mẫu · chưa kết nối dữ liệu thật',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
        ),
      ],
    ),
  );
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.hospitalName,
    required this.staffName,
    required this.selectedRoom,
  });

  final String hospitalName;
  final String staffName;
  final HardcodedRoomContext selectedRoom;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x140F172A),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BỐI CẢNH ĐANG MỞ',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: _muted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hospitalName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          staffName,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _muted,
          ),
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 14),
        _InfoLine(label: 'Khoa đang mở', value: selectedRoom.tenKhoa),
        const SizedBox(height: 8),
        _InfoLine(label: 'Phòng đang mở', value: selectedRoom.tenPhong),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 112,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _muted,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ),
    ],
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.wrongDepartment,
    required this.message,
    required this.assignedDepartmentName,
    required this.assignedRoomName,
    required this.onBack,
  });

  final bool wrongDepartment;
  final String message;
  final String assignedDepartmentName;
  final String assignedRoomName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final accent = wrongDepartment
        ? _amber
        : _green;
    final background = wrongDepartment
        ? _amberBg
        : _greenBg;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                wrongDepartment
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  wrongDepartment ? 'KHÔNG ĐÚNG KHOA TRỰC' : 'ĐÚNG KHOA TRỰC',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            wrongDepartment ? message : 'Bạn đang đúng khoa trực. Có thể tiếp tục.',
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            wrongDepartment
                ? 'Vui lòng quay lại $assignedDepartmentName · $assignedRoomName '
                      'để tiếp tục công việc được phân công.'
                : '$assignedDepartmentName · $assignedRoomName',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: accent.withValues(alpha: 0.86),
            ),
          ),
          if (wrongDepartment) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Về khoa / phòng được phân công'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.selected,
    required this.isAssigned,
    required this.onTap,
  });

  final HardcodedRoomContext room;
  final bool selected;
  final bool isAssigned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _primary
                : const Color(0xFFE2E8F0),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected
                  ? _primary
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.tenKhoa,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    room.tenPhong,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            if (isAssigned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _greenBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Được phân công',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _green,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
