import 'dart:async';
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

/// `GET lodge/guests` -- README 3.12: the guest register, aggregated across
/// bookings, with a "Book again" shortcut into a pre-filled new booking.
class LodgeGuestsScreen extends StatefulWidget {
  const LodgeGuestsScreen({super.key});

  @override
  State<LodgeGuestsScreen> createState() => _LodgeGuestsScreenState();
}

class _LodgeGuestsScreenState extends State<LodgeGuestsScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<LodgeGuest> _guests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response =
        await _apiService.getLodgeGuests(query: _searchController.text.trim());
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _guests = response.data!;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: LodgeTheme.appBar(isDark: isDark, eyebrow: 'Directory', title: 'Guests'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search guest...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_errorMessage!),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _load, child: const Text('Try again')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: _guests.length,
                          itemBuilder: (_, i) {
                            final g = _guests[i];
                            return Card(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                              ),
                              elevation: 0,
                              child: ListTile(
                                leading: LodgeArchIcon(
                                  text: _initials(g.name),
                                  width: 38,
                                  height: 44,
                                  background: AppColors.secondary,
                                  foreground: Colors.white,
                                ),
                                title: Text(g.name, style: LodgeTheme.display(size: 20, weight: FontWeight.w700)),
                                subtitle: Text('${g.stays} stay(s) · '
                                    'Spent ${Formatters.formatCompactCurrency(g.spent)}'
                                    '${g.lastStay != null ? ' · Last stay ${Formatters.formatDate(g.lastStay)}' : ''}'),
                                trailing: g.balance > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(999)),
                                        child: Text('Owes ${Formatters.formatCompactCurrency(g.balance)}',
                                            style: LodgeTheme.body(
                                                size: 12, weight: FontWeight.w600, color: const Color(0xFFB91C1C))),
                                      )
                                    : null,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => LodgeGuestHistoryScreen(guest: g)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class LodgeGuestHistoryScreen extends StatefulWidget {
  final LodgeGuest guest;

  const LodgeGuestHistoryScreen({super.key, required this.guest});

  @override
  State<LodgeGuestHistoryScreen> createState() => _LodgeGuestHistoryScreenState();
}

class _LodgeGuestHistoryScreenState extends State<LodgeGuestHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<LodgeBooking> _bookings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final response = await _apiService.getLodgeGuestHistory(widget.guest.guestKey);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _bookings = response.data!;
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
      appBar: LodgeTheme.appBar(isDark: isDark, eyebrow: 'Guest', title: widget.guest.name),
      floatingActionButton: permissions.hasPermission(PermissionIds.lodgeBookingsAdd)
          ? LodgeFab(
              icon: Icons.replay,
              label: 'Book again',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LodgeNewBookingScreen(
                    initialGuestName: widget.guest.name,
                    initialGuestPhone: widget.guest.phone,
                    initialCustomerId: widget.guest.customerId,
                  ),
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _bookings.length,
                  itemBuilder: (_, i) {
                    final b = _bookings[i];
                    return Card(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('Room ${b.roomNumber ?? '-'}'),
                        subtitle: Text(
                            '${Formatters.formatDate(b.checkInDate)} → ${Formatters.formatDate(b.checkOutDate)}'),
                        trailing: Text(Formatters.formatCompactCurrency(b.totalAmount)),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => LodgeBookingDetailScreen(bookingId: b.bookingId)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
