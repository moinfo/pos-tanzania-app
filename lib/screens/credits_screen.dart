import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/credit.dart';
import '../widgets/credit/credit_list_widgets.dart';
import '../models/stock_location.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/glassmorphic_card.dart';
import '../utils/constants.dart';
import 'customer_credit_screen.dart';
import 'daily_debt_report_screen.dart';

/// Credits Screen - Shows list of supervisors with their credit balances
/// Similar to web /credits page
class CreditsScreen extends StatefulWidget {
  /// True when the screen is a bottom-nav tab rather than a pushed route.
  ///
  /// MainNavigation already supplies the app bar (with the store switcher) and
  /// the bottom navigation, so an embedded instance must not draw its own or
  /// the user sees two of each.
  final bool embedded;

  const CreditsScreen({super.key, this.embedded = false});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _formatter = NumberFormat('#,###');

  SupervisorCreditsResponse? _creditsData;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  /// Balance filter chips (design_handoff_home_credit 3.4): all / open / settled.
  String _balanceFilter = 'all';

  /// Sort toggle behind the 3.5 header button.
  bool _sortByBalance = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndLoad();
    });
  }

  Future<void> _initializeAndLoad() async {
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.initialize(moduleId: 'sales');
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Get location IDs from location provider
    final locationProvider = context.read<LocationProvider>();
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    List<int>? locationIds;
    if (isLeruma && locationProvider.selectedLocation != null) {
      // For Leruma: filter by selected location only
      locationIds = [locationProvider.selectedLocation!.locationId];
    } else if (locationProvider.allowedLocations.isNotEmpty) {
      // Fall back to every location the user is granted
      locationIds = locationProvider.allowedLocations
          .map((loc) => loc.locationId)
          .toList();
    }

    // A null locationIds means "no filter", i.e. every supervisor in the
    // company. Never do that for Leruma: if no location resolved, the seller
    // simply has none, and showing everything would leak other supervisors.
    if (isLeruma && (locationIds == null || locationIds.isEmpty)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No stock location assigned to your account';
      });
      return;
    }

    final response = await _apiService.getSupervisorCredits(
      locationIds: locationIds,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _creditsData = response.data;
        } else {
          _errorMessage = response.message ?? 'Failed to load credits';
        }
      });
    }
  }

  List<SupervisorCredit> get _filteredSupervisors {
    if (_creditsData == null) return [];
    if (_searchQuery.isEmpty) return _creditsData!.supervisors;

    final query = _searchQuery.toLowerCase();
    return _creditsData!.supervisors.where((s) {
      return s.name.toLowerCase().contains(query) ||
          s.phone.toLowerCase().contains(query);
    }).toList();
  }

  /// 3.4/3.5: search, then the balance chip, then the sort toggle.
  List<SupervisorCredit> get _lerumaSupervisors {
    final list = [..._filteredSupervisors];

    if (_balanceFilter == 'open') {
      list.removeWhere((s) => s.balance <= 0);
    } else if (_balanceFilter == 'settled') {
      list.removeWhere((s) => s.balance > 0);
    }

    list.sort((a, b) => _sortByBalance
        ? b.balance.compareTo(a.balance)
        : a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return list;
  }

  /// Initials for the row avatar.
  ///
  /// Non-letter tokens are skipped, so "Mija (sembe) Mapinga" gives MM and not
  /// "M(" -- bracketed nicknames are common in these customer names.
  static String _initials(String name) {
    final letters = name
        .split(RegExp(r'[\s]+'))
        .map((word) => word.replaceAll(RegExp(r'[^A-Za-z]'), ''))
        .where((word) => word.isNotEmpty)
        .toList();

    if (letters.isEmpty) return '?';
    if (letters.length == 1) return letters.first[0].toUpperCase();
    return (letters.first[0] + letters.last[0]).toUpperCase();
  }

  void _viewSupervisorCustomers(SupervisorCredit supervisor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupervisorCustomersScreen(
          supervisorId: supervisor.supervisorId,
          supervisorName: supervisor.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
        title: const Text('Customer Credits'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Location selector - Leruma only
          if (isLeruma && locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PopupMenuButton<StockLocation>(
                  offset: const Offset(0, 40),
                  color: Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          locationProvider.selectedLocation!.locationName,
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
                    ],
                  ),
                  onSelected: (location) async {
                    await locationProvider.selectLocation(location);
                    _loadCredits();
                  },
                  itemBuilder: (context) => locationProvider.allowedLocations
                      .map((location) => PopupMenuItem<StockLocation>(
                            value: location,
                            child: Row(
                              children: [
                                Icon(
                                  location.locationId == locationProvider.selectedLocation?.locationId
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: location.locationId == locationProvider.selectedLocation?.locationId
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  location.locationName,
                                  style: TextStyle(
                                    color: location.locationId == locationProvider.selectedLocation?.locationId
                                        ? AppColors.primary
                                        : Colors.black87,
                                    fontWeight: location.locationId == locationProvider.selectedLocation?.locationId
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCredits,
            tooltip: 'Refresh',
          ),
        ],
      ),
      bottomNavigationBar:
          widget.embedded ? null : const AppBottomNavigation(currentIndex: -1),
      body: isLeruma
          ? _buildLerumaBody()
          : Container(
        color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
        child: Column(
          children: [
            // Summary Card with glassmorphic design
            if (_creditsData != null && !_isLoading)
              _buildSummaryCard(isDark),

            // Daily Debt Report Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassmorphicCard(
                isDark: isDark,
                borderRadius: 12,
                padding: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DailyDebtReportScreen()),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.payments, color: AppColors.success, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Debt Collection',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                'View all debt payments received',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GlassmorphicCard(
                isDark: isDark,
                borderRadius: 12,
                padding: EdgeInsets.zero,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search supervisor or phone...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ),

            // Results count
            if (_creditsData != null && !_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.supervisor_account, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${_filteredSupervisors.length} supervisors',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Supervisors List
            Expanded(
              child: _isLoading
                  ? _buildSkeletonList(isDark)
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _filteredSupervisors.isEmpty
                          ? _buildEmptyView()
                          : _buildSupervisorsList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Leruma credit & debt list (design_handoff_home_credit, screen 3).
  //
  // Leruma only: the glassmorphic cards below are what every other client ships
  // and this handoff does not cover them.
  // ---------------------------------------------------------------------------

  Widget _buildLerumaBody() {
    final supervisors = _lerumaSupervisors;

    return Container(
      color: const Color(0xFFF2F5F9),
      child: RefreshIndicator(
        onRefresh: _loadCredits,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          children: [
            if (_creditsData != null && !_isLoading) ...[
              CreditTotalsCard(
                balance: _creditsData!.summary.totalBalance,
                credit: _creditsData!.summary.totalCredit,
                paid: _creditsData!.summary.totalDebit,
                openAccounts: _creditsData!.supervisors
                    .where((s) => s.balance > 0)
                    .length,
              ),
              const SizedBox(height: 12),
            ],
            _buildLerumaCollectionCard(),
            const SizedBox(height: 12),
            CreditSearchField(
              controller: _searchController,
              hintText: 'Search supervisor or phone',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 10),
            CreditFilterChips(
              selected: _balanceFilter,
              onChanged: (value) => setState(() => _balanceFilter = value),
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildErrorView()
            else ...[
              CreditListHeader(
                label: '${supervisors.length} SUPERVISORS',
                sortByBalance: _sortByBalance,
                onToggleSort: () =>
                    setState(() => _sortByBalance = !_sortByBalance),
              ),
              const SizedBox(height: 10),
              if (supervisors.isEmpty)
                const CreditEmptyResult(
                    message: 'No match for that name or phone')
              else
                for (final supervisor in supervisors) ...[
                  CreditRowCard(
                    name: supervisor.name,
                    phone: supervisor.phone,
                    credit: supervisor.credit,
                    paid: supervisor.debit,
                    balance: supervisor.balance,
                    ctaLabel: 'Customers',
                    onTap: () => _viewSupervisorCustomers(supervisor),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }

  /// 3.3 Daily debt collection card.
  ///
  /// The design puts today's collected amount on the right. There is no field
  /// for it on the supervisor-credits response, so the chevron stands alone
  /// rather than showing a number that is not the one the label promises.
  Widget _buildLerumaCollectionCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DailyDebtReportScreen()),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: creditCardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F6EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.payments,
                    size: 20, color: Color(0xFF12833C)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily debt collection',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF103863),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'All debt payments received today',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5C6675),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: Color(0xFF9AA5B4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final summary = _creditsData!.summary;

    return Container(
      margin: const EdgeInsets.all(16),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 16,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Credit',
                    _formatter.format(summary.totalCredit),
                    AppColors.error,
                    Icons.arrow_upward,
                    isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Paid',
                    _formatter.format(summary.totalDebit),
                    AppColors.success,
                    Icons.arrow_downward,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (summary.totalBalance > 0 ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: summary.totalBalance > 0 ? AppColors.error : AppColors.success,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Total Balance',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatter.format(summary.totalBalance),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: summary.totalBalance > 0 ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, IconData icon, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSupervisorsList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadCredits,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredSupervisors.length,
        itemBuilder: (context, index) {
          final supervisor = _filteredSupervisors[index];
          return _buildSupervisorCard(supervisor, isDark, index + 1);
        },
      ),
    );
  }

  Widget _buildSupervisorCard(SupervisorCredit supervisor, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 14,
        child: InkWell(
          onTap: () => _viewSupervisorCustomers(supervisor),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supervisor.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (supervisor.phone.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.phone, size: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  supervisor.phone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatColumn('Credit', supervisor.credit, AppColors.error, isDark),
                      ),
                      Container(
                        width: 1,
                        height: 35,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildStatColumn('Paid', supervisor.debit, AppColors.success, isDark),
                      ),
                      Container(
                        width: 1,
                        height: 35,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildStatColumn('Balance', supervisor.balance,
                          supervisor.balance > 0 ? AppColors.error : AppColors.success, isDark, isBold: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, double value, Color color, bool isDark, {bool isBold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _formatter.format(value),
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: GlassmorphicCard(
          isDark: isDark,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  SkeletonLoader(width: 44, height: 44, borderRadius: 12, isDark: isDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(width: 140, height: 16, isDark: isDark),
                        const SizedBox(height: 6),
                        SkeletonLoader(width: 100, height: 12, isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SkeletonLoader(width: double.infinity, height: 50, borderRadius: 10, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadCredits,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No supervisors with credit balance'
                : 'No results found for "$_searchQuery"',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Screen to show customers under a specific supervisor
class SupervisorCustomersScreen extends StatefulWidget {
  final int supervisorId;
  final String supervisorName;

  const SupervisorCustomersScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<SupervisorCustomersScreen> createState() => _SupervisorCustomersScreenState();
}

class _SupervisorCustomersScreenState extends State<SupervisorCustomersScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _formatter = NumberFormat('#,###');

  SupervisorCustomersResponse? _customersData;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _balanceFilter = 'all';
  bool _sortByBalance = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 3.4/3.5: search, then the balance chip, then the sort toggle.
  List<CustomerCredit> get _lerumaCustomers {
    final list = [..._filteredCustomers];

    if (_balanceFilter == 'open') {
      list.removeWhere((c) => c.balance <= 0);
    } else if (_balanceFilter == 'settled') {
      list.removeWhere((c) => c.balance > 0);
    }

    list.sort((a, b) => _sortByBalance
        ? b.balance.compareTo(a.balance)
        : a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

    return list;
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getSupervisorCustomers(widget.supervisorId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _customersData = response.data;
        } else {
          _errorMessage = response.message ?? 'Failed to load customers';
        }
      });
    }
  }

  List<CustomerCredit> get _filteredCustomers {
    if (_customersData == null) return [];
    if (_searchQuery.isEmpty) return _customersData!.customers;

    final query = _searchQuery.toLowerCase();
    return _customersData!.customers.where((c) {
      return c.fullName.toLowerCase().contains(query) ||
          c.phone.toLowerCase().contains(query);
    }).toList();
  }

  void _viewCustomerCredit(CustomerCredit customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerCreditScreen(
          customerId: customer.customerId,
          customerName: customer.fullName,
          customerPhone: customer.phone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    if (ApiService.currentClient?.id == 'leruma') return _buildLerumaScreen();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supervisorName),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
      body: Container(
        color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
        child: Column(
          children: [
            // Summary Card
            if (_customersData != null && !_isLoading)
              _buildSummaryCard(isDark),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GlassmorphicCard(
                isDark: isDark,
                borderRadius: 12,
                padding: EdgeInsets.zero,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search customer or phone...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ),

            // Results count
            if (_customersData != null && !_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.people, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${_filteredCustomers.length} customers',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Customers List
            Expanded(
              child: _isLoading
                  ? _buildSkeletonList(isDark)
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _filteredCustomers.isEmpty
                          ? _buildEmptyView()
                          : _buildCustomersList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  /// Customer level of screen 3: same layout as the supervisor list, with the
  /// SUPERVISOR kicker in the app bar and a Statement CTA on each row.
  Widget _buildLerumaScreen() {
    final customers = _lerumaCustomers;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SUPERVISOR',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Colors.white70,
              ),
            ),
            Text(
              widget.supervisorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCustomers,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          children: [
            if (_customersData != null && !_isLoading) ...[
              CreditTotalsCard(
                balance: _customersData!.summary.totalBalance,
                credit: _customersData!.summary.totalCredit,
                paid: _customersData!.summary.totalDebit,
                openAccounts: _customersData!.customers
                    .where((c) => c.balance > 0)
                    .length,
              ),
              const SizedBox(height: 12),
            ],
            CreditSearchField(
              controller: _searchController,
              hintText: 'Search customer or phone',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 10),
            CreditFilterChips(
              selected: _balanceFilter,
              onChanged: (value) => setState(() => _balanceFilter = value),
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildErrorView()
            else ...[
              CreditListHeader(
                label: '${customers.length} CUSTOMERS',
                sortByBalance: _sortByBalance,
                onToggleSort: () =>
                    setState(() => _sortByBalance = !_sortByBalance),
              ),
              const SizedBox(height: 10),
              if (customers.isEmpty)
                const CreditEmptyResult(
                    message: 'No match for that name or phone')
              else
                for (final customer in customers) ...[
                  CreditRowCard(
                    name: customer.fullName,
                    phone: customer.phone,
                    credit: customer.credit,
                    paid: customer.debit,
                    balance: customer.balance,
                    ctaLabel: 'Statement',
                    onTap: () => _viewCustomerCredit(customer),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final summary = _customersData!.summary;

    return Container(
      margin: const EdgeInsets.all(16),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 16,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Credit',
                    _formatter.format(summary.totalCredit),
                    AppColors.error,
                    Icons.arrow_upward,
                    isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Paid',
                    _formatter.format(summary.totalDebit),
                    AppColors.success,
                    Icons.arrow_downward,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (summary.totalBalance > 0 ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: summary.totalBalance > 0 ? AppColors.error : AppColors.success,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Total Balance',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatter.format(summary.totalBalance),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: summary.totalBalance > 0 ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, IconData icon, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomersList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadCustomers,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredCustomers.length,
        itemBuilder: (context, index) {
          final customer = _filteredCustomers[index];
          return _buildCustomerCard(customer, isDark, index + 1);
        },
      ),
    );
  }

  Widget _buildCustomerCard(CustomerCredit customer, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 14,
        child: InkWell(
          onTap: () => _viewCustomerCredit(customer),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.secondary, AppColors.secondary.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          customer.firstName.isNotEmpty
                              ? customer.firstName[0].toUpperCase()
                              : '$index',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.fullName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (customer.phone.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.phone, size: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  customer.phone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatColumn('Credit', customer.credit, AppColors.error, isDark),
                      ),
                      Container(
                        width: 1,
                        height: 35,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildStatColumn('Paid', customer.debit, AppColors.success, isDark),
                      ),
                      Container(
                        width: 1,
                        height: 35,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildStatColumn('Balance', customer.balance,
                          customer.balance > 0 ? AppColors.error : AppColors.success, isDark, isBold: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, double value, Color color, bool isDark, {bool isBold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _formatter.format(value),
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: GlassmorphicCard(
          isDark: isDark,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  SkeletonLoader(width: 44, height: 44, borderRadius: 12, isDark: isDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(width: 140, height: 16, isDark: isDark),
                        const SizedBox(height: 6),
                        SkeletonLoader(width: 100, height: 12, isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SkeletonLoader(width: double.infinity, height: 50, borderRadius: 10, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadCustomers,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No customers with credit balance'
                : 'No results found for "$_searchQuery"',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
