import 'package:flutter/material.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách chat')),
      body: const Center(
        child: Text('Chưa có cuộc trò chuyện nào.'),
      ),
    );
  }
}
