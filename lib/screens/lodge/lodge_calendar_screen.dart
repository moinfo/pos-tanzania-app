import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import 'lodge_booking_detail_screen.dart';
import 'lodge_new_booking_screen.dart';

/// `GET lodge/calendar?month=` -- README 3.9. Rooms down the left (frozen),
/// days of the month across the top (shared horizontal scroll so every
/// room's row stays lined up with the date header).
class LodgeCalendarScreen extends StatefulWidget {
  const LodgeCalendarScreen({super.key});

  @override
  State<LodgeCalendarScreen> createState() => _LodgeCalendarScreenState();
}

class _LodgeCalendarScreenState extends State<LodgeCalendarScreen> {
  static const double _dayWidth = 34;
  static const double _rowHeight = 44;
  static const double _labelWidth = 76;

  final ApiService _apiService = ApiService();
  final ScrollController _hController = ScrollController();

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  LodgeCalendar? _calendar;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hController.dispose();
    super.dispose();
  }

  String get _monthParam =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  int get _daysInMonth => DateTime(_month.year, _month.month + 1, 0).day;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response = await _apiService.getLodgeCalendar(month: _monthParam);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _calendar = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'checked_in':
        return AppColors.error;
      case 'checked_out':
        return Colors.grey;
      default:
        return AppColors.info; // reserved
    }
  }

  /// The calendar booking covering [room] on day [day], if any.
  LodgeCalendarBooking? _bookingOn(LodgeRoom room, int day) {
    final cal = _calendar;
    if (cal == null) return null;
    final date = DateTime(_month.year, _month.month, day);
    for (final b in cal.bookings) {
      if (b.roomId != room.roomId) continue;
      final from = DateTime.tryParse(b.from);
      final to = DateTime.tryParse(b.to);
      if (from == null || to == null) continue;
      if (!date.isBefore(from) && date.isBefore(to)) return b;
    }
    return null;
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
        title: const Text('Calendar'),
      ),
      floatingActionButton: permissions.hasPermission(PermissionIds.lodgeBookingsAdd)
          ? FloatingActionButton.extended(
              heroTag: 'lodge_calendar_fab',
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LodgeNewBookingScreen()),
                );
                if (created == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Booking'),
              backgroundColor: AppColors.brandPrimary,
            )
          : null,
      body: Column(
        children: [
          Container(
            color: isDark ? AppColors.darkCard : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                Text('${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),
          Container(
            color: isDark ? AppColors.darkCard : Colors.white,
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                _legendDot('Reserved', AppColors.info, isDark),
                _legendDot('Checked in', AppColors.error, isDark),
                _legendDot('Checked out', Colors.grey, isDark),
                Text('Tap a free day to book it',
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
              ],
            ),
          ),
          Expanded(child: _buildGrid(isDark)),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
      ],
    );
  }

  Widget _buildGrid(bool isDark) {
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

    final cal = _calendar;
    if (cal == null || cal.rooms.isEmpty) {
      return Center(
          child: Text('No rooms',
              style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)));
    }

    final days = List<int>.generate(_daysInMonth, (i) => i + 1);
    final borderColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    // A single horizontal scroller holds the date header AND every room's
    // day cells stacked in one Column, so there is exactly one ScrollController
    // to keep in sync -- not one per row. The label column sits outside it,
    // and the whole thing (labels + grid) shares one outer vertical scroll so
    // both stay lined up without a second controller to coordinate.
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(width: _labelWidth, height: 28),
              Divider(height: 1, color: borderColor),
              ...cal.rooms.map((room) => Container(
                    width: _labelWidth,
                    height: _rowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                    child: Text(room.roomNumber,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: isDark ? AppColors.darkText : AppColors.lightText)),
                  )),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _hController,
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  Row(
                    children: days
                        .map((d) => Container(
                              width: _dayWidth,
                              height: 28,
                              alignment: Alignment.center,
                              child: Text('$d',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
                            ))
                        .toList(),
                  ),
                  Divider(height: 1, color: borderColor),
                  ...cal.rooms.map((room) => Container(
                        height: _rowHeight,
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                        child: Row(
                          children: days.map((d) {
                            final booking = _bookingOn(room, d);
                            final color = booking != null ? _statusColor(booking.status) : null;
                            final canBookEmptyDay = booking == null &&
                                context.read<PermissionProvider>().hasPermission(PermissionIds.lodgeBookingsAdd);
                            return GestureDetector(
                              onTap: booking != null
                                  ? () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                LodgeBookingDetailScreen(bookingId: booking.bookingId)),
                                      );
                                      _load();
                                    }
                                  : (canBookEmptyDay
                                      ? () async {
                                          final created = await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => LodgeNewBookingScreen(
                                                initialRoomId: room.roomId,
                                                initialCheckInDate:
                                                    '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
                                              ),
                                            ),
                                          );
                                          if (created == true) _load();
                                        }
                                      : null),
                              child: Container(
                                width: _dayWidth,
                                height: _rowHeight - 1,
                                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0.5),
                                decoration: BoxDecoration(
                                  color: color?.withOpacity(isDark ? 0.45 : 0.25),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
