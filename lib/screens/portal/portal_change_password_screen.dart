import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/customer_api_service.dart';
import '../../utils/constants.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../l10n/portal_language_switch.dart';

/// Self-service "change my password" while logged in -- current password
/// + new password, separate from the logged-out OTP forgot/reset flow.
class PortalChangePasswordScreen extends StatefulWidget {
  const PortalChangePasswordScreen({super.key});

  @override
  State<PortalChangePasswordScreen> createState() =>
      _PortalChangePasswordScreenState();
}

class _PortalChangePasswordScreenState
    extends State<PortalChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CustomerApiService();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newController.text != _confirmController.text) {
      _showSnack(PortalStrings.t('new_passwords_no_match'), isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final response = await _service.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (response.isSuccess) {
      _showSnack(PortalStrings.t('password_changed'));
      Navigator.pop(context);
    } else {
      _showSnack(response.message, isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return ValueListenableBuilder<String>(
      valueListenable: PortalLocale.instance.language,
      builder: (context, _, __) => Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: Text(PortalStrings.t('change_password_title')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: const [PortalLanguageSwitch()],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _currentController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: PortalStrings.t('current_password'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? PortalStrings.t('enter_current_password')
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: PortalStrings.t('new_password_field'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? PortalStrings.t('new_password_min')
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: PortalStrings.t('confirm_new_password_field'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? PortalStrings.t('confirm_new_password_required')
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(PortalStrings.t('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
