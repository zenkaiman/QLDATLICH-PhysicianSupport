import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/conversation_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/chat_common.dart';

Future<void> openHospitalChat(
  BuildContext context, {
  required String benhVienId,
  required String tenBenhVien,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    context.showAppSnackBar(
      message: 'Vui lòng đăng nhập để nhắn tin với CSKH.',
      type: SnackBarType.warning,
    );
    return;
  }

  final tenBenhNhan =
      context.read<AuthProvider>().user?.hoTen ??
      FirebaseAuth.instance.currentUser?.displayName ??
      'Bệnh nhân';

  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: ChatColors.primary),
    ),
  );

  try {
    final conv = await ChatService().getOrCreateConversation(
      benhNhanId: uid,
      tenBenhNhan: tenBenhNhan,
      benhVienId: benhVienId,
      tenBenhVien: tenBenhVien,
    );
    navigator.pop(); // đóng hộp thoại tải
    navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            ChatDetailScreen(conversationId: conv.id, initial: conv),
      ),
    );
  } catch (e) {
    debugPrint('Không mở được cuộc trò chuyện: $e');
    navigator.pop();
    if (context.mounted) {
      context.showAppSnackBar(
        message: 'Không thể mở cuộc trò chuyện. Vui lòng thử lại.',
        type: SnackBarType.error,
      );
    }
  }
}

/// Màn hình trò chuyện với CSKH của một bệnh viện (realtime).
class ChatDetailScreen extends StatefulWidget {
  final String conversationId;

  /// Dữ liệu có sẵn để hiện đầu trang ngay, không phải chờ stream.
  final ConversationModel? initial;
  final String hotline;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    this.initial,
    this.hotline = '1900 6868',
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _service = ChatService();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  late final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  late final Stream<ConversationModel?> _convStream = _service
      .streamConversation(widget.conversationId);
  late final Stream<List<MessageModel>> _msgStream = _service.streamMessages(
    widget.conversationId,
  );

  bool _marking = false;
  int _lastCount = 0;

  static const _quickReplies = [
    'Đặt lịch khám',
    'Hỏi kết quả xét nghiệm',
    'Giờ làm việc',
    'Chi phí khám',
  ];

  bool get _canSend => _inputCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── Hành động ─────────────────────────

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputCtrl.text).trim();
    if (text.isEmpty || _myUid.isEmpty) return;

    if (preset == null) _inputCtrl.clear();
    try {
      await _service.sendMessage(
        conversationId: widget.conversationId,
        senderId: _myUid,
        senderRole: 'patient',
        content: text,
      );
    } catch (e) {
      debugPrint('Gửi tin nhắn thất bại: $e');
      if (preset == null) _inputCtrl.text = text; // trả lại nội dung đã gõ
      if (!mounted) return;
      context.showAppSnackBar(
        message: 'Không gửi được tin nhắn. Vui lòng thử lại.',
        type: SnackBarType.error,
      );
    }
  }

  /// Có tin của support chưa đọc -> đánh dấu đã đọc, đưa unreadCountPatient về 0.
  void _syncRead(List<MessageModel> msgs) {
    if (_marking) return;
    final hasUnread = msgs.any((m) => m.senderRole == 'support' && !m.isRead);
    if (!hasUnread) return;

    _marking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _service.markAsRead(widget.conversationId, readerRole: 'patient');
      } catch (e) {
        debugPrint('Không đánh dấu đã đọc được: $e');
      } finally {
        _marking = false;
      }
    });
  }

  void _scrollToEnd({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final end = _scrollCtrl.position.maxScrollExtent;
      if (animate) {
        _scrollCtrl.animateTo(
          end,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollCtrl.jumpTo(end);
      }
    });
  }

  Future<void> _copyHotline() async {
    await Clipboard.setData(
      ClipboardData(text: widget.hotline.replaceAll(' ', '')),
    );
    if (!mounted) return;
    context.showAppSnackBar(
      message: 'Đã sao chép số tổng đài ${widget.hotline}',
      type: SnackBarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  void _attach() {
    context.showAppSnackBar(
      message: 'Tính năng gửi hình ảnh sẽ sớm có.',
      type: SnackBarType.info,
    );
  }

  // ───────────────────────── Giao diện ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConversationModel?>(
      stream: _convStream,
      initialData: widget.initial,
      builder: (context, convSnap) {
        final conv = convSnap.data ?? widget.initial;
        final isOpen = conv?.isOpen ?? true;

        return Scaffold(
          backgroundColor: ChatColors.bg,
          body: Column(
            children: [
              _ChatHeader(conversation: conv),
              Expanded(child: _buildMessages()),
              if (isOpen) ...[
                _QuickReplies(items: _quickReplies, onTap: _send),
                _InputBar(
                  controller: _inputCtrl,
                  canSend: _canSend,
                  onSend: _send,
                  onAttach: _attach,
                ),
              ] else
                const _ClosedBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<List<MessageModel>>(
      stream: _msgStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Không tải được tin nhắn.\nVui lòng thử lại sau.',
                textAlign: TextAlign.center,
                style: chatFont(14, color: ChatColors.muted, height: 1.5),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: ChatColors.primary),
          );
        }

        final msgs = snap.data!;
        _syncRead(msgs);

        if (msgs.length != _lastCount) {
          _scrollToEnd(animate: _lastCount != 0);
          _lastCount = msgs.length;
        }

        final items = <Widget>[
          _HotlineBanner(hotline: widget.hotline, onCall: _copyHotline),
          const SizedBox(height: 14),
        ];

        DateTime? prev;
        for (final m in msgs) {
          if (prev == null || !chatSameDay(prev, m.createdAt)) {
            items.add(_DateChip(label: chatDayLabel(m.createdAt)));
            items.add(const SizedBox(height: 14));
          }
          prev = m.createdAt;

          items.add(_MessageItem(message: m));
          items.add(const SizedBox(height: 14));
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            children: items,
          ),
        );
      },
    );
  }
}

// ───────────────────────── Đầu trang ─────────────────────────

class _ChatHeader extends StatelessWidget {
  final ConversationModel? conversation;
  const _ChatHeader({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final name = c?.displayName ?? 'CSKH Bệnh viện';
    final subtitle = c == null || c.hasSupport
        ? 'Tư vấn viên sẽ phản hồi sớm nhất'
        : 'Đang chờ phân công tư vấn viên';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3F8F), ChatColors.primary],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Color(0x331E6FE0),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ChatAvatar(
                  initials: c?.initials ?? 'BV',
                  color: c?.accent ?? ChatColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: chatFont(
                        16.5,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: chatFont(
                        12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(open: c?.isOpen ?? true),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool open;
  const _StatusPill({required this.open});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: open ? ChatColors.online : ChatColors.muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            open ? 'Đang hỗ trợ' : 'Đã đóng',
            style: chatFont(
              12,
              weight: FontWeight.w700,
              color: open ? const Color(0xFF0B7A6C) : ChatColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Tổng đài khẩn cấp ─────────────────────────

class _HotlineBanner extends StatelessWidget {
  final String hotline;
  final VoidCallback onCall;
  const _HotlineBanner({required this.hotline, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1F1), Color(0xFFFFF8F6)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ChatColors.danger.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ChatColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.emergency_rounded,
              color: ChatColors.danger,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng đài BV: $hotline',
                  style: chatFont(
                    14.5,
                    weight: FontWeight.w800,
                    color: ChatColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bấm gọi ngay nếu cần cấp cứu',
                  style: chatFont(12, color: ChatColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: ChatColors.danger,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onCall,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.call_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Gọi',
                      style: chatFont(
                        14,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE4EAF2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: chatFont(12, weight: FontWeight.w600, color: ChatColors.muted),
        ),
      ),
    );
  }
}

// ───────────────────────── Tin nhắn ─────────────────────────

class _MessageItem extends StatelessWidget {
  final MessageModel message;
  const _MessageItem({required this.message});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.74;

    if (message.isSystem) return _system();
    return message.senderRole == 'patient'
        ? _mine(maxWidth)
        : _theirs(maxWidth);
  }

  /// Nội dung bên trong bong bóng: ảnh (nếu có) + chữ.
  Widget _content(Color textColor) {
    final m = message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (m.isImage)
          Padding(
            padding: EdgeInsets.only(bottom: m.content.isEmpty ? 0 : 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                m.imageUrl,
                width: 220,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        width: 220,
                        height: 140,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 220,
                  height: 100,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, size: 32),
                  ),
                ),
              ),
            ),
          ),
        if (m.content.isNotEmpty)
          Text(
            m.content,
            style: chatFont(14.5, color: textColor, height: 1.45),
          ),
      ],
    );
  }

  Widget _system() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: ChatColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: ChatColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.content,
                style: chatFont(
                  12.5,
                  weight: FontWeight.w600,
                  color: ChatColors.primaryDark,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mine(double maxWidth) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B8BF0), ChatColors.primary],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: ChatColors.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: _content(Colors.white),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chatHm(message.createdAt),
                style: chatFont(11.5, color: ChatColors.muted),
              ),
              const SizedBox(width: 4),
              Icon(
                message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                size: 15,
                color: message.isRead
                    ? ChatColors.primary
                    : ChatColors.muted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _theirs(double maxWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B8BF0), ChatColors.primary],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            size: 21,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Tư vấn viên',
                    style: chatFont(13, weight: FontWeight.w800),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ChatColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'CSKH',
                      style: chatFont(
                        10,
                        weight: FontWeight.w800,
                        color: ChatColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(color: ChatColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _content(ChatColors.ink),
              ),
              const SizedBox(height: 5),
              Text(
                chatHm(message.createdAt),
                style: chatFont(11.5, color: ChatColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Gợi ý trả lời nhanh ─────────────────────────

class _QuickReplies extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onTap;
  const _QuickReplies({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onTap(items[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ChatColors.primary.withValues(alpha: 0.30),
                ),
              ),
              child: Text(
                items[i],
                style: chatFont(
                  12.5,
                  weight: FontWeight.w700,
                  color: ChatColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Ô nhập tin nhắn ─────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _InputBar({
    required this.controller,
    required this.canSend,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Material(
              color: ChatColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onAttach,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.attach_file_rounded,
                    color: ChatColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: ChatColors.bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: ChatColors.line),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  style: chatFont(14.5),
                  decoration: InputDecoration(
                    hintText: 'Nhập tin nhắn...',
                    hintStyle: chatFont(14.5, color: const Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: canSend
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3B8BF0), ChatColors.primary],
                      )
                    : null,
                color: canSend ? null : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(16),
                boxShadow: canSend
                    ? [
                        BoxShadow(
                          color: ChatColors.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: canSend ? onSend : null,
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thay cho ô nhập khi cuộc trò chuyện đã đóng (status = closed).
class _ClosedBar extends StatelessWidget {
  const _ClosedBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 20,
              color: ChatColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cuộc trò chuyện đã được đóng. Vui lòng liên hệ tổng đài '
                'nếu bạn cần hỗ trợ thêm.',
                style: chatFont(13, color: ChatColors.muted, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
