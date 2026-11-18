import 'package:flutter/material.dart';

enum SnackBarType { success, error, warning, info }

// Màu, icon và tiêu đề mặc định theo từng loại thông báo.
class _SnackStyle {
  final Color color;
  final IconData icon;
  final String title;
  const _SnackStyle(this.color, this.icon, this.title);
}

_SnackStyle _styleOf(SnackBarType type) {
  switch (type) {
    case SnackBarType.success:
      return const _SnackStyle(
        Color(0xFF16A34A),
        Icons.check_circle_rounded,
        'Thành công',
      );
    case SnackBarType.error:
      return const _SnackStyle(
        Color(0xFFE53935),
        Icons.error_rounded,
        'Có lỗi xảy ra',
      );
    case SnackBarType.warning:
      return const _SnackStyle(
        Color(0xFFF59E0B),
        Icons.warning_amber_rounded,
        'Lưu ý',
      );
    case SnackBarType.info:
      return const _SnackStyle(
        Color(0xFF2196F3),
        Icons.info_rounded,
        'Thông báo',
      );
  }
}

extension AppSnackBarExtension on BuildContext {
  /// Hiển thị thông báo dùng chung cho toàn bộ ứng dụng.
  ///
  /// - [title]: tiêu đề in đậm; không truyền thì dùng tiêu đề mặc định theo [type].
  /// - [actionLabel] + [onAction]: nút hành động ở bên phải (vd: "Hoàn tác", "Thử lại").
  void showAppSnackBar({
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(this);
    final style = _styleOf(type);

    // Ẩn thông báo cũ để không bị chồng lên nhau
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        // Nền trong suốt: toàn bộ giao diện do _AppSnackBarContent vẽ
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: _AppSnackBarContent(
          style: style,
          title: title ?? style.title,
          message: message,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
          onClose: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }
}

// Thẻ thông báo: dải màu bên trái, ô icon, tiêu đề + nội dung, nút đóng,
// và thanh thời gian chạy ở đáy.
class _AppSnackBarContent extends StatelessWidget {
  final _SnackStyle style;
  final String title;
  final String message;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClose;

  const _AppSnackBarContent({
    required this.style,
    required this.title,
    required this.message,
    required this.duration,
    required this.onClose,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = style.color;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dải màu nhận diện loại thông báo
                  Container(width: 5, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Ô icon
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color.withOpacity(0.20),
                                  color.withOpacity(0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(style.icon, size: 24, color: color),
                          ),
                          const SizedBox(width: 12),

                          // Tiêu đề + nội dung
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Nút hành động (tuỳ chọn)
                          if (actionLabel != null && onAction != null)
                            TextButton(
                              onPressed: onAction,
                              style: TextButton.styleFrom(
                                foregroundColor: color,
                                backgroundColor: color.withOpacity(0.10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                actionLabel!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),

                          // Nút đóng
                          IconButton(
                            onPressed: onClose,
                            visualDensity: VisualDensity.compact,
                            splashRadius: 18,
                            tooltip: 'Đóng',
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 19,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Thanh thời gian: chạy ngược từ đầy về rỗng trong [duration]
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: duration,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: color.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation<Color>(
                  color.withOpacity(0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}