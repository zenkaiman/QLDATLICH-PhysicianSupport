import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';


class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  StreamSubscription<List<NotificationModel>>? _subscription;
  String? _userId;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Số thông báo chưa đọc (dùng cho chuông, huy hiệu thanh điều hướng).
  int get unreadCount => _notifications
      .where((n) => n.status == NotificationStatus.unread)
      .length;

  /// Bắt đầu nghe thông báo của [userId] (uid đang đăng nhập).
  /// Gọi nhiều lần với cùng userId thì bỏ qua; đổi tài khoản thì nghe lại từ đầu.
  void listen(String userId) {
    if (_userId == userId && _subscription != null) return;

    _subscription?.cancel();
    _userId = userId;
    _notifications = [];
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _service
        .watchNotifications(userId)
        .listen(
          (list) {
            _notifications = list;
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (Object e) {
            debugPrint('Lỗi khi nghe thông báo: $e');
            _isLoading = false;
            _error = NotificationService.errorMessage(e);
            notifyListeners();
          },
        );
  }

  /// Tải lại 1 lần (kéo để làm mới).
  Future<void> refresh() async {
    final id = _userId;
    if (id == null) return;
    try {
      _notifications = await _service.getNotifications(id);
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Đánh dấu 1 thông báo đã đọc (cập nhật giao diện ngay, rồi ghi lên Firestore).
  Future<void> markRead(String notificationId) async {
    final id = _userId;
    if (id == null) return;

    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1 || _notifications[index].status == NotificationStatus.read) {
      return;
    }

    _notifications[index] = _notifications[index].copyWith(
      status: NotificationStatus.read,
    );
    notifyListeners();

    try {
      await _service.markAsRead(id, notificationId);
    } catch (e) {
      debugPrint('Không thể đánh dấu đã đọc: $e');
      await refresh(); // ghi lỗi thì lấy lại dữ liệu đúng từ server
    }
  }

  /// Đánh dấu tất cả thông báo chưa đọc là đã đọc.
  Future<void> markAllRead() async {
    final id = _userId;
    if (id == null) return;

    final unreadIds = _notifications
        .where((n) => n.status == NotificationStatus.unread)
        .map((n) => n.id)
        .toList();
    if (unreadIds.isEmpty) return;

    _notifications = _notifications
        .map((n) => n.copyWith(status: NotificationStatus.read))
        .toList();
    notifyListeners();

    try {
      await _service.markAllAsRead(id, unreadIds);
    } catch (e) {
      debugPrint('Không thể đánh dấu tất cả đã đọc: $e');
      await refresh();
    }
  }

  /// Gọi khi đăng xuất: ngừng nghe và xoá dữ liệu của tài khoản trước.
  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _userId = null;
    _notifications = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}