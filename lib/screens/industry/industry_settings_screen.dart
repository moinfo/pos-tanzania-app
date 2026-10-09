import 'package:flutter/material.dart';
import '../../models/industry.dart';
import '../../services/industry_service.dart';
import '../../utils/constants.dart';
import 'industry_casual_labourers_screen.dart' show IndustryCasualLabourersScreen;

const _weekDays = [
  DropdownOption('1', 'Monday'),
  DropdownOption('2', 'Tuesday'),
  DropdownOption('3', 'Wednesday'),
  DropdownOption('4', 'Thursday'),
  DropdownOption('5', 'Friday'),
  DropdownOption('6', 'Saturday'),
  DropdownOption('7', 'Sunday'),
];

class IndustrySettingsScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustrySettingsScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustrySettingsScreen> createState() => _IndustrySettingsScreenState();
}

class _IndustrySettingsScreenState extends State<IndustrySettingsScreen> {
  bool _isLoading = false;
  bool _isSavingWages = false;
  bool _isSavingRatios = false;
  String? _errorMessage;
  IndustrySettings? _settings;

  final _dailyRate = TextEditingController();
  String _weekStartDay = '1';
  String _weekEndDay = '6';
  final _clockInTime = TextEditingController();
  final _clockOutTime = TextEditingController();
  final _lateGraceMinutes = TextEditingController();
  String _latePenaltyMode = 'flat';
  final _latePenaltyAmount = TextEditingController();
  final _latePenaltyBlockMinutes = TextEditingController();

  final _mattressStrapsPerMattress = TextEditingController();
  final _rollerStrapsPerBig = TextEditingController();
  final _rollerStrapsPerSmall = TextEditingController();
  final _rollerPcsPerStrap = TextEditingController();
  final _rollerPcsPerBig = TextEditingController();
  final _rollerPcsPerSmall = TextEditingController();

  final _newLabourerTypeName = TextEditingController();
  String _newLabourerTypePayModel = 'daily_rate';
  final _newProductionLineName = TextEditingController();
  bool _isAddingLabourerType = false;
  bool _isAddingProductionLine = false;
  int? _deletingLabourerTypeId;
  int? _deletingProductionLineId;
  int? _savingMachineLineId;
  int? _savingPackingProductId;
  final Map<int, String> _machineLineSelections = {};
  final Map<int, TextEditingController> _packingItemControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in [
      _dailyRate, _clockInTime, _clockOutTime,
      _lateGraceMinutes, _latePenaltyAmount, _latePenaltyBlockMinutes,
      _mattressStrapsPerMattress, _rollerStrapsPerBig, _rollerStrapsPerSmall, _rollerPcsPerStrap,
      _rollerPcsPerBig, _rollerPcsPerSmall, _newLabourerTypeName, _newProductionLineName,
    ]) {
      c.dispose();
    }
    for (final c in _packingItemControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await widget.service.getSettingsValues();

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

    final s = response.data!;
    _dailyRate.text = s.dailyRate;
    _weekStartDay = _weekDays.any((d) => d.value == s.weekStartDay) ? s.weekStartDay : '1';
    _weekEndDay = _weekDays.any((d) => d.value == s.weekEndDay) ? s.weekEndDay : '6';
    _clockInTime.text = s.clockInTime;
    _clockOutTime.text = s.clockOutTime;
    _lateGraceMinutes.text = s.lateGraceMinutes;
    _latePenaltyMode = s.latePenaltyMode == 'per_block' ? 'per_block' : 'flat';
    _latePenaltyAmount.text = s.latePenaltyAmount;
    _latePenaltyBlockMinutes.text = s.latePenaltyBlockMinutes;
    _mattressStrapsPerMattress.text = s.mattressStrapsPerMattress;
    _rollerStrapsPerBig.text = s.rollerStrapsPerBig;
    _rollerStrapsPerSmall.text = s.rollerStrapsPerSmall;
    _rollerPcsPerStrap.text = s.rollerPcsPerStrap;
    _rollerPcsPerBig.text = s.rollerPcsPerBig;
    _rollerPcsPerSmall.text = s.rollerPcsPerSmall;

    _machineLineSelections.clear();
    for (final m in s.machineLineLinks) {
      _machineLineSelections[m.machineId] = m.lineId ?? '';
    }
    for (final c in _packingItemControllers.values) {
      c.dispose();
    }
    _packingItemControllers.clear();
    for (final p in s.packingProductLinks) {
      _packingItemControllers[p.productId] = TextEditingController(text: p.itemName);
    }

    setState(() {
      _settings = s;
      _isLoading = false;
    });
  }

  void _showResult(bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: success ? Colors.green : Colors.red),
    );
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initial = parts.length >= 2
        ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() => controller.text = '$hh:$mm');
    }
  }

  Future<void> _saveWages() async {
    setState(() => _isSavingWages = true);
    final response = await widget.service.saveWagesSettings(
      dailyRate: _dailyRate.text,
      weekStartDay: _weekStartDay,
      weekEndDay: _weekEndDay,
      clockInTime: _clockInTime.text,
      clockOutTime: _clockOutTime.text,
      lateGraceMinutes: _lateGraceMinutes.text,
      latePenaltyMode: _latePenaltyMode,
      latePenaltyAmount: _latePenaltyAmount.text,
      latePenaltyBlockMinutes: _latePenaltyBlockMinutes.text,
    );
    if (!mounted) return;
    setState(() => _isSavingWages = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) widget.onSessionExpired();
  }

  Future<void> _saveRatios() async {
    setState(() => _isSavingRatios = true);
    final response = await widget.service.saveProductionRatioSettings(
      mattressStrapsPerMattress: _mattressStrapsPerMattress.text,
      rollerStrapsPerBig: _rollerStrapsPerBig.text,
      rollerStrapsPerSmall: _rollerStrapsPerSmall.text,
      rollerPcsPerStrap: _rollerPcsPerStrap.text,
      rollerPcsPerBig: _rollerPcsPerBig.text,
      rollerPcsPerSmall: _rollerPcsPerSmall.text,
    );
    if (!mounted) return;
    setState(() => _isSavingRatios = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) widget.onSessionExpired();
  }

  Future<void> _addLabourerType() async {
    if (_newLabourerTypeName.text.trim().isEmpty) return;
    setState(() => _isAddingLabourerType = true);
    final response = await widget.service.saveLabourerType(
      name: _newLabourerTypeName.text.trim(),
      payModel: _newLabourerTypePayModel,
    );
    if (!mounted) return;
    setState(() => _isAddingLabourerType = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) {
      _newLabourerTypeName.clear();
      _load();
    }
  }

  Future<void> _deleteLabourerType(int id) async {
    setState(() => _deletingLabourerTypeId = id);
    final response = await widget.service.deleteLabourerType(id);
    if (!mounted) return;
    setState(() => _deletingLabourerTypeId = null);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) _load();
  }

  Future<void> _addProductionLine() async {
    if (_newProductionLineName.text.trim().isEmpty) return;
    setState(() => _isAddingProductionLine = true);
    final response = await widget.service.saveProductionLine(_newProductionLineName.text.trim());
    if (!mounted) return;
    setState(() => _isAddingProductionLine = false);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) {
      _newProductionLineName.clear();
      _load();
    }
  }

  Future<void> _deleteProductionLine(int id) async {
    setState(() => _deletingProductionLineId = id);
    final response = await widget.service.deleteProductionLine(id);
    if (!mounted) return;
    setState(() => _deletingProductionLineId = null);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) {
      widget.onSessionExpired();
      return;
    }
    if (response.isSuccess) _load();
  }

  Future<void> _saveMachineLine(int machineId) async {
    setState(() => _savingMachineLineId = machineId);
    final response = await widget.service.saveMachineLine(
      machineId: machineId,
      lineId: _machineLineSelections[machineId] ?? '',
    );
    if (!mounted) return;
    setState(() => _savingMachineLineId = null);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) widget.onSessionExpired();
  }

  Future<void> _savePackingProductLink(int productId) async {
    setState(() => _savingPackingProductId = productId);
    final response = await widget.service.savePackingProductItemLink(
      productId: productId,
      itemName: _packingItemControllers[productId]?.text.trim() ?? '',
    );
    if (!mounted) return;
    setState(() => _savingPackingProductId = null);
    _showResult(response.isSuccess, response.message);
    if (response.statusCode == 440) widget.onSessionExpired();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    return _buildBody();
  }

  Widget _buildBody() {
    final settings = _settings;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: industryScrollPadding(context),
        children: [
          _panel(
            icon: Icons.build,
            title: 'Settings',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _labeledField('Daily Rate', _field(_dailyRate, 'Daily Rate')),
                _labeledField(
                  'Pay Week Start Day',
                  DropdownButtonFormField<String>(
                    initialValue: _weekStartDay,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: _weekDays.map((d) => DropdownMenuItem(value: d.value, child: Text(d.label))).toList(),
                    onChanged: (v) => setState(() => _weekStartDay = v ?? '1'),
                  ),
                ),
                _labeledField(
                  'Pay Week End Day',
                  DropdownButtonFormField<String>(
                    initialValue: _weekEndDay,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: _weekDays.map((d) => DropdownMenuItem(value: d.value, child: Text(d.label))).toList(),
                    onChanged: (v) => setState(() => _weekEndDay = v ?? '6'),
                  ),
                ),
                const Divider(height: 28),
                Row(
                  children: const [
                    Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                    SizedBox(width: 6),
                    Text('Attendance Policy', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                _labeledField(
                  'Expected Clock In',
                  _timeField(_clockInTime),
                ),
                _labeledField(
                  'Expected Clock Out',
                  _timeField(_clockOutTime),
                ),
                _labeledField(
                  'Grace Period (minutes)',
                  _field(_lateGraceMinutes, 'Grace Period'),
                  hint: 'Lateness up to this many minutes is not penalised',
                ),
                _labeledField(
                  'Penalty Type',
                  DropdownButtonFormField<String>(
                    initialValue: _latePenaltyMode,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'flat', child: Text('Fixed amount (once)')),
                      DropdownMenuItem(value: 'per_block', child: Text('Per block of minutes late')),
                    ],
                    onChanged: (v) => setState(() => _latePenaltyMode = v ?? 'flat'),
                  ),
                ),
                _labeledField(
                  'Penalty Amount',
                  _field(_latePenaltyAmount, 'Penalty Amount'),
                  hint: "Deducted from the day's wage. Set to 0 to disable penalties.",
                ),
                if (_latePenaltyMode == 'per_block')
                  _labeledField(
                    'Block Size (minutes)',
                    _field(_latePenaltyBlockMinutes, 'Block Size'),
                    hint: 'Each started block past the grace period costs the penalty amount',
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSavingWages ? null : _saveWages,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
                    child: _isSavingWages
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.shuffle,
            title: 'Production Ratios',
            hint: "Uwiano huu unatumika kuhesabu 'pcs zinazotarajiwa' (hint) kwenye Roller Usage, "
                'Mattress Usage na Production -- si sheria ngumu, ni kumbukumbu tu.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _labeledField('Mikanda kwa Godoro 1 (Straps per Mattress)',
                    _field(_mattressStrapsPerMattress, 'Straps per Mattress')),
                _labeledField('Mikanda kwa Roller Kubwa 1 (Straps per Big Roller)',
                    _field(_rollerStrapsPerBig, 'Straps per Big Roller')),
                _labeledField('Mikanda kwa Roller Ndogo 1 (Straps per Small Roller)',
                    _field(_rollerStrapsPerSmall, 'Straps per Small Roller')),
                _labeledField('Pcs kwa Mkanda 1 (Pcs per Strap)', _field(_rollerPcsPerStrap, 'Pcs per Strap')),
                _labeledField('PC kwa Roller Kubwa 1 (Steel Wire)', _field(_rollerPcsPerBig, 'PC per Big Roller')),
                _labeledField(
                    'PC kwa Roller Ndogo 1 (Steel Wire)', _field(_rollerPcsPerSmall, 'PC per Small Roller')),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSavingRatios ? null : _saveRatios,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
                    child: _isSavingRatios
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.sell_outlined,
            title: 'Aina za Kazi (Labourer Types)',
            hint: 'Ongeza aina mpya za kazi hapa. Kila aina lazima ichague jinsi inavyolipwa: '
                'Mshahara wa Siku (daily rate) au Kulingana na Kazi (piece rate).',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in settings?.labourerTypes ?? []) _labourerTypeRow(t),
                const SizedBox(height: 12),
                TextField(
                  controller: _newLabourerTypeName,
                  decoration: const InputDecoration(
                      hintText: 'Jina la Aina', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _newLabourerTypePayModel,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'daily_rate', child: Text('Mshahara wa Siku (Daily Rate)')),
                    DropdownMenuItem(value: 'piece_rate', child: Text('Kulingana na Kazi (Piece Rate)')),
                    DropdownMenuItem(value: 'monthly_rate', child: Text('Mshahara wa Mwezi (Monthly Rate)')),
                  ],
                  onChanged: (v) => setState(() => _newLabourerTypePayModel = v ?? 'daily_rate'),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _isAddingLabourerType
                      ? const Center(
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : ElevatedButton(
                          onPressed: _addLabourerType,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
                          child: const Text('Ongeza'),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.grid_view,
            title: 'Lines za Uzalishaji (Production Lines)',
            hint: 'Ongeza line mpya hapa (mfano Line ya Auto, Line ya Manual 1). '
                'Kila Mashine na kila Mfanyakazi wanaweza kupewa Line yao kwenye fomu zao.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final l in settings?.productionLines ?? []) _productionLineRow(l),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newProductionLineName,
                        decoration: const InputDecoration(
                            hintText: 'Jina la Line', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isAddingProductionLine
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : ElevatedButton(
                            onPressed: _addProductionLine,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
                            child: const Text('Ongeza'),
                          ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.link,
            title: 'Mashine - Kuunganisha na Line',
            hint: 'Chagua Line ya kila Mashine hapa, kisha bonyeza Submit. '
                'Hii ni njia ya haraka badala ya kufungua fomu ya Mashine kila moja.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final m in settings?.machineLineLinks ?? []) _machineLineRow(m),
                if (settings == null || settings.machineLineLinks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No machines configured.', style: TextStyle(color: Colors.black54)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            icon: Icons.link,
            title: 'Packing Products - Kuunganisha na Items',
            hint: 'Bidhaa ya Packing (Shenke, Ridax Kibegi, Canye n.k.) inahitaji kuunganishwa na Item halisi '
                'ili Ku-Issue kuende moja kwa moja STOCK 1 - MAIN. Badilisha na Submit kubadilisha muunganiko.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in settings?.packingProductLinks ?? []) _packingProductRow(p),
                if (settings == null || settings.packingProductLinks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No Packing Products to display.', style: TextStyle(color: Colors.black54)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labourerTypeRow(LabourerTypeRow t) {
    final isDeleting = _deletingLabourerTypeId == t.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text('${t.labourerCount} wafanyakazi',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(t.payModelLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IndustryCasualLabourersScreen(
                      service: widget.service,
                      onSessionExpired: widget.onSessionExpired,
                    ),
                  ),
                ).then((_) => _load()),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ongeza Mfanyakazi', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32)),
              ),
              const Spacer(),
              if (t.labourerCount == 0)
                isDeleting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _deleteLabourerType(t.id),
                      ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _productionLineRow(ProductionLineRow l) {
    final isDeleting = _deletingProductionLineId == l.id;
    final deletable = l.labourerCount == 0 && l.machineCount == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: Text('${l.labourerCount} watu', style: TextStyle(fontSize: 11, color: Colors.blue.shade800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
            child: Text('${l.machineCount} mashine', style: TextStyle(fontSize: 11, color: Colors.teal.shade800)),
          ),
          if (deletable)
            isDeleting
                ? const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _deleteProductionLine(l.id),
                  ),
        ],
      ),
    );
  }

  Widget _machineLineRow(MachineLineLink m) {
    final isSaving = _savingMachineLineId == m.machineId;
    final current = _machineLineSelections[m.machineId] ?? '';
    final options = <DropdownOption>[const DropdownOption('', '-- Bila Line --'), ...m.lineOptions];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: options.any((o) => o.value == current) ? current : '',
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: options
                      .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => _machineLineSelections[m.machineId] = v ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : ElevatedButton(
                      onPressed: () => _saveMachineLine(m.machineId),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary, minimumSize: const Size(0, 36)),
                      child: const Text('Submit', style: TextStyle(fontSize: 12)),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _packingProductRow(PackingProductLink p) {
    final isSaving = _savingPackingProductId == p.productId;
    final controller = _packingItemControllers.putIfAbsent(p.productId, () => TextEditingController(text: p.itemName));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                      hintText: 'Linked Item', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : ElevatedButton(
                      onPressed: () => _savePackingProductLink(p.productId),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary, minimumSize: const Size(0, 36)),
                      child: const Text('Submit', style: TextStyle(fontSize: 12)),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required IconData icon,
    required String title,
    String? hint,
    required Widget child,
  }) {
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
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hint != null) ...[
                  Text(hint, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                ],
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledField(String label, Widget field, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          field,
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(hint, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
    );
  }

  Widget _timeField(TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickTime(controller),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        suffixIcon: Icon(Icons.access_time, size: 18),
      ),
    );
  }
}
