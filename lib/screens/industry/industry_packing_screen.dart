import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';
import 'industry_stock_section_view.dart';
import 'industry_packing_products_screen.dart';

/// Full carbon-copy of application/views/industry/packing.php: Packing
/// Stock Overview, Receive Raw Material, Material Stock, Record Packing
/// Output (bulk, per labourer), Issue (multi-product batch), and the 3
/// history tables below. Packing Products CRUD lives in its own screen
/// (IndustryPackingProductsScreen), linked from the top.
class IndustryPackingScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryPackingScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryPackingScreen> createState() => _IndustryPackingScreenState();
}

class _IssueLine {
  final int productId;
  final String productName;
  final int quantity;
  _IssueLine({required this.productId, required this.productName, required this.quantity});
}

class _IndustryPackingScreenState extends State<IndustryPackingScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  String? _errorMessage;
  List<PackingStockRow> _stock = [];
  PackingHistoryData? _history;

  DateTime _receiveDate = DateTime.now();
  int? _receiveProductId;
  final _fillerReceivedController = TextEditingController(text: '0');
  final _boxReceivedController = TextEditingController(text: '0');
  final _receiveNoteController = TextEditingController();
  bool _isSavingReceive = false;

  int? _materialProductId;
  DateTime _materialDate = DateTime.now();
  PackingMaterialStockEntry? _materialEntry;
  bool _isLoadingMaterial = false;

  int? _outputProductId;
  DateTime _outputDate = DateTime.now();
  PackingOutputBulkData? _outputData;
  final Map<int, TextEditingController> _outputControllers = {};
  bool _isLoadingOutput = false;
  bool _isSavingOutput = false;

  int? _issueProductId;
  final _issueQuantityController = TextEditingController(text: '1');
  final List<_IssueLine> _issueLines = [];
  bool _isIssuingBatch = false;
  int? _confirmingCancelingId;
  int? _reversingId;

  DateTime _historyStart = DateTime.now();
  DateTime _historyEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _fillerReceivedController.dispose();
    _boxReceivedController.dispose();
    _receiveNoteController.dispose();
    _issueQuantityController.dispose();
    for (final c in _outputControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _finalUnitsInHandFor(int? productId) {
    final row = _stock.firstWhere(
      (r) => r.productId == productId,
      orElse: () => PackingStockRow(
        productId: 0, name: '', finalUnitLabel: '', totalUnitsPacked: 0, finalUnitsInHand: 0,
        fillerBagsInHand: 0, boxBagsInHand: 0, fillersInHand: 0, boxesInHand: 0,
      ),
    );
    return row.finalUnitsInHand;
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await widget.service.searchPackingProducts(limit: 200);
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
    final firstId = rows.isNotEmpty ? int.tryParse(rows.first['product_id']?.toString() ?? '') : null;

    setState(() {
      _products = rows;
      _receiveProductId = firstId;
      _materialProductId = firstId;
      _outputProductId = firstId;
      _issueProductId = firstId;
      _isLoading = false;
    });

    await _loadStock();
    await Future.wait([_loadMaterial(), _loadOutput(), _loadHistory()]);
  }

  Future<void> _loadStock() async {
    final response = await widget.service.getPackingStock();
    if (!mounted) return;
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) setState(() => _stock = response.data ?? []);
  }

  Future<void> _loadMaterial() async {
    final productId = _materialProductId;
    if (productId == null) return;
    setState(() => _isLoadingMaterial = true);
    final response = await widget.service.getMaterialStock(productId, DateFormat('yyyy-MM-dd').format(_materialDate));
    if (!mounted) return;
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    setState(() {
      if (response.isSuccess) _materialEntry = response.data;
      _isLoadingMaterial = false;
    });
  }

  Future<void> _loadOutput() async {
    final productId = _outputProductId;
    if (productId == null) return;
    setState(() => _isLoadingOutput = true);
    final response = await widget.service.getOutputBulk(productId, DateFormat('yyyy-MM-dd').format(_outputDate));
    if (!mounted) return;
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess && response.data != null) {
      for (final c in _outputControllers.values) {
        c.dispose();
      }
      _outputControllers.clear();
      for (final l in response.data!.labourers) {
        _outputControllers[l.casualLabourerId] = TextEditingController(text: '${l.quantityPacked}');
      }
      setState(() {
        _outputData = response.data;
        _isLoadingOutput = false;
      });
    } else {
      setState(() => _isLoadingOutput = false);
    }
  }

  Future<void> _loadHistory() async {
    final response = await widget.service.getPackingHistory(
      startDate: DateFormat('yyyy-MM-dd').format(_historyStart),
      endDate: DateFormat('yyyy-MM-dd').format(_historyEnd),
    );
    if (!mounted) return;
    if (response.isSuccess) setState(() => _history = response.data);
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

  Future<void> _submitReceive() async {
    final productId = _receiveProductId;
    if (productId == null) return;
    setState(() => _isSavingReceive = true);
    final response = await widget.service.receivePackingMaterial(
      productId: productId,
      receiptDate: DateFormat('yyyy-MM-dd').format(_receiveDate),
      fillerBagsReceived: int.tryParse(_fillerReceivedController.text) ?? 0,
      boxBagsReceived: int.tryParse(_boxReceivedController.text) ?? 0,
      note: _receiveNoteController.text,
    );
    if (!mounted) return;
    setState(() => _isSavingReceive = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) {
      _receiveNoteController.clear();
      await Future.wait([_loadStock(), _loadMaterial(), _loadHistory()]);
    }
  }

  Future<void> _submitOutput() async {
    final productId = _outputProductId;
    if (productId == null) return;
    setState(() => _isSavingOutput = true);
    final entries = <int, int>{};
    _outputControllers.forEach((id, c) {
      final qty = int.tryParse(c.text) ?? 0;
      if (qty > 0) entries[id] = qty;
    });
    final response = await widget.service.saveOutputBulk(
      productId: productId,
      outputDate: DateFormat('yyyy-MM-dd').format(_outputDate),
      entries: entries,
    );
    if (!mounted) return;
    setState(() => _isSavingOutput = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) {
      await Future.wait([_loadStock(), _loadOutput(), _loadHistory()]);
    }
  }

  void _addIssueLine() {
    final productId = _issueProductId;
    final product = _products.firstWhere((p) => int.tryParse(p['product_id']?.toString() ?? '') == productId,
        orElse: () => {});
    final quantity = int.tryParse(_issueQuantityController.text) ?? 0;
    if (productId == null || product.isEmpty || quantity <= 0) {
      _showResult(false, 'Invalid quantity');
      return;
    }
    setState(() {
      _issueLines.add(_IssueLine(productId: productId, productName: product['name']?.toString() ?? '', quantity: quantity));
      _issueQuantityController.text = '1';
    });
  }

  Future<void> _submitIssueBatch() async {
    if (_issueLines.isEmpty) return;
    setState(() => _isIssuingBatch = true);
    final response = await widget.service.issuePackingBatch(
      _issueLines.map((l) => {'product_id': l.productId, 'quantity': l.quantity}).toList(),
    );
    if (!mounted) return;
    setState(() => _isIssuingBatch = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) {
      setState(() => _issueLines.clear());
      await Future.wait([_loadStock(), _loadHistory()]);
    }
  }

  Future<void> _confirmIssue(int issueId) async {
    setState(() => _confirmingCancelingId = issueId);
    final response = await widget.service.confirmPackingIssue(issueId);
    if (!mounted) return;
    setState(() => _confirmingCancelingId = null);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) await Future.wait([_loadStock(), _loadHistory()]);
  }

  Future<void> _cancelIssue(int issueId) async {
    setState(() => _confirmingCancelingId = issueId);
    final response = await widget.service.cancelPackingIssue(issueId);
    if (!mounted) return;
    setState(() => _confirmingCancelingId = null);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) await Future.wait([_loadStock(), _loadHistory()]);
  }

  Future<void> _reverseIssue(int issueId) async {
    setState(() => _reversingId = issueId);
    final response = await widget.service.reversePackingIssue(issueId);
    if (!mounted) return;
    setState(() => _reversingId = null);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) await Future.wait([_loadStock(), _loadHistory()]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return _buildBody();
  }

  Widget _buildBody() {
    final cartonsInHand = _finalUnitsInHandFor(_issueProductId);
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: industryScrollPadding(context),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IndustryPackingProductsScreen(
                    service: widget.service,
                    onSessionExpired: widget.onSessionExpired,
                  ),
                ),
              ).then((_) => _loadAll()),
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Manage Products'),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          if (_products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No packing products configured yet.'),
            )
          else ...[
            _panel(icon: Icons.bar_chart, title: 'Packing Stock Overview', child: _buildStockOverview()),
            const SizedBox(height: 16),
            _panel(icon: Icons.file_download_outlined, title: 'Receive Raw Material', child: _buildReceiveForm()),
            const SizedBox(height: 16),
            _panel(icon: Icons.search, title: 'Material Stock', child: _buildMaterialStock()),
            const SizedBox(height: 16),
            _panel(icon: Icons.edit_outlined, title: 'Record Packing Output', child: _buildOutputSection()),
            const SizedBox(height: 16),
            _panel(icon: Icons.file_upload_outlined, title: 'Issue', child: _buildIssueSection(cartonsInHand)),
            const SizedBox(height: 16),
            _panel(icon: Icons.receipt_long, title: 'Packing Output History', child: _buildOutputHistory()),
            const SizedBox(height: 16),
            _panel(icon: Icons.receipt_long, title: 'Issue History', child: _buildIssueHistory()),
            const SizedBox(height: 16),
            _panel(icon: Icons.inbox_outlined, title: 'Material Receipt History', child: _buildReceiptHistory()),
          ],
        ],
      ),
    );
  }

  // ---------------- Packing Stock Overview ----------------

  Widget _buildStockOverview() {
    if (_stock.isEmpty) return _emptyText('No stock data.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in _stock)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(row.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    Text('${row.finalUnitsInHand} ${row.finalUnitLabel}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _miniStat('Jumla', '${row.totalUnitsPacked}'),
                    _miniStat('Filler Bags', '${row.fillerBagsInHand}'),
                    _miniStat('Box Bags', '${row.boxBagsInHand}'),
                    _miniStat('Loose Fillers', '${row.fillersInHand}'),
                    _miniStat('Loose Boxes', '${row.boxesInHand}'),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _miniStat(String label, String value) => Text('$label: $value', style: TextStyle(fontSize: 11, color: Colors.grey.shade700));

  // ---------------- Receive Raw Material ----------------

  Widget _buildReceiveForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledProductDropdown('Product', _receiveProductId, (id) => setState(() => _receiveProductId = id))),
            const SizedBox(width: 10),
            Expanded(child: _labeledDateField('Date', _receiveDate, (d) => setState(() => _receiveDate = d))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledField('Filler Bags Received', _fillerReceivedController)),
            const SizedBox(width: 10),
            Expanded(child: _labeledField('Box Bags Received', _boxReceivedController)),
          ],
        ),
        const SizedBox(height: 10),
        _labeledField('Note', _receiveNoteController, keyboardType: TextInputType.text),
        const SizedBox(height: 12),
        _submitButton(_isSavingReceive, _submitReceive),
      ],
    );
  }

  // ---------------- Material Stock ----------------

  Widget _buildMaterialStock() {
    final filler = _materialEntry?.fillerBagCard;
    final box = _materialEntry?.boxBagCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hesabu inafanyika kiotomatiki: kila roba iliyopokelewa inachukuliwa kuwa na 'Uwezo wa Roba' "
          'uliowekwa kwenye Packing Products (Settings), na hutumika kadri Record Output inavyoongezeka. '
          'Hakuna kufungua/kuhesabu roba kwa mkono tena.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledProductDropdown('Product', _materialProductId, (id) {
              setState(() => _materialProductId = id);
              _loadMaterial();
            })),
            const SizedBox(width: 10),
            Expanded(child: _labeledDateField('Date', _materialDate, (d) {
              setState(() => _materialDate = d);
              _loadMaterial();
            })),
          ],
        ),
        const SizedBox(height: 14),
        Text('Filler Bag Stock', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        _stockCardRow(
          opening: filler?.opening ?? 0, added: filler?.received ?? 0, used: filler?.used ?? 0, closing: filler?.closing ?? 0,
          addedLabel: 'RECEIVED', usedLabel: 'USED',
        ),
        const SizedBox(height: 14),
        Text('Box Bag Stock', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        _stockCardRow(
          opening: box?.opening ?? 0, added: box?.received ?? 0, used: box?.used ?? 0, closing: box?.closing ?? 0,
          addedLabel: 'RECEIVED', usedLabel: 'USED',
        ),
        if (_isLoadingMaterial)
          const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ],
    );
  }

  // ---------------- Record Packing Output ----------------

  Widget _buildOutputSection() {
    final data = _outputData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: stockStatTile('${data?.fillersInHand ?? 0}', 'LOOSE FILLERS')),
            const SizedBox(width: 10),
            Expanded(child: stockStatTile('${data?.boxesInHand ?? 0}', 'LOOSE BOXES')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledProductDropdown('Product', _outputProductId, (id) {
              setState(() => _outputProductId = id);
              _loadOutput();
            })),
            const SizedBox(width: 10),
            Expanded(child: _labeledDateField('Date', _outputDate, (d) {
              setState(() => _outputDate = d);
              _loadOutput();
            })),
          ],
        ),
        const SizedBox(height: 14),
        if (_isLoadingOutput)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (data == null || data.labourers.isEmpty)
          _emptyText('Hakuna mfanyakazi aliyeonekana kwenye Attendance siku hii')
        else ...[
          const Text('Labourer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          for (final l in data.labourers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Flexible(child: Text(l.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                        if (!l.isPaid)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                            child: const Text('Is Paid?: No', style: TextStyle(fontSize: 9)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _outputControllers[l.casualLabourerId],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _submitButton(_isSavingOutput, _submitOutput),
        ],
      ],
    );
  }

  // ---------------- Issue ----------------

  Widget _buildIssueSection(int cartonsInHand) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _labeledProductDropdown('Product', _issueProductId, (id) => setState(() => _issueProductId = id)),
            ),
            const SizedBox(width: 10),
            Expanded(child: _labeledField('Quantity to Issue', _issueQuantityController)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
              child: Text('In Hand: $cartonsInHand', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _addIssueLine,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add to Issue List'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('PRODUCTS TO ISSUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 6),
        if (_issueLines.isEmpty)
          _emptyText('-')
        else
          for (var i = 0; i < _issueLines.length; i++)
            Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(_issueLines[i].productName, style: const TextStyle(fontSize: 13))),
                  Text('${_issueLines[i].quantity}', style: const TextStyle(fontSize: 13)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => setState(() => _issueLines.removeAt(i)),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isIssuingBatch || _issueLines.isEmpty) ? null : _submitIssueBatch,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            icon: _isIssuingBatch
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Issue'),
          ),
        ),
      ],
    );
  }

  // ---------------- History tables ----------------

  Widget _buildOutputHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledDateField('From', _historyStart, (d) {
              setState(() => _historyStart = d);
              _loadHistory();
            })),
            const SizedBox(width: 10),
            Expanded(child: _labeledDateField('To', _historyEnd, (d) {
              setState(() => _historyEnd = d);
              _loadHistory();
            })),
          ],
        ),
        const SizedBox(height: 14),
        if ((_history?.output ?? []).isEmpty)
          _emptyText('No output recorded yet')
        else
          for (final r in _history!.output)
            Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(r.labourerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Text(r.date, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                  Text('${r.productName} · ${r.quantityPacked} · Bonus ${r.bonus} · Pay ${r.pay}',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildIssueHistory() {
    final rows = _history?.issues ?? [];
    if (rows.isEmpty) return _emptyText('No issues recorded yet');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rows)
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(r.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    _issueStatusBadge(r.status),
                  ],
                ),
                Text('${r.date} · Qty ${r.quantityIssued}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                if (r.canConfirmOrCancel || r.canReverse)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        if (r.canConfirmOrCancel) ...[
                          _confirmingCancelingId == r.issueId
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : OutlinedButton(
                                  onPressed: () => _confirmIssue(r.issueId),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade700, minimumSize: const Size(0, 30)),
                                  child: const Text('Confirm Receipt', style: TextStyle(fontSize: 11)),
                                ),
                          const SizedBox(width: 8),
                          if (_confirmingCancelingId != r.issueId)
                            TextButton(
                              onPressed: () => _cancelIssue(r.issueId),
                              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700, minimumSize: const Size(0, 30)),
                              child: const Text('Cancel', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                        if (r.canReverse)
                          _reversingId == r.issueId
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : OutlinedButton(
                                  onPressed: () => _reverseIssue(r.issueId),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800, minimumSize: const Size(0, 30)),
                                  child: const Text('Reverse', style: TextStyle(fontSize: 11)),
                                ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _issueStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'pending':
        bg = Colors.orange.shade50; fg = Colors.orange.shade800; label = 'Pending Approval';
        break;
      case 'issued':
        bg = Colors.green.shade50; fg = Colors.green.shade800; label = 'Received';
        break;
      default:
        bg = Colors.grey.shade200; fg = Colors.grey.shade700; label = 'Reversed';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildReceiptHistory() {
    final rows = _history?.receipts ?? [];
    if (rows.isEmpty) return _emptyText('No receipts recorded yet');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rows)
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(r.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    Text(r.date, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
                Text('Filler: ${r.fillerBagsReceived} · Box: ${r.boxBagsReceived}${r.note.isNotEmpty ? ' · ${r.note}' : ''}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _emptyText(String text) => Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 13));

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

  Widget _labeledField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType ?? TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
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

  Widget _labeledProductDropdown(String label, int? value, void Function(int?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: value,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: _products
              .map((p) => DropdownMenuItem<int>(
                    value: int.tryParse(p['product_id']?.toString() ?? ''),
                    child: Text(p['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
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
