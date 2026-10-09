import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';
import 'industry_stock_section_view.dart';

/// Full carbon-copy of application/views/industry/mattress.php: Stock
/// Report (Magodoro + Mikanda stock cards for a chosen date), Receive
/// Mattresses, Kuchana Godoro/Cutting (with stock card + expected-straps
/// hint), and the Cutting/Receipt history tables.
class IndustryMattressScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryMattressScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryMattressScreen> createState() => _IndustryMattressScreenState();
}

class _IndustryMattressScreenState extends State<IndustryMattressScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  MattressHistoryData? _history;
  int _strapsDamagedTotal = 0;
  int _strapsPerMattress = 1;

  DateTime _reportDate = DateTime.now();
  MattressCuttingEntry? _reportCutting;
  MattressStrapsStockEntry? _reportStraps;
  bool _isLoadingReport = false;

  DateTime _receiveDate = DateTime.now();
  final _mattressesReceivedController = TextEditingController(text: '1');
  final _receiveNoteController = TextEditingController();
  bool _isSavingReceive = false;

  DateTime _cuttingDate = DateTime.now();
  MattressCuttingEntry? _cutting;
  final _mattressesCutController = TextEditingController();
  final _strapsActualController = TextEditingController();
  final _strapsDamagedController = TextEditingController();
  bool _isLoadingCutting = false;
  bool _isSavingCutting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
    _mattressesCutController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mattressesReceivedController.dispose();
    _receiveNoteController.dispose();
    _mattressesCutController.dispose();
    _strapsActualController.dispose();
    _strapsDamagedController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dashboardResponse = await widget.service.getDashboard();
    final historyResponse = await widget.service.getMattressHistory();
    final settingsResponse = await widget.service.getSettingsValues();

    if (!mounted) return;

    if (dashboardResponse.statusCode == 440 || historyResponse.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    if (dashboardResponse.isSuccess && dashboardResponse.data != null) {
      final mattress =
          (dashboardResponse.data!.data['stock'] as Map<String, dynamic>?)?['mattress'] as Map<String, dynamic>? ??
              {};
      setState(() => _strapsDamagedTotal = int.tryParse('${mattress['straps_damaged_total'] ?? 0}') ?? 0);
    } else {
      setState(() => _errorMessage = dashboardResponse.message);
    }

    if (historyResponse.isSuccess && historyResponse.data != null) {
      setState(() => _history = historyResponse.data);
    }

    if (settingsResponse.isSuccess && settingsResponse.data != null) {
      setState(() => _strapsPerMattress = int.tryParse(settingsResponse.data!.mattressStrapsPerMattress) ?? 1);
    }

    setState(() => _isLoading = false);

    await Future.wait([_loadReport(), _loadCutting()]);
  }

  Future<void> _loadReport() async {
    setState(() => _isLoadingReport = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_reportDate);
    final cuttingResponse = await widget.service.getMattressCutting(dateStr);
    final strapsResponse = await widget.service.getMattressStrapsStock(dateStr);
    if (!mounted) return;
    if (cuttingResponse.statusCode == 440 || strapsResponse.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    setState(() {
      if (cuttingResponse.isSuccess) _reportCutting = cuttingResponse.data;
      if (strapsResponse.isSuccess) _reportStraps = strapsResponse.data;
      _isLoadingReport = false;
    });
  }

  Future<void> _loadCutting() async {
    setState(() => _isLoadingCutting = true);
    final response = await widget.service.getMattressCutting(DateFormat('yyyy-MM-dd').format(_cuttingDate));
    if (!mounted) return;
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess && response.data != null) {
      setState(() {
        _cutting = response.data;
        _mattressesCutController.text = response.data!.mattressesCut.toString();
        _strapsActualController.text = response.data!.strapsActual.toString();
        _strapsDamagedController.text = response.data!.strapsDamaged.toString();
        _isLoadingCutting = false;
      });
    } else {
      setState(() => _isLoadingCutting = false);
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
    final response = await widget.service.receiveMattress(
      receiptDate: DateFormat('yyyy-MM-dd').format(_receiveDate),
      mattressesReceived: int.tryParse(_mattressesReceivedController.text) ?? 0,
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

  Future<void> _submitCutting() async {
    setState(() => _isSavingCutting = true);
    final response = await widget.service.saveMattressCutting(
      cuttingDate: DateFormat('yyyy-MM-dd').format(_cuttingDate),
      mattressesCut: int.tryParse(_mattressesCutController.text) ?? 0,
      strapsActual: int.tryParse(_strapsActualController.text) ?? 0,
      strapsDamaged: int.tryParse(_strapsDamagedController.text) ?? 0,
    );
    if (!mounted) return;
    setState(() => _isSavingCutting = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) {
      await Future.wait([_loadCutting(), _loadReport()]);
      final historyResponse = await widget.service.getMattressHistory();
      if (mounted && historyResponse.isSuccess) {
        setState(() => _history = historyResponse.data);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return _buildBody();
  }

  Widget _buildBody() {
    final expectedStraps = (int.tryParse(_mattressesCutController.text) ?? 0) * _strapsPerMattress;

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
          _panel(
            icon: Icons.bar_chart,
            title: 'Stock Report',
            child: _buildStockReport(),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.file_download_outlined,
            title: 'Receive Mattresses',
            child: _buildReceiveForm(),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.content_cut,
            title: 'Kuchana Godoro (Cut Mattresses)',
            child: _buildCuttingSection(expectedStraps),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.receipt_long,
            title: 'Cutting History',
            child: _buildCuttingHistoryTable(),
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

  Widget _buildStockReport() {
    final mattressCard = _reportCutting?.stockCard;
    final strapsCard = _reportStraps?.stockCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeledDateField('Date', _reportDate, (d) {
          setState(() => _reportDate = d);
          _loadReport();
        }),
        const SizedBox(height: 14),
        Text('Magodoro (Mattress) Stock', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        _stockCardRow(
          opening: mattressCard?.opening ?? 0,
          added: mattressCard?.added ?? 0,
          used: mattressCard?.used ?? 0,
          closing: mattressCard?.closing ?? 0,
          addedLabel: 'RECEIVED',
          usedLabel: 'CUT (USED)',
        ),
        const SizedBox(height: 14),
        Text('Mikanda (Straps) Stock', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        _stockCardRow(
          opening: strapsCard?.opening ?? 0,
          added: strapsCard?.added ?? 0,
          used: strapsCard?.used ?? 0,
          closing: strapsCard?.closing ?? 0,
          addedLabel: 'CUT (ADDED)',
          usedLabel: 'USED (ROLLER DRESSING)',
        ),
        const SizedBox(height: 10),
        Text(
          'Straps Damaged (Total): $_strapsDamagedTotal (all-time) -- straps are used when rollers are '
          'dressed/wrapped on the Roller tab (Kuvisha)',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
        if (_isLoadingReport)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  Widget _buildReceiveForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledDateField('Date', _receiveDate, (d) => setState(() => _receiveDate = d))),
            const SizedBox(width: 10),
            Expanded(child: _labeledField('Mattresses Received', _mattressesReceivedController)),
          ],
        ),
        const SizedBox(height: 10),
        _labeledField('Note', _receiveNoteController, keyboardType: TextInputType.text),
        const SizedBox(height: 12),
        _submitButton(_isSavingReceive, _submitReceive),
      ],
    );
  }

  Widget _buildCuttingSection(int expectedStraps) {
    final card = _cutting?.stockCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stockCardRow(
          opening: card?.opening ?? 0,
          added: card?.added ?? 0,
          used: card?.used ?? 0,
          closing: card?.closing ?? 0,
          addedLabel: 'RECEIVED',
          usedLabel: 'CUT (USED)',
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledDateField('Date', _cuttingDate, (d) {
              setState(() => _cuttingDate = d);
              _loadCutting();
            })),
            const SizedBox(width: 10),
            Expanded(child: _labeledField('Mattresses Cut', _mattressesCutController)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '≈ expected $expectedStraps straps at the configured ratio -- record what actually came out '
            '(good + damaged) below',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeledField('Straps Actual (Good)', _strapsActualController)),
            const SizedBox(width: 10),
            Expanded(child: _labeledField('Straps Damaged', _strapsDamagedController)),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingCutting)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
        else
          _submitButton(_isSavingCutting, _submitCutting),
      ],
    );
  }

  Widget _buildCuttingHistoryTable() {
    final rows = _history?.cutting ?? [];
    if (rows.isEmpty) return _emptyHistoryText(text: 'No cutting recorded yet');
    return _historyTable(
      headers: const ['Date', 'Cut', 'Actual', 'Damaged'],
      rows: rows
          .map((r) => [r.date, '${r.mattressesCut}', '${r.strapsActual}', '${r.strapsDamaged}'])
          .toList(),
    );
  }

  Widget _buildReceiptHistoryTable() {
    final rows = _history?.receipts ?? [];
    if (rows.isEmpty) return _emptyHistoryText(text: 'No receipts recorded yet');
    return _historyTable(
      headers: const ['Date', 'Received', 'Note'],
      rows: rows.map((r) => [r.date, '${r.mattressesReceived}', r.note]).toList(),
    );
  }

  Widget _emptyHistoryText({required String text}) =>
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
