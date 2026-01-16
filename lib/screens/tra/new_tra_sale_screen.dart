import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/constants.dart';
import '../../models/tra.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../services/tra_service.dart';

class NewTRASaleScreen extends StatefulWidget {
  final List<EFDDevice> efds;
  final TRASale? sale; // For editing

  const NewTRASaleScreen({
    super.key,
    required this.efds,
    this.sale,
  });

  @override
  State<NewTRASaleScreen> createState() => _NewTRASaleScreenState();
}

class _NewTRASaleScreenState extends State<NewTRASaleScreen> {
  final TRAService _traService = TRAService();
  final _formKey = GlobalKey<FormState>();

  int? _selectedEfdId;
  final _lastZNumberController = TextEditingController();
  final _currentZNumberController = TextEditingController();
  final _turnoverController = TextEditingController();
  final _netAmountController = TextEditingController();
  final _taxController = TextEditingController();
  final _turnoverExSrController = TextEditingController();
  DateTime _saleDate = DateTime.now();
  String? _fileBase64;
  File? _selectedFile;
  String? _selectedFileName;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;

  bool get isEditing => widget.sale != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _populateForm();
    } else if (widget.efds.isNotEmpty) {
      _selectedEfdId = widget.efds.first.id;
      _loadLastZNumber();
    }
  }

  void _populateForm() {
    final sale = widget.sale!;
    _selectedEfdId = sale.efdId;
    _lastZNumberController.text = sale.lastZNumber?.toString() ?? '';
    _currentZNumberController.text = sale.efdNumber.toString();
    _turnoverController.text = sale.turnOver.toString();
    _netAmountController.text = sale.amount.toString();
    _taxController.text = sale.tax.toString();
    _turnoverExSrController.text = sale.vat.toString();
    _saleDate = DateTime.parse(sale.date);
  }

  Future<void> _loadLastZNumber() async {
    if (_selectedEfdId == null) return;

    final result = await _traService.getLastZNumber(_selectedEfdId!);
    if (mounted) {
      setState(() {
        _lastZNumberController.text = result.lastZNumber.toString();
        if (!isEditing) {
          _currentZNumberController.text = result.nextZNumber.toString();
        }
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

        await _setSelectedFile(file, pickedFile.name);
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
        // Try with media type (images) as fallback
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
                content: Text('No file manager found. Please use "Choose from Gallery" for images.'),
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

        // Validate file extension
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

        await _setSelectedFile(file, result.files.single.name);
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

  Future<void> _setSelectedFile(File file, String fileName) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      // Determine MIME type based on file extension
      String mimeType = 'image/jpeg';
      final extension = fileName.split('.').last.toLowerCase();

      if (extension == 'pdf') {
        mimeType = 'application/pdf';
      } else if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        mimeType = 'image/jpeg';
      }

      setState(() {
        _selectedFile = file;
        _selectedFileName = fileName;
        _fileBase64 = 'data:$mimeType;base64,$base64String';
      });
    } catch (e) {
      debugPrint('Error encoding file: $e');
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _fileBase64 = null;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
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

    if (picked != null) {
      setState(() => _saleDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEfdId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an EFD device'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final saleData = TRASaleCreate(
      efdId: _selectedEfdId!,
      lastZNumber: int.tryParse(_lastZNumberController.text),
      currentZNumber: int.parse(_currentZNumberController.text),
      turnover: double.parse(_turnoverController.text),
      netAmount: double.parse(_netAmountController.text),
      tax: double.parse(_taxController.text),
      turnoverExSr: double.tryParse(_turnoverExSrController.text),
      saleDate: DateFormat('yyyy-MM-dd').format(_saleDate),
      file: _fileBase64,
    );

    final result = isEditing
        ? await _traService.updateSale(widget.sale!.id, saleData)
        : await _traService.createSale(saleData);

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppColors.success : AppColors.error,
        ),
      );

      if (result.success) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  void dispose() {
    _lastZNumberController.dispose();
    _currentZNumberController.dispose();
    _turnoverController.dispose();
    _netAmountController.dispose();
    _taxController.dispose();
    _turnoverExSrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Sale' : 'New Sale'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // EFD Device
              _buildLabel('EFD Device', isDark),
              DropdownButtonFormField<int>(
                value: _selectedEfdId,
                decoration: _inputDecoration('Select EFD', isDark),
                dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                items: widget.efds.map((efd) => DropdownMenuItem<int>(
                      value: efd.id,
                      child: Text(efd.name),
                    )).toList(),
                onChanged: (value) {
                  setState(() => _selectedEfdId = value);
                  if (!isEditing) _loadLastZNumber();
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Date with permission
              Consumer<PermissionProvider>(
                builder: (context, permissionProvider, child) {
                  final hasDatePermission = permissionProvider.hasPermission(PermissionIds.traDateFilter);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Sale Date', isDark),
                      InkWell(
                        onTap: hasDatePermission ? _selectDate : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You do not have permission to change the date'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasDatePermission
                                  ? (isDark ? Colors.white24 : Colors.grey.shade300)
                                  : (isDark ? Colors.orange[300]! : AppColors.warning),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasDatePermission ? Icons.calendar_today : Icons.lock,
                                color: hasDatePermission
                                    ? AppColors.primary
                                    : (isDark ? Colors.orange[300] : AppColors.warning),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  DateFormat('MMM dd, yyyy').format(_saleDate),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.lightText,
                                  ),
                                ),
                              ),
                              if (!hasDatePermission)
                                Icon(
                                  Icons.lock,
                                  size: 16,
                                  color: isDark ? Colors.orange[300] : AppColors.warning,
                                ),
                            ],
                          ),
                        ),
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

              // Z-Numbers with permission
              Consumer<PermissionProvider>(
                builder: (context, permissionProvider, child) {
                  final hasZNumberPermission = permissionProvider.hasPermission(PermissionIds.traEditZNumbers);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Last Z-Number', isDark),
                                TextFormField(
                                  controller: _lastZNumberController,
                                  decoration: _inputDecorationWithLock(
                                    'Last Z-Number',
                                    isDark,
                                    !hasZNumberPermission,
                                  ),
                                  keyboardType: TextInputType.number,
                                  readOnly: !hasZNumberPermission,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.lightText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Current Z-Number *', isDark),
                                TextFormField(
                                  controller: _currentZNumberController,
                                  decoration: _inputDecorationWithLock(
                                    'Current Z-Number',
                                    isDark,
                                    !hasZNumberPermission,
                                  ),
                                  keyboardType: TextInputType.number,
                                  readOnly: !hasZNumberPermission,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.lightText,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Required';
                                    if (int.tryParse(value) == null) return 'Invalid number';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!hasZNumberPermission) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            'You do not have permission to edit Z-Numbers',
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

              // Turnover
              _buildLabel('Turnover *', isDark),
              TextFormField(
                controller: _turnoverController,
                decoration: _inputDecoration('Enter turnover amount', isDark),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Net Amount
              _buildLabel('Net Amount *', isDark),
              TextFormField(
                controller: _netAmountController,
                decoration: _inputDecoration('Enter net amount', isDark),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tax
              _buildLabel('Tax *', isDark),
              TextFormField(
                controller: _taxController,
                decoration: _inputDecoration('Enter tax amount', isDark),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Turnover Ex-SR (VAT)
              _buildLabel('Turnover Ex-SR (VAT)', isDark),
              TextFormField(
                controller: _turnoverExSrController,
                decoration: _inputDecoration('Enter VAT amount (optional)', isDark),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: isDark ? Colors.white : AppColors.lightText),
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
                        Icon(
                          Icons.attach_file,
                          color: isDark ? Colors.white70 : AppColors.textLight,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Attach Z-Report (Optional)',
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
                              _selectedFileName?.toLowerCase().endsWith('.pdf') == true
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
                        label: const Text('Attach Z-Report'),
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
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(isEditing ? 'Update Sale' : 'Create Sale'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white70 : AppColors.lightTextLight,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  InputDecoration _inputDecorationWithLock(String hint, bool isDark, bool isLocked) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
      prefixIcon: isLocked
          ? Icon(
              Icons.lock,
              color: isDark ? Colors.orange[300] : AppColors.warning,
            )
          : null,
      suffixIcon: isLocked
          ? Icon(
              Icons.lock,
              size: 16,
              color: isDark ? Colors.orange[300] : AppColors.warning,
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isLocked
              ? (isDark ? Colors.orange[300]! : AppColors.warning)
              : (isDark ? Colors.white24 : Colors.grey.shade300),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isLocked
              ? (isDark ? Colors.orange[300]! : AppColors.warning)
              : (isDark ? Colors.white24 : Colors.grey.shade300),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isLocked
              ? (isDark ? Colors.orange[300]! : AppColors.warning)
              : AppColors.primary,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
