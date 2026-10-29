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

/// Lodge Board — `GET lodge/dashboard`. This is the module's home screen:
/// it is shown as the Home tab itself for a tenant subscribed to Lodge only
/// (no other retail modules), and pushed from the drawer's "Lodge" entry for
/// a tenant that has both. See LODGE_MOBILE_README.md section 3.1.
class LodgeBoardScreen extends StatefulWidget {
  const LodgeBoardScreen({super.key});

  @override
  State<LodgeBoardScreen> createState() => _LodgeBoardScreenState();
}

class _LodgeBoardScreenState extends State<LodgeBoardScreen> {
  final ApiService _apiService = ApiService();

  LodgeMeta? _meta;
  LodgeDashboard? _dashboard;
  int? _locationId;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Keep room/booking status current while a receptionist leaves the
    // screen open at the front desk, same cadence the README specifies.
    _autoRefreshTimer = Timer.periodic(
        const Duration(minutes: 2), (_) => _loadDashboard(showSpinner: false));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final metaResponse = await _apiService.getLodgeMeta();
    if (!mounted) return;

    if (!metaResponse.isSuccess || metaResponse.data == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = metaResponse.statusCode == 403
            ? 'Lodge haijawashwa; iwashe kwenye My Subscription (web) au nunua e-Lodge.'
            : metaResponse.message;
      });
      return;
    }

    setState(() => _meta = metaResponse.data);
    await _loadDashboard(showSpinner: false);
  }

  Future<void> _loadDashboard({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _isLoading = true);

    final response = await _apiService.getLodgeDashboard(locationId: _locationId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _dashboard = response.data;
        _errorMessage = null;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  void _openBookingDetail(int bookingId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => LodgeBookingDetailScreen(bookingId: bookingId)),
    );
    _loadDashboard(showSpinner: false);
  }

  void _openNewBooking({int? roomId, String? checkInDate}) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LodgeNewBookingScreen(
          initialRoomId: roomId,
          initialCheckInDate: checkInDate,
          locationId: _locationId,
        ),
      ),
    );
    if (created == true) _loadDashboard(showSpinner: false);
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
        elevation: 0,
        title: const Text('Lodge'),
        actions: [
          if (_meta != null && _meta!.locations.length > 1)
            PopupMenuButton<int?>(
              icon: const Icon(Icons.location_on_outlined),
              tooltip: 'Tawi',
              onSelected: (id) {
                setState(() => _locationId = id);
                _loadDashboard();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('Matawi yote')),
                ..._meta!.locations.map((l) => PopupMenuItem(
                      value: l.locationId,
                      child: Text(l.locationName),
                    )),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDashboard(),
            tooltip: 'Onyesha upya',
          ),
        ],
      ),
      floatingActionButton: permissions.hasPermission(PermissionIds.lodgeBookingsAdd)
          ? FloatingActionButton.extended(
              onPressed: () => _openNewBooking(),
              icon: const Icon(Icons.add),
              label: const Text('Booking'),
              backgroundColor: AppColors.brandPrimary,
            )
          : null,
      body: _buildBody(isDark, permissions),
    );
  }

  Widget _buildBody(bool isDark, PermissionProvider permissions) {
    if (_isLoading && _dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _dashboard == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hotel_outlined,
                  size: 48, color: isDark ? AppColors.darkTextLight : Colors.grey),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Jaribu tena')),
            ],
          ),
        ),
      );
    }

    final dashboard = _dashboard;
    if (dashboard == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () => _loadDashboard(showSpinner: false),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildStatsStrip(dashboard, isDark),
          const SizedBox(height: 16),
          Text('Vyumba',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText)),
          const SizedBox(height: 8),
          _buildRoomGrid(dashboard, isDark, permissions),
          if (dashboard.arrivals.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildBookingList('Wanaofika', dashboard.arrivals, isDark,
                actionLabel: 'Check in',
                canAct: permissions.hasPermission(PermissionIds.lodgeCheckin),
                onAction: (b) => _checkin(b)),
          ],
          if (dashboard.departures.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildBookingList('Wanaoondoka', dashboard.departures, isDark,
                actionLabel: 'Check out',
                canAct: permissions.hasPermission(PermissionIds.lodgeCheckout),
                onAction: (b) => _openBookingDetail(b.bookingId)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsStrip(LodgeDashboard d, bool isDark) {
    final cs = _meta?.currencySymbol ?? '';
    final tiles = <_StatTile>[
      _StatTile('Occupied', '${d.roomCounts.occupied}/${d.roomCounts.total}',
          AppColors.warning),
      _StatTile('Vacant', '${d.roomCounts.vacant}', AppColors.success),
      _StatTile('Arriving', '${d.stats.arrivals}', AppColors.info),
      _StatTile('Departing', '${d.stats.departures}', AppColors.info),
      _StatTile('Mapato leo',
          '$cs ${Formatters.formatCompactCurrency(d.stats.revenueToday)}',
          AppColors.success),
      _StatTile(
          'Deni',
          '$cs ${Formatters.formatCompactCurrency(d.stats.outstanding)}',
          d.stats.outstanding > 0 ? AppColors.error : AppColors.success),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tiles
          .map((t) => Container(
                width: 108,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.value,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: t.color)),
                    const SizedBox(height: 2),
                    Text(t.label,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildRoomGrid(
      LodgeDashboard d, bool isDark, PermissionProvider permissions) {
    if (d.rooms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Hakuna vyumba bado',
              style: TextStyle(
                  color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.35,
      ),
      itemCount: d.rooms.length,
      itemBuilder: (_, i) => _buildRoomCard(d.rooms[i], isDark, permissions),
    );
  }

  Color _statusColor(String status, bool forSale) {
    if (!forSale) return AppColors.secondary;
    switch (status) {
      case 'occupied':
        return AppColors.error;
      case 'cleaning':
        return AppColors.info;
      case 'maintenance':
        return Colors.grey;
      default:
        return AppColors.success;
    }
  }

  Widget _buildRoomCard(
      LodgeRoom room, bool isDark, PermissionProvider permissions) {
    final color = _statusColor(room.status, room.forSale);
    final booking = room.currentBooking;
    final today = _meta?.today;

    Widget? action;
    if (!room.forSale) {
      action = null;
    } else if (booking != null && booking.status == 'reserved') {
      final canCheckIn = today != null && booking.checkInDate.compareTo(today) <= 0;
      if (canCheckIn && permissions.hasPermission(PermissionIds.lodgeCheckin)) {
        action = _miniButton('Check in', () => _checkin(booking));
      } else {
        action = _miniButton('Angalia', () => _openBookingDetail(booking.bookingId));
      }
    } else if (booking != null && booking.status == 'checked_in') {
      action = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (permissions.hasPermission(PermissionIds.lodgePaymentsAdd))
            _miniButton('Lipa', () => _openBookingDetail(booking.bookingId)),
          const SizedBox(width: 6),
          if (permissions.hasPermission(PermissionIds.lodgeCheckout))
            _miniButton('Check out', () => _openBookingDetail(booking.bookingId)),
        ],
      );
    } else if (room.status == 'vacant' &&
        permissions.hasPermission(PermissionIds.lodgeBookingsAdd)) {
      action = _miniButton('Book', () => _openNewBooking(roomId: room.roomId));
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: booking != null
          ? () => _openBookingDetail(booking.bookingId)
          : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(room.roomNumber,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? AppColors.darkText : AppColors.lightText)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    room.forSale ? (room.statusLabel ?? room.status) : (room.occupant ?? 'Staff'),
                    style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (room.roomType != null && room.roomType!.isNotEmpty)
              Text(room.roomType!,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
            if (room.forSale)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${_meta?.currencySymbol ?? ''} ${Formatters.formatCurrency(room.rate)}/usiku',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight),
                ),
              ),
            if (booking != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(booking.guestName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText)),
              ),
            const Spacer(),
            if (action != null) action,
          ],
        ),
      ),
    );
  }

  Widget _miniButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 28,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 11.5),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildBookingList(
    String title,
    List<LodgeBooking> bookings,
    bool isDark, {
    required String actionLabel,
    required bool canAct,
    required void Function(LodgeBooking) onAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 8),
        ...bookings.map((b) => Card(
              color: isDark ? AppColors.darkCard : Colors.white,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text(b.guestName),
                subtitle: Text('Chumba ${b.roomNumber ?? '-'} · '
                    '${Formatters.formatDate(b.checkInDate)} → ${Formatters.formatDate(b.checkOutDate)}'),
                trailing: canAct
                    ? TextButton(
                        onPressed: () => onAction(b),
                        child: Text(actionLabel),
                      )
                    : null,
                onTap: () => _openBookingDetail(b.bookingId),
              ),
            )),
      ],
    );
  }

  Future<void> _checkin(LodgeBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Check in'),
        content: Text('Check in ${booking.guestName} chumba ${booking.roomNumber ?? ''}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Ghairi')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Check in')),
        ],
      ),
    );
    if (confirmed != true) return;

    final response = await _apiService.checkinLodgeBooking(booking.bookingId);
    if (!mounted) return;

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${booking.guestName} ameingia.'), backgroundColor: AppColors.success),
      );
      _loadDashboard(showSpinner: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }
}

class _StatTile {
  final String label;
  final String value;
  final Color color;
  _StatTile(this.label, this.value, this.color);
}
