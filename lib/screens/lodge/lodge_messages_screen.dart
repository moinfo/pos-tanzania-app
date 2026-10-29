import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'lodge_theme.dart';

/// `GET/POST lodge/messages/*` -- README 3.17: SMS/WhatsApp to guests
/// (reservation/check-in/payment/check-out instantly, arrival/checkout
/// reminders in the morning) plus a boss day-close report. Needs a linked
/// MoSmS account (mosms.co.tz) before anything actually sends.
class LodgeMessagesScreen extends StatefulWidget {
  const LodgeMessagesScreen({super.key});

  @override
  State<LodgeMessagesScreen> createState() => _LodgeMessagesScreenState();
}

class _LodgeMessagesScreenState extends State<LodgeMessagesScreen> {
  final ApiService _apiService = ApiService();
  LodgeMessagesSettings? _settings;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;

  // Local editable copies -- pushed to the server as a whole on Save.
  bool _enabled = false;
  String _channel = 'sms';
  final _smsNameController = TextEditingController();
  late List<_EventState> _eventStates;
  bool _bossEnabled = false;
  final _bossTemplateController = TextEditingController();
  List<LodgeBossPhone> _bossPhones = [];

  // "Test a message" section -- separate from each event's inline Preview:
  // this one renders (or sends) using a REAL booking's details via
  // booking_id, not placeholder data.
  final _testBookingIdController = TextEditingController();
  final _testPhoneController = TextEditingController();
  String _testEvent = 'reservation';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _smsNameController.dispose();
    _bossTemplateController.dispose();
    _testBookingIdController.dispose();
    _testPhoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response = await _apiService.getLodgeMessagesSettings();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _settings = response.data;
        _enabled = _settings!.enabled;
        _channel = _settings!.channel;
        _smsNameController.text = _settings!.smsName;
        _eventStates = _settings!.events
            .map((e) => _EventState(e.event, e.label, e.enabled, TextEditingController(text: e.template), e.defaultTemplate))
            .toList();
        _bossEnabled = _settings!.boss.enabled;
        _bossTemplateController.text = _settings!.boss.template;
        _bossPhones = List.of(_settings!.boss.phones);
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final response = await _apiService.saveLodgeMessagesSettings(
      enabled: _enabled,
      channel: _channel,
      smsName: _smsNameController.text.trim(),
      events: {
        for (final e in _eventStates)
          e.event: {'enabled': e.enabled, 'template': e.templateController.text},
      },
      boss: {
        'enabled': _bossEnabled,
        'phones': _bossPhones.map((p) => p.toJson()).toList(),
        'template': _bossTemplateController.text,
      },
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.'), backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showLinkSheet() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Link MoSmS account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  final response = await _apiService.linkLodgeMessagesAccount(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );
                  if (!mounted) return;
                  if (response.isSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account linked.'), backgroundColor: AppColors.success),
                    );
                    _load();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
                    );
                  }
                },
                child: const Text('Link'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRegisterSheet() async {
    final orgController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create MoSmS account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(controller: orgController, decoration: const InputDecoration(labelText: 'Organisation name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password (min 8)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  final response = await _apiService.registerLodgeMessagesAccount(
                    orgName: orgController.text.trim(),
                    name: nameController.text.trim(),
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim(),
                    password: passwordController.text,
                  );
                  if (!mounted) return;
                  if (response.isSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account created and linked.'), backgroundColor: AppColors.success),
                    );
                    _load();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
                    );
                  }
                },
                child: const Text('Create account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _previewEvent(_EventState e) async {
    final response = await _apiService.testLodgeMessage(event: e.event, preview: true);
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('${e.label} preview'),
          content: Text(response.data!['message']?.toString() ?? ''),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  /// The dedicated "Test a message" section: renders (or sends) using a
  /// real booking's data via [bookingId], unlike each event's inline
  /// Preview button which uses placeholder data.
  Future<void> _runTest({required bool preview}) async {
    final bookingId = int.tryParse(_testBookingIdController.text.trim());
    if (_testEvent != 'day_close' && bookingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a booking number'), backgroundColor: AppColors.error),
      );
      return;
    }

    final response = await _apiService.testLodgeMessage(
      event: _testEvent,
      bookingId: _testEvent == 'day_close' ? null : bookingId,
      phone: _testPhoneController.text.trim().isEmpty ? null : _testPhoneController.text.trim(),
      preview: preview,
    );
    if (!mounted) return;

    if (preview) {
      if (response.isSuccess && response.data != null) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Preview'),
            content: Text(response.data!['message']?.toString() ?? ''),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
        );
      }
    } else {
      final status = response.data?['status']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'sent' ? 'Test message sent.' : response.message),
          backgroundColor: status == 'sent' ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  void _addBossPhone() {
    setState(() => _bossPhones.add(LodgeBossPhone(name: '', phone: '')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();
    final canEdit = permissions.hasPermission(PermissionIds.lodgeMessagesEdit);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: LodgeTheme.appBar(
        isDark: isDark,
        eyebrow: 'Guest comms',
        title: 'Messages',
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Log',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LodgeMessagesLogScreen()),
            ),
          ),
        ],
      ),
      body: _buildBody(isDark, canEdit),
    );
  }

  Widget _buildBody(bool isDark, bool canEdit) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null || _settings == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage ?? 'Not found'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final status = _settings!.status;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (!status.linked)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No MoSmS account linked -- nothing will be sent.',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: _showLinkSheet, child: const Text('Link account')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(onPressed: _showRegisterSheet, child: const Text('Create account')),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('MoSmS linked${status.balance != null ? ' · balance ${Formatters.formatCurrency(status.balance!)}' : ''}'
                      '${status.whatsappReady ? ' · WhatsApp ready' : ''}'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Send guest messages'),
          value: _enabled,
          onChanged: canEdit ? (v) => setState(() => _enabled = v) : null,
        ),
        DropdownButtonFormField<String>(
          value: _channel,
          decoration: const InputDecoration(labelText: 'Channel', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'sms', child: Text('SMS')),
            DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
            DropdownMenuItem(value: 'both', child: Text('Both')),
          ],
          onChanged: canEdit ? (v) => setState(() => _channel = v ?? _channel) : null,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _smsNameController,
          enabled: canEdit,
          decoration: const InputDecoration(labelText: 'Lodge name in messages', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        Text('Events', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 8),
        ..._eventStates.map((e) => Card(
              color: isDark ? AppColors.darkCard : Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(e.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 20),
                          tooltip: 'Preview',
                          onPressed: () => _previewEvent(e),
                        ),
                        Switch(
                          value: e.enabled,
                          onChanged: canEdit ? (v) => setState(() => e.enabled = v) : null,
                        ),
                      ],
                    ),
                    TextField(
                      controller: e.templateController,
                      enabled: canEdit,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: e.defaultTemplate,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 20),
        Text('Boss day-close report', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Send to boss when a day closes'),
          value: _bossEnabled,
          onChanged: canEdit ? (v) => setState(() => _bossEnabled = v) : null,
        ),
        ..._bossPhones.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: p.name,
                    enabled: canEdit,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), isDense: true),
                    onChanged: (v) => _bossPhones[i] = LodgeBossPhone(name: v, phone: p.phone),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: p.phone,
                    enabled: canEdit,
                    decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), isDense: true),
                    onChanged: (v) => _bossPhones[i] = LodgeBossPhone(name: p.name, phone: v),
                  ),
                ),
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () => setState(() => _bossPhones.removeAt(i)),
                  ),
              ],
            ),
          );
        }),
        if (canEdit)
          TextButton.icon(onPressed: _addBossPhone, icon: const Icon(Icons.add), label: const Text('Add phone')),
        const SizedBox(height: 10),
        TextField(
          controller: _bossTemplateController,
          enabled: canEdit,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Boss report template', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        Text('Test a message', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 4),
        Text('Pick a booking and a moment; the message is rendered with that booking\'s details.',
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _testBookingIdController,
                keyboardType: TextInputType.number,
                enabled: _testEvent != 'day_close',
                decoration: const InputDecoration(labelText: 'Booking #', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _testEvent,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: [
                  ..._eventStates.map((e) => DropdownMenuItem(value: e.event, child: Text(e.label, overflow: TextOverflow.ellipsis))),
                  const DropdownMenuItem(value: 'day_close', child: Text('Day-close report')),
                ],
                onChanged: (v) => setState(() => _testEvent = v ?? _testEvent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _testPhoneController,
          decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => _runTest(preview: true), child: const Text('Preview')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _runTest(preview: false),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary, foregroundColor: Colors.white),
                child: const Text('Send test'),
              ),
            ),
          ],
        ),
        if (canEdit) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save settings'),
            ),
          ),
        ],
      ],
    );
  }
}

class _EventState {
  final String event;
  final String label;
  bool enabled;
  final TextEditingController templateController;
  final String defaultTemplate;

  _EventState(this.event, this.label, this.enabled, this.templateController, this.defaultTemplate);
}

class LodgeMessagesLogScreen extends StatefulWidget {
  const LodgeMessagesLogScreen({super.key});

  @override
  State<LodgeMessagesLogScreen> createState() => _LodgeMessagesLogScreenState();
}

class _LodgeMessagesLogScreenState extends State<LodgeMessagesLogScreen> {
  final ApiService _apiService = ApiService();
  List<LodgeMessageLogEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final response = await _apiService.getLodgeMessagesLog();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) _entries = response.data!;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'sent':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: LodgeTheme.appBar(isDark: isDark, eyebrow: 'Guest comms', title: 'Message Log'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _entries.length,
                itemBuilder: (_, i) {
                  final e = _entries[i];
                  return Card(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      title: Text('${e.event} · ${e.channel}'),
                      subtitle: Text('${e.phone ?? '-'} · ${Formatters.formatDate(e.createdAt)}'
                          '${e.message != null ? ' · ${e.message}' : ''}'),
                      trailing: Text(e.status, style: TextStyle(color: _statusColor(e.status), fontWeight: FontWeight.w600)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
