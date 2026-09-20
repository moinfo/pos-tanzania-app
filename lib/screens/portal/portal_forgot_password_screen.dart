import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../utils/constants.dart';
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
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
                  const Text(
                    "We'll text a code to confirm it's you, then let you set a new password.",
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 13.5, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _tenantCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Business Code',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
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
                        : const Text('Send Code'),
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
