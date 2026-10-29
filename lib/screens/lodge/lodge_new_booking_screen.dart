import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'lodge_theme.dart';

/// `POST lodge/bookings` -- README 3.3. One page, three sections: guest,
/// dates, room (room list only loads once both dates are picked, since
/// `rooms/available` needs the range to know what's free).
class LodgeNewBookingScreen extends StatefulWidget {
  final int? initialRoomId;
  final String? initialCheckInDate;
  final int? locationId;

  /// Pre-fill from Guests -> "Book again": a past guest's name/phone, and
  /// their linked customer account if they have one (skips the autocomplete
  /// search -- we already know who this is).
  final String? initialGuestName;
  final String? initialGuestPhone;
  final int? initialCustomerId;

  const LodgeNewBookingScreen({
    super.key,
    this.initialRoomId,
    this.initialCheckInDate,
    this.locationId,
    this.initialGuestName,
    this.initialGuestPhone,
    this.initialCustomerId,
  });

  @override
  State<LodgeNewBookingScreen> createState() => _LodgeNewBookingScreenState();
}

class _LodgeNewBookingScreenState extends State<LodgeNewBookingScreen> {
  final ApiService _apiService = ApiService();
  final _guestNameController = TextEditingController();
  final _guestPhoneController = TextEditingController();
  final _guestIdController = TextEditingController();
  final _numGuestsController = TextEditingController(text: '1');
  final _customerSearchController = TextEditingController();
  final _rateController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _checkIn;
  DateTime? _checkOut;
  LodgeRoom? _selectedRoom;
  List<LodgeRoom> _availableRooms = [];
  bool _isLoadingRooms = false;

  List<LodgeCustomerSuggestion> _customerSuggestions = [];
  LodgeCustomerSuggestion? _selectedCustomer;
  bool _createCustomerAccount = false;
  Timer? _customerSearchDebounce;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCheckInDate != null) {
      _checkIn = DateTime.tryParse(widget.initialCheckInDate!);
    }
    if (widget.initialGuestName != null) {
      _guestNameController.text = widget.initialGuestName!;
    }
    if (widget.initialGuestPhone != null) {
      _guestPhoneController.text = widget.initialGuestPhone!;
    }
    if (widget.initialCustomerId != null) {
      _selectedCustomer = LodgeCustomerSuggestion(
        value: widget.initialCustomerId!,
        label: widget.initialGuestName ?? '',
      );
      _customerSearchController.text = _selectedCustomer!.label;
    }
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    _guestIdController.dispose();
    _numGuestsController.dispose();
    _customerSearchController.dispose();
    _rateController.dispose();
    _notesController.dispose();
    _customerSearchDebounce?.cancel();
    super.dispose();
  }

  bool get _datesChosen => _checkIn != null && _checkOut != null && _checkOut!.isAfter(_checkIn!);

  Future<void> _pickDate({required bool isCheckIn}) async {
    final permissions = context.read<PermissionProvider>();
    final canBackdate = permissions.hasPermission(PermissionIds.lodgeBookingsDate);
    final now = DateTime.now();
    final firstDate = canBackdate ? DateTime(now.year - 1) : DateTime(now.year, now.month, now.day);

    final initial = isCheckIn
        ? (_checkIn ?? now)
        : (_checkOut ?? (_checkIn ?? now).add(const Duration(days: 1)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;

    setState(() {
      if (isCheckIn) {
        _checkIn = picked;
        if (_checkOut != null && !_checkOut!.isAfter(picked)) {
          _checkOut = picked.add(const Duration(days: 1));
        }
      } else {
        _checkOut = picked;
      }
      _selectedRoom = null;
      _availableRooms = [];
    });

    if (_datesChosen) _loadAvailableRooms();
  }

  Future<void> _loadAvailableRooms() async {
    setState(() => _isLoadingRooms = true);
    final response = await _apiService.getLodgeAvailableRooms(
      checkInDate: Formatters.formatDateForApi(_checkIn!),
      checkOutDate: Formatters.formatDateForApi(_checkOut!),
      locationId: widget.locationId,
    );
    if (!mounted) return;
    setState(() {
      _isLoadingRooms = false;
      if (response.isSuccess && response.data != null) {
        _availableRooms = response.data!;
        if (widget.initialRoomId != null && _selectedRoom == null) {
          final match = _availableRooms.where((r) => r.roomId == widget.initialRoomId);
          if (match.isNotEmpty) _selectRoom(match.first);
        }
      } else {
        _availableRooms = [];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
        );
      }
    });
  }

  void _selectRoom(LodgeRoom room) {
    setState(() {
      _selectedRoom = room;
      _rateController.text = room.rate.toStringAsFixed(0);
    });
  }

  void _onCustomerSearchChanged(String term) {
    _customerSearchDebounce?.cancel();
    if (term.trim().length < 2) {
      setState(() => _customerSuggestions = []);
      return;
    }
    _customerSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final response = await _apiService.lodgeCustomerSuggest(term.trim());
      if (!mounted) return;
      if (response.isSuccess && response.data != null) {
        setState(() => _customerSuggestions = response.data!);
      }
    });
  }

  Future<void> _submit() async {
    if (_guestNameController.text.trim().isEmpty) {
      _snack('Guest name is required', success: false);
      return;
    }
    if (!_datesChosen) {
      _snack('Choose check-in and check-out dates', success: false);
      return;
    }
    if (_selectedRoom == null) {
      _snack('Choose a room', success: false);
      return;
    }

    setState(() => _isSubmitting = true);
    final response = await _apiService.createLodgeBooking(
      guestName: _guestNameController.text.trim(),
      roomId: _selectedRoom!.roomId,
      checkInDate: Formatters.formatDateForApi(_checkIn!),
      checkOutDate: Formatters.formatDateForApi(_checkOut!),
      guestPhone: _guestPhoneController.text.trim().isEmpty ? null : _guestPhoneController.text.trim(),
      guestIdNumber: _guestIdController.text.trim().isEmpty ? null : _guestIdController.text.trim(),
      numGuests: int.tryParse(_numGuestsController.text),
      ratePerNight: double.tryParse(_rateController.text),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      customerId: _selectedCustomer?.value,
      createCustomer: _createCustomerAccount,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response.isSuccess) {
      _snack('Booking created.', success: true);
      Navigator.pop(context, true);
    } else {
      _snack(response.message, success: false);
    }
  }

  void _snack(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: success ? AppColors.success : AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: LodgeTheme.appBar(isDark: isDark, eyebrow: 'Reservation', title: 'New Booking'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('1. Guest', isDark),
          const SizedBox(height: 8),
          TextField(
            controller: _guestNameController,
            decoration: const InputDecoration(labelText: 'Guest name *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _guestPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _guestIdController,
            decoration: const InputDecoration(labelText: 'ID number', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _numGuestsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of guests', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _customerSearchController,
            decoration: InputDecoration(
              labelText: 'Customer account (optional)',
              border: const OutlineInputBorder(),
              suffixIcon: _selectedCustomer != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _selectedCustomer = null;
                        _customerSearchController.clear();
                      }),
                    )
                  : null,
            ),
            onChanged: _onCustomerSearchChanged,
          ),
          if (_customerSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _customerSuggestions
                    .map((c) => ListTile(
                          dense: true,
                          title: Text(c.label),
                          onTap: () => setState(() {
                            _selectedCustomer = c;
                            _customerSearchController.text = c.label;
                            _customerSuggestions = [];
                          }),
                        ))
                    .toList(),
              ),
            ),
          if (_selectedCustomer == null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Create a customer account from name+phone'),
              subtitle: const Text('Only needed if the guest might leave owing a balance'),
              value: _createCustomerAccount,
              onChanged: (v) => setState(() => _createCustomerAccount = v ?? false),
            ),
          const SizedBox(height: 20),
          _sectionTitle('2. Dates', isDark),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _dateField('Check-in', _checkIn, () => _pickDate(isCheckIn: true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateField('Check-out', _checkOut, () => _pickDate(isCheckIn: false)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('3. Room', isDark),
          const SizedBox(height: 8),
          if (!_datesChosen)
            Text('Choose both dates first',
                style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight))
          else if (_isLoadingRooms)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (_availableRooms.isEmpty)
            Text('No rooms available for these dates',
                style: TextStyle(color: AppColors.error))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableRooms
                  .map((r) => ChoiceChip(
                        label: Text('${r.roomNumber} (${Formatters.formatCurrency(r.rate)})'),
                        selected: _selectedRoom?.roomId == r.roomId,
                        onSelected: (_) => _selectRoom(r),
                      ))
                  .toList(),
            ),
          if (_selectedRoom != null) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _rateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Rate/night', border: OutlineInputBorder()),
            ),
            if (_datesChosen)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${_checkOut!.difference(_checkIn!).inDays} night(s) × ${Formatters.formatCurrency(double.tryParse(_rateController.text) ?? _selectedRoom!.rate)} '
                  '= ${Formatters.formatCurrency((_checkOut!.difference(_checkIn!).inDays) * (double.tryParse(_rateController.text) ?? _selectedRoom!.rate))}',
                  style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight),
                ),
              ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save booking'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, bool isDark) {
    return Text(text,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText));
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(value != null ? Formatters.formatDateForApi(value) : '--'),
      ),
    );
  }
}
