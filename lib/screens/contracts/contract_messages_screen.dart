import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contract_extras.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// "Sent" log (what actually went out, or failed) plus a live-computed
/// "Upcoming" preview (what would go out at the next cron run if nothing
/// changes). Mirrors web Contracts::messages().
class ContractMessagesScreen extends StatefulWidget {
  const ContractMessagesScreen({super.key});

  @override
  State<ContractMessagesScreen> createState() => _ContractMessagesScreenState();
}

class _ContractMessagesScreenState extends State<ContractMessagesScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late final TabController _tabController;
  ContractMessagesReport? _report;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response = await _apiService.getContractMessages();
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _report = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'danger':
        return AppColors.error;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Sent'),
            Tab(text: 'Upcoming'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Try again')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSent(isDark),
                    _buildUpcoming(isDark),
                  ],
                ),
    );
  }

  Widget _buildSent(bool isDark) {
    final sent = _report!.sent;
    if (sent.isEmpty) {
      return Center(
        child: Text('No messages sent yet',
            style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: sent.map((m) {
          final ok = m.status == 'sent';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isDark ? AppColors.darkCard : Colors.white,
            child: ListTile(
              leading: Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
                  color: ok ? AppColors.success : AppColors.error),
              title: Text(m.contractName ?? '(no contract)', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${m.messageTypeLabel} · ${m.channel.toUpperCase()} · ${m.phone}\n${m.message}'),
              isThreeLine: true,
              trailing: Text(Formatters.formatDate(m.createdAt), style: const TextStyle(fontSize: 11)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUpcoming(bool isDark) {
    final upcoming = _report!.upcoming;
    if (upcoming.isEmpty) {
      return Center(
        child: Text('Nothing scheduled to go out at the next run',
            style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: upcoming.map((u) {
          final color = _severityColor(u.severity);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isDark ? AppColors.darkCard : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(u.contractName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: Text(u.label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(u.message,
                      style: TextStyle(fontSize: 13.5, color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                  if (u.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...u.notes.map((n) => Text('• $n', style: const TextStyle(fontSize: 11.5, color: AppColors.textLight))),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
