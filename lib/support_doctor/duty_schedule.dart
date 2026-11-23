import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'duty_assignment_guard.dart';

/// Callback khi bấm vào MỘT dòng lịch cụ thể. Luồng Firestore sẽ kiểm tra
/// id trạng thái / ngày / phòng rồi quyết định đưa thẳng vào `QueueScreen`.
typedef DutyScheduleTapHandler = Future<void> Function(
  DutyScheduleEntry entry,
);

/// Callback mỗi khi danh sách lịch trực realtime thay đổi.
typedef DutyScheduleListHandler = void Function(
  List<DutyScheduleEntry> entries,
);

/// Ngày trực của một dòng lịch: `yyyy-MM-dd` → [DateTime] chỉ gồm phần ngày.
///
/// `null` khi field `ngay` không đọc được. Màn hình chọn khoa dùng hàm này
/// để gom các ngày trực hợp lệ rồi truyền sang `QueueScreen`.
DateTime? dutyDayOf(DutyScheduleEntry entry) {
  final parts = entry.dateSortKey.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

/// Một dòng lịch trực của nhân viên đang đăng nhập.
///
/// Nội dung được phép render gồm ngày, tên khoa, tên phòng và nhãn trạng
/// thái. Các mã/id dưới đây chỉ dùng NỘI BỘ để lọc nhân viên, kiểm tra
/// trạng thái, so đúng ngày và tìm phòng; KHÔNG render lên giao diện, đúng
/// yêu cầu “giao diện chỉ hiện trạng thái, không hiện id” và “không cần
/// đúng tên nhân viên”.
class DutyScheduleEntry {
  const DutyScheduleEntry({
    required this.dateLabel,
    required this.dateSortKey,
    required this.departmentName,
    required this.roomName,
    required this.statusLabel,
    required this.hospitalId,
    required this.departmentId,
    required this.roomId,
    required this.statusId,
  });

  final String dateLabel;

  /// `yyyy-MM-dd` lấy từ field `ngay`, dùng để sắp xếp, làm ngày nạp hàng
  /// chờ và đối chiếu phân công khi bấm vào dòng lịch.
  final String dateSortKey;
  final String departmentName;
  final String roomName;
  final String statusLabel;

  final String hospitalId;
  final String departmentId;
  final String roomId;
  final String statusId;
}

/// Đọc realtime `PhanCong/{benhVien}/danh_sach` rồi lọc theo đúng mã nhân
/// viên đang đăng nhập (lấy từ document `NhanVien/...` qua guard hiện có).
///
/// Khác với guard vào phòng: thẻ lịch hiện TẤT CẢ lịch khớp mã nhân viên,
/// không giới hạn ngày hôm nay và không chỉ lọc `trang_thai_id = 16`.
class DutyScheduleService {
  const DutyScheduleService({
    required FirebaseFirestore firestore,
    required DutyAssignmentGuard guard,
  }) : _firestore = firestore,
       _guard = guard;

  final FirebaseFirestore _firestore;
  final DutyAssignmentGuard _guard;

  Stream<List<DutyScheduleEntry>> watchCurrentStaffSchedules(
    String hospitalId,
  ) async* {
    final id = hospitalId.trim();
    if (id.isEmpty) {
      yield const <DutyScheduleEntry>[];
      return;
    }

    final staffAliases = await _guard.resolveCurrentStaffAliases(id);
    if (staffAliases.isEmpty) {
      yield const <DutyScheduleEntry>[];
      return;
    }

    yield* _firestore
        .collection(kDutyAssignmentCollection)
        .doc(id)
        .collection(kDutyAssignmentSubcollection)
        .snapshots()
        .map((snapshot) {
      final entries = <DutyScheduleEntry>[];
      for (final doc in snapshot.docs) {
        final data = Map<String, Object?>.from(doc.data());
        if (!_belongsToCurrentStaff(data, staffAliases)) continue;
        final fields = _collectFields(data);
        final date = _dateFromFields(fields);
        final statusId = _statusIdFromFields(fields);
        entries.add(
          DutyScheduleEntry(
            dateLabel: date.label,
            dateSortKey: date.sortKey,
            departmentName: _labelFrom(
              fields,
              _departmentNameKeys,
              fallback: 'Chưa rõ khoa',
            ),
            roomName: _labelFrom(
              fields,
              _roomNameKeys,
              fallback: 'Chưa rõ phòng',
            ),
            statusLabel: _statusLabel(statusId, fields),
            hospitalId: _labelFrom(fields, _hospitalIdKeys, fallback: ''),
            departmentId: _labelFrom(fields, _departmentIdKeys, fallback: ''),
            roomId: _labelFrom(fields, _roomIdKeys, fallback: ''),
            statusId: statusId,
          ),
        );
      }
      entries.sort((a, b) {
        final byDate = b.dateSortKey.compareTo(a.dateSortKey);
        if (byDate != 0) return byDate;
        final byDepartment = a.departmentName.compareTo(b.departmentName);
        if (byDepartment != 0) return byDepartment;
        return a.roomName.compareTo(b.roomName);
      });
      return entries;
    });
  }
}

/// Thẻ lịch đặt ngay dưới tiêu đề màn hình chọn khoa.
///
/// - Nghe realtime một lần duy nhất cho toàn bộ màn hình; không `Timer`,
///   không tạo listener mới mỗi lần rebuild, không ghi ngược Firestore.
/// - Bấm “Xem tất cả” để mở danh sách toàn bộ lịch; danh sách này cũng
///   cập nhật theo cùng stream realtime.
/// - Bấm vào MỘT dòng lịch cụ thể gọi [onScheduleSelected] để luồng
///   Firestore kiểm tra id trạng thái / ngày / phòng rồi đưa thẳng vào phòng.
/// - [onEntriesChanged] (tuỳ chọn) báo danh sách lịch realtime ra ngoài, để
///   `QueueScreen` biết ngày nào có lịch trực và chặn đổi sang ngày khác.
class DutyScheduleBanner extends StatefulWidget {
  const DutyScheduleBanner({
    super.key,
    required this.hospitalId,
    required this.onScheduleSelected,
    this.onEntriesChanged,
    this.firestore,
    this.guard,
  });

  final String hospitalId;
  final DutyScheduleTapHandler onScheduleSelected;
  final DutyScheduleListHandler? onEntriesChanged;
  final FirebaseFirestore? firestore;
  final DutyAssignmentGuard? guard;

  @override
  State<DutyScheduleBanner> createState() => _DutyScheduleBannerState();
}

class _DutyScheduleBannerState extends State<DutyScheduleBanner> {
  late final DutyScheduleService _service;
  StreamSubscription<List<DutyScheduleEntry>>? _subscription;
  final ValueNotifier<_DutyScheduleView> _view =
      ValueNotifier<_DutyScheduleView>(const _DutyScheduleView(loading: true));
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final firestore = widget.firestore ?? FirebaseFirestore.instance;
    _service = DutyScheduleService(
      firestore: firestore,
      guard: widget.guard ?? DutyAssignmentGuard(firestore: firestore),
    );
    _startListening();
  }

  @override
  void didUpdateWidget(covariant DutyScheduleBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hospitalId != widget.hospitalId) _startListening();
  }

  void _startListening() {
    final generation = ++_generation;
    final previous = _subscription;
    _subscription = null;
    if (previous != null) unawaited(previous.cancel());
    _view.value = const _DutyScheduleView(loading: true);

    _subscription = _service
        .watchCurrentStaffSchedules(widget.hospitalId)
        .listen(
      (entries) {
        if (!mounted || generation != _generation) return;
        _view.value = _DutyScheduleView(entries: entries);
        widget.onEntriesChanged?.call(entries);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || generation != _generation) return;
        _view.value = const _DutyScheduleView(error: true);
        widget.onEntriesChanged?.call(const <DutyScheduleEntry>[]);
      },
    );
  }

  @override
  void dispose() {
    _generation++;
    final current = _subscription;
    _subscription = null;
    if (current != null) unawaited(current.cancel());
    _view.dispose();
    super.dispose();
  }

  void _handleEntryTap(
    DutyScheduleEntry entry, {
    BuildContext? sheetContext,
  }) {
    // Đóng bottom sheet trước để thông báo / màn hình phòng không bị che.
    if (sheetContext != null) Navigator.of(sheetContext).pop();
    unawaited(widget.onScheduleSelected(entry));
  }

  void _showAllSchedules() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.68,
        minChildSize: 0.42,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ValueListenableBuilder<_DutyScheduleView>(
            valueListenable: _view,
            builder: (context, view, _) => Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _ScheduleUi.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: _ScheduleUi.accent,
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'TẤT CẢ LỊCH TRỰC',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: _ScheduleUi.text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: _ScheduleUi.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _ScheduleList(
                    view: view,
                    scrollController: scrollController,
                    onRetry: _startListening,
                    onScheduleTap: (entry) =>
                        _handleEntryTap(entry, sheetContext: sheetContext),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<_DutyScheduleView>(
        valueListenable: _view,
        builder: (context, view, _) => _DutyScheduleCard(
          view: view,
          onRetry: _startListening,
          onViewAll: _showAllSchedules,
          onScheduleTap: (entry) => _handleEntryTap(entry),
        ),
      );
}

class _DutyScheduleView {
  const _DutyScheduleView({
    this.entries = const <DutyScheduleEntry>[],
    this.loading = false,
    this.error = false,
  });

  final List<DutyScheduleEntry> entries;
  final bool loading;
  final bool error;
}

class _DutyScheduleCard extends StatelessWidget {
  const _DutyScheduleCard({
    required this.view,
    required this.onRetry,
    required this.onViewAll,
    required this.onScheduleTap,
  });

  final _DutyScheduleView view;
  final VoidCallback onRetry;
  final VoidCallback onViewAll;
  final ValueChanged<DutyScheduleEntry> onScheduleTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    final canOpen = !view.loading && !view.error && view.entries.isNotEmpty;
    final preview = view.entries.take(2).toList();
    final remaining = view.entries.length - preview.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: canOpen ? onViewAll : null,
        child: Container(
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _ScheduleUi.border),
            boxShadow: _ScheduleUi.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 19,
                    color: _ScheduleUi.accent,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'LỊCH TRỰC CỦA BẠN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: _ScheduleUi.text,
                      ),
                    ),
                  ),
                  const _ScheduleLiveBadge(),
                ],
              ),
              const SizedBox(height: 12),
              if (view.loading)
                const _ScheduleNotice(
                  icon: Icons.hourglass_top_rounded,
                  message: 'Đang tải lịch trực…',
                  showSpinner: true,
                )
              else if (view.error)
                _ScheduleNotice(
                  icon: Icons.cloud_off_rounded,
                  message: 'Không tải được lịch trực. Vui lòng thử lại.',
                  actionLabel: 'Thử lại',
                  onAction: onRetry,
                )
              else if (view.entries.isEmpty)
                const _ScheduleNotice(
                  icon: Icons.event_busy_rounded,
                  message: 'Chưa có lịch trực.',
                )
              else ...[
                for (var index = 0; index < preview.length; index++) ...[
                  if (index > 0) const SizedBox(height: 10),
                  _SchedulePreviewRow(
                    entry: preview[index],
                    onTap: () => onScheduleTap(preview[index]),
                  ),
                ],
                if (remaining > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Còn $remaining lịch khác',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: _ScheduleUi.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onViewAll,
                    icon: const Icon(Icons.list_alt_rounded, size: 17),
                    label: Text('Xem tất cả (${view.entries.length})'),
                    style: TextButton.styleFrom(
                      foregroundColor: _ScheduleUi.accent,
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleLiveBadge extends StatelessWidget {
  const _ScheduleLiveBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFECFDF3),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFBBF7D0)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sync_rounded, size: 12, color: Color(0xFF15803D)),
        SizedBox(width: 4),
        Text(
          'Tự động cập nhật',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF15803D),
          ),
        ),
      ],
    ),
  );
}

class _SchedulePreviewRow extends StatelessWidget {
  const _SchedulePreviewRow({required this.entry, required this.onTap});

  final DutyScheduleEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _ScheduleUi.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.dateLabel} · ${entry.statusLabel}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _ScheduleUi.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.departmentName} · ${entry.roomName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _ScheduleUi.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({
    required this.view,
    required this.scrollController,
    required this.onRetry,
    required this.onScheduleTap,
  });

  final _DutyScheduleView view;
  final ScrollController scrollController;
  final VoidCallback onRetry;
  final ValueChanged<DutyScheduleEntry> onScheduleTap;

  @override
  Widget build(BuildContext context) {
    if (view.loading) {
      return const Center(
        child: _ScheduleNotice(
          icon: Icons.hourglass_top_rounded,
          message: 'Đang tải lịch trực…',
          showSpinner: true,
        ),
      );
    }
    if (view.error) {
      return Center(
        child: _ScheduleNotice(
          icon: Icons.cloud_off_rounded,
          message: 'Không tải được lịch trực. Vui lòng thử lại.',
          actionLabel: 'Thử lại',
          onAction: onRetry,
        ),
      );
    }
    if (view.entries.isEmpty) {
      return const Center(
        child: _ScheduleNotice(
          icon: Icons.event_busy_rounded,
          message: 'Chưa có lịch trực.',
        ),
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      itemCount: view.entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _ScheduleDetailTile(
        entry: view.entries[index],
        onTap: () => onScheduleTap(view.entries[index]),
      ),
    );
  }
}

class _ScheduleDetailTile extends StatelessWidget {
  const _ScheduleDetailTile({required this.entry, required this.onTap});

  final DutyScheduleEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ScheduleUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 17,
                color: _ScheduleUi.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.dateLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _ScheduleUi.text,
                  ),
                ),
              ),
              _ScheduleStatusPill(label: entry.statusLabel),
            ],
          ),
          const SizedBox(height: 10),
          _ScheduleLine(
            icon: Icons.local_hospital_outlined,
            label: entry.departmentName,
          ),
          const SizedBox(height: 6),
          _ScheduleLine(
            icon: Icons.meeting_room_outlined,
            label: entry.roomName,
          ),
        ],
      ),
    ),
  );
}

class _ScheduleLine extends StatelessWidget {
  const _ScheduleLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: _ScheduleUi.secondary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: _ScheduleUi.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _ScheduleStatusPill extends StatelessWidget {
  const _ScheduleStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFECFDF3),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF15803D),
      ),
    ),
  );
}

class _ScheduleNotice extends StatelessWidget {
  const _ScheduleNotice({
    required this.icon,
    required this.message,
    this.showSpinner = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final bool showSpinner;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showSpinner)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: 18, color: _ScheduleUi.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              color: _ScheduleUi.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: _ScheduleUi.accent,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(actionLabel!),
          ),
      ],
    ),
  );
}

abstract final class _ScheduleUi {
  static const Color border = Color(0xFFEEF0F7);
  static const Color text = Color(0xFF191C26);
  static const Color secondary = Color(0xFF8B90A0);
  static const Color accent = Color(0xFF2563EB);

  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x12101828), blurRadius: 22, offset: Offset(0, 10)),
  ];
}

/// Field chứa mã nhân viên trong document `PhanCong`. Cố tình KHÔNG gồm
/// `id` (mã bản ghi lịch) và KHÔNG gồm `ten_nhan_vien` (tên hiển thị).
const Set<String> _staffKeys = <String>{
  'manhanvien',
  'nhanvienid',
  'idnhanvien',
  'manv',
  'mataikhoan',
  'staffid',
  'staff',
  'mabacsi',
  'mabs',
  'bacsiid',
  'bacsyid',
  'bsid',
  'uid',
  'email',
  'emailnhanvien',
  'danhsachnhanvien',
  'danhsachbacsi',
  'dsnhanvien',
  'dsbacsi',
};

const Set<String> _dateKeys = <String>{
  'ngay',
  'date',
  'ngaytruc',
  'ngayphancong',
  'ngaylamviec',
  'ngaykham',
};

const Set<String> _departmentNameKeys = <String>{
  'tenkhoa',
  'departmentname',
  'tenchuyenkhoa',
  'tenkhoaphong',
};

const Set<String> _roomNameKeys = <String>{
  'tenphong',
  'roomname',
  'tenphongkham',
  'tenphongkhambenh',
};

/// Mã dùng NỘI BỘ để tìm đúng `ClinicRoomData` khi bấm một dòng lịch.
/// Không render lên giao diện.
const Set<String> _hospitalIdKeys = <String>{
  'benhvienid',
  'mabenhvien',
  'benhvien',
  'hospitalid',
};

const Set<String> _departmentIdKeys = <String>{
  'khoaid',
  'makhoa',
  'idkhoa',
  'departmentid',
  'department',
  'chuyenkhoaid',
  'makhoaphong',
};

const Set<String> _roomIdKeys = <String>{
  'phongid',
  'maphong',
  'idphong',
  'roomid',
  'room',
  'maphongkham',
  'phongkhamid',
  'phongkham',
  'idphongkham',
  'idphongkhambenh',
};

const Set<String> _statusTextKeys = <String>{
  'trangthai',
  'status',
  'assignmentstatus',
  'tentrangthai',
};

const Set<String> _statusIdKeys = <String>{
  'trangthaiid',
  'statusid',
  'idtrangthai',
  'matrangthai',
  'assignmentstatusid',
};

/// Id trạng thái chờ trong lịch trực. Khi gặp id này, luôn render đúng
/// nhãn "Chờ" dù document có kèm field `trang_thai` dạng chữ khác.
const String kDutyPendingStatusId = '15';

bool _belongsToCurrentStaff(
  Map<String, Object?> data,
  Set<String> staffAliases,
) {
  for (final entry in _flattenEntries(data)) {
    if (!_staffKeys.contains(_canonicalKey(entry.key))) continue;
    for (final value in _strings(entry.value)) {
      if (dutyIdentifierMatches(value, staffAliases)) return true;
    }
  }
  return false;
}

List<MapEntry<String, Object?>> _flattenEntries(Object? value, [int depth = 0]) {
  if (depth > 6) return <MapEntry<String, Object?>>[];
  final result = <MapEntry<String, Object?>>[];
  if (value is Map) {
    for (final entry in value.entries) {
      result.add(MapEntry<String, Object?>(entry.key.toString(), entry.value));
      result.addAll(_flattenEntries(entry.value, depth + 1));
    }
  } else if (value is List) {
    for (final item in value) {
      result.addAll(_flattenEntries(item, depth + 1));
    }
  }
  return result;
}

Map<String, List<Object?>> _collectFields(
  Object? value, [
  int depth = 0,
  Map<String, List<Object?>>? result,
]) {
  final fields = result ?? <String, List<Object?>>{};
  if (depth > 6) return fields;
  if (value is Map) {
    for (final entry in value.entries) {
      final key = _canonicalKey(entry.key.toString());
      fields.putIfAbsent(key, () => <Object?>[]).add(entry.value);
      _collectFields(entry.value, depth + 1, fields);
    }
  } else if (value is List) {
    for (final item in value) {
      _collectFields(item, depth + 1, fields);
    }
  }
  return fields;
}

Set<String> _strings(Object? value, [int depth = 0]) {
  final result = <String>{};
  if (depth > 6) return result;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) result.add(trimmed);
  } else if (value is num || value is bool) {
    result.add(value.toString());
  } else if (value is List) {
    for (final item in value) {
      result.addAll(_strings(item, depth + 1));
    }
  } else if (value is Map) {
    for (final item in value.values) {
      result.addAll(_strings(item, depth + 1));
    }
  }
  return result;
}

String _labelFrom(
  Map<String, List<Object?>> fields,
  Set<String> keys, {
  required String fallback,
}) {
  final value = _firstString(fields, keys);
  return value.isEmpty ? fallback : value;
}

String _statusIdFromFields(Map<String, List<Object?>> fields) {
  final raw = _firstString(fields, _statusIdKeys);
  if (raw.isEmpty) return '';
  final parsed = num.tryParse(raw);
  return parsed == null ? raw : parsed.toInt().toString();
}

String _statusLabel(String statusId, Map<String, List<Object?>> fields) {
  // Id trạng thái 15 được ưu tiên tuyệt đối: phần lịch trực phải hiện "Chờ".
  if (statusId == kDutyPendingStatusId) return 'Chờ';
  final text = _firstString(fields, _statusTextKeys);
  if (text.isNotEmpty) return _sentenceCase(text);
  if (statusId == kDutyActiveStatusId) return 'Đã phân công';
  return 'Chưa rõ trạng thái';
}

String _firstString(Map<String, List<Object?>> fields, Set<String> keys) {
  for (final key in keys) {
    for (final raw in fields[key] ?? const <Object?>[]) {
      for (final value in _strings(raw)) {
        if (value.trim().isNotEmpty) return value.trim();
      }
    }
  }
  return '';
}

class _DateInfo {
  const _DateInfo(this.label, this.sortKey);

  final String label;
  final String sortKey;
}

_DateInfo _dateFromFields(Map<String, List<Object?>> fields) {
  for (final key in _dateKeys) {
    for (final raw in fields[key] ?? const <Object?>[]) {
      final info = _dateFromValue(raw);
      if (info.sortKey.isNotEmpty) return info;
    }
  }
  return const _DateInfo('Chưa rõ ngày', '');
}

_DateInfo _dateFromValue(Object? value, [int depth = 0]) {
  if (depth > 6) return const _DateInfo('Chưa rõ ngày', '');
  if (value is String) {
    final trimmed = value.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) {
      final key = trimmed.substring(0, 10);
      return _DateInfo(_displayDate(key), key);
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final key = _ymd(parsed.toLocal());
      return _DateInfo(_displayDate(key), key);
    }
  } else if (value is Timestamp) {
    final key = _ymd(value.toDate().toLocal());
    return _DateInfo(_displayDate(key), key);
  } else if (value is DateTime) {
    final key = _ymd(value.toLocal());
    return _DateInfo(_displayDate(key), key);
  } else if (value is List) {
    for (final item in value) {
      final info = _dateFromValue(item, depth + 1);
      if (info.sortKey.isNotEmpty) return info;
    }
  } else if (value is Map) {
    for (final item in value.values) {
      final info = _dateFromValue(item, depth + 1);
      if (info.sortKey.isNotEmpty) return info;
    }
  }
  return const _DateInfo('Chưa rõ ngày', '');
}

String _ymd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _displayDate(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return 'Chưa rõ ngày';
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String _sentenceCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

String _canonicalKey(String key) =>
    key.toLowerCase().replaceAll(RegExp(r'[_\-\s./]'), '');
