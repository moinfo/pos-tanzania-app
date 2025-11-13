import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/zreport.dart';
import '../../providers/theme_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/glassmorphic_card.dart';

class NewZReportScreen extends StatefulWidget {
  final ZReportListItem? zReport;

  const NewZReportScreen({super.key, this.zReport});

  @override
  State<NewZReportScreen> createState() => _NewZReportScreenState();
}

class _NewZReportScreenState extends State<NewZReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Form controllers
  final TextEditingController _aController = TextEditingController();
  final TextEditingController _cController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  // File attachment state
  File? _selectedFile;
  String? _selectedFileName;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.zReport != null;
    if (_isEditMode) {
      _loadZReportData();
    } else {
      // Set default date to today
      _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  void _loadZReportData() {
    final zReport = widget.zReport!;
    _aController.text = zReport.a;
    _cController.text = zReport.c;
    _dateController.text = zReport.date;
  }

  @override
  void dispose() {
    _aController.dispose();
    _cController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final fileSize = await file.length();

        // Check file size (10MB limit)
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
          _selectedFileName = image.path.split('/').last;
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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        // Check file size (10MB limit)
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
          _selectedFileName = result.files.single.name;
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

  Future<void> _submitZReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // File is required for new Z Reports
    if (!_isEditMode && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach a Z Report file'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Encode file to base64 if selected
      final encodedFile = await _encodeFileToBase64();

      // Get selected location from provider
      final locationProvider = context.read<LocationProvider>();
      final selectedLocationId = locationProvider.selectedLocation?.locationId;

      final response = _isEditMode
          ? await _apiService.updateZReport(
              id: widget.zReport!.id,
              a: _aController.text,
              c: _cController.text,
              date: _dateController.text,
              stockLocationId: selectedLocationId,
              picFile: encodedFile,
            )
          : await _apiService.createZReport(
              a: _aController.text,
              c: _cController.text,
              date: _dateController.text,
              stockLocationId: selectedLocationId,
              picFile: encodedFile!,
            );

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditMode
                  ? 'Z Report updated successfully'
                  : 'Z Report created successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to save Z Report'),
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Z Report' : 'New Z Report'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Value A Field
                GlassmorphicCard(
                  isDark: isDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.label,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textLight,
                                size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Value A',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _aController,
                          style: TextStyle(
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter value A',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkBackground.withOpacity(0.5)
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter value A';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Value C Field
                GlassmorphicCard(
                  isDark: isDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.label_outline,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textLight,
                                size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Value C',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _cController,
                          style: TextStyle(
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter value C',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkBackground.withOpacity(0.5)
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter value C';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Date Field
                GlassmorphicCard(
                  isDark: isDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textLight,
                                size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          onTap: _selectDate,
                          style: TextStyle(
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Select date',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkBackground.withOpacity(0.5)
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: Icon(
                              Icons.calendar_month,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select date';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stock Location Selector
                Consumer<LocationProvider>(
                  builder: (context, locationProvider, child) {
                    final locations = locationProvider.allowedLocations;
                    final selectedLocation = locationProvider.selectedLocation;

                    return GlassmorphicCard(
                      isDark: isDark,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.textLight,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Stock Location',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: selectedLocation?.locationId,
                              style: TextStyle(
                                color: isDark ? AppColors.darkText : AppColors.text,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Select location',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? AppColors.darkTextLight
                                      : AppColors.textLight,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.darkBackground.withOpacity(0.5)
                                    : Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: Icon(
                                  Icons.arrow_drop_down,
                                  color: AppColors.primary,
                                ),
                              ),
                              dropdownColor: isDark
                                  ? AppColors.darkCard
                                  : Colors.white,
                              items: locations.map((location) {
                                return DropdownMenuItem<int>(
                                  value: location.locationId,
                                  child: Text(
                                    location.locationName,
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkText
                                          : AppColors.text,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  final location = locations.firstWhere(
                                    (loc) => loc.locationId == value,
                                  );
                                  locationProvider.selectLocation(location);
                                }
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a location';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

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
                          Icon(Icons.attach_file,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textLight,
                              size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Attach Z Report File',
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
                        // File preview with remove button
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
                          label: const Text('Attach Z Report File'),
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
                            color: isDark
                                ? AppColors.darkTextLight
                                : AppColors.textLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitZReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditMode ? 'Update Z Report' : 'Submit Z Report',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
