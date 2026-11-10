import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/letan_c1/letan_profile_tab_c1.dart';
import 'queue_screen.dart';
import 'room_session_store.dart';
import 'room_status.dart';

/// A reusable screen for choosing a department and then a clinic room.
///
/// This widget is generic so it can use the `RoomInfo` model from an existing
/// app without declaring that model again. See the usage example at the bottom
/// of this file.
class DepartmentRoomPicker<T> extends StatefulWidget {
  const DepartmentRoomPicker({
    super.key,
    required this.rooms,
    required this.departmentOf,
    required this.hospitalIdOf,
    required this.departmentIdOf,
    required this.roomIdOf,
    required this.roomNameOf,
    required this.statusLabelOf,
    required this.isOpen,
    required this.isPaused,
    required this.isClosed,
    required this.currentNumberOf,
    required this.waitingCountOf,
    required this.examinedCountOf,
    required this.onRoomSelected,
    this.initialDepartment,
    this.hospitalName = 'Bệnh viện',
    this.title = 'Chọn phòng khám',
    this.onLogout,
    this.logoutLabel = 'Đăng xuất',
    this.confirmLogout = true,
  });

  /// Room data supplied by the app.
  final List<T> rooms;

  /// Adapters that read the required values from the app's room model.
  final String Function(T room) departmentOf;
  final String Function(T room) hospitalIdOf;
  final String Function(T room) departmentIdOf;
  final String Function(T room) roomIdOf;
  final String Function(T room) roomNameOf;
  final String Function(T room) statusLabelOf;
  final bool Function(T room) isOpen;
  final bool Function(T room) isPaused;
  final bool Function(T room) isClosed;
  final int? Function(T room) currentNumberOf;
  final int Function(T room) waitingCountOf;
  final int Function(T room) examinedCountOf;

  /// Called when the user taps an available room.
  final ValueChanged<T> onRoomSelected;

  /// Khoa mặc định (giữ lại để tương thích với mã gọi cũ). Trang chọn nay
  /// luôn mở ở bước chọn khoa nên giá trị này không còn tự đưa người dùng
  /// vào thẳng danh sách phòng.
  final String? initialDepartment;
  final String hospitalName;
  final String title;

  /// Xử lý đăng xuất của app bao quanh.
  ///
  /// Khi được cung cấp, callback chịu trách nhiệm TOÀN BỘ việc đăng xuất:
  /// kết thúc phiên (ví dụ qua AuthProvider của app) VÀ chuyển màn hình
  /// (thường về route đăng nhập) — widget không tự gọi Navigator nữa.
  /// Để `null` thì nút đăng xuất tự chuyển thẳng về [LoginScreen]
  /// và xoá toàn bộ stack.
  final Future<void> Function()? onLogout;

  /// Nhãn của nút đăng xuất (ẩn nhãn khi màn hình hẹp).
  final String logoutLabel;

  /// Có hỏi xác nhận trước khi đăng xuất hay không.
  final bool confirmLogout;

  @override
  State<DepartmentRoomPicker<T>> createState() =>
      _DepartmentRoomPickerState<T>();
}

class _DepartmentRoomPickerState<T> extends State<DepartmentRoomPicker<T>> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _departmentSearchController =
      TextEditingController();
  String? _selectedDepartment;
  _RoomFilter _filter = _RoomFilter.all;

  List<String> get _departments {
    final values = widget.rooms
        .map((room) => widget.departmentOf(room).trim())
        .where((department) => department.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  /// Danh sách khoa sau khi lọc theo ô tìm khoa ở bước chọn khoa
  /// (tìm theo tên khoa và mã khoa).
  List<String> get _visibleDepartments {
    final query = _departmentSearchController.text.trim().toLowerCase();
    final departments = _departments;
    if (query.isEmpty) return departments;
    return departments.where((department) {
      final roomsInDepartment = _roomsOfDepartment(department);
      final departmentId = roomsInDepartment.isEmpty
          ? ''
          : widget.departmentIdOf(roomsInDepartment.first);
      final searchable = ('$department $departmentId').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  /// Các phòng của một khoa (so theo tên khoa đã cắt khoảng trắng).
  List<T> _roomsOfDepartment(String department) => widget.rooms
      .where((room) => widget.departmentOf(room).trim() == department)
      .toList();

  List<T> get _departmentRooms {
    final selected = _selectedDepartment;
    return selected == null
        ? widget.rooms.toList()
        : _roomsOfDepartment(selected);
  }

  /// Đang ở bước 1 (chọn khoa): chưa chọn khoa và dữ liệu có ít nhất một
  /// khoa. Khi dữ liệu không có khoa nào, hiển thị thẳng bước chọn phòng
  /// với toàn bộ phòng như trước đây.
  bool get _choosingDepartment =>
      _selectedDepartment == null && _departments.isNotEmpty;

  void _chooseDepartment(String department) {
    setState(() {
      _selectedDepartment = department;
      _filter = _RoomFilter.all;
      _searchController.clear();
    });
  }

  void _backToDepartments() {
    setState(() {
      _selectedDepartment = null;
      _filter = _RoomFilter.all;
      _searchController.clear();
    });
  }

  List<T> get _visibleRooms {
    final query = _searchController.text.trim().toLowerCase();
    return _departmentRooms.where((room) {
      final matchesStatus = switch (_filter) {
        _RoomFilter.all => true,
        _RoomFilter.open => widget.isOpen(room),
        _RoomFilter.paused => widget.isPaused(room),
        _RoomFilter.closed => widget.isClosed(room),
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;

      // Chỉ tìm theo phòng (tên phòng và mã phòng), không tìm theo khoa.
      final searchable = ('${widget.roomNameOf(room)} ${widget.roomIdOf(room)}')
          .toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  void didUpdateWidget(covariant DepartmentRoomPicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Khoa đang xem không còn phòng nào -> quay về bước chọn khoa.
    final selected = _selectedDepartment;
    if (selected != null && !_departments.contains(selected)) {
      _selectedDepartment = null;
      _filter = _RoomFilter.all;
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _departmentSearchController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _PickerUi.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        ),
      );
  }

  /// Mở màn hình Hồ sơ cá nhân của nhân viên y tế (đổi mật khẩu, xem thông tin)
  void _handleOpenProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Hồ Sơ Hỗ Trợ Bác Sĩ', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
          ),
          body: LetanProfileTabC1(
            tenKhoaHienTai: _selectedDepartment ?? widget.initialDepartment,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _visibleRooms;
    final departments = _departments;
    final visibleDepartments = _visibleDepartments;
    // Tablet (chiều rộng màn hình từ 600dp): bỏ trần 620dp để giao diện
    // dàn full màn hình thay vì bó thành một cột hẹp ở giữa.
    final useFullWidth = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_PickerUi.bgTop, _PickerUi.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: useFullWidth ? double.infinity : 620,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 430;
                  final tablet = constraints.maxWidth >= 768;
                  final horizontalPadding = compact
                      ? 16.0
                      : tablet
                      ? 28.0
                      : 22.0;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      tablet ? 24 : 20,
                      horizontalPadding,
                      tablet ? 36 : 30,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontSize: compact
                                          ? 21
                                          : tablet
                                          ? 28
                                          : 24,
                                      fontWeight: FontWeight.w800,
                                      color: _PickerUi.text,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const _PickerPulseDot(),
                                      const SizedBox(width: 7),
                                      Flexible(
                                        child: Text(
                                          _selectedDepartment == null
                                              ? widget.hospitalName
                                              : '${_selectedDepartment!} · ${widget.hospitalName}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _PickerUi.secondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _PickerLogoutButton(
                              compact: compact,
                              label: 'Hồ sơ',
                              busy: false,
                              onTap: _handleOpenProfile,
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 16 : 20),
                        if (_choosingDepartment) ...[
                          const Text(
                            'CHỌN KHOA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                              color: _PickerUi.faint,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildSearchBox(
                            controller: _departmentSearchController,
                            hintText: 'Tìm khoa…',
                          ),
                          const SizedBox(height: 12),
                          if (visibleDepartments.isEmpty)
                            _buildEmptyState('Không tìm thấy khoa phù hợp.')
                          else
                            for (
                              var index = 0;
                              index < visibleDepartments.length;
                              index++
                            )
                              Padding(
                                padding: EdgeInsets.only(
                                  top: index == 0 ? 0 : 12,
                                ),
                                child: _buildDepartmentCard(
                                  visibleDepartments[index],
                                  compact,
                                ),
                              ),
                        ] else ...[
                          if (departments.isNotEmpty) ...[
                            _buildBackToDepartmentsButton(),
                            const SizedBox(height: 12),
                          ],
                          _buildSearchBox(
                            controller: _searchController,
                            hintText: 'Tìm phòng…',
                          ),
                          const SizedBox(height: 12),
                          _buildStatusFilters(),
                          const SizedBox(height: 16),
                          if (rooms.isEmpty)
                            _buildEmptyState()
                          else
                            for (var index = 0; index < rooms.length; index++)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: index == 0 ? 0 : 12,
                                ),
                                child: _buildRoomCard(rooms[index], compact),
                              ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ô tìm kiếm dùng chung cho cả hai bước (tìm khoa / tìm phòng).
  Widget _buildSearchBox({
    required TextEditingController controller,
    required String hintText,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _PickerUi.border),
      boxShadow: _PickerUi.quietShadow,
    ),
    child: TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _PickerUi.text,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 13.5,
          color: Color(0xFFB6BCC9),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: _PickerUi.faint,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  setState(() {});
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: _PickerUi.faint,
                ),
              ),
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    ),
  );

  Widget _buildStatusFilters() {
    final filters = <(_RoomFilter, String, int)>[
      (_RoomFilter.all, 'Tất cả', _departmentRooms.length),
      (
        _RoomFilter.open,
        ClinicRoomStatus.open.fullLabel,
        _departmentRooms.where(widget.isOpen).length,
      ),
      (
        _RoomFilter.paused,
        ClinicRoomStatus.paused.fullLabel,
        _departmentRooms.where(widget.isPaused).length,
      ),
      (
        _RoomFilter.closed,
        ClinicRoomStatus.closed.fullLabel,
        _departmentRooms.where(widget.isClosed).length,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < filters.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            _PickerFilterChip(
              label: filters[index].$2,
              count: filters[index].$3,
              selected: _filter == filters[index].$1,
              onTap: () => setState(() => _filter = filters[index].$1),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState([String? message]) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _PickerUi.border),
      boxShadow: _PickerUi.cardShadow,
    ),
    child: Row(
      children: [
        const Icon(Icons.search_off_rounded, color: _PickerUi.faint),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message ??
                (widget.rooms.isEmpty
                    ? 'Chưa có phòng khám.'
                    : 'Không tìm thấy phòng phù hợp.'),
            style: const TextStyle(fontSize: 13, color: _PickerUi.secondary),
          ),
        ),
      ],
    ),
  );

  /// Nút quay lại bước chọn khoa (hiện ở đầu bước chọn phòng).
  Widget _buildBackToDepartmentsButton() => Align(
    alignment: Alignment.centerLeft,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: _backToDepartments,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _PickerUi.border),
            boxShadow: _PickerUi.quietShadow,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_rounded,
                size: 17,
                color: _PickerUi.secondary,
              ),
              SizedBox(width: 7),
              Text(
                'Đổi khoa',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _PickerUi.text,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// Thẻ khoa ở bước 1: bấm để sang bước chọn phòng của khoa đó. Dáng thẻ
  /// giống thẻ phòng: ô mã khoa, tên khoa, số phòng/đang khám và mũi tên.
  Widget _buildDepartmentCard(String department, bool compact) {
    final roomsInDepartment = _roomsOfDepartment(department);
    final openCount = roomsInDepartment.where(widget.isOpen).length;
    final pausedCount = roomsInDepartment.where(widget.isPaused).length;
    final departmentId = roomsInDepartment.isEmpty
        ? ''
        : widget.departmentIdOf(roomsInDepartment.first).trim();
    final hospitalId = roomsInDepartment.isEmpty
        ? ''
        : widget.hospitalIdOf(roomsInDepartment.first).trim();
    final codeLine = [
      if (hospitalId.isNotEmpty) 'BV $hospitalId',
      if (departmentId.isNotEmpty) 'Khoa $departmentId',
    ].join('  ·  ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _PickerUi.border),
        boxShadow: _PickerUi.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _chooseDepartment(department),
          child: Padding(
            padding: EdgeInsets.all(compact ? 14 : 16),
            child: Row(
              children: [
                Container(
                  width: compact ? 52 : 58,
                  height: compact ? 52 : 58,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3D9BF0), Color(0xFF0F6CD6)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: departmentId.isEmpty
                      ? const Icon(
                          Icons.local_hospital_rounded,
                          color: Colors.white,
                          size: 26,
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            departmentId,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: compact ? 14 : 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              department,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 14 : 15,
                                fontWeight: FontWeight.w800,
                                color: _PickerUi.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _PickerRoomStatus(
                            label: '${roomsInDepartment.length} phòng',
                            foreground: const Color(0xFF107FE8),
                            background: const Color(0x14107FE8),
                          ),
                        ],
                      ),
                      if (codeLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          codeLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: _PickerUi.faint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 11,
                        runSpacing: 6,
                        children: [
                          _PickerMeta(
                            icon: Icons.meeting_room_rounded,
                            text: '${roomsInDepartment.length} phòng khám',
                          ),
                          _PickerMeta(
                            icon: Icons.check_circle_rounded,
                            text: '$openCount đang khám',
                          ),
                          if (pausedCount > 0)
                            _PickerMeta(
                              icon: Icons.pause_circle_rounded,
                              text: '$pausedCount tạm dừng',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0x14107FE8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Color(0xFF107FE8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCard(T room, bool compact) {
    final closed = widget.isClosed(room);
    final paused = widget.isPaused(room);
    final open = widget.isOpen(room);
    final statusColor = open
        ? const Color(0xFF1E8E43)
        : paused
        ? const Color(0xFFB47A00)
        : const Color(0xFF8B90A0);
    final statusBackground = open
        ? const Color(0x1F2AC653)
        : paused
        ? const Color(0x24F5A623)
        : const Color(0x14101828);
    final badgeGradient = open
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF41D366), Color(0xFF1FA24C)],
          )
        : paused
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD54A), Color(0xFFFF9000)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD9DDE8), Color(0xFFB7BDCC)],
          );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _PickerUi.border),
        boxShadow: _PickerUi.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Phòng đã đóng VẪN vào được màn hình hàng chờ để bác sĩ bấm
          // "Mở phòng khám" ở nút dưới cùng; nếu chặn tap thì phòng bị kẹt.
          onTap: () {
            if (closed) {
              _showMessage(
                '${widget.roomNameOf(room)} đã đóng. Mở lại từ trong phòng.',
              );
            }
            widget.onRoomSelected(room);
          },
          child: Padding(
            padding: EdgeInsets.all(compact ? 14 : 16),
            child: Row(
              children: [
                Container(
                  width: compact ? 52 : 58,
                  height: compact ? 52 : 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: badgeGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    widget.roomIdOf(room),
                    style: TextStyle(
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w800,
                      color: paused ? const Color(0xFF3A2A00) : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.roomNameOf(room),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 14 : 15,
                                fontWeight: FontWeight.w800,
                                color: _PickerUi.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _PickerRoomStatus(
                            label: widget.statusLabelOf(room),
                            foreground: statusColor,
                            background: statusBackground,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'BV ${widget.hospitalIdOf(room)}  ·  '
                        'Khoa ${widget.departmentIdOf(room)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _PickerUi.faint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 11,
                        runSpacing: 6,
                        children: [
                          _PickerMeta(
                            icon: Icons.person_rounded,
                            text: (widget.currentNumberOf(room) ?? 0) <= 0
                                ? 'Chưa gọi số'
                                : 'Số ${widget.currentNumberOf(room)}',
                          ),
                          _PickerMeta(
                            icon: Icons.groups_rounded,
                            text: '${widget.waitingCountOf(room)} đang đợi',
                          ),
                          _PickerMeta(
                            icon: Icons.task_alt_rounded,
                            text: '${widget.examinedCountOf(room)} đã khám',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: closed
                        ? const Color(0xFFF2F4F8)
                        : const Color(0x14107FE8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    closed
                        ? Icons.lock_outline_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                    color: closed ? _PickerUi.faint : const Color(0xFF107FE8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _PickerUi {
  static const Color bgTop = Color(0xFFF9FAFE);
  static const Color bgBottom = Color(0xFFEBEFF8);
  static const Color border = Color(0xFFEEF0F7);
  static const Color text = Color(0xFF191C26);
  static const Color secondary = Color(0xFF8B90A0);
  static const Color faint = Color(0xFFAAB0BE);

  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x12101828), blurRadius: 22, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> quietShadow = <BoxShadow>[
    BoxShadow(color: Color(0x0F101828), blurRadius: 12, offset: Offset(0, 6)),
  ];
}

enum _RoomFilter { all, open, paused, closed }

class _PickerPulseDot extends StatelessWidget {
  const _PickerPulseDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: Color(0xFF35C95B),
      shape: BoxShape.circle,
    ),
  );
}

/// Nút đăng xuất ở góc phải phần tiêu đề. Ẩn nhãn chữ khi màn hình hẹp,
/// hiện vòng xoay khi đang xử lý đăng xuất.
class _PickerLogoutButton extends StatelessWidget {
  const _PickerLogoutButton({
    required this.compact,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final bool compact;
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: onTap == null ? 0.65 : 1,
          child: Container(
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _PickerUi.border),
              boxShadow: _PickerUi.quietShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFE94B45),
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 18,
                    color: Color(0xFF0284C7),
                  ),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return compact ? Tooltip(message: label, child: button) : button;
  }
}

class _PickerFilterChip extends StatelessWidget {
  const _PickerFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? _PickerUi.text : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? _PickerUi.text : _PickerUi.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _PickerUi.secondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0x33FFFFFF)
                    : const Color(0xFFF1F3F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : _PickerUi.faint,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PickerRoomStatus extends StatelessWidget {
  const _PickerRoomStatus({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      maxLines: 1,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        color: foreground,
      ),
    ),
  );
}

class _PickerMeta extends StatelessWidget {
  const _PickerMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: _PickerUi.faint),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: _PickerUi.secondary,
        ),
      ),
    ],
  );
}

/// Trạng thái phòng khám dùng cho màn hình chọn khoa/phòng.
enum ClinicRoomStatus { open, paused, closed }

extension ClinicRoomStatusLabel on ClinicRoomStatus {
  /// Nhãn ngắn, giữ để tương thích mã cũ; giao diện hiện dùng [fullLabel].
  String get label => switch (this) {
    ClinicRoomStatus.open => 'Đang khám',
    ClinicRoomStatus.paused => 'Tạm dừng',
    ClinicRoomStatus.closed => 'Đã đóng',
  };

  /// Mã id tương ứng để ghi ngược lên `PhongKham/{roomId}`.
  int get statusId => switch (this) {
    ClinicRoomStatus.open => kRoomStatusOpenId,
    ClinicRoomStatus.paused => kRoomStatusPausedId,
    ClinicRoomStatus.closed => kRoomStatusClosedId,
  };

  /// Nhãn đầy đủ theo đúng bảng 12/13/14.
  String get fullLabel => switch (this) {
    ClinicRoomStatus.open => kRoomStatusLabels[kRoomStatusOpenId]!,
    ClinicRoomStatus.paused => kRoomStatusLabels[kRoomStatusPausedId]!,
    ClinicRoomStatus.closed => kRoomStatusLabels[kRoomStatusClosedId]!,
  };
}

/// Thông tin một phòng trong màn hình chọn khoa/phòng.
class ClinicRoomData {
  const ClinicRoomData({
    required this.hospitalId,
    required this.departmentId,
    required this.id,
    required this.name,
    required this.department,
    required this.staffId,
    required this.status,
    this.trangThaiId,
    this.currentNumber,
    this.waitingCount = 0,
    this.examinedCount = 0,
  });

  /// ID bệnh viện (`id_benhvien`).
  final String hospitalId;

  /// ID khoa (`id_khoa`) của phòng khám.
  final String departmentId;

  /// ID phòng khám (`id_phongkham`).
  final String id;
  final String name;
  final String department;
  final String staffId;
  final ClinicRoomStatus status;

  /// Id trạng thái sau khi đối chiếu 4 field trong `PhongKham/{id}`
  /// (12 tạm dừng / 13 đang khám / 14 đóng phòng), ưu tiên field số.
  /// **Không hiển thị trên giao diện**, chỉ dùng nội bộ. `null` khi
  /// document chưa có field hợp lệ — lúc đó dùng trạng thái phiên trong
  /// [RoomSessionStore] như cũ.
  final int? trangThaiId;
  final int? currentNumber;
  final int waitingCount;
  final int examinedCount;

  /// Nhãn hiện trong bảng trạng thái phòng khám: **chỉ tên trạng thái**,
  /// không kèm `trang_thai_id`. Id vẫn được giữ nội bộ để đối chiếu 4
  /// field Firestore và quyết định Firestore/local precedence.
  String get statusLabel => status.fullLabel;

  /// Bản sao có cập nhật trạng thái/số liệu theo thời gian chạy.
  ClinicRoomData copyWith({
    ClinicRoomStatus? status,
    int? trangThaiId,
    int? currentNumber,
    int? waitingCount,
    int? examinedCount,
  }) => ClinicRoomData(
    hospitalId: hospitalId,
    departmentId: departmentId,
    id: id,
    name: name,
    department: department,
    staffId: staffId,
    status: status ?? this.status,
    trangThaiId: trangThaiId ?? this.trangThaiId,
    currentNumber: currentNumber ?? this.currentNumber,
    waitingCount: waitingCount ?? this.waitingCount,
    examinedCount: examinedCount ?? this.examinedCount,
  );

  String sessionIdForToday() {
    final now = DateTime.now();
    final date =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return '$hospitalId-$departmentId-$id-$date-01';
  }
}

/// Nguồn dữ liệu realtime cho một phòng: luồng số thứ tự từ lịch hẹn,
/// luồng trạng thái đã đối chiếu từ 4 field của chính phòng, và các hàm
/// ghi kết quả khám / số thứ tự / trạng thái về nơi lưu trữ.
typedef ClinicAppointmentFeed = ({
  /// Luồng STT của ngày hôm nay, giữ cho mã gọi cũ / chế độ demo.
  Stream<AppointmentQueueUpdate> updates,

  /// Luồng STT cho MỘT ngày bất kỳ do bộ chọn lịch trên QueueScreen truyền
  /// vào. Khi đổi ngày, QueueScreen hủy đăng ký cũ và nghe luồng mới này.
  Stream<AppointmentQueueUpdate> Function(DateTime day) updatesForDay,

  Future<void> Function(String appointmentId, AppointmentOutcome outcome)
  reportOutcome,

  /// Ghi số thứ tự mới của một lịch hẹn khi nhân viên chèn số: số vừa
  /// chèn nhận `số mốc + 1`, các số phía sau tăng thêm 1.
  Future<void> Function(String appointmentId, int soThuTu) renumber,

  /// Id trạng thái theo thời gian thực, đã đối chiếu từ `trang_thai_id`,
  /// `trangThaiId`, `trang_thai`, `trangThai` (ưu tiên field số):
  /// 12 tạm dừng / 13 đang khám / 14 đóng phòng; `null` khi document
  /// chưa có field hợp lệ.
  Stream<int?> roomStatus,

  /// Ghi `trang_thai_id` + `trang_thai` lên Firestore khi bác sĩ bấm nút
  /// Tạm dừng / Tiếp tục hoặc Đóng / Mở phòng khám.
  Future<void> Function(int statusId) setRoomStatus,
});

/// Màn hình chọn khoa/phòng đã kết nối với QueueScreen trong queue_screen.dart.
/// Dữ liệu phòng lấy trực tiếp từ danh sách [rooms] do bên gọi cung cấp.
/// Để lấy từ Cloud Firestore theo thời gian thực, dùng
/// FirestoreClinicRoomPickerScreen trong clinic_firestore_service.dart.
class ClinicRoomPickerScreen extends StatelessWidget {
  const ClinicRoomPickerScreen({
    super.key,
    this.rooms = const <ClinicRoomData>[],
    this.initialDepartment = 'Khoa Tim',
    this.hospitalName = 'Bệnh viện Bạch Mai',
    this.onLogout,
    this.appointmentFeedFor,
  });

  final List<ClinicRoomData> rooms;
  final String initialDepartment;
  final String hospitalName;

  /// Xử lý đăng xuất thật của app. Ví dụ:
  ///
  /// ```dart
  /// ClinicRoomPickerScreen(
  ///   rooms: rooms,
  ///   onLogout: () async {
  ///     await appAuth.logout();   // đăng xuất khỏi phiên của app
  ///     navigator.pushNamedAndRemoveUntil('/login', (_) => false);
  ///   },
  /// )
  /// ```
  ///
  /// (`appAuth`/`navigator` là của app bao quanh, lấy từ context nơi
  /// tạo callback.) Khi có callback, widget KHÔNG tự chuyển màn hình —
  /// đăng xuất và điều hướng do app đảm nhiệm. Để `null` thì nút đăng
  /// xuất tự chuyển về [LoginScreen] và xoá toàn bộ stack điều hướng.
  final Future<void> Function()? onLogout;

  /// Nguồn số thứ tự từ lịch hẹn cho từng phòng khi mở màn hình hàng
  /// chờ. Đây là nguồn STT duy nhất: để `null` (hoặc hàm trả về `null`
  /// cho một phòng) thì QueueScreen không tự sinh số và không nạp thêm
  /// bệnh nhân nào ngoài trạng thái phiên đã có trong cùng lần chạy app.
  final ClinicAppointmentFeed? Function(ClinicRoomData room)?
  appointmentFeedFor;

  /// Danh sách phòng kèm trạng thái/số liệu thật lấy từ [RoomSessionStore]
  /// (phòng chưa mở lần nào thì giữ nguyên dữ liệu ban đầu).
  List<ClinicRoomData> _liveRooms() => <ClinicRoomData>[
    for (final room in rooms)
      if (RoomSessionStore.instance.sessionOf(room.id) case final snapshot
          when snapshot.started)
        room.copyWith(
          // Khi đối chiếu được id từ 4 field Firestore thì Firestore là
          // nguồn sự thật cho bảng trạng thái; chỉ phủ trạng thái phiên
          // local cho dữ liệu cũ chưa có field hợp lệ.
          status: room.trangThaiId != null
              ? room.status
              : switch (snapshot.status) {
                RoomRuntimeStatus.open => ClinicRoomStatus.open,
                RoomRuntimeStatus.paused => ClinicRoomStatus.paused,
                RoomRuntimeStatus.closed => ClinicRoomStatus.closed,
              },
          currentNumber: snapshot.currentNumber,
          waitingCount: snapshot.waitingCount,
          examinedCount: snapshot.examinedCount,
        )
      else
        room,
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: RoomSessionStore.instance,
    builder: (context, _) => _buildPicker(context, _liveRooms()),
  );

  Widget _buildPicker(BuildContext context, List<ClinicRoomData> liveRooms) =>
      DepartmentRoomPicker<ClinicRoomData>(
        rooms: liveRooms,
        initialDepartment: initialDepartment,
        hospitalName: hospitalName,
        onLogout: onLogout,
        departmentOf: (room) => room.department,
        hospitalIdOf: (room) => room.hospitalId,
        departmentIdOf: (room) => room.departmentId,
        roomIdOf: (room) => room.id,
        roomNameOf: (room) => room.name,
        statusLabelOf: (room) => room.statusLabel,
        isOpen: (room) => room.status == ClinicRoomStatus.open,
        isPaused: (room) => room.status == ClinicRoomStatus.paused,
        isClosed: (room) => room.status == ClinicRoomStatus.closed,
        currentNumberOf: (room) => room.currentNumber,
        waitingCountOf: (room) => room.waitingCount,
        examinedCountOf: (room) => room.examinedCount,
        onRoomSelected: (room) {
          final appointmentFeed = appointmentFeedFor?.call(room);
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => QueueScreen(
                sessionId: room.sessionIdForToday(),
                roomId: room.id,
                staffId: room.staffId,
                roomName: room.name,
                departmentName: room.department,
                hospitalName: hospitalName,
                appointmentQueueStream: appointmentFeed?.updates,
                appointmentQueueForDay: appointmentFeed?.updatesForDay,
                onAppointmentOutcome: appointmentFeed?.reportOutcome,
                onRenumberAppointment: appointmentFeed?.renumber,
                roomStatusStream: appointmentFeed?.roomStatus,
                onRoomStatusChanged: appointmentFeed?.setRoomStatus,
              ),
            ),
          );
        },
      );
}
