import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/constants.dart';

import 'package:intl/intl.dart';
import '../../models/banking.dart';
import '../../models/permission_model.dart';
import '../../models/supervisor.dart';
import '../../providers/location_provider.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_bottom_navigation.dart';

class NewBankingScreen extends StatefulWidget {
  final BankingListItem? banking;

  const NewBankingScreen({super.key, this.banking});

  @override
  State<NewBankingScreen> createState() => _NewBankingScreenState();
}

class _NewBankingScreenState extends State<NewBankingScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _depositorController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  String _selectedBank = 'CRDB';
  String? _selectedSupervisorId;
  List<Supervisor> _supervisors = [];
  bool _isLoading = false;
  bool _isProcessing = false;

  DateTime _selectedDate = DateTime.now();

  // File attachment state
  File? _selectedFile;
  String? _selectedFileName;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Initialize with existing data if editing
    if (widget.banking != null) {
      _amountController.text = widget.banking!.amount.toString();
      _depositorController.text = widget.banking!.depositor;
      _selectedBank = widget.banking!.bankName;
      _selectedDate = DateTime.parse(widget.banking!.date);
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    }

    // Load supervisors after frame is built (to access LocationProvider)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSupervisors();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _depositorController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  /// Helper method to check if supervisor filtering by location is enabled (Leruma-specific)
  bool _hasSupervisorByLocationFeature() {
    try {
      return ApiService.currentClient?.features.hasSupervisorByLocation ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadSupervisors() async {
    setState(() => _isLoading = true);

    try {
      // Get location from provider - only filter by location for Leruma
      int? locationId;
      if (_hasSupervisorByLocationFeature()) {
        final locationProvider = context.read<LocationProvider>();
        locationId = locationProvider.selectedLocation?.locationId;
      }

      final response = await _apiService.getSupervisors(locationId: locationId);

      if (response.isSuccess && response.data != null) {
        setState(() {
          _supervisors = response.data!;
          if (widget.banking != null) {
            _selectedSupervisorId = widget.banking!.supervisorId.toString();
          } else if (_supervisors.isNotEmpty) {
            // Auto-select the first (and likely only) supervisor for the location
            _selectedSupervisorId = _supervisors.first.id;
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? 'Failed to load supervisors')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final permissionProvider = context.read<PermissionProvider>();
    final hasDatePermission = permissionProvider.hasPermission(PermissionIds.bankingDate);

    if (!hasDatePermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to change the date'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      });
    }
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.success),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file, color: AppColors.warning),
                title: const Text('Choose File (PDF)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();

        // Check file size (max 10MB)
        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File size must be less than 10MB'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFile = file;
          _selectedFileName = pickedFile.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result;
      bool useImageFallback = false;

      // Try with custom file types first
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
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
                content: Text('No file manager found. Please use "Choose from Gallery" for images, or install a file manager app for PDFs.'),
                backgroundColor: AppColors.warning,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name.toLowerCase();

        // Validate file extension manually
        final allowedExtensions = useImageFallback
            ? ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']
            : ['pdf', 'jpg', 'jpeg', 'png'];
        final extension = fileName.split('.').last;
        if (!allowedExtensions.contains(extension)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(useImageFallback
                    ? 'Please select an image file'
                    : 'Please select a PDF or image file (jpg, jpeg, png)'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        final fileSize = await file.length();

        // Check file size (max 10MB)
        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File size must be less than 10MB'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFile = file;
          _selectedFileName = result!.files.single.name;
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

  void _removeFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
    });
  }

  Future<String?> _encodeFileToBase64() async {
    if (_selectedFile == null) return null;

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final base64String = base64Encode(bytes);

      // Determine MIME type based on file extension
      String mimeType = 'image/jpeg';
      final extension = _selectedFileName?.split('.').last.toLowerCase();

      if (extension == 'pdf') {
        mimeType = 'application/pdf';
      } else if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        mimeType = 'image/jpeg';
      }

      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      debugPrint('Error encoding file: $e');
      return null;
    }
  }

  Future<void> _submitBanking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSupervisorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a supervisor'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Banking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bank: $_selectedBank'),
            const SizedBox(height: 8),
            Text('Amount: ${_formatCurrency(double.parse(_amountController.text))}'),
            Text('Depositor: ${_depositorController.text}'),
            Text('Date: ${_dateController.text}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final locationProvider = context.read<LocationProvider>();
      final selectedLocationId = locationProvider.selectedLocation?.locationId;

      // Encode file to base64 if selected
      final encodedFile = await _encodeFileToBase64();

      final banking = BankingCreate(
        amount: double.parse(_amountController.text),
        date: _dateController.text,
        bankName: _selectedBank,
        depositor: _depositorController.text,
        supervisorId: int.parse(_selectedSupervisorId!),
        stockLocationId: selectedLocationId,
        picFile: encodedFile,
      );

      final response = widget.banking == null
          ? await _apiService.createBanking(banking)
          : await _apiService.updateBanking(widget.banking!.id, banking);

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.banking == null
                  ? 'Banking transaction created successfully!'
                  : 'Banking transaction updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to create banking'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
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
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return '${formatter.format(amount)} TSh';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final locationProvider = context.watch<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(widget.banking == null ? 'New Banking' : 'Edit Banking'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
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
                    // Bank Selection
                    DropdownButtonFormField<String>(
                      value: _selectedBank,
                      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                      decoration: InputDecoration(
                        labelText: 'Bank',
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                        prefixIcon: Icon(Icons.account_balance, color: isDark ? Colors.white70 : null),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                      ),
                      items: TanzaniaBanks.banks.map((bank) {
                        return DropdownMenuItem(
                          value: bank,
                          child: Text(bank),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedBank = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                      decoration: InputDecoration(
                        labelText: 'Amount (TSh)',
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                        prefixIcon: Icon(Icons.money, color: isDark ? Colors.white70 : null),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Depositor
                    TextFormField(
                      controller: _depositorController,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                      decoration: InputDecoration(
                        labelText: 'Depositor Name',
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                        prefixIcon: Icon(Icons.person, color: isDark ? Colors.white70 : null),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter depositor name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date with permission
                    Consumer<PermissionProvider>(
                      builder: (context, permissionProvider, child) {
                        final hasDatePermission = permissionProvider.hasPermission(PermissionIds.bankingDate);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _dateController,
                              readOnly: true,
                              style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                              decoration: InputDecoration(
                                labelText: 'Date',
                                labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                                prefixIcon: Icon(
                                  hasDatePermission ? Icons.calendar_today : Icons.lock,
                                  color: hasDatePermission
                                      ? (isDark ? Colors.white70 : null)
                                      : (isDark ? Colors.orange[300] : AppColors.warning),
                                ),
                                suffixIcon: !hasDatePermission
                                    ? Icon(
                                        Icons.lock,
                                        size: 16,
                                        color: isDark ? Colors.orange[300] : AppColors.warning,
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: hasDatePermission
                                        ? (isDark ? Colors.white24 : Colors.grey.shade300)
                                        : (isDark ? Colors.orange[300]! : AppColors.warning),
                                  ),
                                ),
                                filled: true,
                                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                              ),
                              onTap: _selectDate,
                            ),
                            if (!hasDatePermission) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Text(
                                  'You do not have permission to change the date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.orange[300] : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Supervisor Selection
                    DropdownButtonFormField<String>(
                      value: _selectedSupervisorId,
                      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.text),
                      decoration: InputDecoration(
                        labelText: 'Supervisor',
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                        prefixIcon: Icon(Icons.supervisor_account, color: isDark ? Colors.white70 : null),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                      ),
                      items: _supervisors.map((supervisor) {
                        return DropdownMenuItem(
                          value: supervisor.id,
                          child: Text(supervisor.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedSupervisorId = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a supervisor';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // File Attachment Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.darkCard : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.attach_file,
                                color: isDark ? Colors.white70 : AppColors.textLight,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Attach Banking Slip (Optional)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : AppColors.text,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_selectedFile != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedFileName?.endsWith('.pdf') == true
                                        ? Icons.picture_as_pdf
                                        : Icons.image,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedFileName ?? 'File',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.white : AppColors.text,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'File attached',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : AppColors.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: AppColors.error),
                                    onPressed: _removeFile,
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            OutlinedButton.icon(
                              onPressed: _showAttachmentOptions,
                              icon: const Icon(Icons.add_a_photo),
                              label: const Text('Attach Banking Slip'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                side: BorderSide(
                                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                                ),
                                foregroundColor: isDark ? Colors.white : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Supported formats: PDF, JPG, JPEG, PNG (Max 10MB)',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : AppColors.textLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _submitBanking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              widget.banking == null ? 'Submit Banking' : 'Update Banking',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }
}
