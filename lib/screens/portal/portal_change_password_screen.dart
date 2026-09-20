import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../utils/constants.dart';

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
      _showSnack('Password mpya hazifanani', isError: true);
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
      _showSnack('Password imebadilishwa');
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
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Badilisha Password'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
                labelText: 'Password ya sasa',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Weka password ya sasa' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'Password mpya',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? 'Password iwe na herufi 6 au zaidi'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureNew,
              decoration: const InputDecoration(
                labelText: 'Rudia password mpya',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Rudia password mpya' : null,
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
                  : const Text('Hifadhi'),
            ),
          ],
        ),
      ),
    );
  }
}
