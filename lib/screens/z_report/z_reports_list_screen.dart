import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../models/zreport.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/permission_wrapper.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../pdf_viewer_screen.dart';
import 'new_z_report_screen.dart';

class ZReportsListScreen extends StatefulWidget {
  const ZReportsListScreen({super.key});

  @override
  State<ZReportsListScreen> createState() => _ZReportsListScreenState();
}

class _ZReportsListScreenState extends State<ZReportsListScreen> {
  final ApiService _apiService = ApiService();

  List<ZReportListItem> _zReports = [];
  bool _isLoading = false;
  String? _errorMessage;
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
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.initialize(moduleId: 'sales'); // Use sales permissions
    _loadZReports();
  }

  Future<void> _loadZReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      final locationProvider = context.read<LocationProvider>();
      final selectedLocationId = locationProvider.selectedLocation?.locationId;

      final response = await _apiService.getZReports(
        startDate: startDateStr,
        endDate: endDateStr,
        locationId: selectedLocationId,
        limit: 100,
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _zReports = response.data!;
          // Sort by date (newest first)
          _zReports.sort((a, b) => b.date.compareTo(a.date));
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Failed to load Z reports';
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
    await _loadZReports();
  }

  Future<void> _selectDateRange() async {
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

    if (picked != null &&
        picked != DateTimeRange(start: _startDate, end: _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadZReports();
    }
  }

  void _navigateToNewZReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewZReportScreen(),
      ),
    ).then((_) => _loadZReports());
  }

  void _navigateToEditZReport(ZReportListItem zReport) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewZReportScreen(zReport: zReport),
      ),
    ).then((_) => _loadZReports());
  }

  Future<void> _deleteZReport(ZReportListItem zReport) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = context.watch<ThemeProvider>().isDarkMode;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          title: Text(
            'Delete Z Report',
            style: TextStyle(color: isDark ? Colors.white : AppColors.text),
          ),
          content: Text(
            'Are you sure you want to delete this Z Report?\n\n'
            'Date: ${_formatDate(zReport.date)}\n'
            'Turnover: ${NumberFormat('#,##0.00').format(zReport.turnover)}\n'
            'Net: ${NumberFormat('#,##0.00').format(zReport.net)}',
            style:
                TextStyle(color: isDark ? AppColors.darkText : AppColors.text),
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
      final response = await _apiService.deleteZReport(zReport.id);

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Z Report deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadZReports();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to delete Z Report'),
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

  Widget _buildDetailCell({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
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
                icon,
                size: 14,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
        ],
      ),
    );
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
                  style:
                      TextStyle(color: isDark ? Colors.white : AppColors.text),
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
                  style:
                      TextStyle(color: isDark ? Colors.white : AppColors.text),
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
                  style:
                      TextStyle(color: isDark ? Colors.white : AppColors.text),
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
                title: 'Z Report',
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
                              Icon(Icons.error,
                                  size: 48, color: AppColors.error),
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
          text: 'Z Report',
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
    final hasEditPermission =
        permissionProvider.hasPermission(PermissionIds.cashSubmitEditZReport);
    final hasDeletePermission = permissionProvider
        .hasPermission(PermissionIds.cashSubmitDeleteZReport);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Z Reports'),
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
                _loadZReports();
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
                      Icon(
                        Icons.date_range,
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
                                    color:
                                        isDark ? AppColors.darkText : AppColors.text,
                                  )),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadZReports,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _zReports.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.description,
                                      size: 64,
                                      color: isDark
                                          ? AppColors.darkTextLight
                                          : Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Z Reports found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: isDark
                                          ? AppColors.darkText
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start by creating your first Z Report',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? AppColors.darkTextLight
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _onRefresh,
                              child: ListView.builder(
                                itemCount: _zReports.length,
                                itemBuilder: (context, index) {
                                  final zReport = _zReports[index];

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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Header: Icon and actions
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Icon
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        AppColors.primary
                                                            .withOpacity(0.8),
                                                        AppColors.primary,
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppColors.primary
                                                            .withOpacity(0.3),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.description,
                                                    size: 24,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Z Report',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 17,
                                                          color: isDark
                                                              ? AppColors.darkText
                                                              : AppColors.text,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        _formatDate(zReport.date),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: isDark
                                                              ? AppColors
                                                                  .darkTextLight
                                                              : AppColors
                                                                  .textLight,
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
                                                          color: AppColors.primary
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  8),
                                                        ),
                                                        child: IconButton(
                                                          icon: const Icon(
                                                              Icons.edit,
                                                              color: AppColors
                                                                  .primary,
                                                              size: 20),
                                                          onPressed: () =>
                                                              _navigateToEditZReport(
                                                                  zReport),
                                                          padding:
                                                              const EdgeInsets.all(
                                                                  8),
                                                          constraints:
                                                              const BoxConstraints(),
                                                          tooltip: 'Edit Z Report',
                                                        ),
                                                      ),
                                                    if (hasEditPermission &&
                                                        hasDeletePermission)
                                                      const SizedBox(height: 8),
                                                    if (hasDeletePermission)
                                                      Container(
                                                        decoration: BoxDecoration(
                                                          color: AppColors.error
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  8),
                                                        ),
                                                        child: IconButton(
                                                          icon: const Icon(
                                                              Icons.delete,
                                                              color: AppColors.error,
                                                              size: 20),
                                                          onPressed: () =>
                                                              _deleteZReport(
                                                                  zReport),
                                                          padding:
                                                              const EdgeInsets.all(
                                                                  8),
                                                          constraints:
                                                              const BoxConstraints(),
                                                          tooltip:
                                                              'Delete Z Report',
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            // File attachment indicator
                                            if (zReport.picFile != null &&
                                                zReport.picFile!.isNotEmpty) ...[
                                              GestureDetector(
                                                onTap: () => _showFileOptions(
                                                    zReport.picFile!),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        AppColors.primary
                                                            .withOpacity(0.1),
                                                        AppColors.primary
                                                            .withOpacity(0.05),
                                                      ],
                                                      begin: Alignment.centerLeft,
                                                      end: Alignment.centerRight,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: AppColors.primary
                                                          .withOpacity(0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        zReport.picFile!
                                                                .toLowerCase()
                                                                .endsWith('.pdf')
                                                            ? Icons.picture_as_pdf
                                                            : Icons.image,
                                                        size: 18,
                                                        color: AppColors.primary,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'Z Report File Attached',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                AppColors.primary,
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
                                            // Details section - Row 1: Turnover and Net
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildDetailCell(
                                                    isDark: isDark,
                                                    icon: Icons.trending_up,
                                                    label: 'Turnover',
                                                    value: NumberFormat('#,##0.00').format(zReport.turnover),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: _buildDetailCell(
                                                    isDark: isDark,
                                                    icon: Icons.calculate,
                                                    label: 'Net (A+B+C)',
                                                    value: NumberFormat('#,##0.00').format(zReport.net),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            // Row 2: Tax and Turnover (Ex+SR)
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildDetailCell(
                                                    isDark: isDark,
                                                    icon: Icons.receipt_long,
                                                    label: 'Tax',
                                                    value: NumberFormat('#,##0.00').format(zReport.tax),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: _buildDetailCell(
                                                    isDark: isDark,
                                                    icon: Icons.trending_flat,
                                                    label: 'Turnover (Ex+SR)',
                                                    value: NumberFormat('#,##0.00').format(zReport.turnoverExSr),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            // Row 3: Total and Total Charges
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildDetailCell(
                                                    isDark: isDark,
                                                    icon: Icons.summarize,
                                                    label: 'Total',
                                                    value: NumberFormat('#,##0.00').format(zReport.total),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: _buildDetailCell(
                                                    isDark: isDark,
                                                    icon: Icons.money_off,
                                                    label: 'Total Charges',
                                                    value: NumberFormat('#,##0.00').format(zReport.totalCharges),
                                                  ),
                                                ),
                                              ],
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
        permissionId: PermissionIds.cashSubmitAddZReport,
        onPressed: _navigateToNewZReport,
        tooltip: 'Add Z Report',
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: 6,
      itemBuilder: (context, index) => _buildSkeletonCard(isDark),
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: GlassmorphicCard(
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon skeleton
                  SkeletonLoader(width: 48, height: 48, borderRadius: 12, isDark: isDark),
                  const SizedBox(width: 12),
                  // Title skeleton
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(width: 80, height: 17, isDark: isDark),
                        const SizedBox(height: 8),
                        SkeletonLoader(width: 120, height: 14, isDark: isDark),
                      ],
                    ),
                  ),
                  // Action buttons skeleton
                  SkeletonLoader(width: 36, height: 36, borderRadius: 8, isDark: isDark),
                ],
              ),
              const SizedBox(height: 16),
              // Detail rows skeleton
              Row(
                children: [
                  Expanded(
                    child: _buildDetailCellSkeleton(isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailCellSkeleton(isDark),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailCellSkeleton(isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailCellSkeleton(isDark),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailCellSkeleton(isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailCellSkeleton(isDark),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCellSkeleton(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SkeletonLoader(width: 18, height: 18, borderRadius: 4, isDark: isDark),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 50, height: 10, isDark: isDark),
                const SizedBox(height: 4),
                SkeletonLoader(width: 70, height: 14, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
