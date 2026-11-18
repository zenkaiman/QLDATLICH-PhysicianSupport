import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:qldatlich/services/admin_service.dart';
import 'package:qldatlich/services/admin_provider.dart';

class BugReportsScreen extends StatelessWidget {
  const BugReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AdminService adminService = AdminService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Cáo Sự Cố & Lỗi'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: adminService.getBugReportsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Không có báo cáo lỗi nào'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final docId = docs[index].id;
              final tieuDe = data['tieuDe'] ?? 'Không có tiêu đề';
              final noiDung = data['noiDung'] ?? '';
              final trangThai = data['trangThaiXuly'] ?? 'CHO_XU_LY';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  leading: Icon(
                    trangThai == 'DA_GIAI_QUYET' ? Icons.check_circle : Icons.warning,
                    color: trangThai == 'DA_GIAI_QUYET' ? Colors.green : Colors.orange,
                  ),
                  title: Text(tieuDe, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Trạng thái: $trangThai'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nội dung chi tiết: $noiDung'),
                          const SizedBox(height: 12),
                          if (trangThai != 'DA_GIAI_QUYET')
                            ElevatedButton.icon(
                              icon: const Icon(Icons.done),
                              label: const Text('Đánh dấu đã xử lý'),
                              onPressed: () => _showResolveDialog(context, docId),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showResolveDialog(BuildContext context, String reportId) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xử lý báo cáo'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'Ghi chú khắc phục (nếu có)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await context
                  .read<AdminProvider>()
                  .resolveBugReport(reportId, noteController.text.trim());
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cập nhật trạng thái thành công!')),
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}