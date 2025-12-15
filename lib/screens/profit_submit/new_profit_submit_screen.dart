import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../utils/constants.dart';
import '../../models/profit_submit.dart';
import '../../models/supervisor.dart';
import '../../services/api_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';

class NewProfitSubmitScreen extends StatefulWidget {
  final ProfitSubmitListItem? profit; // For edit mode
  final int? stockLocationId; // Stock location for new submissions
  final String? stockLocationName; // Stock location name for display

  const NewProfitSubmitScreen({
    super.key,
    this.profit,
    this.stockLocationId,
    this.stockLocationName,
  });

  @override
  State<NewProfitSubmitScreen> createState() => _NewProfitSubmitScreenState();
}

class _NewProfitSubmitScreenState extends State<NewProfitSubmitScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

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
    _initializeForm();
    _loadSupervisors();
  }

  /// Initialize form with existing data for edit mode
  void _initializeForm() {
    if (widget.profit != null) {
      // Edit mode - populate with existing data
      _amountController.text = widget.profit!.amount.toString();
      _selectedDate = DateTime.parse(widget.profit!.date);
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _selectedSupervisorId = widget.profit!.supervisorId.toString();
    } else {
      // Create mode - use defaults
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadSupervisors() async {
    setState(() => _isLoading = true);

    try {
      final response = await _apiService.getSupervisors();

      if (response.isSuccess && response.data != null) {
        setState(() {
          _supervisors = response.data!;
          if (_supervisors.isNotEmpty) {
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
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: AppColors.primary),
                title: const Text('Choose PDF/Image File'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
              if (_selectedFile != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.error),
                  title: const Text('Remove Attachment'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeAttachment();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _selectedFileName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing camera: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _selectedFileName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing gallery: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        // Check file size (max 10MB)
        final fileSize = await file.length();
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
          _selectedFileName = fileName;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeAttachment() {
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
      final extension = _selectedFileName?.split('.').last.toLowerCase() ?? 'jpg';

      // Return format: data:image/jpeg;base64,... or data:application/pdf;base64,...
      final mimeType = extension == 'pdf' ? 'application/pdf' : 'image/$extension';
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error encoding file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _submitProfit() async {
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
        title: const Text('Confirm Profit Submission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${_formatCurrency(double.parse(_amountController.text))}'),
            const SizedBox(height: 8),
            Text('Date: ${_dateController.text}'),
            const SizedBox(height: 16),
            const Text(
              'This profit amount will be submitted to the supervisor.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
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
      // Encode file to base64 if selected
      final encodedFile = await _encodeFileToBase64();

      final profitSubmit = ProfitSubmitCreate(
        amount: double.parse(_amountController.text),
        date: _dateController.text,
        supervisorId: int.parse(_selectedSupervisorId!),
        stockLocationId: widget.profit?.stockLocationId ?? widget.stockLocationId ?? 1,
        picFile: encodedFile,
      );

      final response = widget.profit != null
          ? await _apiService.updateProfitSubmission(widget.profit!.id, profitSubmit)
          : await _apiService.createProfitSubmission(profitSubmit);

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.profit != null
                    ? 'Profit submission updated successfully!'
                    : 'Profit submission created successfully!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.message ??
                    (widget.profit != null
                        ? 'Failed to update profit submission'
                        : 'Failed to create profit submission'),
              ),
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
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Profit Submission'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
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
            ? _buildSkeletonForm(isDark)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header card with icon
                      GlassmorphicCard(
                        isDark: isDark,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Gradient icon
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
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
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.trending_up,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Create Profit Submission',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkText : AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Submit your profit to supervisor',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Form card
                      GlassmorphicCard(
                        isDark: isDark,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Amount
                              TextFormField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  color: isDark ? AppColors.darkText : AppColors.text,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Profit Amount (TSh)',
                                  labelStyle: TextStyle(
                                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.attach_money,
                                    color: AppColors.success,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.darkCard.withOpacity(0.5)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.darkCard.withOpacity(0.5)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.success,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? AppColors.darkCard.withOpacity(0.3)
                                      : Colors.grey.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter profit amount';
                                  }
                                  final amount = double.tryParse(value);
                                  if (amount == null || amount <= 0) {
                                    return 'Please enter a valid amount';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Date
                              TextFormField(
                                controller: _dateController,
                                readOnly: true,
                                style: TextStyle(
                                  color: isDark ? AppColors.darkText : AppColors.text,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Date',
                                  labelStyle: TextStyle(
                                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.calendar_today,
                                    color: AppColors.primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.darkCard.withOpacity(0.5)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.darkCard.withOpacity(0.5)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? AppColors.darkCard.withOpacity(0.3)
                                      : Colors.grey.shade50,
                                ),
                                onTap: _selectDate,
                              ),
                              const SizedBox(height: 16),

                              // Supervisor Selection
                              DropdownButtonFormField<String>(
                                value: _selectedSupervisorId,
                                style: TextStyle(
                                  color: isDark ? AppColors.darkText : AppColors.text,
                                ),
                                dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                                decoration: InputDecoration(
                                  labelText: 'Supervisor',
                                  labelStyle: TextStyle(
                                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.supervisor_account,
                                    color: AppColors.primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.darkCard.withOpacity(0.5)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.darkCard.withOpacity(0.5)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? AppColors.darkCard.withOpacity(0.3)
                                      : Colors.grey.shade50,
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Attachment section
                      GlassmorphicCard(
                        isDark: isDark,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_file,
                                    size: 20,
                                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Profit Slip Attachment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkText : AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(Optional)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Attach PDF, JPG, or JPEG document (Max 10MB)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // File preview or attach button
                              if (_selectedFile != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.success.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _selectedFileName?.endsWith('.pdf') == true
                                            ? Icons.picture_as_pdf
                                            : Icons.image,
                                        color: AppColors.success,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedFileName ?? 'Unknown file',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? AppColors.darkText : AppColors.text,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            FutureBuilder<int>(
                                              future: _selectedFile!.length(),
                                              builder: (context, snapshot) {
                                                if (snapshot.hasData) {
                                                  final sizeInKB = (snapshot.data! / 1024).toStringAsFixed(2);
                                                  return Text(
                                                    '$sizeInKB KB',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                                    ),
                                                  );
                                                }
                                                return const SizedBox();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: AppColors.error),
                                        onPressed: _removeAttachment,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                OutlinedButton.icon(
                                  onPressed: _showAttachmentOptions,
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('Attach Document'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: BorderSide(
                                      color: isDark
                                          ? AppColors.darkCard.withOpacity(0.5)
                                          : Colors.grey.shade300,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: _isProcessing
                                ? [Colors.grey.shade400, Colors.grey.shade400]
                                : [
                                    AppColors.success.withOpacity(0.9),
                                    AppColors.success,
                                  ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: _isProcessing
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _submitProfit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text(
                                      'Submit Profit',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildSkeletonForm(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header skeleton
          GlassmorphicCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SkeletonLoader(width: 60, height: 60, borderRadius: 30, isDark: isDark),
                  const SizedBox(height: 12),
                  SkeletonLoader(width: 150, height: 20, isDark: isDark),
                  const SizedBox(height: 8),
                  SkeletonLoader(width: 200, height: 14, isDark: isDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Form fields skeleton
          GlassmorphicCard(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(5, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 80, height: 12, isDark: isDark),
                      const SizedBox(height: 8),
                      SkeletonLoader(width: double.infinity, height: 48, borderRadius: 8, isDark: isDark),
                    ],
                  ),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
