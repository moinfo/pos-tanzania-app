import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../utils/constants.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../l10n/portal_language_switch.dart';
import 'portal_dashboard_screen.dart';

class PortalVerifyRegistrationScreen extends StatefulWidget {
  final String tenantCode;
  final String phone;

  const PortalVerifyRegistrationScreen({
    super.key,
    required this.tenantCode,
    required this.phone,
  });

  @override
  State<PortalVerifyRegistrationScreen> createState() =>
      _PortalVerifyRegistrationScreenState();
}

class _PortalVerifyRegistrationScreenState
    extends State<PortalVerifyRegistrationScreen> {
  final _service = CustomerApiService();
  final _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) return;

    setState(() => _isLoading = true);
    final response = await _service.verifyRegistration(
      tenantCode: widget.tenantCode,
      phone: widget.phone,
      otp: otp,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.isSuccess) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PortalDashboardScreen()),
        (route) => false,
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
    return ValueListenableBuilder<String>(
      valueListenable: PortalLocale.instance.language,
      builder: (context, _, __) => Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          title: Text(PortalStrings.t('verify_phone')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: const [PortalLanguageSwitch()],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sms, size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    PortalStrings.t('verify_intro', {'0': widget.phone}),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 6),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verify,
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
                          : Text(PortalStrings.t('verify')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
