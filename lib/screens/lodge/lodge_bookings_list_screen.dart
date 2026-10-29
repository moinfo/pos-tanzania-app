import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'lodge_booking_detail_screen.dart';
import 'lodge_new_booking_screen.dart';
import 'lodge_theme.dart';

/// `GET lodge/bookings` -- README 3.2: status chips, search, optional date
/// range (gated on lodge_bookings_date_range_filter; without it the server
/// forces "this month").
class LodgeBookingsListScreen extends StatefulWidget {
  const LodgeBookingsListScreen({super.key});

  @override
  State<LodgeBookingsListScreen> createState() => _LodgeBookingsListScreenState();
}

class _LodgeBookingsListScreenState extends State<LodgeBookingsListScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();

  List<LodgeBooking> _bookings = [];
  int _total = 0;
  bool _isLoading = true;
  String? _errorMessage;
  String? _statusFilter; // null = Active (server default-ish), else comma list
  bool _withBalanceOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getLodgeBookings(
      status: _withBalanceOnly ? 'with_balance' : (_statusFilter ?? 'active'),
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _bookings = response.data!.bookings;
        _total = response.data!.total;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: LodgeTheme.appBar(isDark: isDark, eyebrow: 'Reservations', title: 'Bookings'),
      floatingActionButton: permissions.hasPermission(PermissionIds.lodgeBookingsAdd)
          ? LodgeFab(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LodgeNewBookingScreen()),
                );
                if (created == true) _load();
              },
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search name, phone, ID, room...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                _filterChip('Active', _statusFilter == null && !_withBalanceOnly, () {
                  setState(() {
                    _statusFilter = null;
                    _withBalanceOnly = false;
                  });
                  _load();
                }),
                _filterChip('Reserved', _statusFilter == 'reserved', () {
                  setState(() {
                    _statusFilter = 'reserved';
                    _withBalanceOnly = false;
                  });
                  _load();
                }),
                _filterChip('Checked in', _statusFilter == 'checked_in', () {
                  setState(() {
                    _statusFilter = 'checked_in';
                    _withBalanceOnly = false;
                  });
                  _load();
                }),
                _filterChip('Checked out', _statusFilter == 'checked_out', () {
                  setState(() {
                    _statusFilter = 'checked_out';
                    _withBalanceOnly = false;
                  });
                  _load();
                }),
                _filterChip('Cancelled', _statusFilter == 'cancelled', () {
                  setState(() {
                    _statusFilter = 'cancelled';
                    _withBalanceOnly = false;
                  });
                  _load();
                }),
                _filterChip('With balance', _withBalanceOnly, () {
                  setState(() => _withBalanceOnly = !_withBalanceOnly);
                  _load();
                }),
              ],
            ),
          ),
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Total: $_total',
                    style: LodgeTheme.body(
                        size: 12, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
              ),
            ),
          Expanded(child: _buildList(isDark)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }

  Widget _buildList(bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_bookings.isEmpty) {
      return Center(
        child: Text('No bookings',
            style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: _bookings.length,
        itemBuilder: (_, i) => _bookingCard(_bookings[i], isDark),
      ),
    );
  }

  /// Matches the mockup's booking card: a bell badge, name + status badge,
  /// room type, dates, a paid-percent progress bar, then Total/Paid/Balance
  /// as a 3-column grid -- a lot more information at a glance than a plain
  /// ListTile gave.
  Widget _bookingCard(LodgeBooking b, bool isDark) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextLight : AppColors.lightTextLight;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final nights = b.ledger?.plannedNights;
    final paidPct = b.totalAmount > 0 ? (b.amountPaid / b.totalAmount).clamp(0.0, 1.0) : 0.0;
    final labels = {
      'reserved': 'Reserved',
      'checked_in': 'Checked in',
      'checked_out': 'Checked out',
      'cancelled': 'Cancelled',
    };

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LodgeBookingDetailScreen(bookingId: b.bookingId)),
        );
        _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LodgeArchIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(b.guestName,
                                style: LodgeTheme.display(size: 20, weight: FontWeight.w700, color: textColor))),
                          if (b.status == 'checked_in')
                            const LodgeStatusBadge(label: 'Checked in')
                          else
                            Text(labels[b.status] ?? b.status,
                                style: LodgeTheme.body(size: 12, weight: FontWeight.w600, color: subColor)),
                        ],
                      ),
                      Text(b.roomNumber != null ? 'Room ${b.roomNumber}' : '-',
                          style: LodgeTheme.body(size: 13, weight: FontWeight.w600, color: textColor)),
                      Text(
                        '${Formatters.formatDate(b.checkInDate)} → ${Formatters.formatDate(b.checkOutDate)}'
                        '${nights != null ? ' · $nights night(s)' : ''}',
                        style: LodgeTheme.body(size: 13, color: subColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: paidPct,
                minHeight: 8,
                backgroundColor: dividerColor,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _moneyColumn('Total', Formatters.formatCompactCurrency(b.totalAmount), subColor)),
                Expanded(child: _moneyColumn('Paid', Formatters.formatCompactCurrency(b.amountPaid), subColor)),
                Expanded(
                  child: _moneyColumn('Balance', Formatters.formatCompactCurrency(b.balance), subColor,
                      valueColor: b.hasBalance ? const Color(0xFFB91C1C) : subColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyColumn(String label, String value, Color labelColor, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LodgeTheme.body(size: 12, color: labelColor)),
        Text(value,
            style: LodgeTheme.display(size: 18, weight: FontWeight.w700, color: valueColor ?? labelColor)),
      ],
    );
  }
}
