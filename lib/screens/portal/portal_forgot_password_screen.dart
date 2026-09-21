import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/customer_api_service.dart';
import '../../utils/constants.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../l10n/portal_language_switch.dart';
import 'portal_reset_password_screen.dart';

class PortalForgotPasswordScreen extends StatefulWidget {
  const PortalForgotPasswordScreen({super.key});

  @override
  State<PortalForgotPasswordScreen> createState() =>
      _PortalForgotPasswordScreenState();
}

class _PortalForgotPasswordScreenState
    extends State<PortalForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CustomerApiService();
  final _tenantCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _service.getTenantCode().then((saved) {
      if (saved != null && mounted) {
        setState(() => _tenantCodeController.text = saved);
      }
    });
  }

  @override
  void dispose() {
    _tenantCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final tenantCode = _tenantCodeController.text.trim();
    final phone = _phoneController.text.trim();
    final response = await _service.requestPasswordReset(
      tenantCode: tenantCode,
      phone: phone,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Always proceed to the OTP screen regardless of outcome -- the
    // backend doesn't reveal whether an account exists for this phone.
    if (response.isSuccess) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PortalResetPasswordScreen(
            tenantCode: tenantCode,
            phone: phone,
          ),
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
          title: Text(PortalStrings.t('forgot_password_title')),
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
                      PortalStrings.t('forgot_intro'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13.5,
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _tenantCodeController,
                      decoration: InputDecoration(
                        labelText: PortalStrings.t('business_code'),
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
