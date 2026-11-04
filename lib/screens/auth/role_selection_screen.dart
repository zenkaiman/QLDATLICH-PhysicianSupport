import 'package:flutter/material.dart';

import '../../config/app_routes.dart';
import '../../config/constants.dart';
import '../../widgets/custom_button.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roles = Role.values;

    return Scaffold(
      appBar: AppBar(title: const Text('Chọn vai trò')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView.separated(
          itemCount: roles.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final role = roles[index];
            return CustomButton(
              text: AppConstants.roleNames[role] ?? role.name,
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              },
            );
          },
        ),
      ),
    );
  }
}
