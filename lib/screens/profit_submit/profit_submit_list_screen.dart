import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../../models/profit_submit.dart';
import '../../models/permission_model.dart';
import '../../models/stock_location.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/glassmorphic_card.dart';
import '../pdf_viewer_screen.dart';
import 'new_profit_submit_screen.dart';

class ProfitSubmitListScreen extends StatefulWidget {
  const ProfitSubmitListScreen({super.key});

  @override
  State<ProfitSubmitListScreen> createState() => _ProfitSubmitListScreenState();
}

class _ProfitSubmitListScreenState extends State<ProfitSubmitListScreen> {
  final ApiService _apiService = ApiService();

  List<ProfitSubmitListItem> _profitSubmissions = [];
  List<ProfitSubmitListItem> _filteredProfitSubmissions = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Date range state - default to last 7 days
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  // Stock location filter
  String? _selectedLocationFilter;
  List<StockLocation> _availableLocations = [];
  bool _isLoadingLocations = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// Initialize location and load data
  Future<void> _initialize() async {
    await _initializeLocationFilter();
    await _loadProfitSubmissions();
  }

  /// Load allowed stock locations from API
  Future<void> _initializeLocationFilter() async {
    setState(() {
      _isLoadingLocations = true;
    });

    try {
      // Use 'sales' module since profit submit uses sales_ permissions
      final response = await _apiService.getAllowedStockLocations(moduleId: 'sales');

      if (response.isSuccess && response.data != null) {
        final locations = response.data!
            .where((location) => !location.deleted)
            .toList();

        setState(() {
          _availableLocations = locations;
          _isLoadingLocations = false;

          // Set default to first location if available
          if (locations.isNotEmpty && _selectedLocationFilter == null) {
            _selectedLocationFilter = locations.first.locationName;
          }
        });
      } else {
        setState(() {
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocations = false;
      });
      debugPrint('Error loading locations: $e');
    }
  }

  Future<void> _loadProfitSubmissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    try {
      final response = await _apiService.getProfitSubmissions(
        startDate: startDateStr,
        endDate: endDateStr,
        stockLocation: _selectedLocationFilter,
        limit: 100,
      );

      if (response.isSuccess && response.data != null) {
        final profitsData = response.data!['profit_submissions'] as List;
        final profitsList = profitsData
            .map((json) => ProfitSubmitListItem.fromJson(json))
            .toList();

        setState(() {
          _profitSubmissions = profitsList;
          _filteredProfitSubmissions = profitsList; // Already filtered by API
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Failed to load profit submissions';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.darkCard,
                    onSurface: AppColors.darkText,
                    background: AppColors.darkBackground,
                    onBackground: AppColors.darkText,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                    background: Colors.white,
                    onBackground: Colors.black,
                  ),
            dialogBackgroundColor: isDark ? AppColors.darkCard : Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
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
      _loadProfitSubmissions();
    }
  }


  void _onLocationFilterChanged(String? location) {
    setState(() {
      _selectedLocationFilter = location;
    });
    // Reload data from API with new location filter
    _loadProfitSubmissions();
  }

  Future<void> _onRefresh() async {
    await _loadProfitSubmissions();
  }

  void _navigateToNewProfitSubmit() {
    final permissionProvider = Provider.of<PermissionProvider>(context, listen: false);

    // Check cash_submit_add_profit permission
    if (!permissionProvider.hasPermission(PermissionIds.cashSubmitAddProfit)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to add profit submissions'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Get selected stock location
    final selectedLocation = _availableLocations.firstWhere(
      (loc) => loc.locationName == _selectedLocationFilter,
      orElse: () => _availableLocations.isNotEmpty ? _availableLocations.first : StockLocation(locationId: 1, locationName: 'KIWANGWA', deleted: false),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewProfitSubmitScreen(
          stockLocationId: selectedLocation.locationId,
          stockLocationName: selectedLocation.locationName,
        ),
      ),
    ).then((_) => _loadProfitSubmissions());
  }

  Future<void> _deleteProfitSubmit(ProfitSubmitListItem profit) async {
    final permissionProvider = Provider.of<PermissionProvider>(context, listen: false);

    // Check cash_submit_delete_profit permission
    if (!permissionProvider.hasPermission(PermissionIds.cashSubmitDeleteProfit)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to delete profit submissions'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profit Submit'),
        content: Text(
          'Are you sure you want to delete this profit submission?\n\n'
          'Amount: ${_formatCurrency(profit.amount)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await _apiService.deleteProfitSubmission(profit.id);

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profit submission deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadProfitSubmissions();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to delete profit submission'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return '${formatter.format(amount)} TSh';
  }

  /// Show file options dialog
  Future<void> _showFileOptions(ProfitSubmitListItem profit) async {
    if (profit.picFile == null || profit.picFile!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.visibility, color: AppColors.primary),
                  title: const Text('View File'),
                  onTap: () {
                    Navigator.pop(context);
                    _viewFile(profit);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download, color: AppColors.success),
                  title: const Text('Download'),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadFile(profit);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: AppColors.warning),
                  title: const Text('Share'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareFile(profit);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// View file (PDF or image)
  Future<void> _viewFile(ProfitSubmitListItem profit) async {
    if (profit.picFile == null || profit.picFile!.isEmpty) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Download file to temp directory
      final file = await _downloadFileToTemp(profit.picFile!);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load file'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final extension = file.path.split('.').last.toLowerCase();

      if (extension == 'pdf') {
        // Open PDF viewer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              filePath: file.path,
              title: 'Profit Slip',
            ),
          ),
        );
      } else {
        // Show image in dialog
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Profit Slip'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.file(file),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error viewing file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Download file to device
  Future<void> _downloadFile(ProfitSubmitListItem profit) async {
    if (profit.picFile == null || profit.picFile!.isEmpty) return;

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading file...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Get downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'profit_slip_${profit.id}_${DateTime.now().millisecondsSinceEpoch}.${profit.picFile!.split('.').last}';
      final filePath = '${directory.path}/$fileName';

      // Download file
      final response = await http.get(Uri.parse(profit.picFile!));
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved to: $filePath'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Share file
  Future<void> _shareFile(ProfitSubmitListItem profit) async {
    if (profit.picFile == null || profit.picFile!.isEmpty) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Download file to temp directory
      final file = await _downloadFileToTemp(profit.picFile!);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load file for sharing'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Share file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Profit Slip - ${_formatCurrency(profit.amount)} on ${_formatDate(profit.date)}',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Download file to temporary directory
  Future<File?> _downloadFileToTemp(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final tempDir = await getTemporaryDirectory();
      final fileName = url.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final permissionProvider = context.watch<PermissionProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = themeProvider.isDarkMode;

    // Check permissions
    final canAdd = permissionProvider.hasPermission(PermissionIds.cashSubmitAddProfit);
    final canEdit = permissionProvider.hasPermission(PermissionIds.cashSubmitEditProfit);
    final canDelete = permissionProvider.hasPermission(PermissionIds.cashSubmitDeleteProfit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit Submissions'),
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
          // Location dropdown (if user has access to multiple locations)
          if (_availableLocations.length > 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark
                  ? AppColors.darkCard
                  : Colors.grey.shade100,
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 20,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Stock Location:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkText : AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedLocationFilter,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : Colors.white,
                      ),
                      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                      items: _availableLocations.map((location) {
                        return DropdownMenuItem<String>(
                          value: location.locationName,
                          child: Text(location.locationName),
                        );
                      }).toList(),
                      onChanged: _onLocationFilterChanged,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Content
          Expanded(
            child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          )),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadProfitSubmissions,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _filteredProfitSubmissions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.attach_money,
                              size: 64, color: isDark ? AppColors.darkTextLight : Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No profit submissions found',
                            style: TextStyle(
                              fontSize: 18,
                              color: isDark ? AppColors.darkText : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedLocationFilter != null
                                ? 'Try changing the location filter'
                                : 'Start by creating your first profit submission',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextLight : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [AppColors.darkBackground, AppColors.darkSurface]
                              : [AppColors.lightBackground, Colors.white],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredProfitSubmissions.length,
                          itemBuilder: (context, index) {
                            final profit = _filteredProfitSubmissions[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: GlassmorphicCard(
                                isDark: isDark,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          // Gradient icon
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.success.withOpacity(0.8),
                                                  AppColors.success,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.success.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.trending_up,
                                              size: 24,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Amount
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _formatCurrency(profit.amount),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                    color: isDark ? AppColors.darkText : AppColors.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatDate(profit.date),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Action buttons (edit and delete)
                                          if (canEdit || canDelete)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Edit button
                                                if (canEdit)
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                      color: AppColors.primary,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => NewProfitSubmitScreen(profit: profit),
                                                        ),
                                                      ).then((_) => _loadProfitSubmissions());
                                                    },
                                                  ),
                                                // Delete button
                                                if (canDelete)
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: AppColors.error,
                                                    ),
                                                    onPressed: () => _deleteProfitSubmit(profit),
                                                  ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Details container
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.darkCard.withOpacity(0.3)
                                              : Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isDark
                                                ? AppColors.darkCard.withOpacity(0.5)
                                                : Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.supervisor_account,
                                                  size: 16,
                                                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    profit.supervisorName,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark ? AppColors.darkText : AppColors.text,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (profit.locationName != null && profit.locationName!.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.location_on,
                                                    size: 16,
                                                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      profit.locationName!,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: isDark ? AppColors.darkText : AppColors.text,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            // File attachment indicator
                                            if (profit.picFile != null && profit.picFile!.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              InkWell(
                                                onTap: () => _showFileOptions(profit),
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: AppColors.primary.withOpacity(0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        profit.picFile!.toLowerCase().endsWith('.pdf')
                                                            ? Icons.picture_as_pdf
                                                            : Icons.image,
                                                        size: 16,
                                                        color: AppColors.primary,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Profit Slip Attached',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors.primary,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.touch_app,
                                                        size: 14,
                                                        color: AppColors.primary.withOpacity(0.7),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: _navigateToNewProfitSubmit,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('New Profit'),
            )
          : null,
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }
}
