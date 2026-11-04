import 'package:flutter/material.dart';

class ChatProvider extends ChangeNotifier {
  final List<String> _messages = ['Xin chào! Tôi có thể hỗ trợ bạn.'];

  List<String> get messages => _messages;

  void addMessage(String message) {
    _messages.add(message);
    notifyListeners();
  }
}
