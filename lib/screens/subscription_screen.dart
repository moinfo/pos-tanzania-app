import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

class SubscriptionScreen extends StatefulWidget {
  /// Current subscription info fetched from the dashboard (may be null).
  final Map<String, dynamic>? currentSubscription;

  /// Optional callback fired after a successful payment — used by the
  /// post-registration flow to redirect the user to the login screen.
  final VoidCallback? onPaymentCompleted;

  const SubscriptionScreen({
    super.key,
    this.currentSubscription,
    this.onPaymentCompleted,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _apiService = ApiService();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _addons = [];

  // Tier ordering used to determine if a package is an upgrade/downgrade
  static const _tierOrder = ['Basic', 'Standard', 'Premium'];

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _apiService.getSubscriptionPackages();
    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      setState(() {
        _packages = (result.data!['packages'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        _addons = (result.data!['addons'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result.message ?? 'Failed to load packages';
        _isLoading = false;
      });
    }
  }

  String? get _currentPackageName =>
      widget.currentSubscription?['package_name'] as String?;

  bool get _isExpired =>
      widget.currentSubscription?['is_expired'] as bool? ?? false;

  int get _daysRemaining =>
      widget.currentSubscription?['days_remaining'] as int? ?? 0;

  String? get _expiresAt =>
      widget.currentSubscription?['expires_at'] as String?;

  int _tierIndex(String name) {
    final idx = _tierOrder.indexOf(name);
    return idx == -1 ? 99 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        title: Text(
          'Subscription',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.text,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? AppColors.darkText : AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(isDark),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPackages,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.currentSubscription != null) ...[
            _buildCurrentPlanCard(isDark),
            const SizedBox(height: 24),
          ],
          _sectionHeader('Available Plans', isDark),
          const SizedBox(height: 12),
          ..._packages.map((pkg) => _buildPackageCard(pkg, isDark)),
          if (_addons.isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionHeader('Add-on Modules', isDark),
            const SizedBox(height: 4),
            _buildAddonsNote(isDark),
            const SizedBox(height: 12),
            ..._addons.map((addon) => _buildAddonCard(addon, isDark)),
          ],
          const SizedBox(height: 8),
          _buildContactNote(isDark),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.darkText : AppColors.text,
      ),
    );
  }

  Widget _buildAddonsNote(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        'Add features to any existing plan — subscribe to each module independently.',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(bool isDark) {
    final Color statusColor;
    final String statusText;

    if (_isExpired) {
      statusColor = AppColors.error;
      statusText = 'Expired';
    } else if (_daysRemaining <= 3) {
      statusColor = AppColors.error;
      statusText = '$_daysRemaining day${_daysRemaining == 1 ? '' : 's'} left';
    } else if (_daysRemaining <= 7) {
      statusColor = Colors.orange;
      statusText = '$_daysRemaining days left';
    } else {
      statusColor = AppColors.success;
      statusText = '$_daysRemaining days left';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isExpired ? Icons.warning_rounded : Icons.workspace_premium_rounded,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Plan',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _currentPackageName ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Plan',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
                if (_expiresAt != null)
                  Text(
                    _isExpired
                        ? 'Expired on ${_expiresAt!.substring(0, 10)}'
                        : 'Expires ${_expiresAt!.substring(0, 10)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg, bool isDark) {
    final pkgId = pkg['id'] as int? ?? 0;
    final name = pkg['name'] as String? ?? '';
    final price = (pkg['price'] as num?)?.toDouble() ?? 0;
    final durationDays = pkg['duration_days'] as int? ?? 30;
    final maxUsers = pkg['max_users'] as int? ?? 0;
    final maxLocations = pkg['max_locations'] as int? ?? 0;
    final features = (pkg['features'] as List<dynamic>?)
            ?.map((f) => f as String)
            .toList() ??
        [];

    final bool isCurrent = name == _currentPackageName;
    final bool isUpgrade = !isCurrent &&
        _currentPackageName != null &&
        _tierIndex(name) > _tierIndex(_currentPackageName!);
    final bool isDowngrade = !isCurrent &&
        _currentPackageName != null &&
        _tierIndex(name) < _tierIndex(_currentPackageName!);

    final Color cardAccent = isCurrent
        ? AppColors.brandPrimary
        : isUpgrade
            ? AppColors.success
            : Colors.grey;

    final String ctaLabel = isCurrent
        ? (_isExpired ? 'Renew' : 'Renew Plan')
        : isUpgrade
            ? 'Upgrade to $name'
            : isDowngrade
                ? 'Downgrade to $name'
                : 'Select $name';

    final Color ctaColor = isCurrent
        ? AppColors.brandPrimary
        : isUpgrade
            ? AppColors.success
            : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isCurrent
              ? Border.all(color: AppColors.brandPrimary, width: 2)
              : Border.all(
                  color: isDark
                      ? AppColors.darkDivider
                      : AppColors.lightDivider,
                  width: 1,
                ),
          boxShadow: [
            BoxShadow(
              color: (isCurrent ? AppColors.brandPrimary : Colors.black)
                  .withOpacity(isCurrent ? 0.1 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Current',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (isUpgrade) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Recommended',
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
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'TZS ${_formatPrice(price)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cardAccent,
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _infoChip(
                              Icons.people_outline,
                              maxUsers == 0 ? 'Unlimited users' : '$maxUsers users',
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _infoChip(
                              Icons.store_outlined,
                              maxLocations == 0
                                  ? 'Unlimited locations'
                                  : '$maxLocations location${maxLocations > 1 ? 's' : ''}',
                              isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Features list
            if (features.isNotEmpty) ...[
              const Divider(height: 24, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  children: features
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 16, color: cardAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.darkText
                                          : AppColors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
            // CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _startPayment(pkgId, name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrent || isUpgrade
                        ? ctaColor
                        : Colors.transparent,
                    foregroundColor:
                        isCurrent || isUpgrade ? Colors.white : ctaColor,
                    elevation: isCurrent || isUpgrade ? 0 : 0,
                    side: isCurrent || isUpgrade
                        ? null
                        : BorderSide(color: ctaColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    ctaLabel,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, bool isDark) {
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

  Widget _buildAddonCard(Map<String, dynamic> addon, bool isDark) {
    final addonId = addon['id'] as int? ?? 0;
    final name = addon['name'] as String? ?? '';
    final price = (addon['price'] as num?)?.toDouble() ?? 0;
    final durationDays = addon['duration_days'] as int? ?? 30;
    final features = (addon['features'] as List<dynamic>?)
            ?.map((f) => f as String)
            .toList() ??
        [];
    final isActive = addon['is_active'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: AppColors.success, width: 2)
              : Border.all(
                  color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  width: 1,
                ),
          boxShadow: [
            BoxShadow(
              color: (isActive ? AppColors.success : Colors.black)
                  .withOpacity(isActive ? 0.10 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TZS ${_formatPrice(price)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _infoChip(Icons.people_outline, 'Unlimited users', isDark),
                      const SizedBox(width: 8),
                      _infoChip(Icons.store_outlined, 'Unlimited locations', isDark),
                    ],
                  ),
                ],
              ),
            ),
            // Features
            if (features.isNotEmpty) ...[
              const Divider(height: 24, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  children: features
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 16, color: AppColors.success),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.darkText
                                          : AppColors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _startPayment(addonId, name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isActive ? AppColors.brandPrimary : AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isActive ? 'Renew $name' : 'Upgrade to $name',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'To renew or upgrade your subscription, please contact Mopos support.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkText : AppColors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Initiates Pesapal payment for a package and opens the payment URL in browser.
  Future<void> _startPayment(int packageId, String packageName) async {
    final isDark = context.read<ThemeProvider>().isDarkMode;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LoadingDialog(),
    );

    final result = await _apiService.initiateSubscriptionPayment(packageId);

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (!result.isSuccess || result.data == null) {
      _showErrorSnack(result.message ?? 'Failed to initiate payment');
      return;
    }

    final redirectUrl = result.data!['redirect_url'] as String?;
    final merchantRef = result.data!['merchant_reference'] as String?;

    if (redirectUrl == null || merchantRef == null) {
      _showErrorSnack('Invalid response from payment gateway');
      return;
    }

    // Open Pesapal payment page in system browser
    final uri = Uri.parse(redirectUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnack('Could not open payment page');
      return;
    }

    // Show polling bottom sheet so user can confirm when done
    if (!mounted) return;
    _showPollingSheet(merchantRef, packageName, isDark);
  }

  void _showPollingSheet(String merchantRef, String packageName, bool isDark) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PaymentPollingSheet(
        merchantRef: merchantRef,
        packageName: packageName,
        apiService: _apiService,
        onCompleted: () {
          Navigator.pop(context); // close sheet
          if (widget.onPaymentCompleted != null) {
            widget.onPaymentCompleted!();
          } else {
            _loadPackages(); // refresh packages (active status)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$packageName subscription activated!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
        onFailed: () {
          Navigator.pop(context);
          _showErrorSnack('Payment failed. Please try again.');
        },
      ),
    );
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}

// ─── Helper widgets ──────────────────────────────────────────────────────────

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

/// Bottom sheet that polls the backend until payment is confirmed or failed.
class _PaymentPollingSheet extends StatefulWidget {
  final String merchantRef;
  final String packageName;
  final ApiService apiService;
  final VoidCallback onCompleted;
  final VoidCallback onFailed;

  const _PaymentPollingSheet({
    required this.merchantRef,
    required this.packageName,
    required this.apiService,
    required this.onCompleted,
    required this.onFailed,
  });

  @override
  State<_PaymentPollingSheet> createState() => _PaymentPollingSheetState();
}

class _PaymentPollingSheetState extends State<_PaymentPollingSheet> {
  Timer? _timer;
  int _attempts = 0;
  static const _maxAttempts = 36; // 3 min at 5s intervals
  String _statusMessage = 'Waiting for payment confirmation...';

  @override
  void initState() {
    super.initState();
    // Start polling after 5 seconds (give user time to complete payment)
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
        setState(() => _statusMessage = 'Taking longer than expected. Tap "Check Now" to retry.');
      }
      return;
    }

    final result = await widget.apiService.checkPaymentStatus(widget.merchantRef);
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
          const CircularProgressIndicator(color: AppColors.success),
          const SizedBox(height: 20),
          Text(
            'Complete Payment in Browser',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.text,
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
                    setState(() => _statusMessage = 'Checking payment status...');
                    _poll();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
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

