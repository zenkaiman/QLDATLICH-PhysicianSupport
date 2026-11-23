import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:qldatlich/services/admin_service.dart';
import 'package:qldatlich/services/admin_provider.dart';

class ManageHospitalsScreen extends StatefulWidget {
  const ManageHospitalsScreen({Key? key}) : super(key: key);

  @override
  State<ManageHospitalsScreen> createState() => _ManageHospitalsScreenState();
}

class _ManageHospitalsScreenState extends State<ManageHospitalsScreen> {
  final AdminService _adminService = AdminService();
  String _selectedFilter = ''; // '' có nghĩa là tất cả

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Bệnh Viện'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tất cả', ''),
                _buildFilterChip('Chờ duyệt', 'CHO_DUYET'),
                _buildFilterChip('Đã duyệt', 'DA_DUYET'),
                _buildFilterChip('Đã khóa', 'DA_KHOA'),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _adminService.getHospitalsStream(statusFilter: _selectedFilter),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Không có dữ liệu bệnh viện'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final docId = docs[index].id;
              final tenBenhVien = data['tenBenhVien'] ?? 'Bệnh viện chưa đặt tên';
              final diaChi = data['diaChi'] ?? 'Chưa cập nhật địa chỉ';
              final trangThai = data['trangThai'] ?? 'CHO_DUYET';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(tenBenhVien, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$diaChi\nTrạng thái: $trangThai'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trangThai == 'CHO_DUYET')
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          tooltip: 'Duyệt',
                          onPressed: () async {
                            final success = await context.read<AdminProvider>().approveHospital(docId);
                            if (mounted && success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã duyệt bệnh viện thành công!')),
                              );
                            }
                          },
                        ),
                      if (trangThai != 'DA_KHOA')
                        IconButton(
                          icon: const Icon(Icons.block, color: Colors.red),
                          tooltip: 'Khóa bệnh viện',
                          onPressed: () => _showLockDialog(context, docId),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(label),
        selected: _selectedFilter == value,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
      ),
    );
  }

  void _showLockDialog(BuildContext context, String hospitalId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Khóa Bệnh Viện Vi Phạm'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Lý do khóa',
            hintText: 'Nhập lý do tạm dừng/khóa bệnh viện...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                Navigator.pop(dialogContext);
                final success = await context.read<AdminProvider>().lockHospital(hospitalId, reason);
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã khóa bệnh viện!')),
                  );
                }
              }
            },
            child: const Text('Xác nhận khóa'),
          ),
        ],
      ),
    );
  }
}