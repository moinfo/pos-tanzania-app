import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../models/contract_settings.dart';
import '../utils/constants.dart';

/// Contract Rules / Message Templates -- the mobile equivalent of web's
/// My Subscription -> Contract Rules. Loads current settings, lets the
/// user edit them, and saves back through api/Contract_settings.php.
class ContractSettingsScreen extends StatefulWidget {
  const ContractSettingsScreen({super.key});

  @override
  State<ContractSettingsScreen> createState() => _ContractSettingsScreenState();
}

class _ContractSettingsScreenState extends State<ContractSettingsScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  ContractSettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  late TextEditingController _penaltyPerDayController;
  late TextEditingController _penaltyGraceDaysController;
  late TextEditingController _terminationGraceDaysController;
  late TextEditingController _stage2DaysController;
  late TextEditingController _stage3DaysController;
  late TextEditingController _repossessionFeeController;
  late TextEditingController _whatsappPhoneController;
  final Map<String, TextEditingController> _templateControllers = {};

  static const _templateLabels = {
    'reminder': 'Reminder message',
    'warning': 'Warning message',
    'final_notice': 'Final notice message',
    'terminated': 'Termination message',
    'new_contract': 'New contract message',
    'renewed_contract': 'Renewed contract message',
    'payment_received': 'Payment received message',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response = await _apiService.getContractSettings();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      _applySettings(response.data!);
      setState(() => _isLoading = false);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = response.message;
      });
    }
  }

  void _applySettings(ContractSettings s) {
    _settings = s;
    _penaltyPerDayController = TextEditingController(text: s.penaltyPerDay);
    _penaltyGraceDaysController =
        TextEditingController(text: s.penaltyGraceDays);
    _terminationGraceDaysController =
        TextEditingController(text: s.terminationGraceDays);
    _stage2DaysController = TextEditingController(text: s.stage2Days);
    _stage3DaysController = TextEditingController(text: s.stage3Days);
    _repossessionFeeController = TextEditingController(text: s.repossessionFee);
    _whatsappPhoneController = TextEditingController(text: s.whatsappPhone);
    _templateControllers.clear();
    for (final key in _templateLabels.keys) {
      _templateControllers[key] =
          TextEditingController(text: s.templates[key] ?? '');
    }
  }

  @override
  void dispose() {
    if (_settings != null) {
      _penaltyPerDayController.dispose();
      _penaltyGraceDaysController.dispose();
      _terminationGraceDaysController.dispose();
      _stage2DaysController.dispose();
      _stage3DaysController.dispose();
      _repossessionFeeController.dispose();
      _whatsappPhoneController.dispose();
      for (final c in _templateControllers.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_settings == null) return;
    setState(() => _isSaving = true);

    final updated = _settings!.copyWith(
      penaltyPerDay: _penaltyPerDayController.text.trim(),
      penaltyGraceDays: _penaltyGraceDaysController.text.trim(),
      terminationGraceDays: _terminationGraceDaysController.text.trim(),
      stage2Days: _stage2DaysController.text.trim(),
      stage3Days: _stage3DaysController.text.trim(),
      repossessionFee: _repossessionFeeController.text.trim(),
      whatsappPhone: _whatsappPhoneController.text.trim(),
      templates: {
        for (final key in _templateLabels.keys)
          key: _templateControllers[key]!.text.trim(),
      },
    );

    final response = await _apiService.saveContractSettings(updated);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (response.isSuccess && response.data != null) {
      setState(() => _applySettings(response.data!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Contract settings saved'),
            backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contract Rules'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && _settings != null)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _save,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildForm(isDark),
    );
  }

  Widget _buildForm(bool isDark) {
    final s = _settings!;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('Late fee & auto-termination', isDark),
          Text(
            'Leave any day-count field at 0 to keep that rule off -- a '
            'penalty of 0/day never charges anything, and a termination '
            'grace period of 0 means contracts are never auto-terminated.',
            style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 12),
          _numberField(_penaltyPerDayController, 'Late fee per day (TSH)'),
          _numberField(
              _penaltyGraceDaysController, 'Days behind before fee starts'),
          _numberField(_stage2DaysController,
              'Days behind before escalating to a warning'),
          _numberField(
              _stage3DaysController, 'Days behind before a final notice'),
          _numberField(_terminationGraceDaysController,
              'Days behind before auto-termination'),
          _numberField(
              _repossessionFeeController, 'Repossession fee (TSH, one-time)'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily payment reminders'),
            subtitle: const Text(
                'Reminder/warning/final notice while a balance is unpaid'),
            value: s.reminderSmsEnabled,
            onChanged: (v) =>
                setState(() => _settings = s.copyWith(reminderSmsEnabled: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Termination message'),
            subtitle: const Text('Sent when a contract is terminated'),
            value: s.terminationSmsEnabled,
            onChanged: (v) => setState(
                () => _settings = s.copyWith(terminationSmsEnabled: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('New/renewed contract confirmation'),
            subtitle: const Text('Sent when a contract is created or renewed'),
            value: s.confirmationSmsEnabled,
            onChanged: (v) => setState(
                () => _settings = s.copyWith(confirmationSmsEnabled: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Payment receipt'),
            subtitle: const Text(
                'Sent every time a payment is recorded (amount paid, balance, days left)'),
            value: s.paymentSmsEnabled,
            onChanged: (v) =>
                setState(() => _settings = s.copyWith(paymentSmsEnabled: v)),
          ),
          const Divider(height: 32),
          _sectionLabel('Send via', isDark),
          _channelPicker(s, isDark),
          const SizedBox(height: 8),
          _numberField(_whatsappPhoneController,
              'WhatsApp number (if different from business Phone)',
              isPhone: true),
          Text(
            'Only mentioned inside message text as {whatsapp_phone} -- '
            'not the number WhatsApp messages are sent to. That\'s set per '
            'contract on the Add/Renew Contract screen.',
            style: TextStyle(
                fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
          ),
          const Divider(height: 32),
          _sectionLabel('Message wording', isDark),
          Text(
            'Leave a box empty to use the default wording.',
            style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 12),
          for (final key in _templateLabels.keys)
            _templateField(key, _templateLabels[key]!),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _channelPicker(ContractSettings s, bool isDark) {
    Widget option(String value, String label) {
      final disabled = value != 'sms' && !s.waReady;
      return RadioListTile<String>(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label),
        value: value,
        groupValue: s.messageChannel,
        onChanged: disabled
            ? null
            : (v) => setState(() => _settings = s.copyWith(messageChannel: v)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        option('sms', 'SMS'),
        option('whatsapp', 'WhatsApp'),
        option('both', 'Both'),
        if (!s.waReady)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              'WhatsApp needs the custom_message template approved on '
              'the MoSmS page first.',
              style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white54 : Colors.black45),
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primary,
          ),
        ),
      );

  Widget _numberField(TextEditingController controller, String label,
      {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _templateField(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _templateControllers[key],
        maxLines: 3,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
