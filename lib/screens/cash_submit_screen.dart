import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cash_submit.dart';
import '../models/supervisor.dart';
import '../models/permission_model.dart';
import '../providers/theme_provider.dart';
import '../providers/location_provider.dart';
import '../providers/permission_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/permission_wrapper.dart';
import '../widgets/glassmorphic_card.dart';

class CashSubmitScreen extends StatefulWidget {
  const CashSubmitScreen({super.key});

  @override
  State<CashSubmitScreen> createState() => _CashSubmitScreenState();
}

class _CashSubmitScreenState extends State<CashSubmitScreen> {
  final ApiService _apiService = ApiService();
  List<CashSubmitListItem> _submissions = [];
  bool _isLoading = false;

  // Date range state - default to last 7 days
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Defer location initialization until after build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;

    final currentClient = ApiService.currentClient;
    final clientId = currentClient?.id ?? 'sada';

    print('💼 Cash Submit Init - Client ID: $clientId');

    // Initialize location provider only for Come & Save
    if (clientId == 'come_and_save') {
      print('📍 Initializing location provider for Come & Save');
      final locationProvider = context.read<LocationProvider>();
      await locationProvider.initialize(moduleId: 'sales'); // Use sales permissions
      print('📍 Location provider initialized. Locations: ${locationProvider.allowedLocations.length}');
    } else {
      print('📍 Skipping location initialization for SADA');
    }

    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);

    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    // Get location only for Come & Save client
    final currentClient = ApiService.currentClient;
    final clientId = currentClient?.id ?? 'sada';

    int? selectedLocationId;
    if (clientId == 'come_and_save') {
      final locationProvider = context.read<LocationProvider>();
      selectedLocationId = locationProvider.selectedLocation?.locationId;
    }

    final result = await _apiService.getCashSubmissions(
      startDate: startDateStr,
      endDate: endDateStr,
      locationId: selectedLocationId, // null for SADA, specific location for Come & Save
      limit: 100,
    );

    setState(() {
      if (result.isSuccess && result.data != null) {
        _submissions = result.data!;
        // API already filters by location, just sort by date (newest first)
        _submissions.sort((a, b) => b.date.compareTo(a.date));
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Failed to load cash submissions'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      _isLoading = false;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.success,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadSubmissions();
    }
  }

  Future<void> _showCreateDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _CreateCashSubmissionDialog(
        onCreated: () {
          _loadSubmissions();
        },
      ),
    );
  }

  Future<void> _showEditDialog(CashSubmitListItem submission) async {
    await showDialog(
      context: context,
      builder: (context) => _CreateCashSubmissionDialog(
        submission: submission,
        onCreated: () {
          _loadSubmissions();
        },
      ),
    );
  }

  Future<void> _deleteSubmission(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Submission'),
        content: const Text('Are you sure you want to delete this cash submission?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _apiService.deleteCashSubmission(id);

      if (mounted) {
        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cash submission deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadSubmissions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Failed to delete submission'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildSubmissionCard(CashSubmitListItem submission, bool isDark) {
    final permissionProvider = context.read<PermissionProvider>();
    final hasEditPermission = permissionProvider.hasPermission(PermissionIds.cashSubmitEdit);
    final hasDeletePermission = permissionProvider.hasPermission(PermissionIds.cashSubmitDelete);
    final isPositive = submission.amount >= 0;
    final amountColor = isPositive ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon with gradient background
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          amountColor.withOpacity(0.8),
                          amountColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: amountColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              Formatters.formatDate(submission.date),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Amount in badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: amountColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: amountColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            Formatters.formatCurrency(submission.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: amountColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  Column(
                    children: [
                      if (hasEditPermission)
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                            onPressed: () => _showEditDialog(submission),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            tooltip: 'Edit submission',
                          ),
                        ),
                      if (hasEditPermission && hasDeletePermission)
                        const SizedBox(height: 8),
                      if (hasDeletePermission)
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                            onPressed: () => _deleteSubmission(submission.id),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete submission',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (submission.supervisorName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBackground.withOpacity(0.5)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Supervisor: ${submission.supervisorName}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final locationProvider = context.watch<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;
    final locations = locationProvider.allowedLocations;

    // Debug: Check client and locations
    final currentClient = ApiService.currentClient;
    final clientId = currentClient?.id ?? 'unknown';
    print('💼 Cash Submit - Client: $clientId, Locations: ${locations.length}, Selected: ${selectedLocation?.locationName}');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Cash Submissions'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.success,
        foregroundColor: Colors.white,
        actions: [
          // Location selector (Come & Save only)
          if (ApiService.currentClient?.id == 'come_and_save' && locations.isNotEmpty)
            PopupMenuButton<int>(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    selectedLocation?.locationName ?? 'Location',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
              color: isDark ? AppColors.darkCard : Colors.white,
              offset: const Offset(0, 50),
              onSelected: (locationId) {
                final location = locations.firstWhere((loc) => loc.locationId == locationId);
                locationProvider.selectLocation(location);
                _loadSubmissions();
              },
              itemBuilder: (context) {
                return locations.map((location) {
                  return PopupMenuItem<int>(
                    value: location.locationId,
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 18,
                          color: selectedLocation?.locationId == location.locationId
                              ? AppColors.primary
                              : (isDark ? Colors.white70 : AppColors.textLight),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          location.locationName,
                          style: TextStyle(
                            color: selectedLocation?.locationId == location.locationId
                                ? AppColors.primary
                                : (isDark ? Colors.white : AppColors.text),
                            fontWeight: selectedLocation?.locationId == location.locationId
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter by date range',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark
                ? AppColors.darkSurface
                : AppColors.success.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          // Content with gradient background
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.darkBackground, AppColors.darkSurface]
                      : [AppColors.lightBackground, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _submissions.isEmpty
                      ? Center(
                          child: Text(
                            'No cash submissions found for this date range',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadSubmissions,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _submissions.length,
                          itemBuilder: (context, index) {
                            final submission = _submissions[index];
                            return _buildSubmissionCard(submission, isDark);
                          },
                        ),
                      ),
            ),
          ),
        ],
      ),
      floatingActionButton: PermissionFAB(
        permissionId: PermissionIds.cashSubmitAdd,
        onPressed: _showCreateDialog,
        tooltip: 'Add Cash Submission',
        backgroundColor: AppColors.success,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }
}

class _CreateCashSubmissionDialog extends StatefulWidget {
  final VoidCallback onCreated;
  final CashSubmitListItem? submission;

  const _CreateCashSubmissionDialog({
    required this.onCreated,
    this.submission,
  });

  @override
  State<_CreateCashSubmissionDialog> createState() =>
      _CreateCashSubmissionDialogState();
}

class _CreateCashSubmissionDialogState
    extends State<_CreateCashSubmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final ApiService _apiService = ApiService();

  DateTime _selectedDate = DateTime.now();
  Supervisor? _selectedSupervisor;
  List<Supervisor> _supervisors = [];
  bool _isLoading = false;
  bool _isLoadingSupervisors = false;

  @override
  void initState() {
    super.initState();
    _loadSupervisors();

    // Initialize with existing values if editing
    if (widget.submission != null) {
      _amountController.text = widget.submission!.amount.toString();
      _selectedDate = DateTime.parse(widget.submission!.date);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadSupervisors() async {
    setState(() => _isLoadingSupervisors = true);

    final result = await _apiService.getSupervisors();

    setState(() {
      if (result.isSuccess && result.data != null) {
        _supervisors = result.data!;
        if (_supervisors.isNotEmpty) {
          _selectedSupervisor = _supervisors.first;
        }
      }
      _isLoadingSupervisors = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSupervisor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a supervisor'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final locationProvider = context.read<LocationProvider>();
    final selectedLocationId = locationProvider.selectedLocation?.locationId ?? 1;

    final result = widget.submission == null
        ? await _apiService.createCashSubmission(
            amount: amount,
            date: Formatters.formatDateForApi(_selectedDate),
            supervisorId: int.parse(_selectedSupervisor!.id),
            stockLocationId: selectedLocationId,
          )
        : await _apiService.updateCashSubmission(
            widget.submission!.id,
            amount: amount,
            date: Formatters.formatDateForApi(_selectedDate),
            supervisorId: int.parse(_selectedSupervisor!.id),
          );

    setState(() => _isLoading = false);

    if (result.isSuccess && mounted) {
      Navigator.pop(context);
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.submission == null
              ? 'Cash submission created successfully'
              : 'Cash submission updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final locationProvider = context.watch<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      title: Text(
        widget.submission == null ? 'Submit Cash' : 'Edit Cash Submission',
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.text,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Location Display
              if (selectedLocation != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primary.withOpacity(0.2)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Location: ${selectedLocation.locationName}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _amountController,
                style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Amount (TZS)',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                  border: const OutlineInputBorder(),
                  prefixText: 'TZS ',
                  prefixStyle: TextStyle(color: isDark ? Colors.white : AppColors.text),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty == true) return 'Required';
                  if (double.tryParse(v!) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Consumer<PermissionProvider>(
                builder: (context, permissionProvider, child) {
                  final hasDatePermission = permissionProvider.hasPermission(PermissionIds.cashSubmitDate);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        tileColor: isDark ? AppColors.darkSurface : Colors.grey[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                        ),
                        title: Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        subtitle: Text(
                          Formatters.formatDate(Formatters.formatDateForApi(_selectedDate)),
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : AppColors.text,
                          ),
                        ),
                        trailing: Icon(
                          hasDatePermission ? Icons.calendar_today : Icons.lock,
                          color: hasDatePermission
                              ? (isDark ? Colors.white70 : null)
                              : (isDark ? Colors.orange[300] : AppColors.warning),
                        ),
                        enabled: hasDatePermission,
                        onTap: hasDatePermission ? () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        } : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You do not have permission to change the date'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        },
                      ),
                      if (!hasDatePermission)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4),
                          child: Text(
                            'You do not have permission to change the date',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.orange[300] : AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_isLoadingSupervisors)
                const Center(child: CircularProgressIndicator())
              else if (_supervisors.isEmpty)
                Text(
                  'No supervisors available',
                  style: TextStyle(
                    color: isDark ? Colors.red[300] : AppColors.error,
                  ),
                )
              else
                DropdownButtonFormField<Supervisor>(
                  value: _selectedSupervisor,
                  dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                  decoration: InputDecoration(
                    labelText: 'Supervisor',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  items: _supervisors.map((supervisor) {
                    return DropdownMenuItem(
                      value: supervisor,
                      child: Text(supervisor.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedSupervisor = value);
                  },
                  validator: (v) => v == null ? 'Please select supervisor' : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
