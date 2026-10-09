// Industry module models: casual labourers, ZKTeco attendance, roller/mattress
// stock, machine production & wages (ARG Sparkles only)

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class LabourerReportRow {
  final int casualLabourerId;
  final String name;
  final int daysAttended;
  final double grossEarned;
  final double penalty;
  final double adjustment;
  final double amountEarned;

  LabourerReportRow({
    required this.casualLabourerId,
    required this.name,
    required this.daysAttended,
    required this.grossEarned,
    required this.penalty,
    required this.adjustment,
    required this.amountEarned,
  });

  factory LabourerReportRow.fromJson(Map<String, dynamic> json) {
    return LabourerReportRow(
      casualLabourerId: _parseInt(json['casual_labourer_id']),
      name: json['name']?.toString() ?? '',
      daysAttended: _parseInt(json['days_attended']),
      grossEarned: _parseDouble(json['gross_earned']),
      penalty: _parseDouble(json['penalty']),
      adjustment: _parseDouble(json['adjustment']),
      amountEarned: _parseDouble(json['amount_earned']),
    );
  }
}

class LabourerReportTotals {
  final int daysAttended;
  final double grossEarned;
  final double penalty;
  final double adjustment;
  final double amountEarned;

  LabourerReportTotals({
    required this.daysAttended,
    required this.grossEarned,
    required this.penalty,
    required this.adjustment,
    required this.amountEarned,
  });

  factory LabourerReportTotals.fromJson(Map<String, dynamic> json) {
    return LabourerReportTotals(
      daysAttended: _parseInt(json['days_attended']),
      grossEarned: _parseDouble(json['gross_earned']),
      penalty: _parseDouble(json['penalty']),
      adjustment: _parseDouble(json['adjustment']),
      amountEarned: _parseDouble(json['amount_earned']),
    );
  }

  factory LabourerReportTotals.empty() => LabourerReportTotals(
        daysAttended: 0,
        grossEarned: 0,
        penalty: 0,
        adjustment: 0,
        amountEarned: 0,
      );
}

class IndustryReport {
  final String startDate;
  final String endDate;
  final List<LabourerReportRow> labourers;
  final LabourerReportTotals labourersTotals;
  final Map<String, dynamic> wagesPaid;
  final Map<String, dynamic> roller;
  final Map<String, dynamic> mattress;
  final List<Map<String, dynamic>> production;

  IndustryReport({
    required this.startDate,
    required this.endDate,
    required this.labourers,
    required this.labourersTotals,
    required this.wagesPaid,
    required this.roller,
    required this.mattress,
    required this.production,
  });

  factory IndustryReport.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return IndustryReport(
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      labourers: (data['labourers'] as List? ?? [])
          .map((e) => LabourerReportRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      labourersTotals: data['labourers_totals'] != null
          ? LabourerReportTotals.fromJson(
              data['labourers_totals'] as Map<String, dynamic>)
          : LabourerReportTotals.empty(),
      wagesPaid: (data['wages_paid'] as Map<String, dynamic>?) ?? {},
      roller: (data['roller'] as Map<String, dynamic>?) ?? {},
      mattress: (data['mattress'] as Map<String, dynamic>?) ?? {},
      production: ((data['production'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

class IndustryDashboard {
  final String date;
  final Map<String, dynamic> week;
  final Map<String, dynamic> data;

  IndustryDashboard({
    required this.date,
    required this.week,
    required this.data,
  });

  factory IndustryDashboard.fromJson(Map<String, dynamic> json) {
    return IndustryDashboard(
      date: json['date']?.toString() ?? '',
      week: (json['week'] as Map<String, dynamic>?) ?? {},
      data: (json['data'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class AttendanceRosterEntry {
  final int casualLabourerId;
  final String name;
  final String? phoneNumber;
  final bool present;
  final String? clockIn;
  final String? clockOut;
  final bool late;
  final double penalty;
  final String? hoursDisplay;
  final int minutesLate;
  final double gross;
  final double net;
  final double adjustmentAmount;
  final String? adjustmentNote;

  AttendanceRosterEntry({
    required this.casualLabourerId,
    required this.name,
    this.phoneNumber,
    required this.present,
    this.clockIn,
    this.clockOut,
    required this.late,
    required this.penalty,
    this.hoursDisplay,
    this.minutesLate = 0,
    this.gross = 0,
    this.net = 0,
    this.adjustmentAmount = 0,
    this.adjustmentNote,
  });

  /// Field names match Attendance_policy::evaluate() +
  /// Casual_labourer_attendance::get_roster_for_date()'s merged output:
  /// time_in/time_out, hours_worked/hours_display, minutes_late, gross,
  /// penalty, net, adjustment_amount/adjustment_note.
  factory AttendanceRosterEntry.fromJson(Map<String, dynamic> json) {
    return AttendanceRosterEntry(
      casualLabourerId: _parseInt(json['casual_labourer_id']),
      name: json['name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString(),
      present: json['present'] == true || json['present'] == 1 || json['present'] == '1',
      clockIn: json['time_in']?.toString() ?? json['clock_in']?.toString(),
      clockOut: json['time_out']?.toString() ?? json['clock_out']?.toString(),
      late: _parseInt(json['minutes_late']) > 0,
      penalty: _parseDouble(json['penalty']),
      hoursDisplay: json['hours_display']?.toString(),
      minutesLate: _parseInt(json['minutes_late']),
      gross: _parseDouble(json['gross']),
      net: _parseDouble(json['net']),
      adjustmentAmount: _parseDouble(json['adjustment_amount']),
      adjustmentNote: json['adjustment_note']?.toString(),
    );
  }
}

/// Zk_punch::search_punches(): zk_punches.* (punch_id, device_ip,
/// device_user_id, punch_time, work_date, casual_labourer_id, synced_date)
/// plus the joined casual_labourers.name AS labourer_name.
class AttendanceLogRow {
  final int id;
  final String deviceIp;
  final String deviceUserId;
  final String? punchTime;
  final String? workDate;
  final String? syncedDate;
  final String? labourerName;
  final bool mapped;

  AttendanceLogRow({
    required this.id,
    required this.deviceIp,
    required this.deviceUserId,
    this.punchTime,
    this.workDate,
    this.syncedDate,
    this.labourerName,
    required this.mapped,
  });

  factory AttendanceLogRow.fromJson(Map<String, dynamic> json) {
    return AttendanceLogRow(
      id: _parseInt(json['punch_id'] ?? json['id']),
      deviceIp: json['device_ip']?.toString() ?? '',
      deviceUserId: json['device_user_id']?.toString() ?? '',
      punchTime: json['punch_time']?.toString(),
      workDate: json['work_date']?.toString(),
      syncedDate: json['synced_date']?.toString(),
      labourerName: json['labourer_name']?.toString(),
      mapped: json['casual_labourer_id'] != null ||
          json['mapped'] == true ||
          json['mapped'] == 1 ||
          json['mapped'] == '1',
    );
  }
}

class AttendanceLogPage {
  final List<AttendanceLogRow> rows;
  final Map<String, dynamic> summary;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  AttendanceLogPage({
    required this.rows,
    required this.summary,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory AttendanceLogPage.fromJson(Map<String, dynamic> json) {
    return AttendanceLogPage(
      rows: (json['rows'] as List? ?? [])
          .map((e) => AttendanceLogRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: (json['summary'] as Map<String, dynamic>?) ?? {},
      page: _parseInt(json['page']),
      pageSize: _parseInt(json['page_size']),
      total: _parseInt(json['total']),
      totalPages: _parseInt(json['total_pages']),
    );
  }

  factory AttendanceLogPage.empty() => AttendanceLogPage(
        rows: [],
        summary: {},
        page: 1,
        pageSize: 0,
        total: 0,
        totalPages: 1,
      );
}

/// Zk_punch::get_device_status(): device_ip, last_sync, last_punch,
/// punch_count. The web flags a device as stale (not syncing) when
/// last_sync is older than 1 day -- computed here the same way, not
/// returned by the backend.
class AttendanceDevice {
  final String deviceIp;
  final String? lastSync;
  final String? lastPunch;
  final int punchCount;

  AttendanceDevice({
    required this.deviceIp,
    this.lastSync,
    this.lastPunch,
    this.punchCount = 0,
  });

  bool get isStale {
    if (lastSync == null || lastSync!.isEmpty) return true;
    final parsed = DateTime.tryParse(lastSync!);
    if (parsed == null) return true;
    return DateTime.now().difference(parsed) > const Duration(days: 1);
  }

  factory AttendanceDevice.fromJson(Map<String, dynamic> json) {
    return AttendanceDevice(
      deviceIp: json['device_ip']?.toString() ?? json['ip']?.toString() ?? '',
      lastSync: json['last_sync']?.toString(),
      lastPunch: json['last_punch']?.toString(),
      punchCount: _parseInt(json['punch_count'] ?? json['count']),
    );
  }
}

/// Zk_punch::get_unmatched_device_users(): device_user_id, punch_count,
/// last_punch.
class UnmatchedPunch {
  final String deviceUserId;
  final String? lastPunch;
  final int punchCount;

  UnmatchedPunch({
    required this.deviceUserId,
    this.lastPunch,
    required this.punchCount,
  });

  factory UnmatchedPunch.fromJson(Map<String, dynamic> json) {
    return UnmatchedPunch(
      deviceUserId: json['device_user_id']?.toString() ?? '',
      lastPunch: json['last_punch']?.toString(),
      punchCount: _parseInt(json['punch_count'] ?? json['count']),
    );
  }
}

/// Wages tab's "Current Week" view - scraped from industry/wages.php's
/// rendered HTML (Casual_labourer_payment::get_weekly_status(), grouped by
/// Labourer Type). No JSON endpoint exists for this; mark_paid/verify
/// actions themselves are real JSON POSTs.
class WagesWeekRow {
  final int casualLabourerId;
  final String name;
  final bool isPaidFlag;
  final String quantityOrDays;
  final String gross;
  final String bonusOrPenalty;
  final bool bonusOrPenaltyIsNegative;
  final String adjustment;
  final String amount;
  final bool verified;
  final bool canVerify;
  final bool paid;
  final bool canMarkPaid;

  WagesWeekRow({
    required this.casualLabourerId,
    required this.name,
    required this.isPaidFlag,
    required this.quantityOrDays,
    required this.gross,
    required this.bonusOrPenalty,
    required this.bonusOrPenaltyIsNegative,
    required this.adjustment,
    required this.amount,
    required this.verified,
    required this.canVerify,
    required this.paid,
    required this.canMarkPaid,
  });
}

class WagesWeekGroup {
  final String name;
  final bool isPieceRate;
  final String unpaidTotal;
  final List<WagesWeekRow> labourers;

  WagesWeekGroup({
    required this.name,
    required this.isPieceRate,
    required this.unpaidTotal,
    required this.labourers,
  });
}

class WagesWeekData {
  final String weekRangeDisplay;
  final String referenceDate;
  final bool isCurrentWeek;
  final String totalUnpaid;
  final List<WagesWeekGroup> groups;

  WagesWeekData({
    required this.weekRangeDisplay,
    required this.referenceDate,
    required this.isCurrentWeek,
    required this.totalUnpaid,
    required this.groups,
  });
}

class DropdownOption {
  final String value;
  final String label;
  const DropdownOption(this.value, this.label);
}

/// Settings tab's Labourer Types table (Labourer_type::get_active() +
/// labourer_count, scraped - no JSON list endpoint exists).
class LabourerTypeRow {
  final int id;
  final String name;
  final String payModelLabel;
  final int labourerCount;
  LabourerTypeRow({required this.id, required this.name, required this.payModelLabel, required this.labourerCount});
}

/// Settings tab's Production Lines table (Production_line::get_active() +
/// labourer_count/machine_count).
class ProductionLineRow {
  final int id;
  final String name;
  final int labourerCount;
  final int machineCount;
  ProductionLineRow({required this.id, required this.name, required this.labourerCount, required this.machineCount});
}

/// Settings tab's "Mashine - Kuunganisha na Line" quick-link table.
class MachineLineLink {
  final int machineId;
  final String name;
  final String? lineId;
  final List<DropdownOption> lineOptions;
  MachineLineLink({required this.machineId, required this.name, required this.lineId, required this.lineOptions});
}

/// Settings tab's "Packing Products - Kuunganisha na Items" quick-link table.
class PackingProductLink {
  final int productId;
  final String name;
  final String itemId;
  final String itemName;
  PackingProductLink({required this.productId, required this.name, required this.itemId, required this.itemName});
}

/// Scraped from casual_labourers/view/{id}'s form.php (no JSON endpoint
/// returns raw editable fields - the search/get_row rows only carry
/// display labels like labourer_type NAME, not labourer_type_id).
class CasualLabourerFormData {
  final String name;
  final String phoneNumber;
  final String deviceUserId;
  final String monthlySalary;
  final String labourerTypeId;
  final String lineId;
  final bool isPaid;
  final List<DropdownOption> labourerTypes;
  final List<DropdownOption> productionLines;

  CasualLabourerFormData({
    required this.name,
    required this.phoneNumber,
    required this.deviceUserId,
    required this.monthlySalary,
    required this.labourerTypeId,
    required this.lineId,
    required this.isPaid,
    required this.labourerTypes,
    required this.productionLines,
  });
}

class CasualLabourer {
  final int id;
  final String name;
  final String? phoneNumber;
  final String? deviceUserId;
  final bool isPaid;

  CasualLabourer({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.deviceUserId,
    required this.isPaid,
  });

  /// From casual_labourers/get_row - raw model fields (numeric is_paid).
  factory CasualLabourer.fromJson(Map<String, dynamic> json) {
    return CasualLabourer(
      id: _parseInt(json['casual_labourer_id'] ?? json['id']),
      name: json['name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString(),
      deviceUserId: json['device_user_id']?.toString(),
      isPaid: json['is_paid'] == true || json['is_paid'] == 1 || json['is_paid'] == '1',
    );
  }

  Map<String, String> toFormFields() => {
        'name': name,
        'phone_number': phoneNumber ?? '',
        'device_user_id': deviceUserId ?? '',
        if (isPaid) 'is_paid': '1',
      };
}

/// Scraped from machines/view/{id}'s form.php (no JSON endpoint returns
/// raw type/line_id - the search/get_row rows only carry display labels).
class MachineFormData {
  final String name;
  final String type;
  final String lineId;
  final String ctnItemName;
  final String rejectCtnItemName;
  final List<DropdownOption> productionLines;

  MachineFormData({
    required this.name,
    required this.type,
    required this.lineId,
    required this.ctnItemName,
    required this.rejectCtnItemName,
    required this.productionLines,
  });
}

class IndustryMachine {
  final int id;
  final String name;
  final String? type;
  final String? ctnItemName;
  final String? rejectCtnItemName;

  IndustryMachine({
    required this.id,
    required this.name,
    this.type,
    this.ctnItemName,
    this.rejectCtnItemName,
  });

  /// From machines/get_row - raw model fields.
  factory IndustryMachine.fromJson(Map<String, dynamic> json) {
    return IndustryMachine(
      id: _parseInt(json['machine_id'] ?? json['id']),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString(),
      ctnItemName: json['ctn_item_name']?.toString(),
      rejectCtnItemName: json['reject_ctn_item_name']?.toString(),
    );
  }

  Map<String, String> toFormFields() => {
        'name': name,
        'type': type ?? '',
        'ctn_item_name': ctnItemName ?? '',
        'reject_ctn_item_name': rejectCtnItemName ?? '',
      };
}

/// Current Settings-tab values, read from the server-rendered Industry page
/// itself (no JSON endpoint exists for these - see WebSessionService.getHtml).
class IndustrySettings {
  final String dailyRate;
  final String weekStartDay;
  final String weekEndDay;
  final String clockInTime;
  final String clockOutTime;
  final String lateGraceMinutes;
  final String latePenaltyMode;
  final String latePenaltyAmount;
  final String latePenaltyBlockMinutes;
  final String mattressStrapsPerMattress;
  final String rollerStrapsPerBig;
  final String rollerStrapsPerSmall;
  final String rollerPcsPerStrap;
  final String rollerPcsPerBig;
  final String rollerPcsPerSmall;
  final List<LabourerTypeRow> labourerTypes;
  final List<ProductionLineRow> productionLines;
  final List<MachineLineLink> machineLineLinks;
  final List<PackingProductLink> packingProductLinks;

  IndustrySettings({
    required this.dailyRate,
    required this.weekStartDay,
    required this.weekEndDay,
    required this.clockInTime,
    required this.clockOutTime,
    required this.lateGraceMinutes,
    required this.latePenaltyMode,
    required this.latePenaltyAmount,
    required this.latePenaltyBlockMinutes,
    required this.mattressStrapsPerMattress,
    required this.rollerStrapsPerBig,
    required this.rollerStrapsPerSmall,
    required this.rollerPcsPerStrap,
    this.rollerPcsPerBig = '1',
    this.rollerPcsPerSmall = '1',
    this.labourerTypes = const [],
    this.productionLines = const [],
    this.machineLineLinks = const [],
    this.packingProductLinks = const [],
  });
}

// ============ Lines / Timu (read-only, scraped from the Industry index page) ============

class LineLabourer {
  final int casualLabourerId;
  final String name;
  final bool present;

  LineLabourer({required this.casualLabourerId, required this.name, required this.present});
}

class ProductionLineGroup {
  final String name; // "Bila Line" for the leftover/unassigned bucket
  final List<LineLabourer> labourers;
  final List<String> machineNames;
  final int producedToday;
  final bool isUnassigned;

  ProductionLineGroup({
    required this.name,
    required this.labourers,
    required this.machineNames,
    required this.producedToday,
    this.isUnassigned = false,
  });

  int get presentCount => labourers.where((l) => l.present).length;
}

// ============ Packing ============

/// Scraped from packing_products/view/{id}'s form.php (no JSON endpoint
/// returns raw editable fields - search/get_row only carry display-
/// formatted combined strings like middle_ratio="30 PC = 1 OUTER").
class PackingProductFormData {
  final String name;
  final String unitsPerPc;
  final String unitLabel;
  final String middleQty;
  final String middleLabel;
  final String outerQty;
  final String outerLabel;
  final String payRatePerUnit;
  final String bonusThresholdUnits;
  final String bonusAmountPerUnit;
  final String fillerBagPcCapacity;
  final String boxBagPcCapacity;
  final String itemId;
  final String itemName;

  PackingProductFormData({
    required this.name,
    required this.unitsPerPc,
    required this.unitLabel,
    required this.middleQty,
    required this.middleLabel,
    required this.outerQty,
    required this.outerLabel,
    required this.payRatePerUnit,
    required this.bonusThresholdUnits,
    required this.bonusAmountPerUnit,
    required this.fillerBagPcCapacity,
    required this.boxBagPcCapacity,
    required this.itemId,
    required this.itemName,
  });
}

class PackingProduct {
  final int id;
  final String name;
  final String unitLabel;
  final String? itemName;
  final String unitsPerPc;
  final String middleLabel;
  final String middleQty;
  final String outerLabel;
  final String outerQty;
  final String payRatePerUnit;
  final String bonusThresholdUnits;
  final String bonusAmountPerUnit;
  final String fillerBagPcCapacity;
  final String boxBagPcCapacity;

  PackingProduct({
    required this.id,
    required this.name,
    required this.unitLabel,
    this.itemName,
    required this.unitsPerPc,
    required this.middleLabel,
    required this.middleQty,
    required this.outerLabel,
    required this.outerQty,
    required this.payRatePerUnit,
    required this.bonusThresholdUnits,
    required this.bonusAmountPerUnit,
    required this.fillerBagPcCapacity,
    required this.boxBagPcCapacity,
  });

  factory PackingProduct.fromJson(Map<String, dynamic> json) {
    return PackingProduct(
      id: _parseInt(json['product_id'] ?? json['id']),
      name: json['name']?.toString() ?? '',
      unitLabel: json['unit_label']?.toString() ?? '',
      itemName: json['item_name']?.toString(),
      unitsPerPc: json['units_per_pc']?.toString() ?? '',
      middleLabel: json['middle_label']?.toString() ?? '',
      middleQty: json['middle_qty']?.toString() ?? '',
      outerLabel: json['outer_label']?.toString() ?? '',
      outerQty: json['outer_qty']?.toString() ?? '',
      payRatePerUnit: json['pay_rate_per_unit']?.toString() ?? '',
      bonusThresholdUnits: json['bonus_threshold_units']?.toString() ?? '',
      bonusAmountPerUnit: json['bonus_amount_per_unit']?.toString() ?? '',
      fillerBagPcCapacity: json['filler_bag_pc_capacity']?.toString() ?? '',
      boxBagPcCapacity: json['box_bag_pc_capacity']?.toString() ?? '',
    );
  }

  Map<String, String> toFormFields() => {
        'name': name,
        'item_name': itemName ?? '',
        'unit_label': unitLabel,
        'units_per_pc': unitsPerPc,
        'middle_label': middleLabel,
        'middle_qty': middleQty,
        'outer_label': outerLabel,
        'outer_qty': outerQty,
        'pay_rate_per_unit': payRatePerUnit,
        'bonus_threshold_units': bonusThresholdUnits,
        'bonus_amount_per_unit': bonusAmountPerUnit,
        'filler_bag_pc_capacity': fillerBagPcCapacity,
        'box_bag_pc_capacity': boxBagPcCapacity,
      };
}

// ============ Wages verification ============

class AttendanceDetailDay {
  final String date;
  final bool present;
  final String? clockIn;
  final String? clockOut;
  final bool late;
  final double penalty;

  AttendanceDetailDay({
    required this.date,
    required this.present,
    this.clockIn,
    this.clockOut,
    required this.late,
    required this.penalty,
  });

  factory AttendanceDetailDay.fromJson(Map<String, dynamic> json) {
    return AttendanceDetailDay(
      date: json['date']?.toString() ?? '',
      present: json['present'] == true || json['present'] == 1 || json['present'] == '1',
      clockIn: json['clock_in']?.toString(),
      clockOut: json['clock_out']?.toString(),
      late: json['late'] == true || json['late'] == 1 || json['late'] == '1',
      penalty: _parseDouble(json['penalty']),
    );
  }
}

class WageVerificationRow {
  final String labourerName;
  final String weekStartDate;
  final String weekEndDate;
  final int daysAttended;
  final double amount;
  final String? verifiedByName;
  final String? verifiedAt;
  final bool paid;
  final String? paidByName;
  final String? paidDate;

  WageVerificationRow({
    required this.labourerName,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.daysAttended,
    required this.amount,
    this.verifiedByName,
    this.verifiedAt,
    required this.paid,
    this.paidByName,
    this.paidDate,
  });
}

// ============ Roller: stock cards, date-scoped entries, history ============

/// Shared 4-tile stock-card shape (opening / added-or-received / used /
/// closing) used by Roller's Bag Opening, Dressing (Kuvisha) and Trimming
/// (Kupruniwa) sections - only the "added" column's key differs per
/// section (received/counted/dressed).
class RollerStockCard {
  final int opening;
  final int added;
  final int used;
  final int closing;

  RollerStockCard({required this.opening, required this.added, required this.used, required this.closing});

  factory RollerStockCard.fromJson(Map<String, dynamic> json, String addedKey) {
    return RollerStockCard(
      opening: _parseInt(json['opening']),
      added: _parseInt(json[addedKey]),
      used: _parseInt(json['used']),
      closing: _parseInt(json['closing']),
    );
  }

  factory RollerStockCard.empty() => RollerStockCard(opening: 0, added: 0, used: 0, closing: 0);
}

class RollerBagOpeningEntry {
  final int bagsOpened;
  final int rollersCountedBig;
  final int rollersCountedSmall;
  final RollerStockCard stockCard;

  RollerBagOpeningEntry({
    required this.bagsOpened,
    required this.rollersCountedBig,
    required this.rollersCountedSmall,
    required this.stockCard,
  });

  factory RollerBagOpeningEntry.fromJson(Map<String, dynamic> json) {
    return RollerBagOpeningEntry(
      bagsOpened: _parseInt(json['bags_opened']),
      rollersCountedBig: _parseInt(json['rollers_counted_big']),
      rollersCountedSmall: _parseInt(json['rollers_counted_small']),
      stockCard: json['stock_card'] is Map
          ? RollerStockCard.fromJson(json['stock_card'] as Map<String, dynamic>, 'received')
          : RollerStockCard.empty(),
    );
  }
}

class RollerUsageEntry {
  final int rollersUsedBig;
  final int rollersUsedSmall;
  final int strapsUsed;
  final int strapsInHand;
  final RollerStockCard bigStockCard;
  final RollerStockCard smallStockCard;

  RollerUsageEntry({
    required this.rollersUsedBig,
    required this.rollersUsedSmall,
    required this.strapsUsed,
    required this.strapsInHand,
    required this.bigStockCard,
    required this.smallStockCard,
  });

  factory RollerUsageEntry.fromJson(Map<String, dynamic> json) {
    return RollerUsageEntry(
      rollersUsedBig: _parseInt(json['rollers_used_big']),
      rollersUsedSmall: _parseInt(json['rollers_used_small']),
      strapsUsed: _parseInt(json['straps_used']),
      strapsInHand: _parseInt(json['straps_in_hand']),
      bigStockCard: json['big_stock_card'] is Map
          ? RollerStockCard.fromJson(json['big_stock_card'] as Map<String, dynamic>, 'counted')
          : RollerStockCard.empty(),
      smallStockCard: json['small_stock_card'] is Map
          ? RollerStockCard.fromJson(json['small_stock_card'] as Map<String, dynamic>, 'counted')
          : RollerStockCard.empty(),
    );
  }
}

class RollerTrimmingEntry {
  final int trimmedBig;
  final int trimmedSmall;
  final RollerStockCard bigStockCard;
  final RollerStockCard smallStockCard;

  RollerTrimmingEntry({
    required this.trimmedBig,
    required this.trimmedSmall,
    required this.bigStockCard,
    required this.smallStockCard,
  });

  factory RollerTrimmingEntry.fromJson(Map<String, dynamic> json) {
    return RollerTrimmingEntry(
      trimmedBig: _parseInt(json['trimmed_big']),
      trimmedSmall: _parseInt(json['trimmed_small']),
      bigStockCard: json['big_stock_card'] is Map
          ? RollerStockCard.fromJson(json['big_stock_card'] as Map<String, dynamic>, 'dressed')
          : RollerStockCard.empty(),
      smallStockCard: json['small_stock_card'] is Map
          ? RollerStockCard.fromJson(json['small_stock_card'] as Map<String, dynamic>, 'dressed')
          : RollerStockCard.empty(),
    );
  }
}

/// Roller tab's 4 history tables - scraped from the Industry page (no JSON
/// endpoint exists for any of these).
class RollerBagOpeningHistoryRow {
  final String date;
  final int bagsOpened;
  final int countedBig;
  final int countedSmall;
  RollerBagOpeningHistoryRow(
      {required this.date, required this.bagsOpened, required this.countedBig, required this.countedSmall});
}

class RollerUsageHistoryRow {
  final String date;
  final int usedBig;
  final int usedSmall;
  final int strapsUsed;
  RollerUsageHistoryRow(
      {required this.date, required this.usedBig, required this.usedSmall, required this.strapsUsed});
}

class RollerTrimmingHistoryRow {
  final String date;
  final int trimmedBig;
  final int trimmedSmall;
  RollerTrimmingHistoryRow({required this.date, required this.trimmedBig, required this.trimmedSmall});
}

class RollerReceiptRow {
  final String date;
  final int bagsReceived;
  final String note;
  RollerReceiptRow({required this.date, required this.bagsReceived, required this.note});
}

// ============ Mattress: stock cards, date-scoped entries, history ============

class MattressStockCard {
  final int opening;
  final int added;
  final int used;
  final int closing;

  MattressStockCard({required this.opening, required this.added, required this.used, required this.closing});

  factory MattressStockCard.fromJson(Map<String, dynamic> json, String addedKey) {
    return MattressStockCard(
      opening: _parseInt(json['opening']),
      added: _parseInt(json[addedKey]),
      used: _parseInt(json['used']),
      closing: _parseInt(json['closing']),
    );
  }

  factory MattressStockCard.empty() => MattressStockCard(opening: 0, added: 0, used: 0, closing: 0);
}

class MattressCuttingEntry {
  final int mattressesCut;
  final int strapsActual;
  final int strapsDamaged;
  final int mattressesInHand;
  final MattressStockCard stockCard;

  MattressCuttingEntry({
    required this.mattressesCut,
    required this.strapsActual,
    required this.strapsDamaged,
    required this.mattressesInHand,
    required this.stockCard,
  });

  factory MattressCuttingEntry.fromJson(Map<String, dynamic> json) {
    return MattressCuttingEntry(
      mattressesCut: _parseInt(json['mattresses_cut']),
      strapsActual: _parseInt(json['straps_actual']),
      strapsDamaged: _parseInt(json['straps_damaged']),
      mattressesInHand: _parseInt(json['mattresses_in_hand']),
      stockCard: json['stock_card'] is Map
          ? MattressStockCard.fromJson(json['stock_card'] as Map<String, dynamic>, 'received')
          : MattressStockCard.empty(),
    );
  }
}

class MattressStrapsStockEntry {
  final int strapsInHand;
  final MattressStockCard stockCard;

  MattressStrapsStockEntry({required this.strapsInHand, required this.stockCard});

  factory MattressStrapsStockEntry.fromJson(Map<String, dynamic> json) {
    return MattressStrapsStockEntry(
      strapsInHand: _parseInt(json['straps_in_hand']),
      stockCard: json['stock_card'] is Map
          ? MattressStockCard.fromJson(json['stock_card'] as Map<String, dynamic>, 'cut')
          : MattressStockCard.empty(),
    );
  }
}

class MattressCuttingHistoryRow {
  final String date;
  final int mattressesCut;
  final int strapsActual;
  final int strapsDamaged;
  MattressCuttingHistoryRow({
    required this.date,
    required this.mattressesCut,
    required this.strapsActual,
    required this.strapsDamaged,
  });
}

class MattressReceiptRow {
  final String date;
  final int mattressesReceived;
  final String note;
  MattressReceiptRow({required this.date, required this.mattressesReceived, required this.note});
}

class MattressHistoryData {
  final List<MattressCuttingHistoryRow> cutting;
  final List<MattressReceiptRow> receipts;
  MattressHistoryData({required this.cutting, required this.receipts});
}

class RollerHistoryData {
  final List<RollerBagOpeningHistoryRow> bagOpening;
  final List<RollerUsageHistoryRow> usage;
  final List<RollerTrimmingHistoryRow> trimming;
  final List<RollerReceiptRow> receipts;

  RollerHistoryData({
    required this.bagOpening,
    required this.usage,
    required this.trimming,
    required this.receipts,
  });
}

// ============ Production: welding, per-machine packing/issue, history ============

class ProductionStockCard {
  final int opening;
  final int added;
  final int used;
  final int closing;

  ProductionStockCard({required this.opening, required this.added, required this.used, required this.closing});

  factory ProductionStockCard.fromJson(Map<String, dynamic> json) {
    return ProductionStockCard(
      opening: _parseInt(json['opening']),
      added: _parseInt(json['added']),
      used: _parseInt(json['used']),
      closing: _parseInt(json['closing']),
    );
  }

  factory ProductionStockCard.empty() => ProductionStockCard(opening: 0, added: 0, used: 0, closing: 0);
}

/// Chomwa/Welding - entirely read-only, auto-filled by Roller's save_usage().
class WeldingEntry {
  final int strapsWelded;
  final ProductionStockCard stockCard;
  final int expectedPcs;
  final int actualPcsProduced;

  WeldingEntry({
    required this.strapsWelded,
    required this.stockCard,
    required this.expectedPcs,
    required this.actualPcsProduced,
  });

  factory WeldingEntry.fromJson(Map<String, dynamic> json) {
    return WeldingEntry(
      strapsWelded: _parseInt(json['straps_welded']),
      stockCard: json['stock_card'] is Map
          ? ProductionStockCard.fromJson(json['stock_card'] as Map<String, dynamic>)
          : ProductionStockCard.empty(),
      expectedPcs: _parseInt(json['expected_pcs']),
      actualPcsProduced: _parseInt(json['actual_pcs_produced']),
    );
  }
}

class CurrentStockEntry {
  final int pcsInHand;
  final int dozensInHand;
  final int dozensInHandReject;
  final int cartonsInHand;
  final int cartonsInHandReject;

  CurrentStockEntry({
    required this.pcsInHand,
    required this.dozensInHand,
    required this.dozensInHandReject,
    required this.cartonsInHand,
    required this.cartonsInHandReject,
  });

  factory CurrentStockEntry.fromJson(Map<String, dynamic> json) {
    return CurrentStockEntry(
      pcsInHand: _parseInt(json['pcs_in_hand']),
      dozensInHand: _parseInt(json['dozens_in_hand']),
      dozensInHandReject: _parseInt(json['dozens_in_hand_reject']),
      cartonsInHand: _parseInt(json['cartons_in_hand']),
      cartonsInHandReject: _parseInt(json['cartons_in_hand_reject']),
    );
  }

  factory CurrentStockEntry.empty() =>
      CurrentStockEntry(pcsInHand: 0, dozensInHand: 0, dozensInHandReject: 0, cartonsInHand: 0, cartonsInHandReject: 0);
}

class PackingHistoryRow {
  final String date;
  final String machineName;
  final bool isReject;
  final int cartonsPacked;
  PackingHistoryRow(
      {required this.date, required this.machineName, required this.isReject, required this.cartonsPacked});
}

class IssueHistoryRow {
  final int issueId;
  final String issuedDate;
  final String machineName;
  final bool isReject;
  final int quantityIssued;
  final bool isIssued; // false = reversed
  final bool canReverse;
  IssueHistoryRow({
    required this.issueId,
    required this.issuedDate,
    required this.machineName,
    required this.isReject,
    required this.quantityIssued,
    required this.isIssued,
    required this.canReverse,
  });
}

class ProductionHistoryRow {
  final String date;
  final String machineName;
  final int quantityProduced;
  ProductionHistoryRow({required this.date, required this.machineName, required this.quantityProduced});
}

class WeldingHistoryRow {
  final String date;
  final int strapsWelded;
  WeldingHistoryRow({required this.date, required this.strapsWelded});
}

class ProductionHistoryData {
  final List<PackingHistoryRow> packing;
  final List<IssueHistoryRow> issues;
  final List<ProductionHistoryRow> production;
  final List<WeldingHistoryRow> welding;

  ProductionHistoryData({
    required this.packing,
    required this.issues,
    required this.production,
    required this.welding,
  });
}

// ============ Packing: stock overview, material, output, issue, history ============

class PackingStockRow {
  final int productId;
  final String name;
  final String finalUnitLabel;
  final int totalUnitsPacked;
  final int finalUnitsInHand;
  final int fillerBagsInHand;
  final int boxBagsInHand;
  final int fillersInHand;
  final int boxesInHand;

  PackingStockRow({
    required this.productId,
    required this.name,
    required this.finalUnitLabel,
    required this.totalUnitsPacked,
    required this.finalUnitsInHand,
    required this.fillerBagsInHand,
    required this.boxBagsInHand,
    required this.fillersInHand,
    required this.boxesInHand,
  });

  factory PackingStockRow.fromJson(Map<String, dynamic> json) {
    return PackingStockRow(
      productId: _parseInt(json['product_id']),
      name: json['name']?.toString() ?? '',
      finalUnitLabel: json['final_unit_label']?.toString() ?? '',
      totalUnitsPacked: _parseInt(json['total_units_packed']),
      finalUnitsInHand: _parseInt(json['final_units_in_hand']),
      fillerBagsInHand: _parseInt(json['filler_bags_in_hand']),
      boxBagsInHand: _parseInt(json['box_bags_in_hand']),
      fillersInHand: _parseInt(json['fillers_in_hand']),
      boxesInHand: _parseInt(json['boxes_in_hand']),
    );
  }
}

class PackingMaterialCard {
  final int opening;
  final int received;
  final int used;
  final int closing;
  PackingMaterialCard({required this.opening, required this.received, required this.used, required this.closing});

  factory PackingMaterialCard.fromJson(Map<String, dynamic> json) {
    return PackingMaterialCard(
      opening: _parseInt(json['opening']),
      received: _parseInt(json['received']),
      used: _parseInt(json['used']),
      closing: _parseInt(json['closing']),
    );
  }

  factory PackingMaterialCard.empty() => PackingMaterialCard(opening: 0, received: 0, used: 0, closing: 0);
}

class PackingMaterialStockEntry {
  final PackingMaterialCard fillerBagCard;
  final PackingMaterialCard boxBagCard;

  PackingMaterialStockEntry({required this.fillerBagCard, required this.boxBagCard});

  factory PackingMaterialStockEntry.fromJson(Map<String, dynamic> json) {
    return PackingMaterialStockEntry(
      fillerBagCard: json['filler_bag_card'] is Map
          ? PackingMaterialCard.fromJson(json['filler_bag_card'] as Map<String, dynamic>)
          : PackingMaterialCard.empty(),
      boxBagCard: json['box_bag_card'] is Map
          ? PackingMaterialCard.fromJson(json['box_bag_card'] as Map<String, dynamic>)
          : PackingMaterialCard.empty(),
    );
  }
}

class PackingOutputLabourer {
  final int casualLabourerId;
  final String name;
  final bool isPaid;
  final int quantityPacked;
  PackingOutputLabourer({
    required this.casualLabourerId,
    required this.name,
    required this.isPaid,
    required this.quantityPacked,
  });
}

class PackingOutputBulkData {
  final List<PackingOutputLabourer> labourers;
  final int fillersInHand;
  final int boxesInHand;
  PackingOutputBulkData({required this.labourers, required this.fillersInHand, required this.boxesInHand});

  factory PackingOutputBulkData.fromJson(Map<String, dynamic> json) {
    final entries = (json['entries'] as Map?) ?? {};
    final labourers = ((json['labourers'] as List?) ?? []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = _parseInt(m['casual_labourer_id']);
      return PackingOutputLabourer(
        casualLabourerId: id,
        name: m['name']?.toString() ?? '',
        isPaid: m['is_paid'] == true || m['is_paid'] == 1 || m['is_paid'] == '1',
        quantityPacked: _parseInt(entries['$id']),
      );
    }).toList();
    return PackingOutputBulkData(
      labourers: labourers,
      fillersInHand: _parseInt(json['fillers_in_hand']),
      boxesInHand: _parseInt(json['boxes_in_hand']),
    );
  }
}

class PackingOutputHistoryRow {
  final String date;
  final String labourerName;
  final bool isPaid;
  final String productName;
  final String quantityPacked;
  final String bonus;
  final String pay;
  PackingOutputHistoryRow({
    required this.date,
    required this.labourerName,
    required this.isPaid,
    required this.productName,
    required this.quantityPacked,
    required this.bonus,
    required this.pay,
  });
}

class PackingIssueHistoryRow {
  final int issueId;
  final String date;
  final String productName;
  final int quantityIssued;
  final String status; // 'pending' | 'issued' | 'cancelled' | 'reversed'
  final bool canConfirmOrCancel;
  final bool canReverse;
  PackingIssueHistoryRow({
    required this.issueId,
    required this.date,
    required this.productName,
    required this.quantityIssued,
    required this.status,
    required this.canConfirmOrCancel,
    required this.canReverse,
  });
}

class PackingMaterialReceiptRow {
  final String productName;
  final String date;
  final int fillerBagsReceived;
  final int boxBagsReceived;
  final String note;
  PackingMaterialReceiptRow({
    required this.productName,
    required this.date,
    required this.fillerBagsReceived,
    required this.boxBagsReceived,
    required this.note,
  });
}

class PackingHistoryData {
  final List<PackingOutputHistoryRow> output;
  final List<PackingIssueHistoryRow> issues;
  final List<PackingMaterialReceiptRow> receipts;
  PackingHistoryData({required this.output, required this.issues, required this.receipts});
}
