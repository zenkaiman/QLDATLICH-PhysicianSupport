import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String title;
  final String url;

  const DocumentViewerScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _hasError = false;
  String _errorMessage = '';

  String get _viewUrl {
    final lower = widget.url.toLowerCase();
    final isOfficeOrPdf = lower.contains('.docx') ||
        lower.contains('.doc') ||
        lower.contains('.pdf') ||
        lower.contains('.xlsx') ||
        lower.contains('.xls') ||
        lower.contains('alt=media');

    if (isOfficeOrPdf) {
      // Dùng Google Docs Viewer để xem trực tiếp các file docx/pdf trong ứng dụng
      return 'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.url)}&embedded=true';
    }
    return widget.url;
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _loadingProgress = 10;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _loadingProgress = 100;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_viewUrl));
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể mở liên kết: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kSlate800, size: 20),
          tooltip: 'Quay lại đơn đăng ký',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: kSlate900,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            const Text(
              'Xem tài liệu pháp lý hồ sơ',
              style: TextStyle(
                color: kSlate500,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kSlate700, size: 22),
            tooltip: 'Tải lại',
            onPressed: () {
              setState(() {
                _hasError = false;
                _loadingProgress = 10;
              });
              _controller.reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: kPrimary, size: 22),
            tooltip: 'Mở bằng trình duyệt ngoài',
            onPressed: _openExternal,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _loadingProgress < 100
              ? LinearProgressIndicator(
                  value: _loadingProgress / 100.0,
                  backgroundColor: kSlate200,
                  color: kPrimary,
                  minHeight: 2.5,
                )
              : const Divider(height: 1, color: kBorder),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_hasError)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: kRedBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline_rounded, color: kRed, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Không thể tải tài liệu trực tiếp',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kSlate900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage.isNotEmpty
                          ? _errorMessage
                          : 'Định dạng tài liệu hoặc đường truyền không hỗ trợ hiển thị xem trước.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: kSlate600, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _loadingProgress = 10;
                            });
                            _controller.reload();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Thử lại'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _openExternal,
                          icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                          label: const Text('Mở trình duyệt ngoài'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
