import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:attendance_app/screens/login_screen.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/message_helper.dart';

class OrganizationSetupScreen extends StatefulWidget {
  const OrganizationSetupScreen({super.key});

  @override
  State<OrganizationSetupScreen> createState() => _OrganizationSetupScreenState();
}

class _OrganizationSetupScreenState extends State<OrganizationSetupScreen> {
  final _organizationNameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  int _step = 0;
  bool _isSubmitting = false;
  String _organizationType = 'Information Technology';
  String _state = 'Karnataka';
  String _country = 'India';
  String _timeZone = 'Asia/Kolkata (IST +5:30)';
  String _organizationSize = '51-200 Employees';
  String? _createdRequestId;
  DateTime? _createdAt;

  static const _steps = [
    'Organization Details',
    'Location & Address',
    'Review & Create',
  ];

  static const _organizationTypes = [
    'Information Technology',
    'Engineering',
    'Finance',
    'Healthcare',
    'Education',
    'Retail',
  ];

  static const _states = [
    'Karnataka',
    'Tamil Nadu',
    'Maharashtra',
    'Telangana',
    'Kerala',
    'Delhi',
  ];

  static const _sizes = [
    '1-10 Employees',
    '11-50 Employees',
    '51-200 Employees',
    '201-500 Employees',
    '500+ Employees',
  ];

  @override
  void dispose() {
    _organizationNameController.dispose();
    _websiteController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _contactEmailController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _submitOrganization() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final createdAt = DateTime.now();
      final docRef = await FirestoreService.organizationSetupRequestsCol.add({
        'flow': 'pre_login_organization_setup',
        'status': 'pending_admin_setup',
        'organizationName': _organizationNameController.text.trim(),
        'website': _websiteController.text.trim(),
        'organizationType': _organizationType,
        'contactPerson': _contactPersonController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'contactEmail': _contactEmailController.text.trim().toLowerCase(),
        'addressLine1': _addressLine1Controller.text.trim(),
        'addressLine2': _addressLine2Controller.text.trim(),
        'city': _cityController.text.trim(),
        'state': _state,
        'country': _country,
        'postalCode': _postalCodeController.text.trim(),
        'timeZone': _timeZone,
        'organizationSize': _organizationSize,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'workspaceStatus': 'active',
      });

      if (!mounted) return;
      setState(() {
        _createdRequestId = docRef.id;
        _createdAt = createdAt;
        _step = 4;
      });
    } catch (e) {
      if (mounted) {
        MessageHelper.showError(
          context,
          'Could not create organization. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _validateStep() {
    if (_step == 1) {
      if (_organizationNameController.text.trim().isEmpty ||
          _contactPersonController.text.trim().isEmpty ||
          _contactNumberController.text.trim().isEmpty ||
          _contactEmailController.text.trim().isEmpty) {
        MessageHelper.showWarning(context, 'Fill all required organization details.');
        return false;
      }
      return true;
    }

    if (_step == 2) {
      if (_addressLine1Controller.text.trim().isEmpty ||
          _cityController.text.trim().isEmpty ||
          _postalCodeController.text.trim().isEmpty) {
        MessageHelper.showWarning(context, 'Fill all required address details.');
        return false;
      }
    }

    return true;
  }

  void _goNext() {
    if (!_validateStep()) return;
    setState(() => _step += 1);
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return DateFormat('dd MMM yyyy').format(DateTime.now());
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
          onPressed: _step == 4 ? () => Navigator.pop(context) : _goBack,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_step < 4) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F1FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _step == 0 ? 'First-Time Setup' : 'STEP ${_step + 1} OF 3',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildStepBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _buildIntroStep();
      case 1:
        return _buildOrganizationDetailsStep();
      case 2:
        return _buildAddressStep();
      case 3:
        return _buildReviewStep();
      case 4:
        return _buildSuccessStep();
      default:
        return _buildIntroStep();
    }
  }

  Widget _buildIntroStep() {
    return _buildScrollableStep(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EAF1)),
          ),
          child: Column(
            children: [
              Container(
                height: 34,
                width: 126,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'TechCorp Solutions',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Expanded(child: _PreviewPill(label: 'Engineering', color: Color(0xFFE8E9FB), dotColor: AppTheme.primary)),
                  SizedBox(width: 8),
                  Expanded(child: _PreviewPill(label: 'HR', color: Color(0xFFDFF0FF), dotColor: Color(0xFF23A6F0))),
                  SizedBox(width: 8),
                  Expanded(child: _PreviewPill(label: 'Finance', color: Color(0xFFDFF7EA), dotColor: Color(0xFF22C55E))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Expanded(child: _MiniStatBox(label: 'Employees')),
                  SizedBox(width: 8),
                  Expanded(child: _MiniStatBox(label: 'Attendance')),
                  SizedBox(width: 8),
                  Expanded(child: _MiniStatBox(label: 'Leaves')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Let's set up your organization",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Create your company workspace to manage attendance, leave, employees, and teams.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            _steps.length,
            (index) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                '${index + 1}. ${_steps[index]}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        _primaryButton(
          label: 'Start Setup',
          onPressed: () => setState(() => _step = 1),
        ),
        const SizedBox(height: 10),
        _secondaryButton(
          label: 'Save & Continue Later',
          onPressed: () {
            MessageHelper.showWarning(
              context,
              'Start setup first to save organization details.',
            );
          },
        ),
      ],
    );
  }

  Widget _buildOrganizationDetailsStep() {
    return _buildScrollableStep(
      children: [
        _buildStepHeader('Organization Details', 1),
        const SizedBox(height: 18),
        _buildProgressIndicator(1),
        const SizedBox(height: 24),
        _uploadCard(),
        const SizedBox(height: 18),
        _inputField(_organizationNameController, 'Organization Name *', Icons.business_outlined),
        const SizedBox(height: 12),
        _inputField(_websiteController, 'Website', Icons.language_rounded),
        const SizedBox(height: 12),
        _dropdownField(
          label: 'Organization Type *',
          icon: Icons.apartment_rounded,
          value: _organizationType,
          items: _organizationTypes,
          onChanged: (value) => setState(() => _organizationType = value!),
        ),
        const SizedBox(height: 18),
        Text(
          'CONTACT INFORMATION',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textHint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        _inputField(_contactPersonController, 'Contact Person *', Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _inputField(_contactNumberController, 'Contact Number *', Icons.call_outlined, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        _inputField(_contactEmailController, 'Contact Email *', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        const Spacer(),
        _primaryButton(label: 'Continue', onPressed: _goNext),
      ],
    );
  }

  Widget _buildAddressStep() {
    return _buildScrollableStep(
      children: [
        _buildStepHeader('Organization Address', 2),
        const SizedBox(height: 18),
        _buildProgressIndicator(2),
        const SizedBox(height: 24),
        _inputField(_addressLine1Controller, 'Address Line 1 *', Icons.location_on_outlined),
        const SizedBox(height: 12),
        _inputField(_addressLine2Controller, 'Address Line 2', Icons.location_on_outlined),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _inputField(_cityController, 'City *', Icons.location_city_outlined)),
            const SizedBox(width: 10),
            Expanded(
              child: _dropdownField(
                label: 'State *',
                icon: Icons.map_outlined,
                value: _state,
                items: _states,
                onChanged: (value) => setState(() => _state = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _dropdownField(
                label: 'Country *',
                icon: Icons.public_rounded,
                value: _country,
                items: const ['India'],
                onChanged: (value) => setState(() => _country = value!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _inputField(
                _postalCodeController,
                'Postal Code *',
                Icons.markunread_mailbox_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _dropdownField(
          label: 'Time Zone *',
          icon: Icons.schedule_rounded,
          value: _timeZone,
          items: const ['Asia/Kolkata (IST +5:30)'],
          onChanged: (value) => setState(() => _timeZone = value!),
        ),
        const SizedBox(height: 18),
        Text(
          'OPTIONAL',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textHint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        _dropdownField(
          label: 'Organization Size',
          icon: Icons.groups_outlined,
          value: _organizationSize,
          items: _sizes,
          onChanged: (value) => setState(() => _organizationSize = value!),
        ),
        const Spacer(),
        _primaryButton(label: 'Continue', onPressed: _goNext),
        const SizedBox(height: 10),
        _secondaryButton(label: 'Back', onPressed: _goBack),
      ],
    );
  }

  Widget _buildReviewStep() {
    return _buildScrollableStep(
      children: [
        _buildStepHeader('Review & Create', 3),
        const SizedBox(height: 18),
        _buildProgressIndicator(3),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6EAF2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _organizationNameController.text.trim().isEmpty
                          ? 'TC'
                          : _organizationNameController.text.trim().substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _organizationNameController.text.trim(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _organizationType,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _reviewSection('Organization Information', [
                _reviewRow('Organization Name', _organizationNameController.text.trim()),
                _reviewRow('Type', _organizationType),
                _reviewRow('Website', _websiteController.text.trim().isEmpty ? '-' : _websiteController.text.trim()),
              ]),
              const SizedBox(height: 16),
              _reviewSection('Contact Information', [
                _reviewRow('Contact Person', _contactPersonController.text.trim()),
                _reviewRow('Phone', _contactNumberController.text.trim()),
                _reviewRow('Email', _contactEmailController.text.trim()),
              ]),
              const SizedBox(height: 16),
              _reviewSection('Address & Location', [
                _reviewRow('Address', _addressLine1Controller.text.trim()),
                _reviewRow('Address 2', _addressLine2Controller.text.trim().isEmpty ? '-' : _addressLine2Controller.text.trim()),
                _reviewRow('City, State', '${_cityController.text.trim()}, $_state'),
                _reviewRow('Country / Postal Code', '$_country - ${_postalCodeController.text.trim()}'),
                _reviewRow('Time Zone', _timeZone),
                _reviewRow('Organization Size', _organizationSize),
              ]),
            ],
          ),
        ),
        const Spacer(),
        _primaryButton(
          label: _isSubmitting ? 'Creating...' : 'Create Organization',
          onPressed: _isSubmitting ? null : _submitOrganization,
        ),
        const SizedBox(height: 10),
        _secondaryButton(label: 'Back', onPressed: _goBack),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return _buildScrollableStep(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F9EF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.apartment_rounded, color: Color(0xFF16A34A), size: 38),
        ),
        const SizedBox(height: 24),
        const Text(
          'Organization Created Successfully',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your workspace is ready. Next, create your first administrator account.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6EAF2)),
          ),
          child: Column(
            children: [
              _successRow('Organization', _organizationNameController.text.trim()),
              const Divider(height: 24),
              _successRow('Created On', _formatDate(_createdAt)),
              const Divider(height: 24),
              _successRow('Workspace', 'Active'),
              const Divider(height: 24),
              _successRow('Request ID', _createdRequestId ?? '-'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Next: Admin Setup\nCreate the first administrator account',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
            ],
          ),
        ),
        const Spacer(),
        _primaryButton(
          label: 'Continue to Admin Setup',
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  Widget _buildScrollableStep({
    required List<Widget> children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepHeader(String title, int step) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP $step OF 3',
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textHint,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(int activeStep) {
    return Row(
      children: List.generate(
        3,
        (index) {
          final stepNumber = index + 1;
          final isComplete = stepNumber < activeStep;
          final isActive = stepNumber == activeStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isComplete || isActive ? AppTheme.primary : Colors.white,
                    border: Border.all(
                      color: isComplete || isActive ? AppTheme.primary : const Color(0xFFD1D5DB),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isComplete
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : Text(
                          '$stepNumber',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : AppTheme.textHint,
                          ),
                        ),
                ),
                if (index < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: stepNumber < activeStep ? AppTheme.primary : const Color(0xFFE5E7EB),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _uploadCard() {
    return InkWell(
      onTap: () {
        MessageHelper.showWarning(
          context,
          'Logo upload can be added next. Organization creation already works.',
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(Icons.file_upload_outlined, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload Organization Logo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'PNG, JPG up to 2MB',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textHint,
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

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textHint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textHint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _reviewSection(String title, List<Widget> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...rows,
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _successRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppTheme.textHint),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF111827),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color dotColor;

  const _PreviewPill({
    required this.label,
    required this.color,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  final String label;

  const _MiniStatBox({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Text(
            '—',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
