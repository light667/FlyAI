import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/profile_model.dart';
import '../providers/profile_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Form Controllers & State
  final _nameCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _universityCtrl = TextEditingController();
  final _fieldCtrl = TextEditingController();
  final _averageCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();

  DateTime? _birthDate;
  String _educationLevel = "Bachelor's Degree";
  String _englishLevel = "Intermediate";
  String _frenchLevel = "Intermediate";
  double _convertedGpa = 0.0;

  final List<String> _targetCountries = [];
  final List<String> _targetFields = [];

  // Picked files
  XFile? _photoFile;
  Uint8List? _photoBytes;
  PlatformFile? _cvFile;
  bool _isSaving = false;

  // Static Lists
  final List<String> _africanCountries = [
    "Algeria", "Angola", "Benin", "Botswana", "Burkina Faso", "Burundi", "Cabo Verde", "Cameroon",
    "Central African Republic", "Chad", "Comoros", "Congo", "DR Congo", "Djibouti", "Egypt",
    "Equatorial Guinea", "Eritrea", "Eswatini", "Ethiopia", "Gabon", "Gambia", "Ghana", "Guinea",
    "Guinea-Bissau", "Ivory Coast", "Kenya", "Lesotho", "Liberia", "Libya", "Madagascar", "Malawi",
    "Mali", "Mauritania", "Mauritius", "Morocco", "Mozambique", "Namibia", "Niger", "Nigeria",
    "Rwanda", "Sao Tome and Principe", "Senegal", "Seychelles", "Sierra Leone", "Somalia", "South Africa",
    "South Sudan", "Sudan", "Tanzania", "Togo", "Tunisia", "Uganda", "Zambia", "Zimbabwe"
  ];

  final List<String> _fieldsOfStudyList = [
    "Computer Science", "Software Engineering", "Artificial Intelligence & Data Science",
    "Information Technology", "Cybersecurity", "Mechanical Engineering", "Civil Engineering",
    "Electrical & Electronic Engineering", "Chemical Engineering", "Aerospace Engineering",
    "Biomedical Engineering", "General Medicine", "Nursing", "Pharmacy", "Public Health",
    "Dentistry", "Business Administration", "Finance & Banking", "Accounting", "Marketing",
    "Economics", "Psychology", "Sociology", "Political Science", "International Relations",
    "Law & Jurisprudence", "English Literature", "Modern Languages", "History", "Philosophy",
    "Physics", "Chemistry", "Biology & Biotechnology", "Mathematics & Statistics",
    "Environmental Science", "Agriculture & Agronomy", "Forestry", "Education & Teaching",
    "Fine Arts", "Architecture", "Journalism & Media", "Geology & Earth Sciences"
  ];

  final List<String> _destinationCountries = [
    "Canada", "United States", "United Kingdom", "France", "Germany", "Belgium", "Switzerland",
    "Australia", "Japan", "China", "Turkey", "Morocco", "Senegal", "South Africa", "Kenya"
  ];

  final List<String> _targetFieldsList = [
    "Computer Science & IT", "Engineering", "Medicine & Health Sciences", "Business & Finance",
    "Social Sciences", "Arts & Humanities", "Natural Sciences", "Law & Legal Studies",
    "Agriculture & Forestry", "Education"
  ];

  final List<String> _educationLevels = [
    "High School",
    "Bachelor's Degree",
    "Master's Degree",
    "PhD / Doctorate",
    "Other"
  ];

  final List<String> _languageLevels = [
    "Beginner",
    "Intermediate",
    "Advanced",
    "Native / Fluent"
  ];

  @override
  void initState() {
    super.initState();
    // Default selects
    _countryCtrl.text = _africanCountries.first;
    _nationalityCtrl.text = _africanCountries.first;
    _fieldCtrl.text = _fieldsOfStudyList.first;

    // Pre-populate display name from Firebase Auth user if available
    final currentUser = AuthService.currentUser;
    if (currentUser != null && currentUser.displayName != null) {
      _nameCtrl.text = currentUser.displayName!;
    }

    // GPA / Average controller listener
    _averageCtrl.addListener(() {
      final average = double.tryParse(_averageCtrl.text) ?? 0.0;
      setState(() {
        _convertedGpa = _convert20To4(average);
      });
    });
  }

  double _convert20To4(double averageOutOf20) {
    if (averageOutOf20 <= 0) return 0.0;
    if (averageOutOf20 >= 20) return 4.0;
    
    if (averageOutOf20 >= 16) return 4.0;
    if (averageOutOf20 >= 14) {
      return 3.5 + (averageOutOf20 - 14) * (0.5 / 2.0); // 14 -> 3.5, 16 -> 4.0
    }
    if (averageOutOf20 >= 12) {
      return 3.0 + (averageOutOf20 - 12) * (0.5 / 2.0); // 12 -> 3.0, 14 -> 3.5
    }
    if (averageOutOf20 >= 10) {
      return 2.0 + (averageOutOf20 - 10) * (1.0 / 2.0); // 10 -> 2.0, 12 -> 3.0
    }
    return (averageOutOf20 / 10.0) * 2.0; // below 10 scales down to 0
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _countryCtrl.dispose();
    _nationalityCtrl.dispose();
    _universityCtrl.dispose();
    _fieldCtrl.dispose();
    _averageCtrl.dispose();
    _goalsCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.card,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 500,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _photoFile = image;
        _photoBytes = bytes;
      });
    }
  }

  Future<void> _pickCV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _cvFile = result.files.first);
    }
  }

  Future<void> _submitProfile() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    setState(() => _isSaving = true);
    try {
      String? photoUrl;
      String? cvUrl;

      // 1. Upload assets if selected
      if (_photoBytes != null) {
        final ext = _photoFile!.path.split('.').last;
        photoUrl = await ref
            .read(profileNotifierProvider.notifier)
            .uploadPhoto(_photoBytes!, ext);
      }

      if (_cvFile != null) {
        final bytes = _cvFile!.bytes ?? (kIsWeb ? null : await File(_cvFile!.path!).readAsBytes());
        if (bytes != null) {
          final ext = _cvFile!.name.split('.').last;
          cvUrl = await ref
              .read(profileNotifierProvider.notifier)
              .uploadCV(bytes, ext);
        }
      }

      // 2. Save Profile details
      final profile = ProfileModel(
        id: '', // Supabase will auto-assign UUID
        firebaseUid: currentUser.uid,
        fullName: _nameCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        nationality: _nationalityCtrl.text.trim(),
        birthDate: _birthDate,
        educationLevel: _educationLevel,
        fieldOfStudy: _fieldCtrl.text.trim(),
        university: _universityCtrl.text.trim(),
        gpa: _convertedGpa,
        englishLevel: _englishLevel,
        frenchLevel: _frenchLevel,
        targetCountries: _targetCountries,
        targetFields: _targetFields,
        academicGoals: _goalsCtrl.text.trim(),
        photoUrl: photoUrl,
        cvUrl: cvUrl,
      );

      await ref.read(profileNotifierProvider.notifier).updateProfile(profile);

      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error creating profile: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _submitProfile();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Set Up Profile 🎓',
                          style: AppTextStyles.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Step ${_currentStep + 1} of $_totalSteps',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      backgroundColor: AppColors.glassBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentStep),
                    child: _buildStepContent(),
                  ),
                ),
              ),
            ),

            // Bottom Navigation Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _prevStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.glassBorder),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: _currentStep == _totalSteps - 1
                          ? (_isSaving ? 'Saving...' : 'Finish')
                          : 'Next',
                      isLoading: _isSaving,
                      onPressed: _isStepValid() ? _nextStep : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isStepValid() {
    switch (_currentStep) {
      case 0:
        return _nameCtrl.text.isNotEmpty &&
            _countryCtrl.text.isNotEmpty &&
            _nationalityCtrl.text.isNotEmpty &&
            _birthDate != null;
      case 1:
        return _universityCtrl.text.isNotEmpty &&
            _fieldCtrl.text.isNotEmpty &&
            _averageCtrl.text.isNotEmpty &&
            double.tryParse(_averageCtrl.text) != null &&
            double.parse(_averageCtrl.text) >= 0 &&
            double.parse(_averageCtrl.text) <= 20;
      case 2:
        return _targetCountries.isNotEmpty && _targetFields.isNotEmpty;
      case 3:
        return true; // CV & Photo are optional, though recommended
      default:
        return false;
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfoStep();
      case 1:
        return _buildAcademicStep();
      case 2:
        return _buildPreferencesStep();
      case 3:
        return _buildUploadsStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── STEP 1: Personal Info ──────────────────────────────────────────────────
  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tell us about yourself', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Help us verify your eligibility for regional academic opportunities.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 32),
        AppTextField(
          controller: _nameCtrl,
          label: 'Full Name',
          hint: 'Enter your full name',
          prefixIcon: Icons.person_outline,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Country of Residence',
          value: _countryCtrl.text.isEmpty ? _africanCountries.first : _countryCtrl.text,
          items: _africanCountries,
          onChanged: (val) {
            if (val != null) {
              setState(() => _countryCtrl.text = val);
            }
          },
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Nationality',
          value: _nationalityCtrl.text.isEmpty ? _africanCountries.first : _nationalityCtrl.text,
          items: _africanCountries,
          onChanged: (val) {
            if (val != null) {
              setState(() => _nationalityCtrl.text = val);
            }
          },
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _selectBirthDate,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _birthDate == null
                        ? 'Date of Birth'
                        : DateFormat('MMM dd, yyyy').format(_birthDate!),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _birthDate == null ? AppColors.textSecondary : Colors.white,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── STEP 2: Academic Info ──────────────────────────────────────────────────
  Widget _buildAcademicStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Academic profile', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Provide your academic metrics to match with degree requirements.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 32),

        // Education Level Dropdown
        _buildDropdown(
          label: 'Current Education Level',
          value: _educationLevel,
          items: _educationLevels,
          onChanged: (val) {
            if (val != null) setState(() => _educationLevel = val);
          },
        ),
        const SizedBox(height: 16),

        AppTextField(
          controller: _universityCtrl,
          label: 'University / School Name',
          hint: 'e.g. University of Ibadan',
          prefixIcon: Icons.school_outlined,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Field of Study',
          value: _fieldCtrl.text.isEmpty ? _fieldsOfStudyList.first : _fieldCtrl.text,
          items: _fieldsOfStudyList,
          onChanged: (val) {
            if (val != null) setState(() => _fieldCtrl.text = val);
          },
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _averageCtrl,
          label: 'Average Academic Score (out of 20)',
          hint: 'e.g. 14.5',
          prefixIcon: Icons.grade_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Converted GPA: ${_convertedGpa.toStringAsFixed(2)} / 4.0',
            style: TextStyle(
              color: _convertedGpa >= 3.0 ? AppColors.success : AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ── STEP 3: Preferences & Languages ────────────────────────────────────────
  Widget _buildPreferencesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preferences & Languages', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Tell us where you want to study and which languages you speak.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 32),

        // English Level Dropdown
        _buildDropdown(
          label: 'English Language Level',
          value: _englishLevel,
          items: _languageLevels,
          onChanged: (val) {
            if (val != null) setState(() => _englishLevel = val);
          },
        ),
        const SizedBox(height: 16),

        // French Level Dropdown
        _buildDropdown(
          label: 'French Language Level',
          value: _frenchLevel,
          items: _languageLevels,
          onChanged: (val) {
            if (val != null) setState(() => _frenchLevel = val);
          },
        ),
        const SizedBox(height: 24),

        // Target Countries Chips
        Text('Target Study Countries (Select multiple)', style: AppTextStyles.labelLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _destinationCountries.map((country) {
            final isSelected = _targetCountries.contains(country);
            return FilterChip(
              label: Text(country, style: const TextStyle(color: Colors.white)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _targetCountries.add(country);
                  } else {
                    _targetCountries.remove(country);
                  }
                });
              },
              backgroundColor: AppColors.card,
              selectedColor: AppColors.primary.withOpacity(0.25),
              checkmarkColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.glassBorder,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Target Fields Chips
        Text('Target Study Fields (Select multiple)', style: AppTextStyles.labelLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _targetFieldsList.map((field) {
            final isSelected = _targetFields.contains(field);
            return FilterChip(
              label: Text(field, style: const TextStyle(color: Colors.white)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _targetFields.add(field);
                  } else {
                    _targetFields.remove(field);
                  }
                });
              },
              backgroundColor: AppColors.card,
              selectedColor: AppColors.primary.withOpacity(0.25),
              checkmarkColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.glassBorder,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Goals
        AppTextField(
          controller: _goalsCtrl,
          label: 'Academic / Career Goals',
          hint: 'Describe your future aspirations...',
          maxLines: 3,
        ),
      ],
    );
  }

  // ── STEP 4: Documents Upload ───────────────────────────────────────────────
  Widget _buildUploadsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profile Photo & CV', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Upload these now to enable CV reviews and application checklists.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 32),

        // Photo Picker
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.card,
                backgroundImage: _photoBytes != null
                    ? MemoryImage(_photoBytes!)
                    : const AssetImage('assets/images/logo.png') as ImageProvider,
                child: _photoBytes == null
                    ? const Icon(Icons.person, size: 50, color: AppColors.textSecondary)
                    : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                label: const Text('Change Photo', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.glassBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        // CV / Resume Picker
        Text('Curriculum Vitae (CV)', style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickCV,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.upload_file_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  _cvFile == null ? 'Select CV File' : _cvFile!.name,
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _cvFile == null
                      ? 'Supports PDF, DOC, DOCX up to 10MB'
                      : '${(_cvFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper Widget for custom formatted Dropdowns
  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              dropdownColor: AppColors.card,
              style: AppTextStyles.bodyMedium,
              items: items.map((i) {
                return DropdownMenuItem<String>(
                  value: i,
                  child: Text(i, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
