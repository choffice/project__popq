import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

class SectionPlaceholderScreen extends StatelessWidget {
  const SectionPlaceholderScreen({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return PopqEmptyView(icon: icon, title: title, description: description);
  }
}
