import 'package:flutter/material.dart';
import 'manage_students_parents_screen.dart';

class ManageStudentsScreen extends StatelessWidget {
  const ManageStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ManageStudentsParentsScreen(initialTab: 0);
  }
}
