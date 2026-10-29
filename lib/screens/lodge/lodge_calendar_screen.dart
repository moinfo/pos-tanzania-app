import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import 'lodge_booking_detail_screen.dart';
import 'lodge_new_booking_screen.dart';
import 'lodge_theme.dart';

/// `GET lodge/calendar?month=` -- README 3.9. Rooms down the left (frozen),
/// days of the month across the top (shared horizontal scroll so every
/// room's row stays lined up with the date header).
class LodgeCalendarScreen extends StatefulWidget {
  const LodgeCalendarScreen({super.key});

  @override
  State<LodgeCalendarScreen> createState() => _LodgeCalendarScreenState();
}

class _LodgeCalendarScreenState extends State<LodgeCalendarScreen> {
  static const double _dayWidth = 40;
  static const double _rowHeight = 52;
  static const double _labelWidth = 92;
  static const double _dayHeaderHeight = 34;

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

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

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
        return AppColors.warning;
      case 'checked_out':
        return AppColors.lightTextLight;
      default:
        return AppColors.brandPrimary; // reserved
    }
  }

  /// First letter of each word in the guest's name, max two -- "Amina
  /// Hassan" -> "AH", "mohamed" -> "M". Keeps the cell readable without the
  /// full name, which rarely fits a day-wide column.
  String _initials(String guestName) {
    final parts = guestName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
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

  /// True for the first day a booking appears in this room's row -- that
  /// cell carries the guest's initials; the rest of the stay reads as a
  /// continuous bar of color, the way a calendar bar normally communicates
  /// a span rather than repeating a label on every day.
  bool _isBookingStart(LodgeRoom room, int day, LodgeCalendarBooking booking) {
    if (day == 1) return true;
    final previous = _bookingOn(room, day - 1);
    return previous?.bookingId != booking.bookingId;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: LodgeTheme.appBar(
        isDark: isDark,
        eyebrow: 'Availability',
        title: 'Calendar',
        showStars: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_month),
                  style: LodgeTheme.body(size: 15, weight: FontWeight.w700, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
        ),
      ),
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
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _legendDot('Reserved', AppColors.brandPrimary, isDark),
                      _legendDot('Checked in', AppColors.warning, isDark),
                      _legendDot('Checked out', AppColors.lightTextLight, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Icon(Icons.touch_app_outlined,
                    size: 14, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight),
                const SizedBox(width: 5),
                Text('Tap a free day to start a booking',
                    style: LodgeTheme.body(
                        size: 11.5,
                        color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  _buildGrid(isDark),
                  const SizedBox(height: 14),
                  _buildTodayCard(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A plain-language itinerary for today, under the grid -- "who's in,
  /// which night of their stay, when they leave" -- answers the question
  /// the grid itself only shows as a coded bar.
  Widget _buildTodayCard(bool isDark) {
    final cal = _calendar;
    if (cal == null || !_isCurrentMonth) return const SizedBox.shrink();
    final today = DateTime.now().day;
    final todayStr = DateFormat('EEE d MMM').format(DateTime.now());

    final staying = <(LodgeRoom, LodgeCalendarBooking)>[];
    for (final room in cal.rooms) {
      final booking = _bookingOn(room, today);
      if (booking != null) staying.add((room, booking));
    }
    if (staying.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today · $todayStr',
              style: LodgeTheme.display(
                  size: 20, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.lightText)),
          const SizedBox(height: 12),
          for (int i = 0; i < staying.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              const SizedBox(height: 12),
            ],
            _todayRow(staying[i].$1, staying[i].$2, isDark),
          ],
        ],
      ),
    );
  }

  Widget _todayRow(LodgeRoom room, LodgeCalendarBooking booking, bool isDark) {
    final from = DateTime.tryParse(booking.from);
    final to = DateTime.tryParse(booking.to);
    final nightOf = from != null ? DateTime.now().difference(from).inDays + 1 : null;
    final totalNights = (from != null && to != null) ? to.difference(from).inDays : null;
    final leaves = to != null ? DateFormat('d MMM').format(to) : '-';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LodgeArchIcon(width: 40, height: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(booking.guestName,
                  style: LodgeTheme.body(
                      size: 15, weight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.lightText)),
              Text(room.roomNumber,
                  style: LodgeTheme.body(size: 13, color: isDark ? AppColors.darkText : AppColors.lightText)),
              Text(
                nightOf != null && totalNights != null
                    ? 'Night $nightOf of $totalNights · leaves $leaves'
                    : 'Leaves $leaves',
                style: LodgeTheme.body(
                    size: 13, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendDot(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: LodgeTheme.body(
                size: 12,
                weight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText)),
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
    final today = DateTime.now().day;
    final borderColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;

    // A single horizontal scroller holds the date header AND every room's
    // day cells stacked in one Column, so there is exactly one ScrollController
    // to keep in sync -- not one per row. The label column sits outside it,
    // and the whole thing (labels + grid) shares one outer vertical scroll so
    // both stay lined up without a second controller to coordinate.
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
              children: [
                SizedBox(width: _labelWidth, height: _dayHeaderHeight),
                Divider(height: 1, thickness: 1, color: borderColor),
                ...cal.rooms.map((room) => Container(
                      width: _labelWidth,
                      height: _rowHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(room.roomNumber,
                              style: LodgeTheme.display(
                                  weight: FontWeight.w700,
                                  size: 13.5,
                                  color: isDark ? AppColors.darkText : AppColors.lightText)),
                          if (room.roomType != null && room.roomType!.isNotEmpty)
                            Text(room.roomType!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LodgeTheme.body(
                                    size: 10.5,
                                    color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
                        ],
                      ),
                    )),
              ],
            ),
            VerticalDivider(width: 1, thickness: 1, color: borderColor),
            Expanded(
              child: SingleChildScrollView(
                controller: _hController,
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    Row(
                      children: days.map((d) {
                        final isToday = _isCurrentMonth && d == today;
                        return Container(
                          width: _dayWidth,
                          height: _dayHeaderHeight,
                          alignment: Alignment.center,
                          color: isToday ? AppColors.warning.withOpacity(isDark ? 0.18 : 0.12) : null,
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: isToday
                                ? const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle)
                                : null,
                            child: Text('$d',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                    color: isToday
                                        ? Colors.white
                                        : (isDark ? AppColors.darkTextLight : AppColors.lightTextLight))),
                          ),
                        );
                      }).toList(),
                    ),
                    Divider(height: 1, thickness: 1, color: borderColor),
                    ...cal.rooms.map((room) => Container(
                          height: _rowHeight,
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                          child: Row(
                            children: days.map((d) {
                              final booking = _bookingOn(room, d);
                              final isToday = _isCurrentMonth && d == today;
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
                                  color: isToday && booking == null
                                      ? AppColors.warning.withOpacity(isDark ? 0.1 : 0.06)
                                      : null,
                                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                                  child: booking == null
                                      ? null
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.horizontal(
                                              left: _isBookingStart(room, d, booking)
                                                  ? const Radius.circular(6)
                                                  : Radius.zero,
                                              right: Radius.circular(
                                                  _bookingOn(room, d + 1)?.bookingId == booking.bookingId
                                                      ? 0
                                                      : 6),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: _isBookingStart(room, d, booking)
                                              ? FittedBox(
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                                    child: Text(
                                                      _initials(booking.guestName),
                                                      style: TextStyle(
                                                          color: booking.status == 'checked_in'
                                                              ? AppColors.secondary
                                                              : Colors.white,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700),
                                                    ),
                                                  ),
                                                )
                                              : null,
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
