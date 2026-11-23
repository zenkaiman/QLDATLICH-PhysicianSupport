import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qldatlich/services/admin_provider.dart';
import 'manage_hospitals_screen.dart';
import 'bug_reports_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng Điều Khiển Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => adminProvider.fetchDashboardStats(),
          ),
        ],
      ),
      body: adminProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => adminProvider.fetchDashboardStats(),
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  const Text(
                    'Tổng Quan Hệ Thống',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildStatCard(
                        'Tổng Bệnh Viện',
                        '${adminProvider.stats['totalHospitals']}',
                        Icons.local_hospital,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Chờ Duyệt',
                        '${adminProvider.stats['pendingHospitals']}',
                        Icons.pending_actions,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Bệnh Nhân',
                        '${adminProvider.stats['totalPatients']}',
                        Icons.people,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Báo Cáo Lỗi',
                        '${adminProvider.stats['openReports']}',
                        Icons.bug_report,
                        Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Chức Năng Quản Lý',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.domain, color: Colors.blue),
                    title: const Text('Quản lý & Duyệt Bệnh viện'),
                    subtitle: const Text('Duyệt cơ sở mới, khóa bệnh viện vi phạm'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ManageHospitalsScreen()),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.report_problem, color: Colors.red),
                    title: const Text('Xử lý Báo cáo Lỗi'),
                    subtitle: const Text('Xem danh sách phản hồi và sự cố từ người dùng'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BugReportsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}