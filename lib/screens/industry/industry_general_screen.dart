import 'package:flutter/material.dart';
import '../../services/industry_service.dart';
import 'industry_overview_tab.dart';

/// Body-only wrapper (no Scaffold - IndustryHomeScreen owns the single
/// AppBar/Drawer) around the existing dashboard body widget.
class IndustryGeneralScreen extends StatelessWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryGeneralScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  Widget build(BuildContext context) {
    return IndustryOverviewTab(
      service: service,
      onSessionExpired: () async => onSessionExpired(),
    );
  }
}
