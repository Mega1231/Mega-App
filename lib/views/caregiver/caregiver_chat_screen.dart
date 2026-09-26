import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../common/chat_list_screen.dart';

class CaregiverChatScreen extends StatelessWidget {
  const CaregiverChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final currentUser = authVm.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ChatListScreen(
      currentUser: currentUser,
      showAppBar: true,
    );
  }
}
