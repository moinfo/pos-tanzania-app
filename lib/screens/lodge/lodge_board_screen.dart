import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import 'lodge_report_screen.dart';
import 'lodge_theme.dart';

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
            ? 'Lodge is not enabled; turn it on in My Subscription (web) or buy e-Lodge.'
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: LodgeTheme.appBar(
        isDark: isDark,
        big: true,
        eyebrow: DateFormat('EEE d MMM yyyy').format(DateTime.now()),
        title: 'Lodge',
        actions: [
          if (_meta != null && _meta!.locations.length > 1)
            PopupMenuButton<int?>(
              icon: const Icon(Icons.location_on_outlined),
              tooltip: 'Branch',
              onSelected: (id) {
                setState(() => _locationId = id);
                _loadDashboard();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('All branches')),
                ..._meta!.locations.map((l) => PopupMenuItem(
                      value: l.locationId,
                      child: Text(l.locationName),
                    )),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDashboard(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      // No FAB here -- unlike Bookings/Calendar, Board's room cards each sit
      // right above the nav bar and already carry their own "Book"/"Pay"/
      // "Check out" buttons, so a floating "+ Booking" button just overlapped
      // whichever card happened to be at the bottom of the list.
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
              ElevatedButton(onPressed: _load, child: const Text('Try again')),
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
          _buildStatsStrip(dashboard, isDark, permissions),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rooms tonight',
                  style: LodgeTheme.display(
                      size: 19,
                      weight: FontWeight.w800,
                      color: isDark ? AppColors.darkText : AppColors.lightText)),
              if (permissions.hasPermission(PermissionIds.lodgeReports))
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LodgeReportScreen()),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Full report',
                          style: LodgeTheme.body(
                              size: 13, weight: FontWeight.w700, color: AppColors.brandPrimary)),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward, size: 14, color: AppColors.brandPrimary),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRoomList(dashboard, isDark, permissions),
          if (dashboard.arrivals.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildBookingList('Arriving', dashboard.arrivals, isDark,
                actionLabel: 'Check in',
                canAct: permissions.hasPermission(PermissionIds.lodgeCheckin),
                onAction: (b) => _checkin(b)),
          ],
          if (dashboard.departures.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildBookingList('Departing', dashboard.departures, isDark,
                actionLabel: 'Check out',
                canAct: permissions.hasPermission(PermissionIds.lodgeCheckout),
                onAction: (b) => _openBookingDetail(b.bookingId)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Revenue gets top billing -- a big hero row, not one tile the same size
  /// as "Vacant" -- then occupancy/arrivals/departures as one bordered strip
  /// with a divider between each number, matching the mockup's "Tonight"
  /// card exactly (Occupied alone picks up the amber-brown tint; the rest
  /// stay plain dark, since the room count isn't itself good or bad news).
  Widget _buildStatsStrip(LodgeDashboard d, bool isDark, PermissionProvider permissions) {
    final cs = _meta?.currencySymbol ?? 'TZS';
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final secondary = <_StatTile>[
      _StatTile('Occupied', '${d.roomCounts.occupied}', const Color(0xFF92400E)),
      _StatTile('Vacant', '${d.roomCounts.vacant}', textColor),
      _StatTile('Arriving', '${d.stats.arrivals}', textColor),
      _StatTile('Departing', '${d.stats.departures}', textColor),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _heroStat(
                "Today's revenue",
                Formatters.formatCurrency(d.stats.revenueToday),
                d.stats.revenueToday > 0 ? 'collected today' : 'no payments yet',
                textColor,
                cs,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _heroStat(
                'Outstanding',
                Formatters.formatCurrency(d.stats.outstanding),
                d.stats.outstanding > 0 ? 'to collect' : 'fully paid',
                d.stats.outstanding > 0 ? const Color(0xFFB91C1C) : textColor,
                cs,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dividerColor),
          ),
          child: Row(
            children: secondary
                .asMap()
                .entries
                .map((e) => Expanded(
                      child: Container(
                        decoration: e.key == 0
                            ? null
                            : BoxDecoration(border: Border(left: BorderSide(color: dividerColor))),
                        child: Column(
                          children: [
                            Text(e.value.value,
                                style: LodgeTheme.display(size: 30, weight: FontWeight.w700, color: e.value.color)),
                            const SizedBox(height: 2),
                            Text(e.value.label,
                                style: LodgeTheme.body(
                                    size: 12,
                                    color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _heroStat(
      String label, String value, String caption, Color valueColor, String currencySymbol, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: LodgeTheme.body(
                  size: 13, weight: FontWeight.w500, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
          Text(
            value,
            style: LodgeTheme.display(size: 32, weight: FontWeight.w700, color: valueColor, letterSpacing: -0.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text('$currencySymbol · $caption',
              style: LodgeTheme.body(
                  size: 12, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
        ],
      ),
    );
  }

  Widget _buildRoomList(
      LodgeDashboard d, bool isDark, PermissionProvider permissions) {
    if (d.rooms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('No rooms yet',
              style: TextStyle(
                  color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
        ),
      );
    }

    return Column(
      children: d.rooms
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildRoomCard(r, isDark, permissions),
              ))
          .toList(),
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
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextLight : AppColors.lightTextLight;

    // Two-column Pay/Check out (occupied), one wide action (reserved/
    // vacant), or nothing (a room nobody can act on) -- matches the
    // mockup's full-width button row under each room, not small chips.
    List<Widget> actions = [];
    if (!room.forSale) {
      actions = [];
    } else if (booking != null && booking.status == 'reserved') {
      final canCheckIn = today != null && booking.checkInDate.compareTo(today) <= 0;
      actions = [
        Expanded(
          child: canCheckIn && permissions.hasPermission(PermissionIds.lodgeCheckin)
              ? _wideButton('Check in', () => _checkin(booking), filled: true)
              : _wideButton('View', () => _openBookingDetail(booking.bookingId), filled: true),
        ),
      ];
    } else if (booking != null && booking.status == 'checked_in') {
      actions = [
        if (permissions.hasPermission(PermissionIds.lodgePaymentsAdd))
          Expanded(child: _wideButton('Pay', () => _openBookingDetail(booking.bookingId), filled: true)),
        if (permissions.hasPermission(PermissionIds.lodgePaymentsAdd) &&
            permissions.hasPermission(PermissionIds.lodgeCheckout))
          const SizedBox(width: 10),
        if (permissions.hasPermission(PermissionIds.lodgeCheckout))
          Expanded(
              child: _wideButton('Check out', () => _openBookingDetail(booking.bookingId), filled: false)),
      ];
    } else if (room.status == 'vacant' &&
        permissions.hasPermission(PermissionIds.lodgeBookingsAdd)) {
      actions = [Expanded(child: _wideButton('Book', () => _openNewBooking(roomId: room.roomId), filled: true))];
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: booking != null
          ? () => _openBookingDetail(booking.bookingId)
          : (room.forSale ? () => _showRoomSheet(room, permissions) : null),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LodgeArchIcon(
                  width: 48,
                  height: 56,
                  background: room.forSale ? AppColors.warning : AppColors.secondary,
                  foreground: room.forSale ? AppColors.secondary : Colors.white,
                  ringColor: room.status == 'occupied' ? const Color(0xFFFEF3C7) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(room.roomNumber,
                          style: LodgeTheme.display(size: 20, weight: FontWeight.w700, color: textColor)),
                      Text(
                        room.forSale
                            ? '${room.roomType ?? 'Room'} · ${_meta?.currencySymbol ?? ''} ${Formatters.formatCurrency(room.rate)} / night'
                            : (room.roomType ?? 'Staff / office'),
                        style: LodgeTheme.body(size: 13, color: subColor),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (booking != null)
                              Text(booking.guestName,
                                  style: LodgeTheme.body(size: 15, weight: FontWeight.w600, color: textColor)),
                            room.status == 'occupied'
                                ? const LodgeStatusBadge(label: 'Occupied')
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(isDark ? 0.25 : 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      room.forSale
                                          ? (room.statusLabel ?? room.status)
                                          : (room.occupant ?? 'Staff'),
                                      style: LodgeTheme.body(size: 11, color: color, weight: FontWeight.w600),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: actions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _wideButton(String label, VoidCallback onTap, {required bool filled}) {
    return SizedBox(
      height: 44,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(label, style: LodgeTheme.body(size: 14, weight: FontWeight.w700, color: Colors.white)),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.lightTextLight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(label, style: LodgeTheme.body(size: 14, weight: FontWeight.w700)),
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
            style: LodgeTheme.display(
                size: 17,
                weight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 8),
        ...bookings.map((b) => Card(
              color: isDark ? AppColors.darkCard : Colors.white,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text(b.guestName),
                subtitle: Text('Room ${b.roomNumber ?? '-'} · '
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
        content: Text('Check in ${booking.guestName}, room ${booking.roomNumber ?? ''}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
        SnackBar(content: Text('${booking.guestName} checked in.'), backgroundColor: AppColors.success),
      );
      _loadDashboard(showSpinner: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  /// Empty-room quick actions -- README's "Room sheet": mark vacant/cleaning/
  /// maintenance. (Statement/Extend/Move/Edit room/Add expense live on the
  /// booking itself or the Rooms tab; this sheet only covers what applies to
  /// a room with nobody currently in it.)
  Future<void> _showRoomSheet(LodgeRoom room, PermissionProvider permissions) async {
    if (!permissions.hasPermission(PermissionIds.lodgeRoomsStatus)) return;

    final status = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Room ${room.roomNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
              title: const Text('Mark vacant'),
              onTap: () => Navigator.pop(ctx, 'vacant'),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined, color: AppColors.info),
              title: const Text('Mark cleaning'),
              onTap: () => Navigator.pop(ctx, 'cleaning'),
            ),
            ListTile(
              leading: const Icon(Icons.build_outlined, color: Colors.grey),
              title: const Text('Mark maintenance'),
              onTap: () => Navigator.pop(ctx, 'maintenance'),
            ),
          ],
        ),
      ),
    );
    if (status == null) return;

    final response = await _apiService.setLodgeRoomStatus(roomId: room.roomId, status: status);
    if (!mounted) return;
    if (response.isSuccess) {
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

