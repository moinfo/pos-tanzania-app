import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/customer_api_service.dart';
import '../../utils/constants.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../l10n/portal_language_switch.dart';
import 'portal_login_screen.dart';

class PortalResetPasswordScreen extends StatefulWidget {
  final String tenantCode;
  final String phone;

  const PortalResetPasswordScreen({
    super.key,
    required this.tenantCode,
    required this.phone,
  });

  @override
  State<PortalResetPasswordScreen> createState() =>
      _PortalResetPasswordScreenState();
}

class _PortalResetPasswordScreenState extends State<PortalResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CustomerApiService();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _passwordConfirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(PortalStrings.t('passwords_no_match')),
            backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    final response = await _service.resetPassword(
      tenantCode: widget.tenantCode,
      phone: widget.phone,
      otp: _otpController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.isSuccess) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PortalLoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PortalStrings.t('password_reset_success')),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
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
          title: Text(PortalStrings.t('reset_password_title')),
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
                      PortalStrings.t('reset_intro', {'0': widget.phone}),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13.5,
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: PortalStrings.t('otp'),
                        counterText: '',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? PortalStrings.t('required')
                          : null,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: PortalStrings.t('new_password'),
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
                        labelText: PortalStrings.t('confirm_new_password'),
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
                          : Text(PortalStrings.t('reset_password_btn')),
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
