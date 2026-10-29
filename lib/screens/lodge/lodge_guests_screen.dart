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

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final headerColor = isDark ? AppColors.darkSurface : AppColors.brandPrimary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        title: const Text('Guests'),
      ),
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
                              child: ListTile(
                                title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${g.stays} stay(s) · '
                                    'Spent ${Formatters.formatCompactCurrency(g.spent)}'
                                    '${g.lastStay != null ? ' · Last stay ${Formatters.formatDate(g.lastStay)}' : ''}'),
                                trailing: g.balance > 0
                                    ? Text(Formatters.formatCompactCurrency(g.balance),
                                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))
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
    final headerColor = isDark ? AppColors.darkSurface : AppColors.brandPrimary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        title: Text(widget.guest.name),
      ),
      floatingActionButton: permissions.hasPermission(PermissionIds.lodgeBookingsAdd)
          ? FloatingActionButton.extended(
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
              icon: const Icon(Icons.replay),
              label: const Text('Book again'),
              backgroundColor: AppColors.brandPrimary,
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
