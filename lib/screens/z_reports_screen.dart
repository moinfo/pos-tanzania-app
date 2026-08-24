import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/zreport.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/offline_actions.dart';
import '../services/offline_submit.dart';
import '../widgets/offline_submit_feedback.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../services/read_cache.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/state_views.dart';

class ZReportsScreen extends StatefulWidget {
  const ZReportsScreen({super.key});

  @override
  State<ZReportsScreen> createState() => _ZReportsScreenState();
}

class _ZReportsScreenState extends State<ZReportsScreen> {
  final ApiService _apiService = ApiService();
  List<ZReportListItem> _reports = [];
  bool _isLoading = false;

  /// The last load failed on the network rather than being answered.
  bool _offline = false;

  /// Non-null when these rows came off the saved copy.
  ///
  /// This screen used to DROP saved rows rather than show them, because a
  /// filed Z report and a stale one look identical and the screen had no way
  /// to tell them apart. The banner is that way, so the rows can stay.
  DateTime? _cachedAt;

  // Date range state - default to last 7 days
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    final result = await _apiService.getZReports(
      startDate: startDateStr,
      endDate: endDateStr,
      limit: 100,
    );

    final offline = !result.isSuccess && isTransportFailure(result);
    setState(() {
      if (result.isSuccess && result.data != null) {
        _reports = result.data!;
        _cachedAt = result.servedFromCacheAt;
        _offline = false;
      } else {
        _offline = offline;
        // Nothing on this screen can mark a row as old, so a stale report left
        // on screen reads as a filed one. Drop them and say so.
        if (offline) _reports = [];
        if (mounted && !offline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
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
            // Forcing ColorScheme.light here painted the picker's header,
            // weekday letters and month labels black on the dark theme's black
            // sheet. Tint the theme's own scheme instead, so dark mode keeps
            // its ink and light mode looks exactly as it did.
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
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
      _loadReports();
    }
  }

  Future<void> _showCreateDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _CreateZReportDialog(
        onCreated: () {
          _loadReports();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Z Reports'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter by date range',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_cachedAt != null)
            CachedDataBanner(
              fetchedAtLabel: describeCacheAge(_cachedAt!),
              noun: 'these Z reports',
              isDark: isDark,
              onRetry: _loadReports,
            ),
          // Date range display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark
                ? AppColors.darkSurface
                : AppColors.primary.withOpacity(0.1),
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
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? _buildSkeletonList(isDark)
                // Ahead of the empty state: "none in this range" is a claim
                // about the server's records.
                : _offline && _reports.isEmpty
                    ? OfflineEmptyView(
                        noun: 'Z reports',
                        isDark: isDark,
                        onRefresh: _loadReports,
                      )
                : _reports.isEmpty
                    ? Center(
                        child: Text(
                          'No Z Reports found for this date range',
                          style: TextStyle(
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReports,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _reports.length,
                          itemBuilder: (context, index) {
                            final report = _reports[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                          leading: const Icon(
                            Icons.description,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            'Date: ${Formatters.formatDate(report.date)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkText : AppColors.text,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Turnover: ${Formatters.formatCurrency(report.turnover)}',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                ),
                              ),
                              Text(
                                'Total: ${Formatters.formatCurrency(report.total)}  •  Tax: ${Formatters.formatCurrency(report.tax)}',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                ),
                              ),
                              if (report.picFile != null)
                                const Text(
                                  'File attached',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => _buildSkeletonCard(isDark),
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoader(width: 100, height: 18, isDark: isDark),
                SkeletonLoader(width: 70, height: 18, isDark: isDark),
              ],
            ),
            const SizedBox(height: 12),
            SkeletonLoader(width: 150, height: 12, isDark: isDark),
            const SizedBox(height: 8),
            SkeletonLoader(width: 120, height: 12, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _CreateZReportDialog extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateZReportDialog({required this.onCreated});

  @override
  State<_CreateZReportDialog> createState() => _CreateZReportDialogState();
}

class _CreateZReportDialogState extends State<_CreateZReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  /// Holds this form's idempotency key across attempts, so a Save that times
  /// out and is tapped again cannot file the same Z report twice.
  final OfflineSubmitter _offlineSubmit = OfflineSubmitter();

  // One controller per EFD Z-report figure, in the order they appear on the
  // fiscal printout.
  final _turnoverController = TextEditingController();
  final _netController = TextEditingController();
  final _taxController = TextEditingController();
  final _turnoverExSrController = TextEditingController();
  final _totalController = TextEditingController();
  final _totalChargesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  File? _selectedFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _turnoverController.dispose();
    _netController.dispose();
    _taxController.dispose();
    _turnoverExSrController.dispose();
    _totalController.dispose();
    _totalChargesController.dispose();
    super.dispose();
  }

  /// Parses an amount field, tolerating thousands separators typed by cashiers.
  double _amountOf(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value.trim().replaceAll(',', '')) == null) {
      return 'Enter a valid amount';
    }
    return null;
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result;
      bool useImageFallback = false;

      // Try with custom file types first
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        );
      } catch (e) {
        debugPrint('Custom file picker failed: $e');
        // Try with media type (images) as fallback - works without file manager
        try {
          result = await FilePicker.platform.pickFiles(
            type: FileType.media,
          );
          useImageFallback = true;
        } catch (e2) {
          debugPrint('Media file picker also failed: $e2');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No file manager found. Please use gallery for images, or install a file manager app for PDFs.'),
                backgroundColor: AppColors.warning,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      if (result != null && result.files.single.path != null) {
        final fileName = result.files.single.name.toLowerCase();

        // Validate file extension manually
        final allowedExtensions = useImageFallback
            ? ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']
            : ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'];
        final extension = fileName.split('.').last;
        if (!allowedExtensions.contains(extension)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(useImageFallback
                    ? 'Please select an image file'
                    : 'Please select a PDF, image, or document file'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFile = File(result!.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert file to base64
      final bytes = await _selectedFile!.readAsBytes();
      final base64String = base64Encode(bytes);

      // Determine MIME type from file extension
      String mimeType = 'image/jpeg';
      final extension = _selectedFile!.path.split('.').last.toLowerCase();

      if (extension == 'pdf') {
        mimeType = 'application/pdf';
      } else if (extension == 'png') {
        mimeType = 'image/png';
      }

      final picFile = 'data:$mimeType;base64,$base64String';

      final date = Formatters.formatDateForApi(_selectedDate);

      final result = await _offlineSubmit.submit<ZReportDetails>(
        context: context,
        action: OfflineAction.zReport,
        payload: ApiService.zReportBody(
          turnover: _amountOf(_turnoverController),
          net: _amountOf(_netController),
          tax: _amountOf(_taxController),
          turnoverExSr: _amountOf(_turnoverExSrController),
          total: _amountOf(_totalController),
          totalCharges: _amountOf(_totalChargesController),
          date: date,
          picFile: picFile,
        ),
        summary: date,
        send: (requestId) => _apiService.createZReport(
          turnover: _amountOf(_turnoverController),
          net: _amountOf(_netController),
          tax: _amountOf(_taxController),
          turnoverExSr: _amountOf(_turnoverExSrController),
          total: _amountOf(_totalController),
          totalCharges: _amountOf(_totalChargesController),
          date: date,
          picFile: picFile,
          requestId: requestId,
        ),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Queued counts as filed: it is on the device and will upload itself.
      if (result.isKept) {
        Navigator.pop(context);
        widget.onCreated();
      }

      if (result.isSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Z Report created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        showOfflineSubmitFeedback(context, result);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildAmountField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: _validateAmount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Z Report'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAmountField(_turnoverController, 'Turnover'),
              const SizedBox(height: 16),
              _buildAmountField(_netController, 'Net'),
              const SizedBox(height: 16),
              _buildAmountField(_taxController, 'Tax'),
              const SizedBox(height: 16),
              _buildAmountField(_turnoverExSrController, 'Turnover excl. SR'),
              const SizedBox(height: 16),
              _buildAmountField(_totalController, 'Total'),
              const SizedBox(height: 16),
              _buildAmountField(_totalChargesController, 'Total charges'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Date'),
                subtitle: Text(Formatters.formatDate(
                  Formatters.formatDateForApi(_selectedDate),
                )),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(_selectedFile == null
                    ? 'Select File'
                    : _selectedFile!.path.split('/').last),
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
              : const Text('Create'),
        ),
      ],
    );
  }
}
