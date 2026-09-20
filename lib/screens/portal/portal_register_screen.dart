import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../utils/constants.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../l10n/portal_language_switch.dart';
import 'portal_verify_registration_screen.dart';

/// Step 1 of customer registration: phone + password. Doesn't log the
/// customer in -- the backend sends an OTP to confirm the phone before the
/// account becomes usable (PortalVerifyRegistrationScreen).
class PortalRegisterScreen extends StatefulWidget {
  const PortalRegisterScreen({super.key});

  @override
  State<PortalRegisterScreen> createState() => _PortalRegisterScreenState();
}

class _PortalRegisterScreenState extends State<PortalRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CustomerApiService();
  final _tenantCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _tenantCodeController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _passwordConfirmController.text) {
      _showSnack(PortalStrings.t('passwords_no_match'), isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final tenantCode = _tenantCodeController.text.trim();
    final phone = _phoneController.text.trim();
    final response = await _service.register(
      tenantCode: tenantCode,
      phone: phone,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.isSuccess) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PortalVerifyRegistrationScreen(
            tenantCode: tenantCode,
            phone: phone,
          ),
        ),
      );
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
    return ValueListenableBuilder<String>(
      valueListenable: PortalLocale.instance.language,
      builder: (context, _, __) => Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          title: Text(PortalStrings.t('register_title')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: const [PortalLanguageSwitch()],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      PortalStrings.t('register_intro'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.textLight),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _tenantCodeController,
                      decoration: InputDecoration(
                        labelText: PortalStrings.t('business_code'),
                        hintText: 'e.g. leruma-shop',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? PortalStrings.t('required')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: PortalStrings.t('phone_number'),
                        hintText: '0712345678',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? PortalStrings.t('required')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: PortalStrings.t('password'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? PortalStrings.t('min_6_chars')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordConfirmController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: PortalStrings.t('confirm_password'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? PortalStrings.t('required')
                          : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(PortalStrings.t('send_code')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
