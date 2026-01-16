import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../../utils/constants.dart';

import 'package:intl/intl.dart';
import '../../models/banking.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/permission_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/permission_wrapper.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../pdf_viewer_screen.dart';
import 'new_banking_screen.dart';

class BankingListScreen extends StatefulWidget {
  const BankingListScreen({super.key});

  @override
  State<BankingListScreen> createState() => _BankingListScreenState();
}

class _BankingListScreenState extends State<BankingListScreen> {
  final ApiService _apiService = ApiService();

  List<BankingListItem> _bankings = [];
  bool _isLoading = false;
  String? _errorMessage;
  // Default to today - will be updated based on permission
  DateTime _startDate = DateTime.now();
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
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.initialize(moduleId: 'sales'); // Use sales permissions

    // Default date is always today - permission only controls if user can change it
    setState(() {
      _startDate = DateTime.now();
      _endDate = DateTime.now();
    });

    _loadBankings();
  }

  Future<void> _loadBankings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      final locationProvider = context.read<LocationProvider>();
      final selectedLocationId = locationProvider.selectedLocation?.locationId;

      final response = await _apiService.getBankingList(
        startDate: startDateStr,
        endDate: endDateStr,
        locationId: selectedLocationId,
        limit: 100,
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _bankings = response.data!;
          // Sort by date (newest first)
          _bankings.sort((a, b) => b.date.compareTo(a.date));
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Failed to load banking transactions';
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

  Future<void> _onRefresh() async {
    await _loadBankings();
  }

  Future<void> _selectDateRange() async {
    // Check for date range filter permission
    final permissionProvider = context.read<PermissionProvider>();
    final hasDateRangePermission = permissionProvider.hasPermission(PermissionIds.bankingDateRangeFilter);

    if (!hasDateRangePermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to change the date range'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != DateTimeRange(start: _startDate, end: _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadBankings();
    }
  }

  void _navigateToNewBanking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewBankingScreen(),
      ),
    ).then((_) => _loadBankings());
  }

  void _navigateToEditBanking(BankingListItem banking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewBankingScreen(banking: banking),
      ),
    ).then((_) => _loadBankings());
  }

  Future<void> _deleteBanking(BankingListItem banking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = context.watch<ThemeProvider>().isDarkMode;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          title: Text(
            'Delete Banking',
            style: TextStyle(color: isDark ? Colors.white : AppColors.text),
          ),
          content: Text(
            'Are you sure you want to delete this banking transaction?\n\n'
            'Bank: ${banking.bankName}\n'
            'Amount: ${_formatCurrency(banking.amount)}',
            style: TextStyle(color: isDark ? AppColors.darkText : AppColors.text),
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
        );
      },
    );

    if (confirmed != true) return;

    try {
      final response = await _apiService.deleteBanking(banking.id);

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Banking transaction deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadBankings();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to delete banking'),
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

  Color _getBankColor(String bankName) {
    switch (bankName) {
      case 'CRDB':
        return AppColors.primary;
      case 'NMB':
        return AppColors.secondary;
      case 'NBC':
        return AppColors.primaryDark;
      default:
        return AppColors.textLight;
    }
  }

  // File handling methods
  Future<void> _showFileOptions(String fileUrl) async {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Attachment Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility, color: AppColors.primary),
                title: Text(
                  'View File',
                  style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _viewFile(fileUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: AppColors.success),
                title: Text(
                  'Download File',
                  style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile(fileUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: AppColors.warning),
                title: Text(
                  'Share File',
                  style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _shareFile(fileUrl);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _viewFile(String fileUrl) async {
    try {
      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final isPdf = fileUrl.toLowerCase().endsWith('.pdf');

      if (isPdf) {
        // Download PDF to temp directory and open in PDF viewer
        final file = await _downloadFileToTemp(fileUrl);
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog

        if (file != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerScreen(
                filePath: file.path,
                title: 'Banking Slip',
              ),
            ),
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to load PDF file'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } else {
        // For images, show in dialog
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog

        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: InteractiveViewer(
                    child: Image.network(
                      fileUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 48, color: AppColors.error),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error viewing file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(String fileUrl) async {
    try {
      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Download file
      final response = await http.get(Uri.parse(fileUrl));

      if (response.statusCode == 200) {
        // Get download directory
        final directory = Platform.isAndroid
            ? Directory('/storage/emulated/0/Download')
            : await getApplicationDocumentsDirectory();

        // Extract filename from URL
        final fileName = fileUrl.split('/').last;
        final filePath = '${directory.path}/$fileName';

        // Save file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File downloaded to: ${directory.path}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download file'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _shareFile(String fileUrl) async {
    try {
      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Download file to temp directory first
      final file = await _downloadFileToTemp(fileUrl);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (file != null) {
        // Share the file
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Banking Slip',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to prepare file for sharing'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<File?> _downloadFileToTemp(String fileUrl) async {
    try {
      final response = await http.get(Uri.parse(fileUrl));

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = fileUrl.split('/').last;
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Error downloading file to temp: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final locationProvider = context.watch<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;
    final locations = locationProvider.allowedLocations;
    final permissionProvider = context.watch<PermissionProvider>();
    final hasEditPermission = permissionProvider.hasPermission(PermissionIds.bankingEditDeposit);
    final hasDeletePermission = permissionProvider.hasPermission(PermissionIds.bankingDeleteDeposit);
    final hasDateRangePermission = permissionProvider.hasPermission(PermissionIds.bankingDateRangeFilter);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Banking'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Location selector
          if (locations.isNotEmpty)
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
                _loadBankings();
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
          // Only show calendar icon if user has date range permission
          if (hasDateRangePermission)
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _selectDateRange,
              tooltip: 'Select Date Range',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark
                ? AppColors.darkSurface
                : AppColors.primary.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.date_range,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkText : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Only show Change button if user has date range permission
                if (hasDateRangePermission)
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
          ? _buildSkeletonList(isDark)
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
                        onPressed: _loadBankings,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _bankings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance,
                              size: 64, color: isDark ? AppColors.darkTextLight : Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No banking transactions found',
                            style: TextStyle(
                              fontSize: 18,
                              color: isDark ? AppColors.darkText : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start by creating your first banking transaction',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextLight : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        itemCount: _bankings.length,
                        itemBuilder: (context, index) {
                          final banking = _bankings[index];
                          final bankColor = _getBankColor(banking.bankName);

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: GlassmorphicCard(
                              isDark: isDark,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Bank name and amount
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Bank icon with gradient
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            gradient: LinearGradient(
                                              colors: [
                                                bankColor.withOpacity(0.8),
                                                bankColor,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: bankColor.withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.account_balance,
                                            size: 24,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                banking.bankName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  color: isDark ? AppColors.darkText : AppColors.text,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              // Amount in badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: AppColors.primary.withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  _formatCurrency(banking.amount),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
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
                                                  onPressed: () => _navigateToEditBanking(banking),
                                                  padding: const EdgeInsets.all(8),
                                                  constraints: const BoxConstraints(),
                                                  tooltip: 'Edit banking',
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
                                                  onPressed: () => _deleteBanking(banking),
                                                  padding: const EdgeInsets.all(8),
                                                  constraints: const BoxConstraints(),
                                                  tooltip: 'Delete banking',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 12),
                                  // File attachment indicator
                                  if (banking.picFile != null && banking.picFile!.isNotEmpty) ...[
                                    GestureDetector(
                                      onTap: () => _showFileOptions(banking.picFile!),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary.withOpacity(0.1),
                                              AppColors.primary.withOpacity(0.05),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.primary.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              banking.picFile!.toLowerCase().endsWith('.pdf')
                                                  ? Icons.picture_as_pdf
                                                  : Icons.image,
                                              size: 18,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Banking Slip Attached',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.visibility,
                                              size: 18,
                                              color: AppColors.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  // Details section in containers
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors.darkBackground.withOpacity(0.5)
                                                : Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.person,
                                                    size: 14,
                                                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Depositor',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                banking.depositor,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? AppColors.darkText : AppColors.text,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors.darkBackground.withOpacity(0.5)
                                                : Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
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
                                                    'Date',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatDate(banking.date),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? AppColors.darkText : AppColors.text,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Supervisor
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkBackground.withOpacity(0.5)
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.supervisor_account,
                                              size: 14,
                                              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Supervisor',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          banking.supervisorName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.darkText : AppColors.text,
                                          ),
                                        ),
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
      floatingActionButton: PermissionFAB(
        permissionId: PermissionIds.bankingAddDeposit,
        onPressed: _navigateToNewBanking,
        tooltip: 'Add Banking',
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      itemBuilder: (context, index) => _buildSkeletonCard(isDark),
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    return GlassmorphicCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SkeletonLoader(width: 44, height: 44, borderRadius: 12, isDark: isDark),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 100, height: 16, isDark: isDark),
                      const SizedBox(height: 4),
                      SkeletonLoader(width: 80, height: 12, isDark: isDark),
                    ],
                  ),
                ],
              ),
              SkeletonLoader(width: 80, height: 24, borderRadius: 12, isDark: isDark),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonLoader(width: 100, height: 14, isDark: isDark),
              SkeletonLoader(width: 100, height: 18, isDark: isDark),
            ],
          ),
          const SizedBox(height: 8),
          SkeletonLoader(width: 150, height: 12, isDark: isDark),
        ],
      ),
    );
  }
}

// Helper to get bank colors (moved from old class)
Color _getBankColor(String bankName) {
  final lowerName = bankName.toLowerCase();
  if (lowerName.contains('crdb')) return const Color(0xFF1976D2);
  if (lowerName.contains('nmb')) return const Color(0xFF388E3C);
  if (lowerName.contains('nbc')) return const Color(0xFFD32F2F);
  return AppColors.primary;
}

String _formatCurrency(double amount) {
  return NumberFormat('#,##0.00', 'en_US').format(amount);
}

String _formatDate(String dateStr) {
  try {
    final date = DateTime.parse(dateStr);
    return DateFormat('MMM dd, yyyy').format(date);
  } catch (e) {
    return dateStr;
  }
}
