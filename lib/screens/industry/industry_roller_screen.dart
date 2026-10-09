import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';
import 'industry_stock_section_view.dart';

/// Full carbon-copy of application/views/industry/roller.php: Stock
/// Summary, Receive Bags, Open Bag/Count Rollers (with stock card),
/// Kuvisha/Dressing (with stock cards + straps-needed hint), Kupruniwa/
/// Trimming (read-only, auto-filled from Kuvisha), and the 4 history
/// tables below.
class IndustryRollerScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryRollerScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryRollerScreen> createState() => _IndustryRollerScreenState();
}

class _IndustryRollerScreenState extends State<IndustryRollerScreen> {
  Map<String, dynamic>? _summary;
  RollerHistoryData? _history;
  bool _isLoading = false;
  String? _errorMessage;

  DateTime _receiveDate = DateTime.now();
  final _bagsReceivedController = TextEditingController(text: '1');
  final _receiveNoteController = TextEditingController();
  bool _isSavingReceive = false;

  DateTime _openingDate = DateTime.now();
  RollerBagOpeningEntry? _bagOpening;
  final _bagsOpenedController = TextEditingController();
  final _countedBigController = TextEditingController();
  final _countedSmallController = TextEditingController();
  bool _isLoadingOpening = false;
  bool _isSavingOpening = false;

  DateTime _usageDate = DateTime.now();
  RollerUsageEntry? _usage;
  final _usedBigController = TextEditingController();
  final _usedSmallController = TextEditingController();
  bool _isLoadingUsage = false;
  bool _isSavingUsage = false;

  DateTime _trimmingDate = DateTime.now();
  RollerTrimmingEntry? _trimming;
  bool _isLoadingTrimming = false;

  int _strapsPerBig = 21;
  int _strapsPerSmall = 13;
  int _pcsPerBig = 250;
  int _pcsPerSmall = 150;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
    _usedBigController.addListener(() => setState(() {}));
    _usedSmallController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _bagsReceivedController.dispose();
    _receiveNoteController.dispose();
    _bagsOpenedController.dispose();
    _countedBigController.dispose();
    _countedSmallController.dispose();
    _usedBigController.dispose();
    _usedSmallController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dashboardResponse = await widget.service.getDashboard();
    final historyResponse = await widget.service.getRollerHistory();
    final settingsResponse = await widget.service.getSettingsValues();

    if (!mounted) return;

    if (dashboardResponse.statusCode == 440 || historyResponse.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    if (dashboardResponse.isSuccess && dashboardResponse.data != null) {
      setState(() {
        _summary = (dashboardResponse.data!.data['stock'] as Map<String, dynamic>?)?['roller']
                as Map<String, dynamic>? ??
            {};
      });
    } else {
      setState(() => _errorMessage = dashboardResponse.message);
    }

    if (historyResponse.isSuccess && historyResponse.data != null) {
      setState(() => _history = historyResponse.data);
    }

    if (settingsResponse.isSuccess && settingsResponse.data != null) {
      setState(() {
        _strapsPerBig = int.tryParse(settingsResponse.data!.rollerStrapsPerBig) ?? 21;
        _strapsPerSmall = int.tryParse(settingsResponse.data!.rollerStrapsPerSmall) ?? 13;
        _pcsPerBig = int.tryParse(settingsResponse.data!.rollerPcsPerBig) ?? 250;
        _pcsPerSmall = int.tryParse(settingsResponse.data!.rollerPcsPerSmall) ?? 150;
      });
    }

    setState(() => _isLoading = false);

    await Future.wait([_loadOpening(), _loadUsage(), _loadTrimming()]);
  }

  Future<void> _loadOpening() async {
    setState(() => _isLoadingOpening = true);
    final response = await widget.service.getRollerBagOpening(DateFormat('yyyy-MM-dd').format(_openingDate));
    if (!mounted) return;
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess && response.data != null) {
      setState(() {
        _bagOpening = response.data;
        _bagsOpenedController.text = response.data!.bagsOpened.toString();
        _countedBigController.text = response.data!.rollersCountedBig.toString();
        _countedSmallController.text = response.data!.rollersCountedSmall.toString();
        _isLoadingOpening = false;
      });
    } else {
      setState(() => _isLoadingOpening = false);
    }
  }

  Future<void> _loadUsage() async {
    setState(() => _isLoadingUsage = true);
    final response = await widget.service.getRollerUsage(DateFormat('yyyy-MM-dd').format(_usageDate));
    if (!mounted) return;
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess && response.data != null) {
      setState(() {
        _usage = response.data;
        _usedBigController.text = response.data!.rollersUsedBig.toString();
        _usedSmallController.text = response.data!.rollersUsedSmall.toString();
        _isLoadingUsage = false;
      });
    } else {
      setState(() => _isLoadingUsage = false);
    }
  }

  Future<void> _loadTrimming() async {
    setState(() => _isLoadingTrimming = true);
    final response = await widget.service.getRollerTrimming(DateFormat('yyyy-MM-dd').format(_trimmingDate));
    if (!mounted) return;
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess && response.data != null) {
      setState(() {
        _trimming = response.data;
        _isLoadingTrimming = false;
      });
    } else {
      setState(() => _isLoadingTrimming = false);
    }
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
    setState(() => _isSavingReceive = true);
    final response = await widget.service.receiveRoller(
      receiptDate: DateFormat('yyyy-MM-dd').format(_receiveDate),
      bagsReceived: int.tryParse(_bagsReceivedController.text) ?? 0,
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
      _loadAll();
    }
  }

  Future<void> _submitOpening() async {
    setState(() => _isSavingOpening = true);
    final response = await widget.service.saveRollerBagOpening(
      openingDate: DateFormat('yyyy-MM-dd').format(_openingDate),
      bagsOpened: int.tryParse(_bagsOpenedController.text) ?? 0,
      rollersCountedBig: int.tryParse(_countedBigController.text) ?? 0,
      rollersCountedSmall: int.tryParse(_countedSmallController.text) ?? 0,
    );
    if (!mounted) return;
    setState(() => _isSavingOpening = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) {
      await _loadOpening();
      final dashboardResponse = await widget.service.getDashboard();
      if (mounted && dashboardResponse.isSuccess && dashboardResponse.data != null) {
        setState(() {
          _summary = (dashboardResponse.data!.data['stock'] as Map<String, dynamic>?)?['roller']
                  as Map<String, dynamic>? ??
              {};
        });
      }
    }
  }

  Future<void> _submitUsage() async {
    setState(() => _isSavingUsage = true);
    final response = await widget.service.saveRollerUsage(
      usageDate: DateFormat('yyyy-MM-dd').format(_usageDate),
      rollersUsedBig: int.tryParse(_usedBigController.text) ?? 0,
      rollersUsedSmall: int.tryParse(_usedSmallController.text) ?? 0,
    );
    if (!mounted) return;
    setState(() => _isSavingUsage = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) {
      await Future.wait([_loadUsage(), _loadTrimming()]);
      final dashboardResponse = await widget.service.getDashboard();
      if (mounted && dashboardResponse.isSuccess && dashboardResponse.data != null) {
        setState(() {
          _summary = (dashboardResponse.data!.data['stock'] as Map<String, dynamic>?)?['roller']
                  as Map<String, dynamic>? ??
              {};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return _buildBody();
  }

  Widget _buildBody() {
    final summary = _summary ?? {};
    final big = (summary['big'] as Map<String, dynamic>?) ?? {};
    final small = (summary['small'] as Map<String, dynamic>?) ?? {};

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: industryScrollPadding(context),
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              stockStatTile('${summary['bags_in_store'] ?? 0}', 'BAGS IN STORE'),
              stockStatTile('${big['loose_rollers_available'] ?? 0}', 'BIG ROLLER — LOOSE ROLLERS AVAILABLE',
                  accent: true),
              stockStatTile('${small['loose_rollers_available'] ?? 0}', 'SMALL ROLLER — LOOSE ROLLERS AVAILABLE',
                  accent: true),
              stockStatTile('${big['dressed_available'] ?? 0}', 'BIG ROLLER — DRESSED, NOT YET TRIMMED'),
              stockStatTile('${small['dressed_available'] ?? 0}', 'SMALL ROLLER — DRESSED, NOT YET TRIMMED'),
            ],
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.file_download_outlined,
            title: 'Receive Bags',
            child: _buildReceiveForm(),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.search,
            title: 'Open Bag / Count Rollers',
            child: _buildOpeningSection(),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.remove_circle_outline,
            title: 'Kuvisha (Dress / Wrap Roller with Straps)',
            child: _buildUsageSection(),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.content_cut,
            title: 'Kupruniwa (Trim Dressed Rollers)',
            child: _buildTrimmingSection(),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.receipt_long,
            title: 'Bag Opening History',
            child: _buildBagOpeningHistoryTable(),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.receipt_long,
            title: 'Dressing History',
            child: _buildUsageHistoryTable(),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.receipt_long,
            title: 'Trimming History',
            child: _buildTrimmingHistoryTable(),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.inbox_outlined,
            title: 'Receipt History',
            child: _buildReceiptHistoryTable(),
          ),
        ],
      ),
    );
  }

  // ---------------- Receive Bags ----------------

  Widget _buildReceiveForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledDateField('Date', _receiveDate, (d) => setState(() => _receiveDate = d))),
            const SizedBox(width: 10),
            Expanded(child: _labeledField('Bags Received', _bagsReceivedController)),
          ],
        ),
        const SizedBox(height: 10),
        _labeledField('Note', _receiveNoteController, keyboardType: TextInputType.text),
        const SizedBox(height: 12),
        _submitButton(_isSavingReceive, _submitReceive),
      ],
    );
  }

  // ---------------- Open Bag / Count Rollers ----------------

  Widget _buildOpeningSection() {
    final card = _bagOpening?.stockCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stockCardRow(
          opening: card?.opening ?? 0,
          added: card?.added ?? 0,
          used: card?.used ?? 0,
          closing: card?.closing ?? 0,
          addedLabel: 'RECEIVED',
          usedLabel: 'OPENED (USED)',
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledDateField('Date', _openingDate, (d) {
              setState(() => _openingDate = d);
              _loadOpening();
            })),
            const SizedBox(width: 10),
            Expanded(child: _labeledField('Bags Opened Today', _bagsOpenedController)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledField('Rollers Counted (Big)', _countedBigController)),
            const SizedBox(width: 10),
            Expanded(child: _labeledField('Rollers Counted (Small)', _countedSmallController)),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingOpening)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
        else
          _submitButton(_isSavingOpening, _submitOpening),
      ],
    );
  }

  // ---------------- Kuvisha / Dressing ----------------

  Widget _buildUsageSection() {
    final bigCard = _usage?.bigStockCard;
    final smallCard = _usage?.smallStockCard;
    final usedBig = int.tryParse(_usedBigController.text) ?? 0;
    final usedSmall = int.tryParse(_usedSmallController.text) ?? 0;
    final strapsNeeded = usedBig * _strapsPerBig + usedSmall * _strapsPerSmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stockStatTile('${_usage?.strapsInHand ?? 0}', 'MATTRESS STRAPS IN HAND', accent: true),
        const SizedBox(height: 14),
        Text('Big Roller', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        _stockCardRow(
          opening: bigCard?.opening ?? 0,
          added: bigCard?.added ?? 0,
          used: bigCard?.used ?? 0,
          closing: bigCard?.closing ?? 0,
          addedLabel: 'COUNTED (ADDED)',
          usedLabel: 'USED',
        ),
        const SizedBox(height: 14),
        Text('Small Roller', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        _stockCardRow(
          opening: smallCard?.opening ?? 0,
          added: smallCard?.added ?? 0,
          used: smallCard?.used ?? 0,
          closing: smallCard?.closing ?? 0,
          addedLabel: 'COUNTED (ADDED)',
          usedLabel: 'USED',
        ),
        const SizedBox(height: 10),
        Text(
          "Roller ambazo hazijavishwa leo zinabaki 'Loose Rollers Available' -- unaweza kuzivisha siku nyingine, hazipotei.",
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledDateField('Date', _usageDate, (d) {
              setState(() => _usageDate = d);
              _loadUsage();
            })),
            const SizedBox(width: 10),
            Expanded(child: _labeledField('Rollers Dressed (Big)', _usedBigController)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledField('Rollers Dressed (Small)', _usedSmallController)),
            const SizedBox(width: 10),
            Expanded(
              child: _labeledStatic('Straps Used', '${_usage?.strapsUsed ?? 0}'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '≈ needs $strapsNeeded mattress strap(s) -- expected pcs after wrapping & welding: '
            '${usedBig * _pcsPerBig + usedSmall * _pcsPerSmall} '
            '(big roller = $_strapsPerBig, small roller = $_strapsPerSmall)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingUsage)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
        else
          _submitButton(_isSavingUsage, _submitUsage),
      ],
    );
  }

  // ---------------- Kupruniwa / Trimming (read-only) ----------------

  Widget _buildTrimmingSection() {
    final bigCard = _trimming?.bigStockCard;
    final smallCard = _trimming?.smallStockCard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Auto -- inatokana na Kuvisha (Dressing) ya siku hiyo, hakuna kuingiza kwa mkono.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        Text('Big Roller', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        _stockCardRow(
          opening: bigCard?.opening ?? 0,
          added: bigCard?.added ?? 0,
          used: bigCard?.used ?? 0,
          closing: bigCard?.closing ?? 0,
          addedLabel: 'DRESSED (ADDED)',
          usedLabel: 'TRIMMED (USED)',
        ),
        const SizedBox(height: 14),
        Text('Small Roller', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        _stockCardRow(
          opening: smallCard?.opening ?? 0,
          added: smallCard?.added ?? 0,
          used: smallCard?.used ?? 0,
          closing: smallCard?.closing ?? 0,
          addedLabel: 'DRESSED (ADDED)',
          usedLabel: 'TRIMMED (USED)',
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledDateField('Date', _trimmingDate, (d) {
              setState(() => _trimmingDate = d);
              _loadTrimming();
            })),
            const SizedBox(width: 10),
            Expanded(child: _labeledStatic('Rollers Trimmed (Big)', '${_trimming?.trimmedBig ?? 0}')),
          ],
        ),
        const SizedBox(height: 10),
        _labeledStatic('Rollers Trimmed (Small)', '${_trimming?.trimmedSmall ?? 0}'),
        if (_isLoadingTrimming)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  // ---------------- History tables ----------------

  Widget _buildBagOpeningHistoryTable() {
    final rows = _history?.bagOpening ?? [];
    if (rows.isEmpty) return _emptyHistoryText();
    return _historyTable(
      headers: const ['Date', 'Bags Opened', 'Big', 'Small'],
      rows: rows
          .map((r) => [r.date, '${r.bagsOpened}', '${r.countedBig}', '${r.countedSmall}'])
          .toList(),
    );
  }

  Widget _buildUsageHistoryTable() {
    final rows = _history?.usage ?? [];
    if (rows.isEmpty) return _emptyHistoryText(text: 'No dressing recorded yet');
    return _historyTable(
      headers: const ['Date', 'Big', 'Small', 'Straps Used'],
      rows: rows.map((r) => [r.date, '${r.usedBig}', '${r.usedSmall}', '${r.strapsUsed}']).toList(),
    );
  }

  Widget _buildTrimmingHistoryTable() {
    final rows = _history?.trimming ?? [];
    if (rows.isEmpty) return _emptyHistoryText(text: 'No trimming recorded yet');
    return _historyTable(
      headers: const ['Date', 'Big', 'Small'],
      rows: rows.map((r) => [r.date, '${r.trimmedBig}', '${r.trimmedSmall}']).toList(),
    );
  }

  Widget _buildReceiptHistoryTable() {
    final rows = _history?.receipts ?? [];
    if (rows.isEmpty) return _emptyHistoryText();
    return _historyTable(
      headers: const ['Date', 'Bags Received', 'Note'],
      rows: rows.map((r) => [r.date, '${r.bagsReceived}', r.note]).toList(),
    );
  }

  Widget _emptyHistoryText({String text = 'No records yet'}) =>
      Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 13));

  Widget _historyTable({required List<String> headers, required List<List<String>> rows}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: headers
              .asMap()
              .entries
              .map((e) => Expanded(
                    flex: e.key == 0 ? 2 : 1,
                    child: Text(e.value,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  ))
              .toList(),
        ),
        const Divider(height: 16),
        for (final row in rows)
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: row
                  .asMap()
                  .entries
                  .map((e) => Expanded(
                        flex: e.key == 0 ? 2 : 1,
                        child: Text(e.value, style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

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

  Widget _submitButton(bool isSaving, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isSaving ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
        icon: isSaving
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check, size: 18),
        label: const Text('Submit'),
      ),
    );
  }
}
