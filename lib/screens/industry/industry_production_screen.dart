import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';
import 'industry_stock_section_view.dart';

const _typeOptions = [
  DropdownOption('normal', 'Nzima (Normal)'),
  DropdownOption('reject', 'Mbovu (Reject)'),
];

/// Full carbon-copy of application/views/industry/production.php: Chomwa
/// (Welding, read-only), Record Production, Dozens Packing, Carton
/// Packing, Issue, and the 4 history tables below.
class IndustryProductionScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryProductionScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryProductionScreen> createState() => _IndustryProductionScreenState();
}

class _IndustryProductionScreenState extends State<IndustryProductionScreen> {
  List<Map<String, dynamic>> _machines = [];
  bool _isLoading = false;
  String? _errorMessage;
  ProductionHistoryData? _history;

  // Welding (read-only)
  DateTime _weldingDate = DateTime.now();
  WeldingEntry? _welding;
  bool _isLoadingWelding = false;

  // Record Production
  int? _productionMachineId;
  DateTime _productionDate = DateTime.now();
  final _quantityProducedController = TextEditingController();
  bool _isLoadingProduction = false;
  bool _isSavingProduction = false;

  // Dozens Packing
  int? _dozensMachineId;
  String _dozensType = 'normal';
  DateTime _dozensDate = DateTime.now();
  final _dozensPackedController = TextEditingController();
  CurrentStockEntry? _dozensStock;
  int _dozensQuantityProducedToday = 0;
  bool _isLoadingDozens = false;
  bool _isSavingDozens = false;

  // Carton Packing
  int? _packingMachineId;
  String _packingType = 'normal';
  DateTime _packingDate = DateTime.now();
  final _cartonsPackedController = TextEditingController();
  int _packingDozensInHand = 0;
  bool _isLoadingPacking = false;
  bool _isSavingPacking = false;

  // Issue
  int? _issueMachineId;
  String _issueType = 'normal';
  final _issueQuantityController = TextEditingController(text: '1');
  CurrentStockEntry? _issueStock;
  bool _isLoadingIssueStock = false;
  bool _isIssuing = false;
  int? _reversingIssueId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMachines());
    _dozensPackedController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _quantityProducedController.dispose();
    _dozensPackedController.dispose();
    _cartonsPackedController.dispose();
    _issueQuantityController.dispose();
    super.dispose();
  }

  Future<void> _loadMachines() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await widget.service.searchMachines(limit: 200);
    if (!mounted) return;

    if (response.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    if (!response.isSuccess || response.data == null) {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
      return;
    }

    final rows = (response.data!['rows'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final firstId = rows.isNotEmpty ? int.tryParse(rows.first['machine_id']?.toString() ?? '') : null;

    setState(() {
      _machines = rows;
      _productionMachineId = firstId;
      _dozensMachineId = firstId;
      _packingMachineId = firstId;
      _issueMachineId = firstId;
      _isLoading = false;
    });

    final historyResponse = await widget.service.getProductionHistory();
    if (mounted && historyResponse.isSuccess) {
      setState(() => _history = historyResponse.data);
    }

    await Future.wait([_loadWelding(), _loadProduction(), _loadDozens(), _loadPacking(), _loadIssueStock()]);
  }

  Future<void> _loadWelding() async {
    setState(() => _isLoadingWelding = true);
    final response = await widget.service.getWelding(DateFormat('yyyy-MM-dd').format(_weldingDate));
    if (!mounted) return;
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    setState(() {
      if (response.isSuccess) _welding = response.data;
      _isLoadingWelding = false;
    });
  }

  Future<void> _loadProduction() async {
    final machineId = _productionMachineId;
    if (machineId == null) return;
    setState(() => _isLoadingProduction = true);
    final response =
        await widget.service.getProduction(machineId, DateFormat('yyyy-MM-dd').format(_productionDate));
    if (!mounted) return;
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess && response.data != null) {
      setState(() {
        _quantityProducedController.text = '${response.data!['quantity_produced'] ?? 0}';
        _isLoadingProduction = false;
      });
    } else {
      setState(() => _isLoadingProduction = false);
    }
  }

  Future<void> _loadDozens() async {
    final machineId = _dozensMachineId;
    if (machineId == null) return;
    setState(() => _isLoadingDozens = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_dozensDate);
    final dozensResponse = await widget.service.getDozens(machineId, dateStr, type: _dozensType);
    final productionResponse = await widget.service.getProduction(machineId, dateStr);
    final stockResponse = await widget.service.getCurrentStock(machineId);

    if (!mounted) return;
    if (dozensResponse.statusCode == 440 || stockResponse.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }

    setState(() {
      if (dozensResponse.isSuccess && dozensResponse.data != null) {
        _dozensPackedController.text = '${dozensResponse.data!['dozens_packed'] ?? 0}';
      }
      if (productionResponse.isSuccess && productionResponse.data != null) {
        _dozensQuantityProducedToday = int.tryParse('${productionResponse.data!['quantity_produced'] ?? 0}') ?? 0;
      }
      if (stockResponse.isSuccess) _dozensStock = stockResponse.data;
      _isLoadingDozens = false;
    });
  }

  Future<void> _loadPacking() async {
    final machineId = _packingMachineId;
    if (machineId == null) return;
    setState(() => _isLoadingPacking = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_packingDate);
    final packingResponse = await widget.service.getPacking(machineId, dateStr, type: _packingType);
    final dozensResponse = await widget.service.getDozens(machineId, dateStr, type: _packingType);

    if (!mounted) return;
    if (packingResponse.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }

    setState(() {
      if (packingResponse.isSuccess && packingResponse.data != null) {
        _cartonsPackedController.text = '${packingResponse.data!['cartons_packed'] ?? 0}';
      }
      if (dozensResponse.isSuccess && dozensResponse.data != null) {
        _packingDozensInHand = int.tryParse('${dozensResponse.data!['dozens_in_hand'] ?? 0}') ?? 0;
      }
      _isLoadingPacking = false;
    });
  }

  Future<void> _loadIssueStock() async {
    final machineId = _issueMachineId;
    if (machineId == null) return;
    setState(() => _isLoadingIssueStock = true);
    final response = await widget.service.getCurrentStock(machineId);
    if (!mounted) return;
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    setState(() {
      if (response.isSuccess) _issueStock = response.data;
      _isLoadingIssueStock = false;
    });
  }

  Future<void> _pickDate(DateTime current, void Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) onPicked(picked);
  }

  void _showResult(bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: success ? Colors.green : Colors.red),
    );
  }

  Future<void> _refreshHistory() async {
    final response = await widget.service.getProductionHistory();
    if (mounted && response.isSuccess) setState(() => _history = response.data);
  }

  Future<void> _submitProduction() async {
    final machineId = _productionMachineId;
    if (machineId == null) return;
    setState(() => _isSavingProduction = true);
    final response = await widget.service.saveProduction(
      machineId: machineId,
      productionDate: DateFormat('yyyy-MM-dd').format(_productionDate),
      quantityProduced: int.tryParse(_quantityProducedController.text) ?? 0,
    );
    if (!mounted) return;
    setState(() => _isSavingProduction = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) {
      await Future.wait([_loadProduction(), _loadWelding(), _refreshHistory()]);
    }
  }

  Future<void> _submitDozens() async {
    final machineId = _dozensMachineId;
    if (machineId == null) return;
    setState(() => _isSavingDozens = true);
    final response = await widget.service.saveDozens(
      machineId: machineId,
      packingDate: DateFormat('yyyy-MM-dd').format(_dozensDate),
      dozensPacked: int.tryParse(_dozensPackedController.text) ?? 0,
      type: _dozensType,
    );
    if (!mounted) return;
    setState(() => _isSavingDozens = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) await _loadDozens();
  }

  Future<void> _submitPacking() async {
    final machineId = _packingMachineId;
    if (machineId == null) return;
    setState(() => _isSavingPacking = true);
    final response = await widget.service.savePacking(
      machineId: machineId,
      packingDate: DateFormat('yyyy-MM-dd').format(_packingDate),
      cartonsPacked: int.tryParse(_cartonsPackedController.text) ?? 0,
      type: _packingType,
    );
    if (!mounted) return;
    setState(() => _isSavingPacking = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) await Future.wait([_loadPacking(), _refreshHistory()]);
  }

  Future<void> _submitIssue() async {
    final machineId = _issueMachineId;
    if (machineId == null) return;
    setState(() => _isIssuing = true);
    final response = await widget.service.issueCartons(
      machineId: machineId,
      quantity: int.tryParse(_issueQuantityController.text) ?? 0,
      type: _issueType,
    );
    if (!mounted) return;
    setState(() => _isIssuing = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) await Future.wait([_loadIssueStock(), _refreshHistory()]);
  }

  Future<void> _reverseIssue(int issueId) async {
    setState(() => _reversingIssueId = issueId);
    final response = await widget.service.reverseIssue(issueId);
    if (!mounted) return;
    setState(() => _reversingIssueId = null);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) await Future.wait([_loadIssueStock(), _refreshHistory()]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_machines.isEmpty && _errorMessage == null) {
      return const Center(child: Text('No machines configured yet - add one under Machines.'));
    }
    return _buildBody();
  }

  Widget _buildBody() {
    final dozensPossible = _dozensQuantityProducedToday ~/ 12;
    final ctnsPossible = _packingDozensInHand ~/ 40;

    return RefreshIndicator(
      onRefresh: _loadMachines,
      child: ListView(
        padding: industryScrollPadding(context),
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          _panel(icon: Icons.local_fire_department, title: 'Chomwa (Welding)', child: _buildWeldingSection()),
          const SizedBox(height: 16),
          _panel(icon: Icons.list_alt, title: 'Record Production', child: _buildProductionSection()),
          const SizedBox(height: 16),
          _panel(icon: Icons.grid_view, title: 'Dozens Packing', child: _buildDozensSection(dozensPossible)),
          const SizedBox(height: 16),
          _panel(icon: Icons.inbox_outlined, title: 'Carton Packing', child: _buildPackingSection(ctnsPossible)),
          const SizedBox(height: 16),
          _panel(icon: Icons.file_upload_outlined, title: 'Issue', child: _buildIssueSection()),
          const SizedBox(height: 16),
          _panel(icon: Icons.receipt_long, title: 'Packing History', child: _buildPackingHistoryTable()),
          const SizedBox(height: 16),
          _panel(icon: Icons.receipt_long, title: 'Issue History', child: _buildIssueHistoryTable()),
          const SizedBox(height: 16),
          _panel(icon: Icons.receipt_long, title: 'Production History', child: _buildProductionHistoryTable()),
          const SizedBox(height: 16),
          _panel(icon: Icons.receipt_long, title: 'Welding History', child: _buildWeldingHistoryTable()),
        ],
      ),
    );
  }

  // ---------------- Chomwa / Welding (read-only) ----------------

  Widget _buildWeldingSection() {
    final card = _welding?.stockCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stockCardRow(
          opening: card?.opening ?? 0,
          added: card?.added ?? 0,
          used: card?.used ?? 0,
          closing: card?.closing ?? 0,
          addedLabel: 'TRIMMED (ADDED)',
          usedLabel: 'WELDED (USED)',
        ),
        const SizedBox(height: 10),
        Text(
          'Auto -- inatokana na Roller Usage (Kuvisha) ya siku hiyo, hakuna kuingiza kwa mkono.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        _labeledDateField('Date', _weldingDate, (d) {
          setState(() => _weldingDate = d);
          _loadWelding();
        }),
        const SizedBox(height: 10),
        _labeledStatic('Straps Welded', '${_welding?.strapsWelded ?? 0}'),
        const SizedBox(height: 14),
        Text('Comparison', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: stockStatTile('${_welding?.expectedPcs ?? 0}', 'EXPECTED PCS (FROM STRAPS WELDED)')),
            const SizedBox(width: 10),
            Expanded(
              child: stockStatTile(
                '${_welding?.actualPcsProduced ?? 0}',
                'ACTUAL PCS PRODUCED (ALL MACHINES, THIS DATE)',
                accent: true,
              ),
            ),
          ],
        ),
        if (_isLoadingWelding)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  // ---------------- Record Production ----------------

  Widget _buildProductionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeledMachineDropdown('Machine', _productionMachineId, (id) {
          setState(() => _productionMachineId = id);
          _loadProduction();
        }),
        const SizedBox(height: 10),
        _labeledDateField('Date', _productionDate, (d) {
          setState(() => _productionDate = d);
          _loadProduction();
        }),
        const SizedBox(height: 10),
        _labeledField('Quantity Produced (pcs)', _quantityProducedController),
        const SizedBox(height: 12),
        if (_isLoadingProduction)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
        else
          _submitButton(_isSavingProduction, _submitProduction),
      ],
    );
  }

  // ---------------- Dozens Packing ----------------

  Widget _buildDozensSection(int dozensPossible) {
    final stock = _dozensStock ?? CurrentStockEntry.empty();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: stockStatTile('${stock.pcsInHand}', 'PCS IN HAND')),
            const SizedBox(width: 10),
            Expanded(child: stockStatTile('${stock.dozensInHand}', 'DOZENS IN HAND')),
            const SizedBox(width: 10),
            Expanded(child: stockStatTile('${stock.dozensInHandReject}', 'DOZENS IN HAND (MBOVU)')),
          ],
        ),
        const SizedBox(height: 14),
        _labeledMachineDropdown('Machine', _dozensMachineId, (id) {
          setState(() => _dozensMachineId = id);
          _loadDozens();
        }),
        const SizedBox(height: 10),
        _labeledTypeDropdown('Type', _dozensType, (v) {
          setState(() => _dozensType = v);
          _loadDozens();
        }),
        const SizedBox(height: 10),
        _labeledDateField('Date', _dozensDate, (d) {
          setState(() => _dozensDate = d);
          _loadDozens();
        }),
        const SizedBox(height: 10),
        _labeledField('Dozens Packed', _dozensPackedController),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '≈ $dozensPossible dozen(s) possible from pcs produced today (1 dozen = 12 pcs)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingDozens)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
        else
          _submitButton(_isSavingDozens, _submitDozens),
      ],
    );
  }

  // ---------------- Carton Packing ----------------

  Widget _buildPackingSection(int ctnsPossible) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeledMachineDropdown('Machine', _packingMachineId, (id) {
          setState(() => _packingMachineId = id);
          _loadPacking();
        }),
        const SizedBox(height: 10),
        _labeledTypeDropdown('Type', _packingType, (v) {
          setState(() => _packingType = v);
          _loadPacking();
        }),
        const SizedBox(height: 10),
        _labeledDateField('Date', _packingDate, (d) {
          setState(() => _packingDate = d);
          _loadPacking();
        }),
        const SizedBox(height: 10),
        _labeledField('Cartons Packed (CTN)', _cartonsPackedController),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '≈ $ctnsPossible carton(s) possible from dozens in hand (1 CTN = 40 dozen)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingPacking)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
        else
          _submitButton(_isSavingPacking, _submitPacking),
      ],
    );
  }

  // ---------------- Issue ----------------

  Widget _buildIssueSection() {
    final stock = _issueStock ?? CurrentStockEntry.empty();
    final cartonsInHand = _issueType == 'reject' ? stock.cartonsInHandReject : stock.cartonsInHand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeledMachineDropdown('Machine', _issueMachineId, (id) {
          setState(() => _issueMachineId = id);
          _loadIssueStock();
        }),
        const SizedBox(height: 10),
        _labeledTypeDropdown('Type', _issueType, (v) {
          setState(() => _issueType = v);
          _loadIssueStock();
        }),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
          child: _isLoadingIssueStock
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Cartons in Hand: $cartonsInHand', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(height: 10),
        _labeledField('Quantity to Issue (CTN)', _issueQuantityController),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isIssuing ? null : _submitIssue,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            icon: _isIssuing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Issue'),
          ),
        ),
      ],
    );
  }

  // ---------------- History tables ----------------

  Widget _buildPackingHistoryTable() {
    final rows = _history?.packing ?? [];
    if (rows.isEmpty) return _emptyHistoryText('No packing history yet');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _historyHeader(const ['Date', 'Machine', 'Type', 'CTN']),
        const Divider(height: 16),
        for (final r in rows) _packingHistoryRow(r.date, r.machineName, r.isReject, '${r.cartonsPacked}'),
      ],
    );
  }

  Widget _buildIssueHistoryTable() {
    final rows = _history?.issues ?? [];
    if (rows.isEmpty) return _emptyHistoryText('No issue history yet');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _historyHeader(const ['Date', 'Machine', 'Type', 'CTN', 'Status', '']),
        const Divider(height: 16),
        for (final r in rows)
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 2, child: Text(r.issuedDate, style: const TextStyle(fontSize: 12))),
                Expanded(flex: 2, child: Text(r.machineName, style: const TextStyle(fontSize: 12))),
                Expanded(flex: 1, child: _typeBadge(r.isReject)),
                Expanded(flex: 1, child: Text('${r.quantityIssued}', style: const TextStyle(fontSize: 12))),
                Expanded(flex: 1, child: _statusBadge(r.isIssued)),
                Expanded(
                  flex: 1,
                  child: r.canReverse
                      ? (_reversingIssueId == r.issueId
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton(
                              onPressed: () => _reverseIssue(r.issueId),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.orange.shade800, padding: EdgeInsets.zero),
                              child: const Text('Reverse', style: TextStyle(fontSize: 11)),
                            ))
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProductionHistoryTable() {
    final rows = _history?.production ?? [];
    if (rows.isEmpty) return _emptyHistoryText('No production history yet');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _historyHeader(const ['Date', 'Machine', 'Pcs']),
        const Divider(height: 16),
        for (final r in rows) _plainHistoryRow([r.date, r.machineName, '${r.quantityProduced}']),
      ],
    );
  }

  Widget _buildWeldingHistoryTable() {
    final rows = _history?.welding ?? [];
    if (rows.isEmpty) return _emptyHistoryText('No welding history yet');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _historyHeader(const ['Date', 'Straps Welded']),
        const Divider(height: 16),
        for (final r in rows) _plainHistoryRow([r.date, '${r.strapsWelded}']),
      ],
    );
  }

  Widget _emptyHistoryText(String text) => Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 13));

  Widget _historyHeader(List<String> headers) => Row(
        children: headers
            .asMap()
            .entries
            .map((e) => Expanded(
                  flex: e.key == 0 || e.key == 1 ? 2 : 1,
                  child: Text(e.value,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                ))
            .toList(),
      );

  Widget _plainHistoryRow(List<String> values) => Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: values
              .asMap()
              .entries
              .map((e) => Expanded(
                    flex: e.key == 0 || e.key == 1 ? 2 : 1,
                    child: Text(e.value, style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
        ),
      );

  Widget _packingHistoryRow(String date, String machine, bool isReject, String ctn) => Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: Text(date, style: const TextStyle(fontSize: 12))),
            Expanded(flex: 2, child: Text(machine, style: const TextStyle(fontSize: 12))),
            Expanded(flex: 1, child: _typeBadge(isReject)),
            Expanded(flex: 1, child: Text(ctn, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );

  Widget _typeBadge(bool isReject) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isReject ? Colors.orange.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isReject ? 'Mbovu' : 'Nzima',
          style: TextStyle(fontSize: 10, color: isReject ? Colors.orange.shade900 : Colors.black87),
        ),
      );

  Widget _statusBadge(bool isIssued) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isIssued ? Colors.green.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isIssued ? 'Issued' : 'Reversed',
          style: TextStyle(fontSize: 10, color: isIssued ? Colors.green.shade900 : Colors.black54),
        ),
      );

  // ---------------- Shared small widgets ----------------

  Widget _stockCardRow({
    required int opening,
    required int added,
    required int used,
    required int closing,
    required String addedLabel,
    required String usedLabel,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        stockStatTile('$opening', 'OPENING STOCK'),
        stockStatTile('$added', addedLabel),
        stockStatTile('$used', usedLabel),
        stockStatTile('$closing', 'CLOSING STOCK', accent: true),
      ],
    );
  }

  Widget _panel({required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.brandPrimary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  Widget _labeledField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        ),
      ],
    );
  }

  Widget _labeledStatic(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(value, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  Widget _labeledDateField(String label, DateTime value, void Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDate(value, onPicked),
          child: InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            child: Text(DateFormat('yyyy-MM-dd').format(value), style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _labeledMachineDropdown(String label, int? value, void Function(int?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: _machines
              .map((m) => DropdownMenuItem<int>(
                    value: int.tryParse(m['machine_id']?.toString() ?? ''),
                    child: Text(
                      m['name']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _labeledTypeDropdown(String label, String value, void Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: _typeOptions
              .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => onChanged(v ?? 'normal'),
        ),
      ],
    );
  }

  Widget _submitButton(bool isSaving, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isSaving ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
        icon: isSaving
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check, size: 18),
        label: const Text('Submit'),
      ),
    );
  }
}
