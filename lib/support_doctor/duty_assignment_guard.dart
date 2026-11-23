import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/app_session.dart';
import '../models/letan_c1/letan_profile_model_c1.dart';
import '../services/letan_c1/letan_firebase_service_c1.dart';

/// Collection phân công ca trực: `PhanCong/{maBenhVien}/danh_sach/...`.
///
/// Schema thực tế trong ảnh Console: `benh_vien_id`, `khoa_id`, `phong_id`,
/// `ma_nhan_vien`, `nhan_vien_id`, `ngay`, `trang_thai_id`, `ten_khoa`,
/// `ten_phong`. Quyết định vào phòng CHỈ dùng đúng ngày trong field `ngay`
/// và `trang_thai_id = 16`; không đọc field `id`, không đọc document ID,
/// không so `ten_nhan_vien`.
///
/// Mã nhân viên được xác định từ chính document
/// `NhanVien/{maBenhVien}/danh_sach/{maNhanVien}` (document ID + các field
/// id/mã/uid/email), rồi đem so với `ma_nhan_vien` / `nhan_vien_id` bên
/// `PhanCong`.
///
/// Code chỉ nằm trong `lib/support_doctor`: đọc MỘT LẦN khi bấm chọn
/// phòng, không tạo listener realtime, không ghi ngược lên Firestore, không
/// sửa luồng đăng nhập, route, tài liệu hay bản preview tĩnh.
const String kDutyAssignmentCollection = 'PhanCong';
const String kDutyAssignmentSubcollection = 'danh_sach';
const String kDutyStaffCollection = 'NhanVien';
const String kDutyStaffSubcollection = 'danh_sach';

/// Chỉ ca có id trạng thái này mới được phép vào phòng.
const String kDutyActiveStatusId = '16';

/// Câu báo lỗi đúng theo yêu cầu khi bấm sai khoa / phòng được phân công.
const String kDutyWrongRoomMessage = 'bạn không được phân vào trực khoa này';

/// Lỗi riêng khi không đọc được dữ liệu phân công (rules / mạng / project).
const String kDutyReadErrorMessage =
    'Không kiểm tra được phân công. Vui lòng thử lại.';

/// Ngữ cảnh phòng vừa được bấm trên màn hình chọn khoa / phòng.
///
/// Các mã chỉ dùng để đối chiếu trong code, KHÔNG render lên dialog. Tên
/// khoa / phòng chỉ dùng làm fallback khi document phân công lưu tên thay
/// vì mã.
class DutyRoomContext {
  const DutyRoomContext({
    required this.hospitalId,
    required this.departmentId,
    required this.roomId,
    this.departmentName = '',
    this.roomName = '',
    this.staffId = '',
  });

  final String hospitalId;
  final String departmentId;
  final String roomId;
  final String departmentName;
  final String roomName;
  final String staffId;
}

class DutyAssignmentDecision {
  const DutyAssignmentDecision.allowed()
    : allowed = true,
      message = '';

  const DutyAssignmentDecision.blocked(this.message) : allowed = false;

  final bool allowed;
  final String message;
}

/// Kiểm tra phân công trực trước khi cho bác sĩ vào `QueueScreen`.
///
/// - Nguồn: Firestore thật. Chỉ nhận document có field `ngay` đúng ngày
///   đang xét `yyyy-MM-dd` (mặc định hôm nay; khi mở phòng từ thẻ lịch
///   trực thì là ngày của dòng lịch đó); KHÔNG lọc theo `id` hay document ID.
/// - Chỉ nhận `trang_thai_id = 16` (hoặc alias id trạng thái); mọi id khác
///   hoặc thiếu id trạng thái → bỏ document đó.
/// - Mã nhân viên lấy từ đúng document `NhanVien/{bv}/danh_sach/{...}`:
///   document ID, `id`, `ma_nhan_vien`, `ma_tai_khoan`, `uid`, `email`…
///   Fail-closed: không đọc được doc nhân viên hoặc không khớp mã → chặn.
/// - So bằng MÃ: `ma_nhan_vien` / `nhan_vien_id` / `khoa_id` / `phong_id` /
///   `benh_vien_id`. Bỏ qua `ten_nhan_vien`; vẫn giữ `ten_khoa` /
///   `ten_phong` làm fallback khi thiếu mã.
/// - So CẢ mã khoa và mã phòng; nếu document chỉ có một loại mã thì chỉ
///   dùng loại đó.
/// - Sai / không tìm thấy phân công hợp lệ → chặn và hiện đúng câu
///   [kDutyWrongRoomMessage].
class DutyAssignmentGuard {
  DutyAssignmentGuard({FirebaseFirestore? firestore, DateTime Function()? now})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _now = now ?? (() => DateTime.now());

  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  /// [day] cho phép đối chiếu theo ngày đang test thay vì ngày máy: khi mở
  /// phòng từ một dòng lịch trực, ngày của chính dòng lịch đó được truyền
  /// vào để màn hình gọi số nạp đúng lịch hẹn của ngày đó.
  Future<DutyAssignmentDecision> evaluate(
    DutyRoomContext room, {
    DateTime? day,
  }) async {
    final hospitalId = room.hospitalId.trim();
    if (hospitalId.isEmpty) {
      return const DutyAssignmentDecision.blocked(kDutyReadErrorMessage);
    }

    final today = _dateOnly(day ?? _now());
    Set<String> staffAliases;
    try {
      staffAliases = await _resolveCurrentStaffAliases(hospitalId);
    } catch (_) {
      return const DutyAssignmentDecision.blocked(kDutyReadErrorMessage);
    }
    if (staffAliases.isEmpty) {
      return const DutyAssignmentDecision.blocked(kDutyWrongRoomMessage);
    }
    final assignments = <_AssignmentDraft>[];

    try {
      // Đọc một lần toàn bộ subcollection rồi lọc ở client theo đúng field
      // `ngay` và `trang_thai_id = 16`. Không dùng `id` / document ID.
      final snapshot = await _firestore
          .collection(kDutyAssignmentCollection)
          .doc(hospitalId)
          .collection(kDutyAssignmentSubcollection)
          .get();
      for (final doc in snapshot.docs) {
        final data = Map<String, Object?>.from(doc.data());
        if (!_documentMatchesDutyDate(data, today)) continue;
        if (!_documentHasActiveStatusId(data)) continue;
        assignments.addAll(
          _parseDocument(hospitalId, data, staffAliases),
        );
      }
    } catch (_) {
      return const DutyAssignmentDecision.blocked(kDutyReadErrorMessage);
    }

    if (assignments.isEmpty) {
      return const DutyAssignmentDecision.blocked(kDutyWrongRoomMessage);
    }

    final allStaffIds = <String>{};
    for (final assignment in assignments) {
      allStaffIds.addAll(assignment.staffIds);
    }

    if (staffAliases.isEmpty && allStaffIds.isNotEmpty) {
      return const DutyAssignmentDecision.blocked(kDutyWrongRoomMessage);
    }

    final matching = <_AssignmentDraft>[];
    for (final assignment in assignments) {
      // Bản ghi không có mã nhân viên được coi là phân công chung cho ca;
      // bản ghi có mã nhân viên chỉ dùng khi trùng nhân viên đang đăng nhập.
      if (allStaffIds.isEmpty ||
          assignment.staffIds.isEmpty ||
          _matchesAny(assignment.staffIds, staffAliases)) {
        matching.add(assignment);
      }
    }
    if (matching.isEmpty) {
      return const DutyAssignmentDecision.blocked(kDutyWrongRoomMessage);
    }

    final hospitalAliases = <String>{hospitalId};
    final hospitalMatched = <_AssignmentDraft>[];
    for (final assignment in matching) {
      if (assignment.hospitalIds.isEmpty ||
          _matchesAny(assignment.hospitalIds, hospitalAliases)) {
        hospitalMatched.add(assignment);
      }
    }
    if (hospitalMatched.isEmpty) {
      return const DutyAssignmentDecision.blocked(kDutyWrongRoomMessage);
    }

    final departmentIds = <String>{};
    final roomIds = <String>{};
    final departmentNames = <String>{};
    final roomNames = <String>{};
    for (final assignment in hospitalMatched) {
      departmentIds.addAll(assignment.departmentIds);
      roomIds.addAll(assignment.roomIds);
      departmentNames.addAll(assignment.departmentNames);
      roomNames.addAll(assignment.roomNames);
    }

    final hasDepartmentConstraint =
        departmentIds.isNotEmpty || departmentNames.isNotEmpty;
    final hasRoomConstraint = roomIds.isNotEmpty || roomNames.isNotEmpty;
    if (!hasDepartmentConstraint && !hasRoomConstraint) {
      return const DutyAssignmentDecision.blocked(kDutyWrongRoomMessage);
    }

    final departmentMatched = _matchesSelection(
      departmentIds,
      departmentNames,
      room.departmentId,
      room.departmentName,
    );
    final roomMatched = _matchesSelection(
      roomIds,
      roomNames,
      room.roomId,
      room.roomName,
    );
    if (!departmentMatched || !roomMatched) {
      return const DutyAssignmentDecision.blocked(kDutyWrongRoomMessage);
    }
    return const DutyAssignmentDecision.allowed();
  }

  /// Dùng trực tiếp làm guard cho `DepartmentRoomPicker`: trả `false` để
  /// chặn `onRoomSelected`, đồng thời tự hiện dialog báo lỗi.
  Future<bool> checkAndNotify(
    BuildContext context,
    DutyRoomContext room, {
    DateTime? day,
  }) async {
    final decision = await evaluate(room, day: day);
    if (decision.allowed) return true;
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Color(0xFFB45309)),
            SizedBox(width: 10),
            Expanded(child: Text('Không đúng phân công')),
          ],
        ),
        content: Text(decision.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    return false;
  }

  /// Đọc đúng document `NhanVien/{bv}/danh_sach/{...}` của nhân viên đang
  /// đăng nhập để lấy toàn bộ alias mã/id, rồi mới đem so với `PhanCong`.
  /// Không tìm thấy doc → trả set rỗng để `evaluate` chặn (fail-closed).
  /// Alias mã/id của nhân viên hiện tại để các widget khác (ví dụ thẻ lịch
  /// trực) dùng chung mà không phải đọc lại `NhanVien` theo cách khác.
  Future<Set<String>> resolveCurrentStaffAliases(String hospitalId) =>
      _resolveCurrentStaffAliases(hospitalId);

  Future<Set<String>> _resolveCurrentStaffAliases(String hospitalId) async {
    final profile = DuLieuProfileMauC1.thongTinHienTai;
    User? authUser;
    try {
      authUser = FirebaseAuth.instance.currentUser;
    } catch (_) {
      authUser = null;
    }

    final baseValues = <String?>[
      profile.maNhanVien,
      profile.email,
      authUser?.uid,
      authUser?.email,
    ];
    final hospitalCandidates = <String>{
      hospitalId,
      profile.benhVienId,
      AppSession.benhVienId,
      _hospitalIdFromStaffCode(profile.maNhanVien),
    }..removeWhere((value) => value.trim().isEmpty);

    final lookupEmail = profile.email.trim().isNotEmpty
        ? profile.email.trim()
        : authUser?.email;
    final lookupStaffCode = profile.maNhanVien.trim().isNotEmpty
        ? profile.maNhanVien.trim()
        : null;

    // Dùng chung bộ tìm kiếm nhân viên của luồng đăng nhập để ra đúng
    // document ID / docPath, sau đó vẫn thử đường dẫn thẳng theo bệnh viện
    // nếu bộ tìm kiếm trả null (rules/index khác nhau giữa các project).
    DocumentSnapshot<Map<String, dynamic>>? staffDoc =
        await FirebaseServiceC1.timKiemDocNhanVien(
      email: lookupEmail,
      maNhanVien: lookupStaffCode,
      uid: authUser?.uid,
    );
    if (staffDoc != null &&
        staffDoc.exists &&
        !_docBelongsToHospital(staffDoc.reference.path, hospitalCandidates)) {
      staffDoc = null;
    }
    staffDoc ??= await _findStaffDocDirectly(hospitalCandidates, baseValues);

    if (staffDoc == null || !staffDoc.exists) return <String>{};
    final data = staffDoc.data() ?? <String, dynamic>{};
    final raw = <String?>[
      staffDoc.id,
      staffDoc.reference.path,
      ...baseValues,
    ];
    for (final entry in data.entries) {
      if (_staffIdentityKeys.contains(_canonicalKey(entry.key))) {
        raw.addAll(_strings(entry.value));
      }
    }

    final aliases = <String>{};
    for (final value in raw) {
      if (value == null) continue;
      final normalized = _normalizeId(value);
      if (normalized.isNotEmpty) aliases.add(normalized);
    }
    return aliases;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findStaffDocDirectly(
    Set<String> hospitalCandidates,
    List<String?> baseValues,
  ) async {
    final candidateIds = <String>{};
    for (final value in baseValues) {
      if (value == null) continue;
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      candidateIds.add(trimmed);
      candidateIds.add(trimmed.toUpperCase());
    }
    for (final hospital in hospitalCandidates) {
      for (final id in candidateIds) {
        final doc = await _firestore
            .collection(kDutyStaffCollection)
            .doc(hospital)
            .collection(kDutyStaffSubcollection)
            .doc(id)
            .get();
        if (doc.exists) return doc;
      }
    }
    return null;
  }

  bool _docBelongsToHospital(String path, Set<String> hospitals) {
    for (final hospital in hospitals) {
      if (hospital.isEmpty) continue;
      if (path.contains(hospital)) return true;
    }
    return false;
  }

  String _hospitalIdFromStaffCode(String value) {
    final match = RegExp(r'^(BV\d+)_', caseSensitive: false)
        .firstMatch(value.trim());
    return match?.group(1) ?? '';
  }

}

class _AssignmentDraft {
  final Set<String> staffIds = <String>{};
  final Set<String> departmentIds = <String>{};
  final Set<String> roomIds = <String>{};
  final Set<String> hospitalIds = <String>{};
  final Set<String> departmentNames = <String>{};
  final Set<String> roomNames = <String>{};

  void inheritFrom(_AssignmentDraft parent) {
    staffIds.addAll(parent.staffIds);
    departmentIds.addAll(parent.departmentIds);
    roomIds.addAll(parent.roomIds);
    hospitalIds.addAll(parent.hospitalIds);
    departmentNames.addAll(parent.departmentNames);
    roomNames.addAll(parent.roomNames);
  }
}

class _DraftVisit {
  const _DraftVisit(this.map, this.inherited, this.keyHint, this.depth);

  final Map<String, Object?> map;
  final _AssignmentDraft inherited;
  final String? keyHint;
  final int depth;
}

/// Tách mọi map con (kể cả trong list) thành bản ghi phân công, kế thừa
/// ngữ cảnh của map cha. Hỗ trợ document phẳng, `danh_sach: [...]`, map
/// keyed theo mã nhân viên, hoặc list lồng nhau.
List<_AssignmentDraft> _parseDocument(
  String hospitalId,
  Map<String, Object?> data,
  Set<String> currentStaffAliases,
) {
  final drafts = <_AssignmentDraft>[];
  final root = _AssignmentDraft()..hospitalIds.add(hospitalId);
  final queue = <_DraftVisit>[_DraftVisit(data, root, null, 0)];

  while (queue.isNotEmpty) {
    final visit = queue.removeAt(0);
    final draft = _AssignmentDraft()..inheritFrom(visit.inherited);
    final keyHint = visit.keyHint;
    if (keyHint != null && _matchesAny(<String>{keyHint}, currentStaffAliases)) {
      draft.staffIds.add(keyHint);
    }

    for (final entry in visit.map.entries) {
      _addByKey(draft, entry.key, entry.value);
    }
    drafts.add(draft);

    if (visit.depth >= 5) continue;
    for (final entry in visit.map.entries) {
      final value = entry.value;
      if (value is Map) {
        queue.add(
          _DraftVisit(
            Map<String, Object?>.from(value),
            draft,
            entry.key,
            visit.depth + 1,
          ),
        );
      } else if (value is List) {
        for (final item in value) {
          if (item is Map) {
            queue.add(
              _DraftVisit(
                Map<String, Object?>.from(item),
                draft,
                entry.key,
                visit.depth + 1,
              ),
            );
          } else if (item is List) {
            queue.add(
              _DraftVisit(
                <String, Object?>{entry.key: item},
                draft,
                entry.key,
                visit.depth + 1,
              ),
            );
          }
        }
      }
    }
  }
  return drafts;
}

void _addByKey(_AssignmentDraft draft, String key, Object? value) {
  final canonical = _canonicalKey(key);
  if (_ignoredAssignmentKeys.contains(canonical)) return;
  final values = _strings(value);
  if (_staffIdKeys.contains(canonical)) draft.staffIds.addAll(values);
  if (_departmentIdKeys.contains(canonical)) {
    draft.departmentIds.addAll(values);
  }
  if (_roomIdKeys.contains(canonical)) draft.roomIds.addAll(values);
  if (_hospitalIdKeys.contains(canonical)) draft.hospitalIds.addAll(values);
  if (_departmentNameKeys.contains(canonical)) {
    draft.departmentNames.addAll(values);
  }
  if (_roomNameKeys.contains(canonical)) draft.roomNames.addAll(values);
}

bool _matchesSelection(
  Set<String> ids,
  Set<String> names,
  String id,
  String name,
) {
  if (ids.isEmpty && names.isEmpty) return true;
  if (id.trim().isNotEmpty && _matchesAny(ids, <String>{id})) return true;
  if (name.trim().isNotEmpty && _matchesAny(names, <String>{name})) return true;
  return false;
}

bool _matchesAny(Iterable<String> values, Iterable<String> targets) {
  for (final value in values) {
    for (final target in targets) {
      if (_sameIdentifier(value, target)) return true;
    }
  }
  return false;
}

/// Dùng chung cho thẻ lịch trực: đối chiếu một mã nhân viên trong
/// `PhanCong` với bộ alias lấy từ document `NhanVien` hiện tại.
bool dutyIdentifierMatches(String value, Iterable<String> aliases) =>
    _matchesAny(<String>{value}, aliases);

/// So sánh linh hoạt: bỏ dấu / hoa thường, chấp nhận mã ngắn là hậu tố
/// (`K001` ↔ `BV502_K001`), tiền tố hoặc một đoạn có dấu phân cách
/// (`BV502_K001` ↔ `BV502_K001_HH001`).
bool _sameIdentifier(String a, String b) {
  final na = _normalizeId(a);
  final nb = _normalizeId(b);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) return true;
  if (na.length < 3 || nb.length < 3) return false;
  if (_hasBoundarySuffix(na, nb) || _hasBoundarySuffix(nb, na)) return true;
  if (_hasBoundaryPrefix(na, nb) || _hasBoundaryPrefix(nb, na)) return true;
  return _containsAsSegment(na, nb) || _containsAsSegment(nb, na);
}

bool _hasBoundarySuffix(String longer, String shorter) {
  if (shorter.isEmpty || longer.length <= shorter.length) return false;
  if (!longer.endsWith(shorter)) return false;
  return longer[longer.length - shorter.length - 1] == '_';
}

bool _hasBoundaryPrefix(String longer, String shorter) {
  if (shorter.isEmpty || longer.length <= shorter.length) return false;
  if (!longer.startsWith(shorter)) return false;
  return longer[shorter.length] == '_';
}

bool _containsAsSegment(String longer, String shorter) {
  if (shorter.isEmpty || longer.length < shorter.length) return false;
  final start = longer.indexOf(shorter);
  if (start < 0) return false;
  final beforeOk = start == 0 || longer[start - 1] == '_';
  final end = start + shorter.length;
  final afterOk = end == longer.length || longer[end] == '_';
  return beforeOk && afterOk;
}

String _normalizeId(String value) {
  final folded = _foldAccents(value.toLowerCase().trim());
  return folded
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String _canonicalKey(String key) =>
    key.toLowerCase().replaceAll(RegExp(r'[_\-\s./]'), '');

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Chỉ so đúng field ngày trong document (`ngay: "yyyy-MM-dd"`), KHÔNG đọc
/// field `id` và KHÔNG đọc document ID.
bool _documentMatchesDutyDate(Map<String, Object?> data, String today) =>
    _findMatchingDate(data, today, 0);

bool _findMatchingDate(Object? value, String today, int depth) {
  if (depth > 6) return false;
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (_dutyDateKeys.contains(_canonicalKey(key)) &&
          _dateValueMatches(entry.value, today)) {
        return true;
      }
      if (_findMatchingDate(entry.value, today, depth + 1)) return true;
    }
  } else if (value is List) {
    for (final item in value) {
      if (_findMatchingDate(item, today, depth + 1)) return true;
    }
  }
  return false;
}

bool _dateValueMatches(Object? value, String today) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed == today ||
        trimmed.startsWith('$today ') ||
        trimmed.startsWith('${today}T');
  }
  if (value is Timestamp) return _dateOnly(value.toDate()) == today;
  if (value is DateTime) return _dateOnly(value) == today;
  if (value is List) {
    for (final item in value) {
      if (_dateValueMatches(item, today)) return true;
    }
  } else if (value is Map) {
    for (final item in value.values) {
      if (_dateValueMatches(item, today)) return true;
    }
  }
  return false;
}

/// Chỉ `trang_thai_id = 16` mới hợp lệ; id khác hoặc thiếu field → loại.
bool _documentHasActiveStatusId(Map<String, Object?> data) =>
    _findActiveStatusId(data, 0);

bool _findActiveStatusId(Object? value, int depth) {
  if (depth > 6) return false;
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (_activeStatusIdKeys.contains(_canonicalKey(key)) &&
          _statusValueIsActive(entry.value)) {
        return true;
      }
      if (_findActiveStatusId(entry.value, depth + 1)) return true;
    }
  } else if (value is List) {
    for (final item in value) {
      if (_findActiveStatusId(item, depth + 1)) return true;
    }
  }
  return false;
}

bool _statusValueIsActive(Object? value) {
  if (value is num) return value == 16;
  if (value is String) return value.trim() == kDutyActiveStatusId;
  if (value is List) {
    for (final item in value) {
      if (_statusValueIsActive(item)) return true;
    }
  } else if (value is Map) {
    for (final item in value.values) {
      if (_statusValueIsActive(item)) return true;
    }
  }
  return false;
}

Set<String> _strings(Object? value) {
  final result = <String>{};
  void visit(Object? current, int depth) {
    if (depth > 6) return;
    if (current is String) {
      final trimmed = current.trim();
      if (trimmed.isNotEmpty) result.add(trimmed);
    } else if (current is num || current is bool) {
      result.add(current.toString());
    } else if (current is List) {
      for (final item in current) {
        visit(item, depth + 1);
      }
    } else if (current is Map) {
      for (final item in current.values) {
        visit(item, depth + 1);
      }
    }
  }

  visit(value, 0);
  return result;
}

String _foldAccents(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accentMap[char] ?? char);
  }
  return buffer.toString();
}

const Map<String, String> _accentMap = <String, String>{
  'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
  'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
  'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
  'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
  'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
  'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
  'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
  'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
  'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
  'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
  'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
  'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
  'đ': 'd',
};

const Set<String> _staffIdKeys = <String>{
  'manhanvien',
  'mataikhoan',
  'manv',
  'nhanvienid',
  'idnhanvien',
  'staffid',
  'staff',
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
  'mabacsi',
  'mabs',
  'nhanvien',
  'bacsi',
  'taikhoan',
  'username',
};

/// Field mã/id trong chính document `NhanVien/...` được gom làm alias để so
/// với mã nhân viên bên `PhanCong`. Document ID và `reference.path` cũng
/// được thêm riêng trong [_resolveCurrentStaffAliases].
const Set<String> _staffIdentityKeys = <String>{
  'id',
  'docid',
  'documentid',
  'docpath',
  'manhanvien',
  'mataikhoan',
  'manv',
  'nhanvienid',
  'nhanvien',
  'idnhanvien',
  'staffid',
  'uid',
  'email',
  'emailnhanvien',
  'taikhoan',
  'username',
  'mabacsi',
  'mabs',
  'bacsiid',
};

const Set<String> _departmentIdKeys = <String>{
  'makhoa',
  'khoaid',
  'khoa',
  'idkhoa',
  'departmentid',
  'department',
  'makhoaphong',
  'chuyenkhoaid',
  'danhsachkhoa',
  'dskhoa',
};

const Set<String> _roomIdKeys = <String>{
  'maphong',
  'phongid',
  'phong',
  'idphong',
  'roomid',
  'room',
  'maphongkham',
  'phongkhamid',
  'phongkham',
  'idphongkham',
  'idphongkhambenh',
  'danhsachphong',
  'dsphong',
};

const Set<String> _hospitalIdKeys = <String>{
  'mabenhvien',
  'benhvienid',
  'benhvien',
  'hospitalid',
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

/// Field ngày được phép dùng để chọn ca. Cố tình KHÔNG gồm `id`,
/// `ngay_cap_nhat` hay document ID.
const Set<String> _dutyDateKeys = <String>{
  'ngay',
  'date',
  'ngaytruc',
  'ngayphancong',
  'ngaylamviec',
  'ngaykham',
};

/// Field id trạng thái. `trang_thai` dạng chữ ("đã phân công") không nằm
/// trong set này vì yêu cầu chỉ đọc id trạng thái = 16.
const Set<String> _activeStatusIdKeys = <String>{
  'trangthaiid',
  'statusid',
  'idtrangthai',
  'matrangthai',
  'assignmentstatusid',
};

/// Các field trong ảnh KHÔNG được dùng để xác định nhân viên / ngày.
/// `id` là mã bản ghi phân công, `ten_nhan_vien` chỉ là tên hiển thị.
const Set<String> _ignoredAssignmentKeys = <String>{
  'id',
  'tennhanvien',
  'vaitro',
  'trangthai',
  'ngaycapnhat',
  'prefixkhoa',
};
