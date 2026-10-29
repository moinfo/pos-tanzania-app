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
