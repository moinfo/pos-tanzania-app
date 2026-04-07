import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/glassmorphic_card.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ── Steps: 0 = pick plan, 1 = fill details ──────────────────────────────
  int _step = 0;

  // Plans
  List<Map<String, dynamic>> _plans = [];
  bool _loadingPlans = true;
  String? _plansError;
  int? _selectedPlanId;
  String? _selectedPlanName;

  // Form
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String _passwordValue = '';

  final _apiService = ApiService();

  // Password rules
  bool get _hasMinLength => _passwordValue.length >= 8;
  bool get _hasUppercase => _passwordValue.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _passwordValue.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial =>
      _passwordValue.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'));
  int get _strengthLevel =>
      [_hasMinLength, _hasUppercase, _hasNumber, _hasSpecial]
          .where((r) => r)
          .length;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loadingPlans = true;
      _plansError = null;
    });
    final result = await _apiService.getPublicPlans();
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() {
        _plans = result.data!;
        _loadingPlans = false;
        // Pre-select first plan
        if (_plans.isNotEmpty) {
          _selectedPlanId = _plans.first['id'] as int?;
          _selectedPlanName = _plans.first['name'] as String?;
        }
      });
    } else {
      setState(() {
        _plansError = result.message ?? 'Failed to load plans';
        _loadingPlans = false;
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a plan first'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await _apiService.registerTenant(
      businessName: _businessNameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      passwordConfirmation: _confirmPasswordController.text,
      packageId: _selectedPlanId!,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.isSuccess || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Registration failed'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final redirectUrl = result.data!['redirect_url'] as String?;
    final merchantRef = result.data!['merchant_reference'] as String?;
    final username = result.data!['username'] as String?;
    final packageName = result.data!['package_name'] as String?;

    if (redirectUrl == null || merchantRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid response from payment gateway'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Open Pesapal in system browser
    final uri = Uri.parse(redirectUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open payment page'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Show polling sheet
    if (!mounted) return;
    _showPollingSheet(merchantRef, packageName ?? _selectedPlanName ?? '', username ?? '');
  }

  void _showPollingSheet(String merchantRef, String packageName, String username) {
    final isDark = context.read<ThemeProvider>().isDarkMode;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RegistrationPollingSheet(
        merchantRef: merchantRef,
        packageName: packageName,
        username: username,
        apiService: _apiService,
        onCompleted: () {
          Navigator.pop(context); // close sheet
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Account activated! Login with username: $username'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 5),
            ),
          );
        },
        onFailed: () {
          Navigator.pop(context); // close sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment failed or cancelled. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final client = ApiService.currentClient;
    final branding = client?.branding;
    final brandPrimary =
        branding != null ? Color(branding.primaryColor) : AppColors.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : brandPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _step == 0 ? Icons.close : Icons.arrow_back_rounded,
                      color: isDark ? AppColors.darkText : Colors.white,
                    ),
                    onPressed: () {
                      if (_step == 1) {
                        setState(() => _step = 0);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  Expanded(
                    child: Text(
                      _step == 0 ? 'Choose a Plan' : 'Create Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : Colors.white,
                      ),
                    ),
                  ),
                  // Step indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Step ${_step + 1} of 2',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkText : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _step == 0
                  ? _buildPlanStep(isDark, brandPrimary)
                  : _buildDetailsStep(isDark, brandPrimary),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Plan Picker ──────────────────────────────────────────────────

  Widget _buildPlanStep(bool isDark, Color brandPrimary) {
    if (_loadingPlans) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_plansError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_plansError!,
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadPlans, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _plans.length,
            itemBuilder: (context, i) {
              final pkg = _plans[i];
              final id = pkg['id'] as int? ?? 0;
              final name = pkg['name'] as String? ?? '';
              final price = (pkg['price'] as num?)?.toDouble() ?? 0;
              final durationDays = pkg['duration_days'] as int? ?? 30;
              final maxUsers = pkg['max_users'] as int? ?? 0;
              final isAddon = pkg['is_addon'] as bool? ?? false;
              final features = (pkg['features'] as List<dynamic>?)
                      ?.map((f) => f as String)
                      .toList() ??
                  [];
              final isSelected = _selectedPlanId == id;

              return GestureDetector(
                onTap: () => setState(() {
                  _selectedPlanId = id;
                  _selectedPlanName = name;
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? brandPrimary : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isSelected ? brandPrimary : Colors.black)
                            .withOpacity(isSelected ? 0.15 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.darkText
                                          : AppColors.text,
                                    ),
                                  ),
                                  if (isAddon) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.success
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Add-on',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: brandPrimary, size: 22),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'TZS ${_formatPrice(price)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? brandPrimary
                                    : (isDark
                                        ? AppColors.darkText
                                        : AppColors.text),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                '/ ${durationDays}d',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextLight
                                      : AppColors.textLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _chip(Icons.people_outline,
                                maxUsers == 0 ? 'Unlimited users' : '$maxUsers users',
                                isDark),
                          ],
                        ),
                        if (features.isNotEmpty) ...[
                          const Divider(height: 16),
                          ...features.take(3).map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_rounded,
                                        size: 14, color: brandPrimary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        f,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.darkText
                                              : AppColors.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedPlanId == null
                  ? null
                  : () => setState(() => _step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? brandPrimary : Colors.white,
                foregroundColor: isDark ? Colors.white : brandPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _selectedPlanName != null
                    ? 'Continue with $_selectedPlanName'
                    : 'Select a Plan',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Details Form ─────────────────────────────────────────────────

  Widget _buildDetailsStep(bool isDark, Color brandPrimary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Selected plan banner
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: brandPrimary.withOpacity(isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: brandPrimary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_rounded,
                    color: brandPrimary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Plan: $_selectedPlanName',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _step = 0),
                  child: Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      color: brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          GlassmorphicCard(
            isDark: isDark,
            onColoredBackground: !isDark,
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field(
                    controller: _businessNameController,
                    label: 'Business Name',
                    icon: Icons.store_rounded,
                    isDark: isDark,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Required'
                        : null,
                    action: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _ownerNameController,
                    label: 'Owner Name',
                    icon: Icons.person_rounded,
                    isDark: isDark,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Required'
                        : null,
                    action: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_rounded,
                    isDark: isDark,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().length < 9) return 'Enter a valid phone number';
                      return null;
                    },
                    action: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_rounded,
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                    action: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  _passwordField(
                    controller: _passwordController,
                    label: 'Password',
                    isDark: isDark,
                    obscure: _obscurePassword,
                    onToggle: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onChanged: (v) => setState(() => _passwordValue = v),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!_hasMinLength) return 'Minimum 8 characters';
                      if (!_hasUppercase)
                        return 'Add at least one uppercase letter';
                      if (!_hasNumber) return 'Add at least one number';
                      return null;
                    },
                    action: TextInputAction.next,
                  ),
                  if (_passwordValue.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildStrengthWidget(isDark),
                  ],
                  const SizedBox(height: 14),
                  _passwordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    isDark: isDark,
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v != _passwordController.text)
                        return 'Passwords do not match';
                      return null;
                    },
                    action: TextInputAction.done,
                    onSubmitted: (_) => _handleRegister(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? brandPrimary : Colors.white,
                      foregroundColor:
                          isDark ? Colors.white : brandPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  isDark ? Colors.white : brandPrimary,
                            ),
                          )
                        : const Text(
                            'Create Account & Pay',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Already have an account? Login',
              style: TextStyle(
                color: isDark ? AppColors.darkTextLight : Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Powered by Moinfotech',
            style: TextStyle(
              color: isDark ? AppColors.darkTextLight : Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? action,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: action,
      style: TextStyle(color: isDark ? AppColors.darkText : Colors.white),
      decoration: _deco(label, icon, isDark),
      validator: validator,
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    TextInputAction? action,
    void Function(String)? onSubmitted,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: action,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      style: TextStyle(color: isDark ? AppColors.darkText : Colors.white),
      decoration: _deco(label, Icons.lock_rounded, isDark).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility : Icons.visibility_off,
            color: isDark ? AppColors.darkTextLight : Colors.white70,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildStrengthWidget(bool isDark) {
    final colors = [
      AppColors.error,
      Colors.orange,
      Colors.amber,
      AppColors.success
    ];
    final labels = ['Weak', 'Fair', 'Good', 'Strong'];
    final level = _strengthLevel.clamp(1, 4);
    final color = colors[level - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i < level
                        ? color
                        : Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
        ),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            labels[level - 1],
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ),
        const SizedBox(height: 6),
        _req('At least 8 characters', _hasMinLength, isDark),
        _req('One uppercase letter (A–Z)', _hasUppercase, isDark),
        _req('One number (0–9)', _hasNumber, isDark),
        _req('One special character (!@#\$...)', _hasSpecial, isDark),
      ],
    );
  }

  Widget _req(String label, bool met, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            met
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            size: 14,
            color: met ? AppColors.success : Colors.white.withOpacity(0.5),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: met
                  ? (isDark ? AppColors.darkText : Colors.white)
                  : Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 13,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
      ],
    );
  }

  InputDecoration _deco(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: isDark ? AppColors.darkTextLight : Colors.white70),
      prefixIcon: Icon(icon,
          color: isDark ? AppColors.darkTextLight : Colors.white70),
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.1)
          : Colors.white.withOpacity(0.2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Colors.white.withOpacity(0.6), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}

// ── Registration Payment Polling Sheet ───────────────────────────────────────

class _RegistrationPollingSheet extends StatefulWidget {
  final String merchantRef;
  final String packageName;
  final String username;
  final ApiService apiService;
  final VoidCallback onCompleted;
  final VoidCallback onFailed;

  const _RegistrationPollingSheet({
    required this.merchantRef,
    required this.packageName,
    required this.username,
    required this.apiService,
    required this.onCompleted,
    required this.onFailed,
  });

  @override
  State<_RegistrationPollingSheet> createState() =>
      _RegistrationPollingSheetState();
}

class _RegistrationPollingSheetState
    extends State<_RegistrationPollingSheet> {
  Timer? _timer;
  int _attempts = 0;
  static const _maxAttempts = 36; // 3 min at 5s intervals
  String _statusMessage = 'Waiting for payment confirmation...';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    _attempts++;
    if (_attempts > _maxAttempts) {
      _timer?.cancel();
      if (mounted) {
        setState(() =>
            _statusMessage = 'Taking longer than expected. Tap "Check Now".');
      }
      return;
    }

    final result =
        await widget.apiService.checkRegistrationStatus(widget.merchantRef);
    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      final status = result.data!['status'] as String?;
      if (status == 'completed') {
        _timer?.cancel();
        widget.onCompleted();
      } else if (status == 'failed') {
        _timer?.cancel();
        widget.onFailed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Complete Payment in Browser',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Subscribing to ${widget.packageName}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _timer?.cancel();
                    widget.onFailed();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _attempts = 0;
                    setState(
                        () => _statusMessage = 'Checking payment status...');
                    _poll();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Check Now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
