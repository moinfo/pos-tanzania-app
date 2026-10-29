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
        itemBuilder: (_, i) {
          final b = _bookings[i];
          return Card(
            color: isDark ? AppColors.darkCard : Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            ),
            elevation: 0,
            child: ListTile(
              leading: LodgeArchIcon(text: _initials(b.guestName), width: 38, height: 44),
              title: Text(b.guestName, style: LodgeTheme.body(size: 14.5, weight: FontWeight.w700)),
              subtitle: Text('Room ${b.roomNumber ?? '-'} · '
                  '${Formatters.formatDate(b.checkInDate)} → ${Formatters.formatDate(b.checkOutDate)} · '
                  '${b.ledger?.plannedNights ?? ''} night(s)\n'
                  'Total ${Formatters.formatCompactCurrency(b.totalAmount)} · Paid ${Formatters.formatCompactCurrency(b.amountPaid)}'),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (b.hasBalance)
                    Text(Formatters.formatCompactCurrency(b.balance),
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  _statusBadge(b.status),
                ],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LodgeBookingDetailScreen(bookingId: b.bookingId)),
                );
                _load();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _statusBadge(String status) {
    final labels = {
      'reserved': 'Reserved',
      'checked_in': 'Checked in',
      'checked_out': 'Checked out',
      'cancelled': 'Cancelled',
    };
    if (status == 'checked_in') {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: LodgeStatusBadge(label: 'Checked in'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(labels[status] ?? status, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
