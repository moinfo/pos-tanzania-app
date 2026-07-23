import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/receiving_provider.dart';
import '../providers/sale_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'main_navigation.dart';

/// Linked Accounts: one owner, several businesses (tenants). Link the other
/// business's account once with its password; afterwards switch between them
/// with a single tap — the server issues a fresh token for the linked account.
class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;
  bool _isSwitching = false;
  String? _error;

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
    final result = await _apiService.getLinkedAccounts();
    if (!mounted) return;
    setState(() {
      if (result.isSuccess) {
        _accounts = result.data ?? [];
      } else {
        _error = result.message;
      }
      _isLoading = false;
    });
  }

  Future<void> _showLinkDialog() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Link Another Business'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the login of your account in the other business. '
                  'You only need to do this once.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter username' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                          size: 20),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter password' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  submitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => submitting = true);
                      final result = await _apiService.linkAccount(
                        usernameController.text.trim(),
                        passwordController.text,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result.isSuccess
                              ? 'Account linked'
                              : result.message),
                          backgroundColor: result.isSuccess
                              ? Colors.green
                              : AppColors.error,
                        ),
                      );
                      if (result.isSuccess) _load();
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Link'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchTo(Map<String, dynamic> account) async {
    final name = account['tenant_name']?.toString().trim() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Business'),
        content: Text('Switch to $name (${account['username']})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSwitching = true);

    // Wipe the previous tenant's in-progress state before the swap
    context.read<SaleProvider>().resetForNewSession();
    context.read<ReceivingProvider>().resetForNewSession();

    final ok = await context
        .read<AuthProvider>()
        .switchAccount(account['person_id'] as int);

    if (!mounted) return;
    setState(() => _isSwitching = false);

    if (ok) {
      // Fresh navigation stack so every screen rebuilds against the new tenant
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              context.read<AuthProvider>().error ?? 'Switch failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _unlink(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Account'),
        content: Text(
            'Remove the link to ${account['tenant_name']} (${account['username']})? '
            'You can link it again later with its password.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _apiService.unlinkAccount(account['link_id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(result.isSuccess ? 'Account unlinked' : result.message),
        backgroundColor:
            result.isSuccess ? Colors.green : AppColors.error,
      ),
    );
    if (result.isSuccess) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked Accounts'),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLinkDialog,
        icon: const Icon(Icons.add_link),
        label: const Text('Link Account'),
      ),
      body: _isSwitching
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Switching business...'),
                ],
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 44, color: AppColors.error),
                          const SizedBox(height: 10),
                          Text(_error!),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _accounts.isEmpty
                      ? _buildEmptyState(isDark)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _accounts.length,
                            itemBuilder: (context, i) =>
                                _buildAccountCard(_accounts[i], isDark),
                          ),
                        ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link,
                size: 48,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight),
            const SizedBox(height: 14),
            const Text('No linked accounts yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'If you run more than one business, link your other account '
              'once and switch between them without typing passwords.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account, bool isDark) {
    final available = account['is_available'] == true;
    final tenantName = account['tenant_name']?.toString().trim() ?? '';
    final fullName =
        '${account['first_name'] ?? ''} ${account['last_name'] ?? ''}'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: available ? () => _switchTo(account) : null,
        leading: CircleAvatar(
          backgroundColor:
              AppColors.brandPrimary.withOpacity(isDark ? 0.25 : 0.12),
          child: Icon(Icons.storefront,
              color: isDark ? AppColors.primaryLight : AppColors.primary),
        ),
        title: Text(tenantName.isNotEmpty ? tenantName : fullName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${account['username']}${available ? '' : '  ·  unavailable'}',
          style: TextStyle(
            fontSize: 12.5,
            color: available
                ? (isDark ? AppColors.darkTextLight : AppColors.textLight)
                : AppColors.error,
          ),
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            if (available)
              const PopupMenuItem(
                value: 'switch',
                child: Row(children: [
                  Icon(Icons.swap_horiz, size: 20),
                  SizedBox(width: 8),
                  Text('Switch'),
                ]),
              ),
            const PopupMenuItem(
              value: 'unlink',
              child: Row(children: [
                Icon(Icons.link_off, size: 20, color: AppColors.error),
                SizedBox(width: 8),
                Text('Unlink', style: TextStyle(color: AppColors.error)),
              ]),
            ),
          ],
          onSelected: (v) {
            if (v == 'switch') _switchTo(account);
            if (v == 'unlink') _unlink(account);
          },
        ),
      ),
    );
  }
}
