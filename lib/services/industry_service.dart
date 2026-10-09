// Industry module: consumes the backend's web-only session-cookie endpoints
// (Industry::dashboard/report, Attendance::get_roster/log) via
// WebSessionService, since no JWT API exists for these yet.
import '../models/api_response.dart';
import '../models/industry.dart';
import 'web_session_service.dart';

class IndustryService {
  final WebSessionService _session = WebSessionService();

  WebSessionService get session => _session;

  Future<String> get _base => _session.webBaseUrl;

  /// Generic GET returning the raw decoded JSON object, for endpoints whose
  /// shape varies too much per-call to justify a dedicated model (most of
  /// the Roller/Mattress/Production date-scoped entries + stock cards).
  Future<ApiResponse<Map<String, dynamic>>> _getMap(Uri uri) async {
    try {
      final result = await _session.getJson(uri);
      return ApiResponse.success(data: result);
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Generic CSRF-protected POST. Surfaces the server's own success/message
  /// (WebActionFailedException) as a normal ApiResponse.error rather than
  /// throwing, so every write screen handles failures the same way.
  Future<ApiResponse<Map<String, dynamic>>> _post(
    Uri uri,
    Map<String, String> fields,
  ) async {
    try {
      final result = await _session.postForm(uri, fields);
      return ApiResponse.success(
        data: result,
        message: result['message']?.toString() ?? 'Success',
      );
    } on WebActionFailedException catch (e) {
      return ApiResponse.error(message: e.message);
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  Future<ApiResponse<IndustryDashboard>> getDashboard({String? date}) async {
    try {
      final base = await _session.webBaseUrl;
      final uri = Uri.parse('$base/industry/dashboard').replace(
        queryParameters: date != null ? {'date': date} : null,
      );

      final jsonResponse = await _session.getJson(uri);

      if (jsonResponse['success'] == true) {
        return ApiResponse.success(
          data: IndustryDashboard.fromJson(jsonResponse),
        );
      }
      return ApiResponse.error(
        message: jsonResponse['message']?.toString() ?? 'Failed to load dashboard',
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Daily Report sub-report: [kind] is 'steelwire' or 'packing'.
  Future<ApiResponse<Map<String, dynamic>>> getDailyReport({
    required String kind,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final base = await _base;
      final uri = Uri.parse('$base/daily_report/$kind').replace(
        queryParameters: {'start_date': startDate, 'end_date': endDate},
      );
      final jsonResponse = await _session.getJson(uri);
      if (jsonResponse['success'] == true) {
        return ApiResponse.success(data: Map<String, dynamic>.from(jsonResponse['data'] as Map));
      }
      return ApiResponse.error(message: jsonResponse['message']?.toString() ?? 'Could not load daily report');
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  Future<ApiResponse<IndustryReport>> getReport({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final base = await _session.webBaseUrl;
      final uri = Uri.parse('$base/industry/report').replace(
        queryParameters: {'start_date': startDate, 'end_date': endDate},
      );

      final jsonResponse = await _session.getJson(uri);

      if (jsonResponse['success'] == true) {
        return ApiResponse.success(data: IndustryReport.fromJson(jsonResponse));
      }
      return ApiResponse.error(
        message: jsonResponse['message']?.toString() ?? 'Failed to load report',
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// get_roster returns a bare JSON array (not the {success,...} envelope the
  /// other endpoints use), so it's handled separately from getJson().
  Future<ApiResponse<List<AttendanceRosterEntry>>> getRoster({
    required String date,
  }) async {
    try {
      final base = await _session.webBaseUrl;
      final uri = Uri.parse('$base/attendance/get_roster/$date');

      final list = await _session.getJsonList(uri);
      return ApiResponse.success(
        data: list
            .map((e) => AttendanceRosterEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  Future<ApiResponse<AttendanceLogPage>> getAttendanceLog({
    String? startDate,
    String? endDate,
    String? deviceIp,
    String? deviceUserId,
    bool unmappedOnly = false,
    int page = 1,
  }) async {
    try {
      final base = await _session.webBaseUrl;
      final uri = Uri.parse('$base/attendance/log').replace(queryParameters: {
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (deviceIp != null) 'device_ip': deviceIp,
        if (deviceUserId != null) 'device_user_id': deviceUserId,
        if (unmappedOnly) 'unmapped_only': '1',
        'page': page.toString(),
      });

      final jsonResponse = await _session.getJson(uri);

      if (jsonResponse['success'] == true) {
        return ApiResponse.success(data: AttendanceLogPage.fromJson(jsonResponse));
      }
      return ApiResponse.error(
        message: jsonResponse['message']?.toString() ?? 'Failed to load attendance log',
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============ WAGES: attendance adjustment + mark paid ============

  Future<ApiResponse<Map<String, dynamic>>> saveWageAdjustment({
    required int casualLabourerId,
    required String adjustmentDate,
    required double amount,
    String note = '',
  }) async {
    final uri = Uri.parse('${await _base}/wages/save_adjustment');
    return _post(uri, {
      'casual_labourer_id': casualLabourerId.toString(),
      'adjustment_date': adjustmentDate,
      'amount': amount.toString(),
      'note': note,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> markWagePaid(int casualLabourerId) async {
    final uri = Uri.parse('${await _base}/wages/mark_paid/$casualLabourerId');
    return _post(uri, {});
  }

  // ============ CASUAL LABOURERS: CRUD ============

  Future<ApiResponse<Map<String, dynamic>>> searchCasualLabourers({
    String search = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('${await _base}/casual_labourers/search').replace(
      queryParameters: {'search': search, 'limit': limit.toString(), 'offset': offset.toString()},
    );
    return _getMap(uri);
  }

  Future<ApiResponse<CasualLabourer>> getCasualLabourer(int id) async {
    final result = await _getMap(Uri.parse('${await _base}/casual_labourers/get_row/$id'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: CasualLabourer.fromJson(result.data!));
  }

  /// Full editable form, scraped from casual_labourers/view/{id}'s rendered
  /// form.php - the only place labourer_type_id/line_id/monthly_salary are
  /// exposed raw (get_row only returns their display labels). Use id -1 for
  /// the "New Casual Labourer" form (matches the web's own routing).
  Future<ApiResponse<CasualLabourerFormData>> getCasualLabourerForm(int id) async {
    try {
      final html = await _session.getHtml(Uri.parse('${await _base}/casual_labourers/view/$id'));
      return ApiResponse.success(
        data: CasualLabourerFormData(
          name: _extractInputValue(html, 'name') ?? '',
          phoneNumber: _extractInputValue(html, 'phone_number') ?? '',
          deviceUserId: _extractInputValue(html, 'device_user_id') ?? '',
          monthlySalary: _extractInputValue(html, 'monthly_salary') ?? '',
          labourerTypeId: _extractSelectedOption(html, 'labourer_type_id') ?? '',
          lineId: _extractSelectedOption(html, 'line_id') ?? '',
          isPaid: RegExp('name="is_paid"[^>]*checked', caseSensitive: false).hasMatch(html),
          labourerTypes: _extractSelectOptions(html, 'labourer_type_id'),
          productionLines: _extractSelectOptions(html, 'line_id'),
        ),
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  List<DropdownOption> _extractSelectOptions(String html, String fieldName) {
    final selectMatch = RegExp(
      'name="$fieldName".*?</select>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (selectMatch == null) return [];
    final options = RegExp(
      '<option value="([^"]*)"[^>]*>([^<]*)</option>',
      caseSensitive: false,
    ).allMatches(selectMatch.group(0)!);
    return options.map((m) => DropdownOption(m.group(1) ?? '', (m.group(2) ?? '').trim())).toList();
  }

  Future<ApiResponse<Map<String, dynamic>>> saveCasualLabourer({
    int? id,
    required String name,
    String phoneNumber = '',
    String deviceUserId = '',
    String monthlySalary = '',
    String labourerTypeId = '',
    String lineId = '',
    bool isPaid = false,
  }) async {
    final uri = Uri.parse('${await _base}/casual_labourers/save/${id ?? -1}');
    return _post(uri, {
      'name': name,
      'phone_number': phoneNumber,
      'device_user_id': deviceUserId,
      'monthly_salary': monthlySalary,
      'labourer_type_id': labourerTypeId,
      'line_id': lineId,
      if (isPaid) 'is_paid': '1',
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteCasualLabourers(List<int> ids) async {
    final uri = Uri.parse('${await _base}/casual_labourers/delete');
    // CI's $this->input->post('ids') expects a PHP array - send ids[] repeated.
    return _postWithArrayField(uri, 'ids', ids.map((e) => e.toString()).toList());
  }

  // ============ MACHINES: CRUD ============

  Future<ApiResponse<Map<String, dynamic>>> searchMachines({
    String search = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('${await _base}/machines/search').replace(
      queryParameters: {'search': search, 'limit': limit.toString(), 'offset': offset.toString()},
    );
    return _getMap(uri);
  }

  Future<ApiResponse<IndustryMachine>> getMachine(int id) async {
    final result = await _getMap(Uri.parse('${await _base}/machines/get_row/$id'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: IndustryMachine.fromJson(result.data!));
  }

  Future<ApiResponse<Map<String, dynamic>>> saveMachine({
    int? id,
    required String name,
    String type = '',
    String lineId = '',
    String ctnItemName = '',
    String rejectCtnItemName = '',
  }) async {
    final uri = Uri.parse('${await _base}/machines/save/${id ?? -1}');
    return _post(uri, {
      'name': name,
      'type': type,
      'line_id': lineId,
      'ctn_item_name': ctnItemName,
      'reject_ctn_item_name': rejectCtnItemName,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteMachines(List<int> ids) async {
    final uri = Uri.parse('${await _base}/machines/delete');
    return _postWithArrayField(uri, 'ids', ids.map((e) => e.toString()).toList());
  }

  /// Full editable form, scraped from machines/view/{id}'s rendered
  /// form.php - get_row only returns type/line as translated display
  /// labels, not the raw type value or line_id the save endpoint needs.
  Future<ApiResponse<MachineFormData>> getMachineForm(int id) async {
    try {
      final html = await _session.getHtml(Uri.parse('${await _base}/machines/view/$id'));
      return ApiResponse.success(
        data: MachineFormData(
          name: _extractInputValue(html, 'name') ?? '',
          type: _extractSelectedOption(html, 'type') ?? 'auto',
          lineId: _extractSelectedOption(html, 'line_id') ?? '',
          ctnItemName: _extractInputValue(html, 'ctn_item_name') ?? '',
          rejectCtnItemName: _extractInputValue(html, 'reject_ctn_item_name') ?? '',
          productionLines: _extractSelectOptions(html, 'line_id'),
        ),
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============ ROLLER: bag opening / usage / trimming / receive ============

  Future<ApiResponse<RollerBagOpeningEntry>> getRollerBagOpening(String date) async {
    final result = await _getMap(Uri.parse('${await _base}/roller/get_bag_opening/$date'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: RollerBagOpeningEntry.fromJson(result.data!));
  }

  Future<ApiResponse<Map<String, dynamic>>> saveRollerBagOpening({
    required String openingDate,
    required int bagsOpened,
    required int rollersCountedBig,
    required int rollersCountedSmall,
  }) async {
    final uri = Uri.parse('${await _base}/roller/save_bag_opening');
    return _post(uri, {
      'opening_date': openingDate,
      'bags_opened': bagsOpened.toString(),
      'rollers_counted_big': rollersCountedBig.toString(),
      'rollers_counted_small': rollersCountedSmall.toString(),
    });
  }

  Future<ApiResponse<RollerUsageEntry>> getRollerUsage(String date) async {
    final result = await _getMap(Uri.parse('${await _base}/roller/get_usage/$date'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: RollerUsageEntry.fromJson(result.data!));
  }

  /// Kuvisha / Dressing. straps_used is NOT an input - the backend computes
  /// it itself from rollers_used_big/small (see Roller::save_usage()), so
  /// there is nothing else to send here.
  Future<ApiResponse<Map<String, dynamic>>> saveRollerUsage({
    required String usageDate,
    required int rollersUsedBig,
    required int rollersUsedSmall,
  }) async {
    final uri = Uri.parse('${await _base}/roller/save_usage');
    return _post(uri, {
      'usage_date': usageDate,
      'rollers_used_big': rollersUsedBig.toString(),
      'rollers_used_small': rollersUsedSmall.toString(),
    });
  }

  /// Kupruniwa / Trimming is read-only - it's auto-filled by save_usage()
  /// (Roller_stock::save_pipeline_for_date()), there is no save endpoint.
  Future<ApiResponse<RollerTrimmingEntry>> getRollerTrimming(String date) async {
    final result = await _getMap(Uri.parse('${await _base}/roller/get_trimming/$date'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: RollerTrimmingEntry.fromJson(result.data!));
  }

  Future<ApiResponse<Map<String, dynamic>>> receiveRoller({
    required String receiptDate,
    required int bagsReceived,
    String note = '',
  }) async {
    final uri = Uri.parse('${await _base}/roller/receive');
    return _post(uri, {
      'receipt_date': receiptDate,
      'bags_received': bagsReceived.toString(),
      'note': note,
    });
  }

  /// Roller tab's 4 history tables - no JSON endpoint exists, scraped from
  /// the Industry page. Scoped to id="roller_tab" first since headings like
  /// "Receipt History" also appear verbatim on the Mattress tab.
  Future<ApiResponse<RollerHistoryData>> getRollerHistory() async {
    try {
      final html = await _session.getHtml(Uri.parse('${await _base}/industry'));
      final tabStart = html.indexOf('id="roller_tab"');
      final tabEnd = tabStart == -1 ? html.length : html.indexOf('class="tab-pane', tabStart + 1);
      final rollerHtml = tabStart == -1 ? html : html.substring(tabStart, tabEnd == -1 ? html.length : tabEnd);

      final bagOpening = <RollerBagOpeningHistoryRow>[];
      for (final rowHtml in _dataRows(_sliceTable(rollerHtml, 'Bag Opening History'))) {
        final tds = _tds(rowHtml).map(_stripTags).toList();
        if (tds.length < 4) continue;
        bagOpening.add(RollerBagOpeningHistoryRow(
          date: tds[0],
          bagsOpened: int.tryParse(tds[1]) ?? 0,
          countedBig: int.tryParse(tds[2]) ?? 0,
          countedSmall: int.tryParse(tds[3]) ?? 0,
        ));
      }

      final usage = <RollerUsageHistoryRow>[];
      for (final rowHtml in _dataRows(_sliceTable(rollerHtml, 'Dressing History'))) {
        final tds = _tds(rowHtml).map(_stripTags).toList();
        if (tds.length < 4) continue;
        usage.add(RollerUsageHistoryRow(
          date: tds[0],
          usedBig: int.tryParse(tds[1]) ?? 0,
          usedSmall: int.tryParse(tds[2]) ?? 0,
          strapsUsed: int.tryParse(tds[3]) ?? 0,
        ));
      }

      final trimming = <RollerTrimmingHistoryRow>[];
      for (final rowHtml in _dataRows(_sliceTable(rollerHtml, 'Trimming History'))) {
        final tds = _tds(rowHtml).map(_stripTags).toList();
        if (tds.length < 3) continue;
        trimming.add(RollerTrimmingHistoryRow(
          date: tds[0],
          trimmedBig: int.tryParse(tds[1]) ?? 0,
          trimmedSmall: int.tryParse(tds[2]) ?? 0,
        ));
      }

      final receipts = <RollerReceiptRow>[];
      for (final rowHtml in _dataRows(_sliceTable(rollerHtml, 'Receipt History'))) {
        final tds = _tds(rowHtml).map(_stripTags).toList();
        if (tds.length < 2) continue;
        receipts.add(RollerReceiptRow(
          date: tds[0],
          bagsReceived: int.tryParse(tds[1]) ?? 0,
          note: tds.length > 2 ? tds[2] : '',
        ));
      }

      return ApiResponse.success(
        data: RollerHistoryData(bagOpening: bagOpening, usage: usage, trimming: trimming, receipts: receipts),
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============ MATTRESS: cutting / straps stock / receive ============

  Future<ApiResponse<MattressCuttingEntry>> getMattressCutting(String date) async {
    final result = await _getMap(Uri.parse('${await _base}/mattress/get_cutting/$date'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: MattressCuttingEntry.fromJson(result.data!));
  }

  Future<ApiResponse<Map<String, dynamic>>> saveMattressCutting({
    required String cuttingDate,
    required int mattressesCut,
    required int strapsActual,
    required int strapsDamaged,
  }) async {
    final uri = Uri.parse('${await _base}/mattress/save_cutting');
    return _post(uri, {
      'cutting_date': cuttingDate,
      'mattresses_cut': mattressesCut.toString(),
      'straps_actual': strapsActual.toString(),
      'straps_damaged': strapsDamaged.toString(),
    });
  }

  Future<ApiResponse<MattressStrapsStockEntry>> getMattressStrapsStock(String date) async {
    final result = await _getMap(Uri.parse('${await _base}/mattress/get_straps_stock/$date'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: MattressStrapsStockEntry.fromJson(result.data!));
  }

  Future<ApiResponse<Map<String, dynamic>>> receiveMattress({
    required String receiptDate,
    required int mattressesReceived,
    String note = '',
  }) async {
    final uri = Uri.parse('${await _base}/mattress/receive');
    return _post(uri, {
      'receipt_date': receiptDate,
      'mattresses_received': mattressesReceived.toString(),
      'note': note,
    });
  }

  /// Mattress tab's 2 history tables - no JSON endpoint exists, scraped
  /// from the Industry page. Scoped to id="mattress_tab" first since
  /// "Receipt History" also appears verbatim on the Roller tab.
  Future<ApiResponse<MattressHistoryData>> getMattressHistory() async {
    try {
      final html = await _session.getHtml(Uri.parse('${await _base}/industry'));
      final tabStart = html.indexOf('id="mattress_tab"');
      final tabEnd = tabStart == -1 ? html.length : html.indexOf('class="tab-pane', tabStart + 1);
      final mattressHtml = tabStart == -1 ? html : html.substring(tabStart, tabEnd == -1 ? html.length : tabEnd);

      final cutting = <MattressCuttingHistoryRow>[];
      for (final rowHtml in _dataRows(_sliceTable(mattressHtml, 'Cutting History'))) {
        final tds = _tds(rowHtml).map(_stripTags).toList();
        if (tds.length < 4) continue;
        cutting.add(MattressCuttingHistoryRow(
          date: tds[0],
          mattressesCut: int.tryParse(tds[1]) ?? 0,
          strapsActual: int.tryParse(tds[2]) ?? 0,
          strapsDamaged: int.tryParse(tds[3]) ?? 0,
        ));
      }

      final receipts = <MattressReceiptRow>[];
      for (final rowHtml in _dataRows(_sliceTable(mattressHtml, 'Receipt History'))) {
        final tds = _tds(rowHtml).map(_stripTags).toList();
        if (tds.length < 2) continue;
        receipts.add(MattressReceiptRow(
          date: tds[0],
          mattressesReceived: int.tryParse(tds[1]) ?? 0,
          note: tds.length > 2 ? tds[2] : '',
        ));
      }

      return ApiResponse.success(data: MattressHistoryData(cutting: cutting, receipts: receipts));
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============ PRODUCTION: per-machine production/welding/dozens/packing/issue ============

  Future<ApiResponse<Map<String, dynamic>>> getProduction(int machineId, String date) async =>
      _getMap(Uri.parse('${await _base}/production/get_production/$machineId/$date'));

  Future<ApiResponse<Map<String, dynamic>>> saveProduction({
    required int machineId,
    required String productionDate,
    required int quantityProduced,
  }) async {
    final uri = Uri.parse('${await _base}/production/save');
    return _post(uri, {
      'machine_id': machineId.toString(),
      'production_date': productionDate,
      'quantity_produced': quantityProduced.toString(),
    });
  }

  /// Chomwa/Welding is entirely read-only - auto-filled by Roller's
  /// save_usage() (Roller_stock::save_pipeline_for_date()). There is no
  /// save endpoint on the Production controller for this.
  Future<ApiResponse<WeldingEntry>> getWelding(String date) async {
    final result = await _getMap(Uri.parse('${await _base}/production/get_welding/$date'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: WeldingEntry.fromJson(result.data!));
  }

  Future<ApiResponse<CurrentStockEntry>> getCurrentStock(int machineId) async {
    final result = await _getMap(Uri.parse('${await _base}/production/get_current_stock/$machineId'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: CurrentStockEntry.fromJson(result.data!));
  }

  /// Machine_packing::TYPE_NORMAL/TYPE_REJECT are the lowercase strings
  /// 'normal'/'reject' - NOT 'NORMAL'/'REJECT'.
  Future<ApiResponse<Map<String, dynamic>>> getDozens(
    int machineId,
    String date, {
    String type = 'normal',
  }) async =>
      _getMap(Uri.parse('${await _base}/production/get_dozens/$machineId/$date/$type'));

  Future<ApiResponse<Map<String, dynamic>>> saveDozens({
    required int machineId,
    required String packingDate,
    required int dozensPacked,
    String type = 'normal',
  }) async {
    final uri = Uri.parse('${await _base}/production/save_dozens');
    return _post(uri, {
      'machine_id': machineId.toString(),
      'packing_date': packingDate,
      'dozens_packed': dozensPacked.toString(),
      'type': type,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> getPacking(
    int machineId,
    String date, {
    String type = 'normal',
  }) async =>
      _getMap(Uri.parse('${await _base}/production/get_packing/$machineId/$date/$type'));

  Future<ApiResponse<Map<String, dynamic>>> savePacking({
    required int machineId,
    required String packingDate,
    required int cartonsPacked,
    String type = 'normal',
  }) async {
    final uri = Uri.parse('${await _base}/production/save_packing');
    return _post(uri, {
      'machine_id': machineId.toString(),
      'packing_date': packingDate,
      'cartons_packed': cartonsPacked.toString(),
      'type': type,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> issueCartons({
    required int machineId,
    required int quantity,
    String type = 'normal',
  }) async {
    final uri = Uri.parse('${await _base}/production/issue');
    return _post(uri, {
      'machine_id': machineId.toString(),
      'quantity': quantity.toString(),
      'type': type,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> reverseIssue(int issueId) async {
    final uri = Uri.parse('${await _base}/production/reverse_issue/$issueId');
    return _post(uri, {});
  }

  /// Production tab's 4 history tables - no JSON endpoint exists, scraped
  /// from the Industry page. Scoped to id="production_tab" first since
  /// "Issue History" also appears verbatim on the Packing tab.
  Future<ApiResponse<ProductionHistoryData>> getProductionHistory() async {
    try {
      final html = await _session.getHtml(Uri.parse('${await _base}/industry'));
      final tabStart = html.indexOf('id="production_tab"');
      final tabEnd = tabStart == -1 ? html.length : html.indexOf('class="tab-pane', tabStart + 1);
      final tabHtml = tabStart == -1 ? html : html.substring(tabStart, tabEnd == -1 ? html.length : tabEnd);

      final packing = <PackingHistoryRow>[];
      for (final rowHtml in _dataRows(_sliceTable(tabHtml, 'Packing History'))) {
        final tds = _tds(rowHtml);
        if (tds.length < 4) continue;
        packing.add(PackingHistoryRow(
          date: _stripTags(tds[0]),
          machineName: _stripTags(tds[1]),
          isReject: tds[2].contains('label-warning'),
          cartonsPacked: int.tryParse(_stripTags(tds[3])) ?? 0,
        ));
      }

      final issues = <IssueHistoryRow>[];
      for (final rowHtml in _dataRows(_sliceTable(tabHtml, 'Issue History'))) {
        final tds = _tds(rowHtml);
        if (tds.length < 5) continue;
        final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(rowHtml);
        issues.add(IssueHistoryRow(
          issueId: int.tryParse(idMatch?.group(1) ?? '') ?? 0,
          issuedDate: _stripTags(tds[0]),
          machineName: _stripTags(tds[1]),
          isReject: tds[2].contains('label-warning'),
          quantityIssued: int.tryParse(_stripTags(tds[3])) ?? 0,
          isIssued: tds[4].contains('label-success'),
          canReverse: tds.length > 5 && tds[5].contains('reverse_issue_button'),
        ));
      }

      final production = <ProductionHistoryRow>[];
      for (final rowHtml in _dataRows(_sliceTable(tabHtml, 'Production History'))) {
        final tds = _tds(rowHtml).map(_stripTags).toList();
        if (tds.length < 3) continue;
        production.add(ProductionHistoryRow(
          date: tds[0],
          machineName: tds[1],
          quantityProduced: int.tryParse(tds[2]) ?? 0,
        ));
      }

      final welding = <WeldingHistoryRow>[];
      for (final rowHtml in _dataRows(_sliceTable(tabHtml, 'Welding History'))) {
        final tds = _tds(rowHtml).map(_stripTags).toList();
        if (tds.length < 2) continue;
        welding.add(WeldingHistoryRow(date: tds[0], strapsWelded: int.tryParse(tds[1]) ?? 0));
      }

      return ApiResponse.success(
        data: ProductionHistoryData(packing: packing, issues: issues, production: production, welding: welding),
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============ SETTINGS: read via HTML (no JSON GET exists), write via POST ============

  Future<ApiResponse<IndustrySettings>> getSettingsValues() async {
    try {
      final html = await _session.getHtml(Uri.parse('${await _base}/industry'));
      final tabStart = html.indexOf('id="settings_tab"');
      final tabEnd = tabStart == -1 ? html.length : html.indexOf('class="tab-pane', tabStart + 1);
      final settingsHtml = tabStart == -1 ? html : html.substring(tabStart, tabEnd == -1 ? html.length : tabEnd);

      return ApiResponse.success(
        data: IndustrySettings(
          dailyRate: _extractInputValue(html, 'casual_labourer_daily_rate') ?? '8000',
          weekStartDay: _extractSelectedOption(html, 'casual_labourer_week_start_day') ?? '1',
          weekEndDay: _extractSelectedOption(html, 'casual_labourer_week_end_day') ?? '6',
          clockInTime: _extractInputValue(html, 'casual_labourer_clock_in_time') ?? '',
          clockOutTime: _extractInputValue(html, 'casual_labourer_clock_out_time') ?? '',
          lateGraceMinutes: _extractInputValue(html, 'casual_labourer_late_grace_minutes') ?? '0',
          latePenaltyMode: _extractSelectedOption(html, 'casual_labourer_late_penalty_mode') ?? 'flat',
          latePenaltyAmount: _extractInputValue(html, 'casual_labourer_late_penalty_amount') ?? '0',
          latePenaltyBlockMinutes:
              _extractInputValue(html, 'casual_labourer_late_penalty_block_minutes') ?? '1',
          mattressStrapsPerMattress: _extractInputValue(html, 'mattress_straps_per_mattress') ?? '1',
          rollerStrapsPerBig: _extractInputValue(html, 'roller_straps_per_big') ?? '1',
          rollerStrapsPerSmall: _extractInputValue(html, 'roller_straps_per_small') ?? '1',
          rollerPcsPerStrap: _extractInputValue(html, 'roller_pcs_per_strap') ?? '1',
          rollerPcsPerBig: _extractInputValue(html, 'roller_pcs_per_big') ?? '1',
          rollerPcsPerSmall: _extractInputValue(html, 'roller_pcs_per_small') ?? '1',
          labourerTypes: _parseLabourerTypes(settingsHtml),
          productionLines: _parseProductionLines(settingsHtml),
          machineLineLinks: _parseMachineLineLinks(settingsHtml),
          packingProductLinks: _parsePackingProductLinks(settingsHtml),
        ),
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Slices out one panel's <table>...</table> by searching for its unique
  /// heading text (these panels share icon classes, e.g. two use
  /// glyphicon-link, so text is the only stable per-panel anchor available).
  String _sliceTable(String html, String headingText) {
    final idx = html.indexOf(headingText);
    if (idx == -1) return '';
    final tableStart = html.indexOf('<table', idx);
    if (tableStart == -1) return '';
    final tableEnd = html.indexOf('</table>', tableStart);
    return tableEnd == -1 ? html.substring(tableStart) : html.substring(tableStart, tableEnd);
  }

  List<String> _dataRows(String tableHtml) =>
      RegExp(r'<tr>\s*<td>.*?</tr>', dotAll: true).allMatches(tableHtml).map((m) => m.group(0)!).toList();

  List<String> _tds(String rowHtml) =>
      RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true).allMatches(rowHtml).map((m) => m.group(1) ?? '').toList();

  List<LabourerTypeRow> _parseLabourerTypes(String html) {
    final table = _sliceTable(html, 'Aina za Kazi (Labourer Types)');
    final rows = <LabourerTypeRow>[];
    for (final rowHtml in _dataRows(table)) {
      final tds = _tds(rowHtml);
      if (tds.length < 3) continue;
      final idMatch = RegExp(r'labourer_type_id=(\d+)|labourer_type_delete.*?data-id="(\d+)"', dotAll: true)
          .firstMatch(rowHtml);
      final id = int.tryParse(idMatch?.group(1) ?? idMatch?.group(2) ?? '') ?? 0;
      rows.add(LabourerTypeRow(
        id: id,
        name: _stripTags(tds[0]),
        payModelLabel: _stripTags(tds[1]),
        labourerCount: int.tryParse(_stripTags(tds[2])) ?? 0,
      ));
    }
    return rows;
  }

  List<ProductionLineRow> _parseProductionLines(String html) {
    final table = _sliceTable(html, 'Lines za Uzalishaji (Production Lines)');
    final rows = <ProductionLineRow>[];
    for (final rowHtml in _dataRows(table)) {
      final tds = _tds(rowHtml);
      if (tds.length < 3) continue;
      final idMatch = RegExp(r'production_line_delete.*?data-id="(\d+)"', dotAll: true).firstMatch(rowHtml);
      rows.add(ProductionLineRow(
        id: int.tryParse(idMatch?.group(1) ?? '') ?? 0,
        name: _stripTags(tds[0]),
        labourerCount: int.tryParse(_stripTags(tds[1])) ?? 0,
        machineCount: int.tryParse(_stripTags(tds[2])) ?? 0,
      ));
    }
    return rows;
  }

  List<MachineLineLink> _parseMachineLineLinks(String html) {
    final table = _sliceTable(html, 'Mashine - Kuunganisha na Line');
    final rows = <MachineLineLink>[];
    for (final rowHtml in _dataRows(table)) {
      final tds = _tds(rowHtml);
      if (tds.length < 2) continue;
      final machineIdMatch = RegExp(r'data-machine-id="(\d+)"').firstMatch(tds[1]);
      final machineId = int.tryParse(machineIdMatch?.group(1) ?? '') ?? 0;
      final options = RegExp('<option value="([^"]*)"[^>]*>([^<]*)</option>', caseSensitive: false)
          .allMatches(tds[1])
          .map((m) => DropdownOption(m.group(1) ?? '', (m.group(2) ?? '').trim()))
          .toList();
      final selectedMatch = RegExp('<option value="([^"]*)"[^>]*selected').firstMatch(tds[1]);
      rows.add(MachineLineLink(
        machineId: machineId,
        name: _stripTags(tds[0]),
        lineId: selectedMatch?.group(1) ?? '',
        lineOptions: options,
      ));
    }
    return rows;
  }

  List<PackingProductLink> _parsePackingProductLinks(String html) {
    final table = _sliceTable(html, 'Packing Products - Kuunganisha na Items');
    final rows = <PackingProductLink>[];
    for (final rowHtml in _dataRows(table)) {
      final tds = _tds(rowHtml);
      if (tds.length < 2) continue;
      final productIdMatch = RegExp(r'data-product-id="(\d+)"').firstMatch(tds[1]);
      final itemNameMatch = RegExp('packing_item_link_name[^>]*value="([^"]*)"').firstMatch(tds[1]);
      final itemIdMatch = RegExp('packing_item_link_id[^>]*value="([^"]*)"').firstMatch(tds[1]);
      rows.add(PackingProductLink(
        productId: int.tryParse(productIdMatch?.group(1) ?? '') ?? 0,
        name: _stripTags(tds[0]),
        itemId: itemIdMatch?.group(1) ?? '',
        itemName: itemNameMatch?.group(1) ?? '',
      ));
    }
    return rows;
  }

  Future<ApiResponse<Map<String, dynamic>>> saveLabourerType({required String name, required String payModel}) async {
    final uri = Uri.parse('${await _base}/labourer_types/save');
    return _post(uri, {'name': name, 'pay_model': payModel});
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteLabourerType(int id) async {
    final uri = Uri.parse('${await _base}/labourer_types/delete/$id');
    return _post(uri, {});
  }

  Future<ApiResponse<Map<String, dynamic>>> saveProductionLine(String name) async {
    final uri = Uri.parse('${await _base}/production_lines/save');
    return _post(uri, {'name': name});
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteProductionLine(int id) async {
    final uri = Uri.parse('${await _base}/production_lines/delete/$id');
    return _post(uri, {});
  }

  Future<ApiResponse<Map<String, dynamic>>> saveMachineLine({required int machineId, required String lineId}) async {
    final uri = Uri.parse('${await _base}/machines/save_line/$machineId');
    return _post(uri, {'line_id': lineId});
  }

  Future<ApiResponse<Map<String, dynamic>>> savePackingProductItemLink({
    required int productId,
    required String itemName,
  }) async {
    final uri = Uri.parse('${await _base}/packing_products/save_item_link/$productId');
    return _post(uri, {'item_id': '', 'item_name': itemName});
  }

  String? _extractInputValue(String html, String fieldName) {
    final match = RegExp(
      'name="$fieldName"[^>]*value="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) return match.group(1);
    // Some inputs list value before name - try the reverse order too.
    final reversed = RegExp(
      'value="([^"]*)"[^>]*name="$fieldName"',
      caseSensitive: false,
    ).firstMatch(html);
    return reversed?.group(1);
  }

  String? _extractSelectedOption(String html, String fieldName) {
    final selectMatch = RegExp(
      'name="$fieldName".*?</select>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (selectMatch == null) return null;
    final optionMatch =
        RegExp('<option value="([^"]*)"[^>]*selected').firstMatch(selectMatch.group(0)!);
    return optionMatch?.group(1);
  }

  Future<ApiResponse<Map<String, dynamic>>> saveWagesSettings({
    required String dailyRate,
    required String weekStartDay,
    required String weekEndDay,
    required String clockInTime,
    required String clockOutTime,
    required String lateGraceMinutes,
    required String latePenaltyMode,
    required String latePenaltyAmount,
    required String latePenaltyBlockMinutes,
  }) async {
    final uri = Uri.parse('${await _base}/wages/save_settings');
    return _post(uri, {
      'casual_labourer_daily_rate': dailyRate,
      'casual_labourer_week_start_day': weekStartDay,
      'casual_labourer_week_end_day': weekEndDay,
      'casual_labourer_clock_in_time': clockInTime,
      'casual_labourer_clock_out_time': clockOutTime,
      'casual_labourer_late_grace_minutes': lateGraceMinutes,
      'casual_labourer_late_penalty_mode': latePenaltyMode,
      'casual_labourer_late_penalty_amount': latePenaltyAmount,
      'casual_labourer_late_penalty_block_minutes': latePenaltyBlockMinutes,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> saveProductionRatioSettings({
    required String mattressStrapsPerMattress,
    required String rollerStrapsPerBig,
    required String rollerStrapsPerSmall,
    required String rollerPcsPerStrap,
    required String rollerPcsPerBig,
    required String rollerPcsPerSmall,
  }) async {
    final uri = Uri.parse('${await _base}/production/save_ratio_settings');
    return _post(uri, {
      'mattress_straps_per_mattress': mattressStrapsPerMattress,
      'roller_straps_per_big': rollerStrapsPerBig,
      'roller_straps_per_small': rollerStrapsPerSmall,
      'roller_pcs_per_strap': rollerPcsPerStrap,
      'roller_pcs_per_big': rollerPcsPerBig,
      'roller_pcs_per_small': rollerPcsPerSmall,
    });
  }

  /// CI reads `$this->input->post('ids')` as a PHP array, which requires the
  /// classic `ids[]=1&ids[]=2` form encoding - http.post's Map<String,String>
  /// body can't repeat a key, so this builds the request manually.
  Future<ApiResponse<Map<String, dynamic>>> _postWithArrayField(
    Uri uri,
    String fieldName,
    List<String> values,
  ) async {
    final fields = <String, String>{};
    for (var i = 0; i < values.length; i++) {
      fields['$fieldName[$i]'] = values[i];
    }
    return _post(uri, fields);
  }

  // ============ LINES / TIMU (read-only, scraped from the Industry page - no JSON endpoint) ============

  Future<ApiResponse<List<ProductionLineGroup>>> getLines() async {
    try {
      final html = await _session.getHtml(Uri.parse('${await _base}/industry'));
      return ApiResponse.success(data: _parseLines(html));
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// 'col-md-6 col-lg-4' is lines.php's own grid-column class and is
  /// unique sitewide (confirmed against every other industry view), unlike
  /// the generic 'panel panel-default' class every Settings panel also
  /// uses - matching on that generic class previously pulled in Settings'
  /// Labourer Types/Production Lines/etc. panels as fake "lines" here. Each
  /// card is bounded by the next card's marker (or, for the last card, the
  /// next tab-pane) so extraction never reads into an unrelated section.
  List<ProductionLineGroup> _parseLines(String html) {
    final markers = RegExp('class="col-md-6 col-lg-4"').allMatches(html).toList();
    final groups = <ProductionLineGroup>[];

    for (var i = 0; i < markers.length; i++) {
      final start = markers[i].end;
      int end;
      if (i + 1 < markers.length) {
        end = markers[i + 1].start;
      } else {
        final nextTab = html.indexOf('class="tab-pane', start);
        end = nextTab == -1 ? html.length : nextTab;
      }
      final panel = html.substring(start, end);

      final titleMatch = RegExp(r'panel-title[^>]*>.*?</span>\s*([^<]+)</h4>', dotAll: true).firstMatch(panel);
      final name = titleMatch?.group(1)?.trim() ?? '';
      if (name.isEmpty) continue;

      final strongParts = panel.split('<strong>');
      final labourersBlock = strongParts.length > 1 ? strongParts[1] : '';
      final machinesBlock = strongParts.length > 2 ? strongParts[2] : '';

      final labourers = <LineLabourer>[];
      for (final li in RegExp(r'<li>(.*?)</li>', dotAll: true).allMatches(labourersBlock)) {
        final content = li.group(1) ?? '';
        final present = content.contains('ok-circle');
        final labourerName = content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        if (labourerName.isEmpty) continue;
        labourers.add(LineLabourer(casualLabourerId: 0, name: labourerName, present: present));
      }

      final machines = <String>[];
      for (final li in RegExp(r'<li>(.*?)</li>', dotAll: true).allMatches(machinesBlock)) {
        final content = li.group(1) ?? '';
        final machineName = content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        if (machineName.isNotEmpty) machines.add(machineName);
      }

      // Only the named-line cards render the 3-stat row (Wapo Leo/Mashine/PC
      // Leo); the Bila Line card skips it entirely - so its absence here is
      // the language-agnostic signal for "this is the unassigned bucket".
      final statNumbers =
          RegExp(r'font-size:20px;">([^<]*)</div>').allMatches(panel).map((m) => m.group(1) ?? '').toList();
      final producedText = statNumbers.length > 2 ? statNumbers[2] : '0';
      final produced = int.tryParse(producedText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      groups.add(ProductionLineGroup(
        name: name,
        labourers: labourers,
        machineNames: machines,
        producedToday: produced,
        isUnassigned: statNumbers.isEmpty,
      ));
    }

    return groups;
  }

  // ============ WAGES VERIFICATION ============

  Future<ApiResponse<Map<String, dynamic>>> verifyWage(int casualLabourerId) async {
    final uri = Uri.parse('${await _base}/wages/verify/$casualLabourerId');
    return _post(uri, {});
  }

  /// Wages tab's "Current Week" view (Casual_labourer_payment::get_weekly_status(),
  /// grouped by Labourer Type) - no JSON endpoint exists for this, it is
  /// only ever rendered as part of the Industry index page's wages_tab.
  /// Scraped per the same pattern as getSettingsValues/Stock Transfers,
  /// anchored on stable markers (stat-tile classes, label classes, data-id
  /// attributes, column text that's fixed in English in the source even
  /// though the UI mixes Swahili) rather than translated text.
  Future<ApiResponse<WagesWeekData>> getWagesCurrentWeek({String? weekDate}) async {
    try {
      final uri = Uri.parse('${await _base}/industry').replace(
        queryParameters: weekDate != null ? {'wages_date': weekDate} : null,
      );
      final html = await _session.getHtml(uri);
      return ApiResponse.success(data: _parseWagesWeek(html));
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  double _parseCurrency(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  String _formatCurrency(double v) {
    final fixed = v.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return 'Tshs $whole.${parts[1]}';
  }

  /// Every anchor here (wages_type_* ids, the wages/verification_history
  /// link, the wages_date input, the verify modal id) is unique sitewide,
  /// so this parses straight from the full page rather than first slicing
  /// out a wages_tab/tab-content region - that slicing is what silently
  /// produced zero groups when the per-tab boundary search went wrong, and
  /// these ids can't collide with other Industry tabs (General/Stock also
  /// use stat-tile spans, which is why group totals are summed from each
  /// row's own amount instead of re-scraping stat-tile text).
  WagesWeekData _parseWagesWeek(String html) {
    final weekRangeMatch =
        RegExp(r'&mdash;\s*(.*?)\s*<a href="[^"]*wages/verification_history', dotAll: true).firstMatch(html);
    final weekRangeDisplay = weekRangeMatch?.group(1)?.trim() ?? '';

    final isCurrentWeek = !RegExp('Viewing a past week', caseSensitive: false).hasMatch(html);

    final referenceDate = _extractInputValue(html, 'wages_date') ?? '';

    // tab id -> display name, from the <ul class="nav nav-tabs"> list.
    final tabNames = <String, String>{};
    for (final m in RegExp(r'href="#(wages_type_[^"]+)">([^<]*)</a>').allMatches(html)) {
      tabNames[m.group(1) ?? ''] = (m.group(2) ?? '').trim();
    }

    final modalStart = html.indexOf('id="wages_verify_modal"');
    final searchEnd = modalStart == -1 ? html.length : modalStart;

    final paneStarts = RegExp(r'<div class="tab-pane[^"]*" id="(wages_type_[^"]+)">')
        .allMatches(html, 0)
        .where((m) => m.start < searchEnd)
        .toList();

    final groups = <WagesWeekGroup>[];
    double grandTotalUnpaid = 0;
    for (var i = 0; i < paneStarts.length; i++) {
      final id = paneStarts[i].group(1) ?? '';
      final start = paneStarts[i].end;
      final end = i + 1 < paneStarts.length ? paneStarts[i + 1].start : searchEnd;
      final paneHtml = html.substring(start, end);
      final name = tabNames[id] ?? id;
      final isPieceRate = paneHtml.contains('CTN/Kibegi Packed');

      final rows = <WagesWeekRow>[];
      for (final rowMatch in RegExp(r'<tr>\s*<td>.*?</tr>', dotAll: true).allMatches(paneHtml)) {
        final rowHtml = rowMatch.group(0)!;
        final tds = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true)
            .allMatches(rowHtml)
            .map((m) => m.group(1) ?? '')
            .toList();
        if (tds.length < 8) continue;

        String stripTags(String s) => s.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

        final nameCell = tds[0];
        final isPaidFlag = !RegExp('Is Paid.*?No', caseSensitive: false, dotAll: true).hasMatch(nameCell);
        final rowName = stripTags(nameCell.split('<span').first);

        final verifyCell = tds[6];
        final verified = verifyCell.contains('label-success');
        final canVerify = !verified && verifyCell.contains('verify_button');

        final statusCell = tds[7];
        final paid = statusCell.contains('label-success');

        final markPaidCell = tds.length > 8 ? tds[8] : '';
        final canMarkPaid = markPaidCell.contains('mark_paid_button');

        final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(rowHtml);
        final casualLabourerId = int.tryParse(idMatch?.group(1) ?? '') ?? 0;

        rows.add(WagesWeekRow(
          casualLabourerId: casualLabourerId,
          name: rowName,
          isPaidFlag: isPaidFlag,
          quantityOrDays: stripTags(tds[1]),
          gross: stripTags(tds[2]),
          bonusOrPenalty: stripTags(tds[3]),
          bonusOrPenaltyIsNegative: tds[3].contains('text-danger'),
          adjustment: stripTags(tds[4]),
          amount: stripTags(tds[5]),
          verified: verified,
          canVerify: canVerify,
          paid: paid,
          canMarkPaid: canMarkPaid,
        ));
      }

      final groupUnpaid = rows.where((r) => !r.paid).fold<double>(0, (sum, r) => sum + _parseCurrency(r.amount));
      grandTotalUnpaid += groupUnpaid;

      groups.add(WagesWeekGroup(
        name: name,
        isPieceRate: isPieceRate,
        unpaidTotal: _formatCurrency(groupUnpaid),
        labourers: rows,
      ));
    }

    return WagesWeekData(
      weekRangeDisplay: weekRangeDisplay,
      referenceDate: referenceDate,
      isCurrentWeek: isCurrentWeek,
      totalUnpaid: _formatCurrency(grandTotalUnpaid),
      groups: groups,
    );
  }

  Future<ApiResponse<List<AttendanceDetailDay>>> getAttendanceDetail(int casualLabourerId) async {
    final result = await _getMap(Uri.parse('${await _base}/wages/attendance_detail/$casualLabourerId'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    final days = (result.data!['days'] as List? ?? [])
        .map((e) => AttendanceDetailDay.fromJson(e as Map<String, dynamic>))
        .toList();
    return ApiResponse.success(data: days);
  }

  /// wages/verification_history is a standalone server-rendered page (not
  /// an Industry tab), no JSON endpoint - scraped like Settings/Lines.
  Future<ApiResponse<List<WageVerificationRow>>> getVerificationHistory({
    String? startDate,
    String? endDate,
    String status = '',
  }) async {
    try {
      final base = await _base;
      final uri = Uri.parse('$base/wages/verification_history').replace(queryParameters: {
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (status.isNotEmpty) 'status': status,
      });
      final html = await _session.getHtml(uri);
      return ApiResponse.success(data: _parseVerificationHistory(html));
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  List<WageVerificationRow> _parseVerificationHistory(String html) {
    final tableMatch = RegExp(
      r'id="datatable".*?<tbody>(.*?)</tbody>',
      dotAll: true,
    ).firstMatch(html);
    if (tableMatch == null) return [];

    final rows = <WageVerificationRow>[];
    for (final rowMatch in RegExp(r'<tr>(.*?)</tr>', dotAll: true).allMatches(tableMatch.group(1)!)) {
      final rawCells = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true)
          .allMatches(rowMatch.group(1) ?? '')
          .map((m) => m.group(1) ?? '')
          .toList();
      if (rawCells.length < 9) continue;

      final cells = rawCells.map((c) => c.replaceAll(RegExp(r'<[^>]*>'), '').trim()).toList();
      final weekParts = cells[1].split(' - ');
      rows.add(WageVerificationRow(
        labourerName: cells[0],
        weekStartDate: weekParts.isNotEmpty ? weekParts[0] : '',
        weekEndDate: weekParts.length > 1 ? weekParts[1] : '',
        daysAttended: int.tryParse(cells[2]) ?? 0,
        amount: double.tryParse(cells[3].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
        verifiedByName: cells[4],
        verifiedAt: cells[5],
        // "Paid"/"Unpaid" text is translated - the label-success/label-warning
        // CSS class on the raw (pre-strip) cell is the stable signal.
        paid: rawCells[6].contains('label-success'),
        paidByName: cells[7] == '-' ? null : cells[7],
        paidDate: cells[8] == '-' ? null : cells[8],
      ));
    }
    return rows;
  }

  // ============ PACKING ============

  Future<ApiResponse<PackingMaterialStockEntry>> getMaterialStock(int productId, String date) async {
    final result = await _getMap(Uri.parse('${await _base}/packing/get_material_stock/$productId/$date'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: PackingMaterialStockEntry.fromJson(result.data!));
  }

  Future<ApiResponse<PackingOutputBulkData>> getOutputBulk(int productId, String date) async {
    final result = await _getMap(Uri.parse('${await _base}/packing/get_output_bulk/$productId/$date'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: PackingOutputBulkData.fromJson(result.data!));
  }

  Future<ApiResponse<Map<String, dynamic>>> saveOutputBulk({
    required int productId,
    required String outputDate,
    required Map<int, int> entries, // labourerId -> quantityPacked
  }) async {
    final uri = Uri.parse('${await _base}/packing/save_output_bulk');
    final fields = <String, String>{
      'product_id': productId.toString(),
      'output_date': outputDate,
    };
    entries.forEach((labourerId, qty) {
      fields['entries[$labourerId]'] = qty.toString();
    });
    return _post(uri, fields);
  }

  Future<ApiResponse<Map<String, dynamic>>> receivePackingMaterial({
    required int productId,
    required String receiptDate,
    required int fillerBagsReceived,
    required int boxBagsReceived,
    String note = '',
  }) async {
    final uri = Uri.parse('${await _base}/packing/receive_material');
    return _post(uri, {
      'product_id': productId.toString(),
      'receipt_date': receiptDate,
      'filler_bags_received': fillerBagsReceived.toString(),
      'box_bags_received': boxBagsReceived.toString(),
      'note': note,
    });
  }

  /// Returns a bare JSON array, not an object.
  Future<ApiResponse<List<PackingStockRow>>> getPackingStock() async {
    try {
      final list = await _session.getJsonList(Uri.parse('${await _base}/packing/get_stock'));
      return ApiResponse.success(
        data: list.map((e) => PackingStockRow.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> issuePackingBatch(List<Map<String, dynamic>> items) async {
    final uri = Uri.parse('${await _base}/packing/issue_batch');
    // items -> [{product_id, quantity}] as a JSON string field, per web's contract.
    final itemsJson = items
        .map((i) => '{"product_id":${i['product_id']},"quantity":${i['quantity']}}')
        .join(',');
    return _post(uri, {'items': '[$itemsJson]'});
  }

  Future<ApiResponse<Map<String, dynamic>>> reversePackingIssue(int issueId) async {
    final uri = Uri.parse('${await _base}/packing/reverse_issue/$issueId');
    return _post(uri, {});
  }

  Future<ApiResponse<Map<String, dynamic>>> confirmPackingIssue(int issueId) async {
    final uri = Uri.parse('${await _base}/packing/confirm_issue/$issueId');
    return _post(uri, {});
  }

  Future<ApiResponse<Map<String, dynamic>>> cancelPackingIssue(int issueId) async {
    final uri = Uri.parse('${await _base}/packing/cancel_issue/$issueId');
    return _post(uri, {});
  }

  // Packing Products CRUD (Settings-adjacent management list)
  Future<ApiResponse<Map<String, dynamic>>> searchPackingProducts({
    String search = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('${await _base}/packing_products/search').replace(
      queryParameters: {'search': search, 'limit': limit.toString(), 'offset': offset.toString()},
    );
    return _getMap(uri);
  }

  Future<ApiResponse<PackingProduct>> getPackingProduct(int id) async {
    final result = await _getMap(Uri.parse('${await _base}/packing_products/get_row/$id'));
    if (!result.isSuccess || result.data == null) {
      return ApiResponse.error(message: result.message, statusCode: result.statusCode);
    }
    return ApiResponse.success(data: PackingProduct.fromJson(result.data!));
  }

  Future<ApiResponse<Map<String, dynamic>>> savePackingProduct({
    int? id,
    required Map<String, String> fields,
  }) async {
    final uri = Uri.parse('${await _base}/packing_products/save/${id ?? -1}');
    return _post(uri, fields);
  }

  /// Full editable form, scraped from packing_products/view/{id}'s rendered
  /// form.php - get_row only returns display-formatted combined strings
  /// (e.g. middle_ratio="30 PC = 1 OUTER"), not the raw editable fields.
  Future<ApiResponse<PackingProductFormData>> getPackingProductForm(int id) async {
    try {
      final html = await _session.getHtml(Uri.parse('${await _base}/packing_products/view/$id'));
      return ApiResponse.success(
        data: PackingProductFormData(
          name: _extractInputValue(html, 'name') ?? '',
          unitsPerPc: _extractInputValue(html, 'units_per_pc') ?? '',
          unitLabel: _extractInputValue(html, 'unit_label') ?? '',
          middleQty: _extractInputValue(html, 'middle_qty') ?? '',
          middleLabel: _extractInputValue(html, 'middle_label') ?? '',
          outerQty: _extractInputValue(html, 'outer_qty') ?? '',
          outerLabel: _extractInputValue(html, 'outer_label') ?? '',
          payRatePerUnit: _extractInputValue(html, 'pay_rate_per_unit') ?? '',
          bonusThresholdUnits: _extractInputValue(html, 'bonus_threshold_units') ?? '',
          bonusAmountPerUnit: _extractInputValue(html, 'bonus_amount_per_unit') ?? '',
          fillerBagPcCapacity: _extractInputValue(html, 'filler_bag_pc_capacity') ?? '',
          boxBagPcCapacity: _extractInputValue(html, 'box_bag_pc_capacity') ?? '',
          itemId: _extractInputValue(html, 'item_id') ?? '',
          itemName: _extractInputValue(html, 'item_name') ?? '',
        ),
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> deletePackingProducts(List<int> ids) async {
    final uri = Uri.parse('${await _base}/packing_products/delete');
    return _postWithArrayField(uri, 'ids', ids.map((e) => e.toString()).toList());
  }

  /// Packing tab's 3 history tables - no JSON endpoint exists, scraped from
  /// the Industry page. Scoped to id="packing_tab" first since "Issue
  /// History" also appears verbatim on the Production tab. Output History
  /// is date-range filtered server-side via the same GET params the web's
  /// own "Filter" button submits.
  Future<ApiResponse<PackingHistoryData>> getPackingHistory({String? startDate, String? endDate}) async {
    try {
      final uri = Uri.parse('${await _base}/industry').replace(
        queryParameters: (startDate != null && endDate != null)
            ? {'output_start_date': startDate, 'output_end_date': endDate}
            : null,
      );
      final html = await _session.getHtml(uri);
      final tabStart = html.indexOf('id="packing_tab"');
      final tabEnd = tabStart == -1 ? html.length : html.indexOf('class="tab-pane', tabStart + 1);
      final tabHtml = tabStart == -1 ? html : html.substring(tabStart, tabEnd == -1 ? html.length : tabEnd);

      final output = <PackingOutputHistoryRow>[];
      for (final rowHtml in _dataRows(_sliceTable(tabHtml, 'Packing Output History'))) {
        final tds = _tds(rowHtml);
        if (tds.length < 6) continue;
        output.add(PackingOutputHistoryRow(
          date: _stripTags(tds[0]),
          labourerName: _stripTags(tds[1].split('<span').first),
          isPaid: !tds[1].contains('Is Paid'),
          productName: _stripTags(tds[2]),
          quantityPacked: _stripTags(tds[3]),
          bonus: _stripTags(tds[4]),
          pay: _stripTags(tds[5]),
        ));
      }

      final issues = <PackingIssueHistoryRow>[];
      for (final rowHtml in _dataRows(_sliceTable(tabHtml, 'Issue History'))) {
        final tds = _tds(rowHtml);
        if (tds.length < 5) continue;
        final statusCell = tds[3];
        String status;
        if (statusCell.contains('label-warning')) {
          status = 'pending';
        } else if (statusCell.contains('label-success')) {
          status = 'issued';
        } else {
          status = 'reversed';
        }
        final actionCell = tds[4];
        final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(actionCell);
        issues.add(PackingIssueHistoryRow(
          issueId: int.tryParse(idMatch?.group(1) ?? '') ?? 0,
          date: _stripTags(tds[0]),
          productName: _stripTags(tds[1]),
          quantityIssued: int.tryParse(_stripTags(tds[2])) ?? 0,
          status: status,
          canConfirmOrCancel: actionCell.contains('packing_confirm_issue_button'),
          canReverse: actionCell.contains('packing_reverse_issue_button'),
        ));
      }

      final receipts = <PackingMaterialReceiptRow>[];
      for (final rowHtml in _dataRows(_sliceTable(tabHtml, 'Material Receipt History'))) {
        final tds = _tds(rowHtml).map(_stripTags).toList();
        if (tds.length < 5) continue;
        receipts.add(PackingMaterialReceiptRow(
          productName: tds[0],
          date: tds[1],
          fillerBagsReceived: int.tryParse(tds[2]) ?? 0,
          boxBagsReceived: int.tryParse(tds[3]) ?? 0,
          note: tds[4],
        ));
      }

      return ApiResponse.success(data: PackingHistoryData(output: output, issues: issues, receipts: receipts));
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }
}
