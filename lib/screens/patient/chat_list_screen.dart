import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import '../../models/conversation_model.dart';
import '../../services/chat_service.dart';
import '../../utils/chat_common.dart';
import '../../screens/patient/chat_detail_screen.dart';

/// Danh sách các cuộc trò chuyện của bệnh nhân với CSKH từng bệnh viện.
/// Dữ liệu realtime từ Firestore: Conversations (benhNhanId == uid).
class ChatListScreen extends StatefulWidget {
  /// Hiện nút quay lại (tắt nếu màn hình là một tab của thanh điều hướng).
  final bool showBack;

  const ChatListScreen({super.key, this.showBack = false});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _service = ChatService();
  final _searchCtrl = TextEditingController();
  String _query = '';

  late final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late final Stream<List<ConversationModel>>? _stream = _uid == null
      ? null
      : _service.streamPatientConversations(_uid);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ConversationModel> _filter(List<ConversationModel> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.tenBenhVien.toLowerCase().contains(q) ||
              c.lastMessage.toLowerCase().contains(q),
        )
        .toList();
  }

  void _open(ConversationModel c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(conversationId: c.id, initial: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatColors.bg,
      body: _stream == null
          ? Column(
              children: [
                _Header(
                  showBack: widget.showBack,
                  unread: 0,
                  controller: _searchCtrl,
                  onChanged: (_) {},
                  onClear: () {},
                ),
                const Expanded(
                  child: _MessageState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Bạn chưa đăng nhập',
                    text: 'Vui lòng đăng nhập để xem tin nhắn.',
                  ),
                ),
              ],
            )
          : StreamBuilder<List<ConversationModel>>(
              stream: _stream,
              builder: (context, snap) {
                final all = snap.data ?? const <ConversationModel>[];
                final unread = all.fold<int>(
                  0,
                  (s, c) => s + c.unreadCountPatient,
                );
                final list = _filter(all);

                Widget body;
                if (snap.hasError) {
                  body = const _MessageState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Không tải được tin nhắn',
                    text: 'Vui lòng kiểm tra kết nối và thử lại sau.',
                    isError: true,
                  );
                } else if (!snap.hasData) {
                  body = const Center(
                    child: CircularProgressIndicator(
                      color: ChatColors.primary,
                    ),
                  );
                } else if (list.isEmpty) {
                  final searching = _query.trim().isNotEmpty;
                  body = _MessageState(
                    icon: searching
                        ? Icons.search_off_rounded
                        : Icons.chat_bubble_outline_rounded,
                    title: searching
                        ? 'Không tìm thấy kết quả'
                        : 'Chưa có cuộc trò chuyện',
                    text: searching
                        ? 'Hãy thử tìm bằng tên bệnh viện khác.'
                        : 'Bấm "Nhắn tin với CSKH" ở trang bệnh viện hoặc '
                              'lịch khám để bắt đầu trò chuyện.',
                  );
                } else {
                  body = ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _FadeIn(
                      index: i,
                      child: _ConversationCard(
                        conversation: list[i],
                        onTap: () => _open(list[i]),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    _Header(
                      showBack: widget.showBack,
                      unread: unread,
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      onClear: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
                    Expanded(child: body),
                  ],
                );
              },
            ),
    );
  }
}

// ───────────────────────── Đầu trang ─────────────────────────

class _Header extends StatelessWidget {
  final bool showBack;
  final int unread;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _Header({
    required this.showBack,
    required this.unread,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3F8F), ChatColors.primary, Color(0xFF3B8BF0)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            Positioned(right: -40, top: -40, child: _bubble(170, 0.08)),
            Positioned(left: -50, bottom: -30, child: _bubble(130, 0.06)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showBack) ...[
                          Material(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.maybePop(context),
                              child: Container(
                                width: 44,
                                height: 44,
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
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tin nhắn CSKH',
                                style: chatFont(
                                  22,
                                  weight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                unread > 0
                                    ? 'Bạn có $unread tin nhắn chưa đọc'
                                    : 'Bạn đã đọc hết tin nhắn',
                                style: chatFont(
                                  12.5,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.support_agent_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: controller,
                        onChanged: onChanged,
                        textInputAction: TextInputAction.search,
                        style: chatFont(14.5, weight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Tìm cuộc trò chuyện...',
                          hintStyle: chatFont(
                            14.5,
                            color: const Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: ChatColors.primary,
                          ),
                          suffixIcon: controller.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                    color: ChatColors.muted,
                                  ),
                                  onPressed: onClear,
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

// ───────────────────────── Thẻ cuộc trò chuyện ─────────────────────────

class _ConversationCard extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;
  const _ConversationCard({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unreadCountPatient;
    final hasUnread = unread > 0;
    final preview = c.lastMessage.isEmpty ? 'Chưa có tin nhắn' : c.lastMessage;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (hasUnread ? ChatColors.primary : Colors.black).withValues(
              alpha: hasUnread ? 0.10 : 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasUnread
                    ? ChatColors.primary.withValues(alpha: 0.25)
                    : ChatColors.line,
              ),
            ),
            child: Row(
              children: [
                ChatAvatar(
                  initials: c.initials,
                  color: c.accent,
                  showDot: c.isOpen && c.hasSupport,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: chatFont(15.5, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: chatFont(
                          13.5,
                          weight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          color: hasUnread ? ChatColors.ink : ChatColors.muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            c.isOpen
                                ? Icons.schedule_rounded
                                : Icons.lock_outline_rounded,
                            size: 12.5,
                            color: ChatColors.muted.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              c.isOpen
                                  ? chatTimeLabel(c.sortTime)
                                  : 'Đã đóng · ${chatTimeLabel(c.sortTime)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: chatFont(12, color: ChatColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (hasUnread)
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), ChatColors.danger],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: ChatColors.danger.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: chatFont(
                          12,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB6C2D1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Trạng thái trống / lỗi ─────────────────────────

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool isError;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.text,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? ChatColors.danger : ChatColors.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.07),
              ),
              child: Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: chatFont(17, weight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: chatFont(13.5, color: ChatColors.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mờ dần + trượt nhẹ từ dưới lên, các thẻ sau xuất hiện trễ hơn một chút.
class _FadeIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _FadeIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final step = index > 6 ? 6 : index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + step * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}