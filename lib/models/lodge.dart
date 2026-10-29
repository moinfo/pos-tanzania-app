// Lodge/Guesthouse module: rooms, bookings, ledger, payments, dashboard.
//
// Backend: application/controllers/api/Lodge.php, routes `api/lodge/*`.
// Full endpoint/permission reference: LODGE_API.md. Module/permission
// structure: LODGE_MODULE.md. Mobile screen-by-screen spec:
// LODGE_MOBILE_README.md (all three live in the PointOfSalesTanzania repo).
//
// Server computes every balance/night figure (LodgeLedger) -- these models
// only parse and display it, never recompute it client-side.

double _toDouble(dynamic v, {double fallback = 0.0}) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? fallback;
}

int _toInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

bool _toBool(dynamic v) => v == true || v == 1 || v == '1';

class LodgeLocation {
  final int locationId;
  final String locationName;

  LodgeLocation({required this.locationId, required this.locationName});

  factory LodgeLocation.fromJson(Map<String, dynamic> json) {
    return LodgeLocation(
      locationId: _toInt(json['location_id']),
      locationName: json['location_name']?.toString() ?? '',
    );
  }
}

/// `GET lodge/meta` -- loaded once after login (and whenever the app
/// resumes) and re-read before trusting any permission-gated UI, same
/// contract as the main app's PermissionProvider.
class LodgeMeta {
  final Map<String, bool> permissions;
  final List<LodgeLocation> locations;
  final List<String> paymentTypes;
  final String creditPaymentType;
  final List<String> maintenanceCategories;
  final String dateFormat;
  final String currencySymbol;
  final String today;

  LodgeMeta({
    required this.permissions,
    required this.locations,
    required this.paymentTypes,
    required this.creditPaymentType,
    required this.maintenanceCategories,
    required this.dateFormat,
    required this.currencySymbol,
    required this.today,
  });

  bool has(String permissionId) => permissions[permissionId] == true;

  factory LodgeMeta.fromJson(Map<String, dynamic> json) {
    final permsJson = json['permissions'] as Map<String, dynamic>? ?? {};
    return LodgeMeta(
      permissions: permsJson.map((k, v) => MapEntry(k, _toBool(v))),
      locations: (json['locations'] as List<dynamic>? ?? [])
          .map((l) => LodgeLocation.fromJson(l as Map<String, dynamic>))
          .toList(),
      paymentTypes: (json['payment_types'] as List<dynamic>? ?? [])
          .map((p) => p.toString())
          .toList(),
      creditPaymentType: json['credit_payment_type']?.toString() ?? 'Credit',
      maintenanceCategories:
          (json['maintenance_categories'] as List<dynamic>? ?? [])
              .map((c) => c.toString())
              .toList(),
      dateFormat: json['date_format']?.toString() ?? 'Y-m-d',
      currencySymbol: json['currency_symbol']?.toString() ?? '',
      today: json['today']?.toString() ?? '',
    );
  }
}

/// Per-night balance/occupancy math for a booking. Always comes FROM the
/// server (on the booking, the dashboard room card, the statement) -- never
/// recomputed client-side. See Lodge_booking::ledger on the backend.
class LodgeLedger {
  final double rate;
  final int plannedNights;
  final double plannedTotal;
  final int nightsSoFar;
  final double charged;
  final double paid;
  final double balanceNow;
  final double balancePlanned;
  final int nightsPaid;
  final int nightsUnpaid;
  final String? paidThrough;
  final bool overstay;

  LodgeLedger({
    required this.rate,
    required this.plannedNights,
    required this.plannedTotal,
    required this.nightsSoFar,
    required this.charged,
    required this.paid,
    required this.balanceNow,
    required this.balancePlanned,
    required this.nightsPaid,
    required this.nightsUnpaid,
    this.paidThrough,
    required this.overstay,
  });

  factory LodgeLedger.fromJson(Map<String, dynamic> json) {
    return LodgeLedger(
      rate: _toDouble(json['rate']),
      plannedNights: _toInt(json['planned_nights']),
      plannedTotal: _toDouble(json['planned_total']),
      nightsSoFar: _toInt(json['nights_so_far']),
      charged: _toDouble(json['charged']),
      paid: _toDouble(json['paid']),
      balanceNow: _toDouble(json['balance_now']),
      balancePlanned: _toDouble(json['balance_planned']),
      nightsPaid: _toInt(json['nights_paid']),
      nightsUnpaid: _toInt(json['nights_unpaid']),
      paidThrough: json['paid_through']?.toString(),
      overstay: _toBool(json['overstay']),
    );
  }
}

class LodgeRoom {
  final int roomId;
  final int locationId;
  final String roomNumber;
  final String? roomType;
  final double rate;
  final String status; // vacant | occupied | cleaning | maintenance
  final String? statusLabel;
  final String purpose; // guest | staff | office
  final String? occupant;
  final bool forSale;
  final String? lastMaintenance;
  final LodgeBooking? currentBooking;

  LodgeRoom({
    required this.roomId,
    required this.locationId,
    required this.roomNumber,
    this.roomType,
    required this.rate,
    required this.status,
    this.statusLabel,
    required this.purpose,
    this.occupant,
    required this.forSale,
    this.lastMaintenance,
    this.currentBooking,
  });

  bool get isGuestRoom => purpose == 'guest';

  factory LodgeRoom.fromJson(Map<String, dynamic> json) {
    return LodgeRoom(
      roomId: _toInt(json['room_id']),
      locationId: _toInt(json['location_id']),
      roomNumber: json['room_number']?.toString() ?? '',
      roomType: json['room_type']?.toString(),
      rate: _toDouble(json['rate']),
      status: json['status']?.toString() ?? 'vacant',
      statusLabel: json['status_label']?.toString(),
      purpose: json['purpose']?.toString() ?? 'guest',
      occupant: json['occupant']?.toString(),
      forSale: json['for_sale'] == null ? true : _toBool(json['for_sale']),
      lastMaintenance: json['last_maintenance']?.toString(),
      currentBooking: json['current_booking'] is Map
          ? LodgeBooking.fromJson(
              Map<String, dynamic>.from(json['current_booking']))
          : null,
    );
  }
}

class LodgeBooking {
  final int bookingId;
  final int roomId;
  final String? roomNumber;
  final String guestName;
  final String? guestPhone;
  final String? guestIdNumber;
  final int numGuests;
  final int? customerId;
  final bool? creditAllowed;
  final String checkInDate;
  final String checkOutDate;
  final double ratePerNight;
  final double totalAmount;
  final double amountPaid;
  final double balance;
  final String status; // reserved | checked_in | checked_out | cancelled | no_show
  final int? saleId;
  final String? receiptUrl;
  final String? notes;
  final LodgeLedger? ledger;
  final List<LodgePayment> payments;

  LodgeBooking({
    required this.bookingId,
    required this.roomId,
    this.roomNumber,
    required this.guestName,
    this.guestPhone,
    this.guestIdNumber,
    required this.numGuests,
    this.customerId,
    this.creditAllowed,
    required this.checkInDate,
    required this.checkOutDate,
    required this.ratePerNight,
    required this.totalAmount,
    required this.amountPaid,
    required this.balance,
    required this.status,
    this.saleId,
    this.receiptUrl,
    this.notes,
    this.ledger,
    this.payments = const [],
  });

  bool get hasBalance => balance > 0.009;

  factory LodgeBooking.fromJson(Map<String, dynamic> json) {
    return LodgeBooking(
      bookingId: _toInt(json['booking_id']),
      roomId: _toInt(json['room_id']),
      roomNumber: json['room_number']?.toString(),
      guestName: json['guest_name']?.toString() ?? '',
      guestPhone: json['guest_phone']?.toString(),
      guestIdNumber: json['guest_id_number']?.toString(),
      numGuests: _toInt(json['num_guests'], fallback: 1),
      customerId: _toIntOrNull(json['customer_id']),
      creditAllowed:
          json['credit_allowed'] == null ? null : _toBool(json['credit_allowed']),
      checkInDate: json['check_in_date']?.toString() ?? '',
      checkOutDate: json['check_out_date']?.toString() ?? '',
      ratePerNight: _toDouble(json['rate_per_night']),
      totalAmount: _toDouble(json['total_amount']),
      amountPaid: _toDouble(json['amount_paid']),
      balance: _toDouble(json['balance']),
      status: json['status']?.toString() ?? 'reserved',
      saleId: _toIntOrNull(json['sale_id']),
      receiptUrl: json['receipt_url']?.toString(),
      notes: json['notes']?.toString(),
      ledger: json['ledger'] is Map
          ? LodgeLedger.fromJson(Map<String, dynamic>.from(json['ledger']))
          : null,
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map((p) => LodgePayment.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
    );
  }
}

class LodgePayment {
  final int paymentId;
  final int bookingId;
  final double amount;
  final int? nights;
  final String paymentType;
  final bool isCredit;
  final String paymentTime;
  final String? note;
  final String? receivedByName;
  final bool editable;

  LodgePayment({
    required this.paymentId,
    required this.bookingId,
    required this.amount,
    this.nights,
    required this.paymentType,
    required this.isCredit,
    required this.paymentTime,
    this.note,
    this.receivedByName,
    required this.editable,
  });

  factory LodgePayment.fromJson(Map<String, dynamic> json) {
    return LodgePayment(
      paymentId: _toInt(json['payment_id']),
      bookingId: _toInt(json['booking_id']),
      amount: _toDouble(json['amount']),
      nights: _toIntOrNull(json['nights']),
      paymentType: json['payment_type']?.toString() ?? '',
      isCredit: _toBool(json['is_credit']),
      paymentTime: json['payment_time']?.toString() ?? '',
      note: json['note']?.toString(),
      receivedByName: json['received_by_name']?.toString(),
      editable: json['editable'] == null ? true : _toBool(json['editable']),
    );
  }
}

class LodgeRoomCounts {
  final int total;
  final int vacant;
  final int occupied;
  final int cleaning;
  final int maintenance;

  LodgeRoomCounts({
    required this.total,
    required this.vacant,
    required this.occupied,
    required this.cleaning,
    required this.maintenance,
  });

  factory LodgeRoomCounts.fromJson(Map<String, dynamic> json) {
    return LodgeRoomCounts(
      total: _toInt(json['total']),
      vacant: _toInt(json['vacant']),
      occupied: _toInt(json['occupied']),
      cleaning: _toInt(json['cleaning']),
      maintenance: _toInt(json['maintenance']),
    );
  }
}

class LodgeDashboardStats {
  final int arrivals;
  final int departures;
  final double revenueToday;
  final double outstanding;

  LodgeDashboardStats({
    required this.arrivals,
    required this.departures,
    required this.revenueToday,
    required this.outstanding,
  });

  factory LodgeDashboardStats.fromJson(Map<String, dynamic> json) {
    return LodgeDashboardStats(
      arrivals: _toInt(json['arrivals']),
      departures: _toInt(json['departures']),
      revenueToday: _toDouble(json['revenue_today']),
      outstanding: _toDouble(json['outstanding']),
    );
  }
}

/// `GET lodge/dashboard` -- the Lodge Board/home screen.
class LodgeDashboard {
  final LodgeRoomCounts roomCounts;
  final LodgeDashboardStats stats;
  final List<LodgeRoom> rooms;
  final List<LodgeBooking> arrivals;
  final List<LodgeBooking> departures;

  LodgeDashboard({
    required this.roomCounts,
    required this.stats,
    required this.rooms,
    required this.arrivals,
    required this.departures,
  });

  factory LodgeDashboard.fromJson(Map<String, dynamic> json) {
    return LodgeDashboard(
      roomCounts: LodgeRoomCounts.fromJson(
          Map<String, dynamic>.from(json['room_counts'] ?? {})),
      stats: LodgeDashboardStats.fromJson(
          Map<String, dynamic>.from(json['stats'] ?? {})),
      rooms: (json['rooms'] as List<dynamic>? ?? [])
          .map((r) => LodgeRoom.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      arrivals: (json['arrivals'] as List<dynamic>? ?? [])
          .map((b) => LodgeBooking.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
      departures: (json['departures'] as List<dynamic>? ?? [])
          .map((b) => LodgeBooking.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
    );
  }
}

class LodgeStatementRow {
  final String date;
  final String type; // charge | payment | credit
  final double? charge;
  final double? payment;
  final double balance;
  final bool future;

  LodgeStatementRow({
    required this.date,
    required this.type,
    this.charge,
    this.payment,
    required this.balance,
    required this.future,
  });

  factory LodgeStatementRow.fromJson(Map<String, dynamic> json) {
    return LodgeStatementRow(
      date: json['date']?.toString() ?? '',
      type: json['type']?.toString() ?? 'charge',
      charge: json['charge'] == null ? null : _toDouble(json['charge']),
      payment: json['payment'] == null ? null : _toDouble(json['payment']),
      balance: _toDouble(json['balance']),
      future: _toBool(json['future']),
    );
  }
}

class LodgeStatement {
  final LodgeBooking booking;
  final LodgeLedger ledger;
  final List<LodgeStatementRow> rows;
  final List<LodgePayment> payments;

  LodgeStatement({
    required this.booking,
    required this.ledger,
    required this.rows,
    required this.payments,
  });

  factory LodgeStatement.fromJson(Map<String, dynamic> json) {
    return LodgeStatement(
      booking:
          LodgeBooking.fromJson(Map<String, dynamic>.from(json['booking'])),
      ledger:
          LodgeLedger.fromJson(Map<String, dynamic>.from(json['ledger'])),
      rows: (json['rows'] as List<dynamic>? ?? [])
          .map((r) => LodgeStatementRow.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map((p) => LodgePayment.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
    );
  }
}

/// `GET lodge/customers/suggest?term=` -- customer autocomplete for the new
/// booking form.
class LodgeCustomerSuggestion {
  final int value; // person_id
  final String label;

  LodgeCustomerSuggestion({required this.value, required this.label});

  factory LodgeCustomerSuggestion.fromJson(Map<String, dynamic> json) {
    return LodgeCustomerSuggestion(
      value: _toInt(json['value']),
      label: json['label']?.toString() ?? '',
    );
  }
}

/// Checkout result -- `POST bookings/{id}/checkout`.
class LodgeCheckoutResult {
  final LodgeBooking booking;
  final int saleId;
  final String? receiptUrl;
  final double creditAmount;

  LodgeCheckoutResult({
    required this.booking,
    required this.saleId,
    this.receiptUrl,
    required this.creditAmount,
  });

  factory LodgeCheckoutResult.fromJson(Map<String, dynamic> json) {
    return LodgeCheckoutResult(
      booking:
          LodgeBooking.fromJson(Map<String, dynamic>.from(json['booking'])),
      saleId: _toInt(json['sale_id']),
      receiptUrl: json['receipt_url']?.toString(),
      creditAmount: _toDouble(json['credit_amount']),
    );
  }
}

/// `GET lodge/bookings` (list/filter) result.
class LodgeBookingsList {
  final int total;
  final List<LodgeBooking> bookings;

  LodgeBookingsList({required this.total, required this.bookings});

  factory LodgeBookingsList.fromJson(Map<String, dynamic> json) {
    return LodgeBookingsList(
      total: _toInt(json['total']),
      bookings: (json['bookings'] as List<dynamic>? ?? [])
          .map((b) => LodgeBooking.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
    );
  }
}

/// A booking bar on the Calendar -- deliberately separate from [LodgeBooking]
/// since the calendar endpoint sends `from`/`to` (the slice of the stay that
/// falls inside the requested month), not the booking's full date range.
class LodgeCalendarBooking {
  final int bookingId;
  final int roomId;
  final String guestName;
  final String from;
  final String to;
  final String status;

  LodgeCalendarBooking({
    required this.bookingId,
    required this.roomId,
    required this.guestName,
    required this.from,
    required this.to,
    required this.status,
  });

  factory LodgeCalendarBooking.fromJson(Map<String, dynamic> json) {
    return LodgeCalendarBooking(
      bookingId: _toInt(json['booking_id']),
      roomId: _toInt(json['room_id']),
      guestName: json['guest_name']?.toString() ?? '',
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      status: json['status']?.toString() ?? 'reserved',
    );
  }
}

/// `GET lodge/calendar?month=YYYY-MM` -- guest rooms only.
class LodgeCalendar {
  final List<LodgeRoom> rooms;
  final List<LodgeCalendarBooking> bookings;

  LodgeCalendar({required this.rooms, required this.bookings});

  factory LodgeCalendar.fromJson(Map<String, dynamic> json) {
    return LodgeCalendar(
      rooms: (json['rooms'] as List<dynamic>? ?? [])
          .map((r) => LodgeRoom.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      bookings: (json['bookings'] as List<dynamic>? ?? [])
          .map((b) => LodgeCalendarBooking.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
    );
  }
}

class LodgePaymentsByType {
  final Map<String, double> byType;
  final List<LodgePayment> payments;

  LodgePaymentsByType({required this.byType, required this.payments});

  factory LodgePaymentsByType.fromJson(Map<String, dynamic> json) {
    final byTypeJson = json['by_type'] as Map<String, dynamic>? ?? {};
    return LodgePaymentsByType(
      byType: byTypeJson.map((k, v) => MapEntry(k, _toDouble(v))),
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map((p) => LodgePayment.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
    );
  }
}

/// A row on the Guests register -- aggregated across a guest's bookings
/// (`guest_key`, not a customer account id; `customer_id` is set only when
/// linked to one).
class LodgeGuest {
  final String guestKey;
  final String name;
  final String? phone;
  final int stays;
  final double spent;
  final double balance;
  final String? lastStay;
  final int? customerId;

  LodgeGuest({
    required this.guestKey,
    required this.name,
    this.phone,
    required this.stays,
    required this.spent,
    required this.balance,
    this.lastStay,
    this.customerId,
  });

  factory LodgeGuest.fromJson(Map<String, dynamic> json) {
    return LodgeGuest(
      guestKey: json['guest_key']?.toString() ?? '',
      name: json['guest_name']?.toString() ?? json['name']?.toString() ?? '',
      phone: json['guest_phone']?.toString() ?? json['phone']?.toString(),
      stays: _toInt(json['stays']),
      spent: _toDouble(json['spent']),
      balance: _toDouble(json['balance']),
      lastStay: json['last_stay']?.toString(),
      customerId: _toIntOrNull(json['customer_id']),
    );
  }
}

class LodgeExpenseCategory {
  final int id;
  final String name;

  LodgeExpenseCategory({required this.id, required this.name});

  factory LodgeExpenseCategory.fromJson(Map<String, dynamic> json) {
    return LodgeExpenseCategory(
      id: _toInt(json['id'] ?? json['expense_category_id']),
      name: json['name']?.toString() ?? '',
    );
  }
}

class LodgeExpense {
  final int expenseId;
  final String date;
  final double amount;
  final String paymentType;
  final String? categoryName;
  final String description;
  final String? roomNumber;

  LodgeExpense({
    required this.expenseId,
    required this.date,
    required this.amount,
    required this.paymentType,
    this.categoryName,
    required this.description,
    this.roomNumber,
  });

  factory LodgeExpense.fromJson(Map<String, dynamic> json) {
    return LodgeExpense(
      expenseId: _toInt(json['expense_id']),
      date: json['date']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      paymentType: json['payment_type']?.toString() ?? '',
      categoryName: json['category_name']?.toString(),
      description: json['description']?.toString() ?? '',
      roomNumber: json['room_number']?.toString(),
    );
  }
}

class LodgeExpensesList {
  final double total;
  final List<LodgeExpense> expenses;

  LodgeExpensesList({required this.total, required this.expenses});

  factory LodgeExpensesList.fromJson(Map<String, dynamic> json) {
    return LodgeExpensesList(
      total: _toDouble(json['total']),
      expenses: (json['expenses'] as List<dynamic>? ?? [])
          .map((e) => LodgeExpense.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// `GET/POST lodge/day-close` -- README 3.15.
class LodgeDayCloseFigures {
  final double openingCash;
  final double cashIn;
  final double lipaIn;
  final double bankIn;
  final double creditIn;
  final double cashExpenses;
  final double banked;
  final double cashSubmitted;
  final double closingCash;

  LodgeDayCloseFigures({
    required this.openingCash,
    required this.cashIn,
    required this.lipaIn,
    required this.bankIn,
    required this.creditIn,
    required this.cashExpenses,
    required this.banked,
    required this.cashSubmitted,
    required this.closingCash,
  });

  factory LodgeDayCloseFigures.fromJson(Map<String, dynamic> json) {
    return LodgeDayCloseFigures(
      openingCash: _toDouble(json['opening_cash']),
      cashIn: _toDouble(json['cash_in']),
      lipaIn: _toDouble(json['lipa_in']),
      bankIn: _toDouble(json['bank_in']),
      creditIn: _toDouble(json['credit_in']),
      cashExpenses: _toDouble(json['cash_expenses']),
      banked: _toDouble(json['banked']),
      cashSubmitted: _toDouble(json['cash_submitted']),
      closingCash: _toDouble(json['closing_cash']),
    );
  }
}

class LodgeDayCloseRecent {
  final String date;
  final double closingCash;
  final bool closed;

  LodgeDayCloseRecent({required this.date, required this.closingCash, required this.closed});

  factory LodgeDayCloseRecent.fromJson(Map<String, dynamic> json) {
    return LodgeDayCloseRecent(
      date: json['date']?.toString() ?? '',
      closingCash: _toDouble(json['closing_cash']),
      closed: _toBool(json['closed']),
    );
  }
}

class LodgeDayClose {
  final bool closed;
  final LodgeDayCloseFigures figures;
  final List<LodgePayment> payments;
  final List<LodgeExpense> expenses;
  final List<LodgeDayCloseRecent> recent;
  final bool canPickDate;
  final bool canEditClose;
  final List<dynamic> bossReport;

  LodgeDayClose({
    required this.closed,
    required this.figures,
    required this.payments,
    required this.expenses,
    required this.recent,
    required this.canPickDate,
    required this.canEditClose,
    this.bossReport = const [],
  });

  factory LodgeDayClose.fromJson(Map<String, dynamic> json) {
    return LodgeDayClose(
      closed: _toBool(json['closed']),
      figures: LodgeDayCloseFigures.fromJson(Map<String, dynamic>.from(json['figures'] ?? {})),
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map((p) => LodgePayment.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      expenses: (json['expenses'] as List<dynamic>? ?? [])
          .map((e) => LodgeExpense.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      recent: (json['recent'] as List<dynamic>? ?? [])
          .map((r) => LodgeDayCloseRecent.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      canPickDate: _toBool(json['can_pick_date']),
      canEditClose: _toBool(json['can_edit_close']),
      bossReport: json['boss_report'] as List<dynamic>? ?? [],
    );
  }
}

/// `GET lodge/report` -- README 3.14.
class LodgeReportTotals {
  final double revenue;
  final double paid;
  final double balance;
  final int nightsSold;
  final double occupancyPct;
  final int bookings;
  final double expenses;
  final double net;
  final double maintenanceCost;

  LodgeReportTotals({
    required this.revenue,
    required this.paid,
    required this.balance,
    required this.nightsSold,
    required this.occupancyPct,
    required this.bookings,
    required this.expenses,
    required this.net,
    required this.maintenanceCost,
  });

  factory LodgeReportTotals.fromJson(Map<String, dynamic> json) {
    return LodgeReportTotals(
      revenue: _toDouble(json['revenue']),
      paid: _toDouble(json['paid']),
      balance: _toDouble(json['balance']),
      nightsSold: _toInt(json['nights_sold'] ?? json['room_nights']),
      occupancyPct: _toDouble(json['occupancy_pct']),
      bookings: _toInt(json['bookings']),
      expenses: _toDouble(json['expenses']),
      net: _toDouble(json['net']),
      maintenanceCost: _toDouble(json['maintenance_cost']),
    );
  }
}

class LodgeReportRoom {
  final int roomId;
  final String roomNumber;
  final int bookings;
  final int nightsSold;
  final double occupancyPct;
  final double revenue;
  final double paid;
  final double balance;
  final double maintenanceCost;

  LodgeReportRoom({
    required this.roomId,
    required this.roomNumber,
    required this.bookings,
    required this.nightsSold,
    required this.occupancyPct,
    required this.revenue,
    required this.paid,
    required this.balance,
    required this.maintenanceCost,
  });

  factory LodgeReportRoom.fromJson(Map<String, dynamic> json) {
    return LodgeReportRoom(
      roomId: _toInt(json['room_id']),
      roomNumber: json['room_number']?.toString() ?? '',
      bookings: _toInt(json['bookings']),
      nightsSold: _toInt(json['nights_sold']),
      occupancyPct: _toDouble(json['occupancy_pct']),
      revenue: _toDouble(json['revenue']),
      paid: _toDouble(json['paid']),
      balance: _toDouble(json['balance']),
      maintenanceCost: _toDouble(json['maintenance_cost']),
    );
  }
}

/// One row of the report's guest/booking list -- the web's "Guest list"
/// table is actually booking-level (#, guest, phone, room, check-in/out,
/// nights, total, paid, status), not the aggregated-across-stays LodgeGuest.
/// Parsed leniently since the exact backend key names aren't pinned down
/// in LODGE_API.md.
class LodgeReportGuestRow {
  final int? bookingId;
  final String guestName;
  final String? guestPhone;
  final String? roomNumber;
  final String? checkInDate;
  final String? checkOutDate;
  final int nights;
  final double total;
  final double paid;
  final String? status;

  LodgeReportGuestRow({
    this.bookingId,
    required this.guestName,
    this.guestPhone,
    this.roomNumber,
    this.checkInDate,
    this.checkOutDate,
    required this.nights,
    required this.total,
    required this.paid,
    this.status,
  });

  factory LodgeReportGuestRow.fromJson(Map<String, dynamic> json) {
    return LodgeReportGuestRow(
      bookingId: _toIntOrNull(json['booking_id']),
      guestName: json['guest_name']?.toString() ?? json['name']?.toString() ?? '',
      guestPhone: json['guest_phone']?.toString() ?? json['phone']?.toString(),
      roomNumber: json['room_number']?.toString(),
      checkInDate: json['check_in_date']?.toString(),
      checkOutDate: json['check_out_date']?.toString(),
      nights: _toInt(json['nights']),
      total: _toDouble(json['total'] ?? json['total_amount'] ?? json['spent']),
      paid: _toDouble(json['paid'] ?? json['amount_paid']),
      status: json['status']?.toString(),
    );
  }
}

class LodgeReport {
  final LodgeReportTotals totals;
  final List<LodgeReportRoom> rooms;
  final List<LodgeReportGuestRow> guests;

  LodgeReport({required this.totals, required this.rooms, required this.guests});

  factory LodgeReport.fromJson(Map<String, dynamic> json) {
    return LodgeReport(
      totals: LodgeReportTotals.fromJson(Map<String, dynamic>.from(json['totals'] ?? {})),
      rooms: (json['rooms'] as List<dynamic>? ?? [])
          .map((r) => LodgeReportRoom.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      guests: (json['guests'] as List<dynamic>? ?? [])
          .map((g) => LodgeReportGuestRow.fromJson(Map<String, dynamic>.from(g)))
          .toList(),
    );
  }
}

/// `GET lodge/forecast` -- README 3.16.
class LodgeForecastRoom {
  final int roomId;
  final String roomNumber;
  final double rate;
  final double day;
  final double month;
  final double year;
  final double actualOccupancy;

  LodgeForecastRoom({
    required this.roomId,
    required this.roomNumber,
    required this.rate,
    required this.day,
    required this.month,
    required this.year,
    required this.actualOccupancy,
  });

  factory LodgeForecastRoom.fromJson(Map<String, dynamic> json) {
    return LodgeForecastRoom(
      roomId: _toInt(json['room_id']),
      roomNumber: json['room_number']?.toString() ?? '',
      rate: _toDouble(json['rate']),
      day: _toDouble(json['day']),
      month: _toDouble(json['month']),
      year: _toDouble(json['year']),
      actualOccupancy: _toDouble(json['actual_occupancy']),
    );
  }
}

class LodgeForecastScenario {
  final String label;
  final double occupancy;
  final double day;
  final double month;
  final double year;
  final double netMonth;
  final double netYear;

  LodgeForecastScenario({
    required this.label,
    required this.occupancy,
    required this.day,
    required this.month,
    required this.year,
    required this.netMonth,
    required this.netYear,
  });

  factory LodgeForecastScenario.fromJson(Map<String, dynamic> json) {
    return LodgeForecastScenario(
      label: json['label']?.toString() ?? '',
      occupancy: _toDouble(json['occupancy']),
      day: _toDouble(json['day']),
      month: _toDouble(json['month']),
      year: _toDouble(json['year']),
      netMonth: _toDouble(json['net_month']),
      netYear: _toDouble(json['net_year']),
    );
  }
}

class LodgeForecast {
  final List<LodgeForecastRoom> rooms;
  final double totalDay;
  final double totalMonth;
  final double totalYear;
  final double fullCapacity;
  final double expensesMonth;
  final double netMonth;
  final double netYear;
  final double actualOccupancy;
  final List<LodgeForecastScenario> scenarios;

  LodgeForecast({
    required this.rooms,
    required this.totalDay,
    required this.totalMonth,
    required this.totalYear,
    required this.fullCapacity,
    required this.expensesMonth,
    required this.netMonth,
    required this.netYear,
    required this.actualOccupancy,
    required this.scenarios,
  });

  factory LodgeForecast.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? {};
    return LodgeForecast(
      rooms: (json['rooms'] as List<dynamic>? ?? [])
          .map((r) => LodgeForecastRoom.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      totalDay: _toDouble(totals['day']),
      totalMonth: _toDouble(totals['month']),
      totalYear: _toDouble(totals['year']),
      fullCapacity: _toDouble(json['full_capacity']),
      expensesMonth: _toDouble(json['expenses_month']),
      netMonth: _toDouble(json['net_month']),
      netYear: _toDouble(json['net_year']),
      actualOccupancy: _toDouble(json['actual_occupancy']),
      scenarios: (json['scenarios'] as List<dynamic>? ?? [])
          .map((s) => LodgeForecastScenario.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }
}

/// `GET/POST lodge/messages/settings` -- README 3.17.
class LodgeMessageEvent {
  final String event;
  final String label;
  final bool enabled;
  final String template;
  final String defaultTemplate;
  final String? cron;

  LodgeMessageEvent({
    required this.event,
    required this.label,
    required this.enabled,
    required this.template,
    required this.defaultTemplate,
    this.cron,
  });

  factory LodgeMessageEvent.fromJson(Map<String, dynamic> json) {
    return LodgeMessageEvent(
      event: json['event']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      enabled: _toBool(json['enabled']),
      template: json['template']?.toString() ?? '',
      defaultTemplate: json['default_template']?.toString() ?? '',
      cron: json['cron']?.toString(),
    );
  }
}

class LodgeBossPhone {
  final String name;
  final String phone;

  LodgeBossPhone({required this.name, required this.phone});

  factory LodgeBossPhone.fromJson(Map<String, dynamic> json) {
    return LodgeBossPhone(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
}

class LodgeBossSettings {
  final bool enabled;
  final List<LodgeBossPhone> phones;
  final String template;

  LodgeBossSettings({required this.enabled, required this.phones, required this.template});

  factory LodgeBossSettings.fromJson(Map<String, dynamic> json) {
    return LodgeBossSettings(
      enabled: _toBool(json['enabled']),
      phones: (json['phones'] as List<dynamic>? ?? [])
          .map((p) => LodgeBossPhone.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      template: json['template']?.toString() ?? '',
    );
  }
}

class LodgeMessagesStatus {
  final bool linked;
  final double? balance;
  final bool whatsappReady;

  LodgeMessagesStatus({required this.linked, this.balance, required this.whatsappReady});

  factory LodgeMessagesStatus.fromJson(Map<String, dynamic> json) {
    return LodgeMessagesStatus(
      linked: _toBool(json['linked']),
      balance: json['balance'] == null ? null : _toDouble(json['balance']),
      whatsappReady: _toBool(json['whatsapp_ready']),
    );
  }
}

class LodgeMessagesSettings {
  final bool enabled;
  final String channel;
  final String smsName;
  final List<LodgeMessageEvent> events;
  final LodgeBossSettings boss;
  final LodgeMessagesStatus status;
  final bool canEdit;

  LodgeMessagesSettings({
    required this.enabled,
    required this.channel,
    required this.smsName,
    required this.events,
    required this.boss,
    required this.status,
    required this.canEdit,
  });

  factory LodgeMessagesSettings.fromJson(Map<String, dynamic> json) {
    return LodgeMessagesSettings(
      enabled: _toBool(json['enabled']),
      channel: json['channel']?.toString() ?? 'sms',
      smsName: json['sms_name']?.toString() ?? '',
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => LodgeMessageEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      boss: LodgeBossSettings.fromJson(Map<String, dynamic>.from(json['boss'] ?? {})),
      status: LodgeMessagesStatus.fromJson(Map<String, dynamic>.from(json['status'] ?? {})),
      canEdit: json['can_edit'] == null ? true : _toBool(json['can_edit']),
    );
  }
}

class LodgeMessageLogEntry {
  final String event;
  final String channel;
  final String? phone;
  final String status;
  final String? response;
  final String? message;
  final String createdAt;

  LodgeMessageLogEntry({
    required this.event,
    required this.channel,
    this.phone,
    required this.status,
    this.response,
    this.message,
    required this.createdAt,
  });

  factory LodgeMessageLogEntry.fromJson(Map<String, dynamic> json) {
    return LodgeMessageLogEntry(
      event: json['event']?.toString() ?? '',
      channel: json['channel']?.toString() ?? '',
      phone: json['phone']?.toString(),
      status: json['status']?.toString() ?? '',
      response: json['response']?.toString(),
      message: json['message']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

/// `GET/POST lodge/rooms/{id}/maintenance` -- README 3.10.
class LodgeMaintenance {
  final int maintenanceId;
  final String? doneOn;
  final String? category;
  final String description;
  final String? doneBy;
  final double cost;
  final int? expenseId;

  LodgeMaintenance({
    required this.maintenanceId,
    this.doneOn,
    this.category,
    required this.description,
    this.doneBy,
    required this.cost,
    this.expenseId,
  });

  factory LodgeMaintenance.fromJson(Map<String, dynamic> json) {
    return LodgeMaintenance(
      maintenanceId: _toInt(json['maintenance_id'] ?? json['id']),
      doneOn: json['done_on']?.toString(),
      category: json['category']?.toString(),
      description: json['description']?.toString() ?? '',
      doneBy: json['done_by']?.toString(),
      cost: _toDouble(json['cost']),
      expenseId: _toIntOrNull(json['expense_id']),
    );
  }
}
