import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../models/contract.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'portal_contract_detail_screen.dart';
import 'portal_login_screen.dart';

class PortalDashboardScreen extends StatefulWidget {
  const PortalDashboardScreen({super.key});

  @override
  State<PortalDashboardScreen> createState() => _PortalDashboardScreenState();
}

class _PortalDashboardScreenState extends State<PortalDashboardScreen> {
  final _service = CustomerApiService();
  List<Contract>? _contracts;
  bool _isLoading = true;
  String? _error;
  String _tenantName = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final tenantName = await _service.getTenantName();
    final phone = await _service.getPhone();
    final response = await _service.getContracts();

    if (!mounted) return;
    setState(() {
      _tenantName = tenantName ?? '';
      _phone = phone ?? '';
      _isLoading = false;
      if (response.isSuccess) {
        _contracts = response.data;
      } else {
        _error = response.message;
      }
    });
  }

  Future<void> _logout() async {
    await _service.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PortalLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(_tenantName.isEmpty ? 'My Contracts' : _tenantName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildList(),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final contracts = _contracts ?? [];
    if (contracts.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.receipt_long, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          const Center(
              child: Text('No contracts found for this phone number.')),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_phone,
                  style: const TextStyle(color: AppColors.textLight)),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contracts.length,
      itemBuilder: (context, index) {
        final contract = contracts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(contract.contractDescription.isNotEmpty
                ? contract.contractDescription
                : 'Contract #${contract.id}'),
            subtitle: Text('${contract.date} → ${contract.endDate}'),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusBadge(contract.status),
                const SizedBox(height: 4),
                Text(Formatters.formatCurrency(contract.balance),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PortalContractDetailScreen(contract: contract),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color;
    final String label;
    switch (status) {
      case 'terminated':
        color = Colors.grey;
        label = 'Terminated';
        break;
      case 'completed':
        color = AppColors.success;
        label = 'Completed';
        break;
      case 'on_track':
        color = AppColors.success;
        label = 'On Track';
        break;
      case 'behind':
        color = AppColors.warning;
        label = 'Behind';
        break;
      default:
        color = AppColors.error;
        label = 'Overdue';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
