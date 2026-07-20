import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'package:attendance_app/screens/admin_setup_screen.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/message_helper.dart';

const _kGoogleApiKey = 'AIzaSyALDMYAfDXu-dDv5dXd6VuQCJCTsRPG4UY';

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
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  int _step = 0;
  bool _isSubmitting = false;
  String? _organizationType;
  String? _state;
  String _country = 'India';
  String _timeZone = 'Asia/Kolkata (IST +5:30)';
  String? _organizationSize;
  String? _createdRequestId;
  DateTime? _createdAt;

  // â”€â”€ Address / Geocoding state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;
  bool _isLoadingSuggestions = false;
  List<Map<String, dynamic>> _addressSuggestions = [];
  Timer? _debounce;

  static const _states = [
    'Karnataka',
    'Tamil Nadu',
    'Maharashtra',
    'Telangana',
    'Kerala',
    'Delhi',
    'Gujarat',
    'Rajasthan',
    'Uttar Pradesh',
    'West Bengal',
  ];

  static const _steps = [
    'Organization Details',
    'Location & Address',
    'Review & Create',
  ];

  static const _sizes = [
    '1-10 Employees',
    '11-50 Employees',
    '51-200 Employees',
    '201-500 Employees',
    '500+ Employees',
  ];

  static const _organizationTypes = [
    'Information Technology',
    'Engineering',
    'Finance',
    'Healthcare',
    'Education',
    'Retail',
  ];

  @override
  void dispose() {
    _organizationNameController.dispose();
    _websiteController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _contactEmailController.dispose();
    _addressLine1Controller.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // â”€â”€ Places Autocomplete â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _onAddressSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _addressSuggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchPlacesSuggestions(query.trim());
    });
  }

  Future<void> _fetchPlacesSuggestions(String input) async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&types=geocode'
        '&language=en'
        '&key=$_kGoogleApiKey',
      );
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final predictions = (data['predictions'] as List?) ?? [];
        setState(() {
          _addressSuggestions = predictions
              .map((p) => {
                    'placeId': p['place_id'] as String,
                    'description': p['description'] as String,
                  })
              .toList();
        });
      }
    } catch (_) {
      // Silently ignore network errors
    } finally {
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  Future<void> _fetchPlaceDetails(String placeId, String description) async {
    setState(() {
      _isLoadingSuggestions = true;
      _addressSuggestions = [];
    });
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${Uri.encodeComponent(placeId)}'
        '&fields=geometry,formatted_address,address_components'
        '&key=$_kGoogleApiKey',
      );
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final result = data['result'] as Map<String, dynamic>?;
        if (result != null) {
          final location = result['geometry']?['location'];
          final formatted = result['formatted_address'] as String? ?? description;
          // Try to extract city, state, postal code from address_components
          String city = '';
          String state = '';
          String postalCode = '';
          String country = 'India';
          final components = result['address_components'] as List? ?? [];
          for (final c in components) {
            final types = (c['types'] as List).cast<String>();
            if (types.contains('locality')) city = c['long_name'] as String? ?? '';
            if (types.contains('administrative_area_level_1')) state = c['long_name'] as String? ?? '';
            if (types.contains('postal_code')) postalCode = c['long_name'] as String? ?? '';
            if (types.contains('country')) country = c['long_name'] as String? ?? 'India';
          }
          // Match state to our list or keep null
          final matchedState = _states.firstWhere(
            (s) => state.contains(s) || s.contains(state),
            orElse: () => '',
          );
          setState(() {
            _latitude = (location?['lat'] as num?)?.toDouble();
            _longitude = (location?['lng'] as num?)?.toDouble();
            _addressLine1Controller.text = formatted;
            if (city.isNotEmpty) _cityController.text = city;
            if (postalCode.isNotEmpty) _postalCodeController.text = postalCode;
            if (matchedState.isNotEmpty) _state = matchedState;
            _country = country;
            _addressSuggestions = [];
          });
        }
      }
    } catch (e) {
      if (mounted) MessageHelper.showError(context, 'Failed to get address details.');
    } finally {
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  // â”€â”€ Live Location â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _fetchLiveLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          MessageHelper.showError(
            context,
            'Location permission permanently denied. Enable it in app settings.',
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          // Build address line 1 from street + subLocality
          final addressParts = [
            if (p.street != null && p.street!.isNotEmpty) p.street,
            if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality,
          ];
          _addressLine1Controller.text = addressParts.isNotEmpty
              ? addressParts.join(', ')
              : '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          // Auto-fill city
          if (p.locality != null && p.locality!.isNotEmpty) {
            _cityController.text = p.locality!;
          }
          // Auto-fill postal code
          if (p.postalCode != null && p.postalCode!.isNotEmpty) {
            _postalCodeController.text = p.postalCode!;
          }
          // Match state
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
            final area = p.administrativeArea!;
            final matched = _states.firstWhere(
              (s) => area.contains(s) || s.contains(area),
              orElse: () => '',
            );
            if (matched.isNotEmpty) _state = matched;
          }
          _addressSuggestions = [];
        });
      } else {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _addressLine1Controller.text =
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          _addressSuggestions = [];
        });
      }
    } catch (e) {
      if (mounted) MessageHelper.showError(context, 'Could not fetch location: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _submitOrganization() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    await Future.delayed(const Duration(milliseconds: 600));

    final createdAt = DateTime.now();
    final newCompanyId = FirebaseFirestore.instance.collection('organizations').doc().id;

    if (!mounted) return;
    setState(() {
      _createdRequestId = newCompanyId;
      _createdAt = createdAt;
      _step = 4;
      _isSubmitting = false;
    });
  }

  bool _validateStep() {
    if (_step == 1) {
      if (_organizationNameController.text.trim().isEmpty ||
          _contactPersonController.text.trim().isEmpty ||
          _contactNumberController.text.trim().isEmpty ||
          _contactEmailController.text.trim().isEmpty ||
          _organizationType == null) {
        MessageHelper.showWarning(context, 'Fill all required organization details.');
        return false;
      }
      return true;
    }

    if (_step == 2) {
      if (_addressLine1Controller.text.trim().isEmpty ||
          _cityController.text.trim().isEmpty ||
          _postalCodeController.text.trim().isEmpty ||
          _state == null) {
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
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
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
        leading: (_step == 0 && !Navigator.canPop(context))
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
                onPressed: _step == 4 ? () => Navigator.pop(context) : _goBack,
              ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: _buildStepBody(),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'First-Time Setup',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.business_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'TechCorp Solutions',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
        const SizedBox(height: 32),
        const Text(
          "Let's set up your organization",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Create your company workspace to manage attendance, leave, employees, and teams.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(
            _steps.length,
            (index) => Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: const Color(0xFFF0F1FF),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _steps[index],
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
        if (Navigator.canPop(context)) ...[
          const SizedBox(height: 10),
          _secondaryButton(
            label: 'Back',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ],
    );
  }

  Widget _buildOrganizationDetailsStep() {
    return _buildScrollableStep(
      children: [
        _buildStepHeader('Organization Details', 1),
        const SizedBox(height: 20),
        _buildProgressIndicator(1),
        const SizedBox(height: 32),
        _uploadCard(),
        const SizedBox(height: 20),
        _inputField(_organizationNameController, 'Organization Name *', Icons.business_outlined),
        const SizedBox(height: 16),
        _inputField(_websiteController, 'Website', Icons.language_rounded),
        const SizedBox(height: 16),
        _dropdownField(
          label: 'Organization Type *',
          icon: Icons.apartment_rounded,
          value: _organizationType,
          items: _organizationTypes,
          onChanged: (value) => setState(() => _organizationType = value!),
        ),
        const SizedBox(height: 24),
        const Text(
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
        const SizedBox(height: 16),
        _inputField(_contactNumberController, 'Contact Number *', Icons.call_outlined, keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        _inputField(_contactEmailController, 'Contact Email *', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        const Spacer(),
        const SizedBox(height: 20),
        _primaryButton(label: 'Continue', onPressed: _goNext),
        const SizedBox(height: 10),
        _secondaryButton(label: 'Back', onPressed: _goBack),
      ],
    );
  }

  Widget _buildAddressStep() {
    return _buildScrollableStep(
      children: [
        _buildStepHeader('Organization Address', 2),
        const SizedBox(height: 20),
        _buildProgressIndicator(2),
        const SizedBox(height: 32),

        // â”€â”€ Address Line 1 with Places Autocomplete â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _addressLine1Controller,
              onChanged: _onAddressSearchChanged,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Address Line 1 *',
                labelStyle:
                    const TextStyle(fontSize: 13, color: AppTheme.textHint),
                prefixIcon: const Icon(Icons.location_on_outlined,
                    size: 20, color: AppTheme.textHint),
                suffixIcon: _isLoadingSuggestions
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary),
                        ),
                      )
                    : _isFetchingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.primary),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Use live location',
                            icon: const Icon(Icons.my_location_rounded,
                                size: 20, color: AppTheme.primary),
                            onPressed: _fetchLiveLocation,
                          ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
            // â”€â”€ Autocomplete suggestions dropdown â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (_addressSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _addressSuggestions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  itemBuilder: (context, index) {
                    final s = _addressSuggestions[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _fetchPlaceDetails(
                        s['placeId'] as String,
                        s['description'] as String,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 16, color: AppTheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s['description'] as String,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // â”€â”€ City & State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Row(
          children: [
            Expanded(
              child: _inputField(_cityController, 'City *', null),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdownField(
                label: 'State *',
                icon: null,
                value: _state,
                items: _states,
                onChanged: (value) => setState(() => _state = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // â”€â”€ Country & Postal Code â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Row(
          children: [
            Expanded(
              child: _dropdownField(
                label: 'Country *',
                icon: null,
                value: _country,
                items: const ['India'],
                onChanged: (value) => setState(() => _country = value!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _inputField(
                _postalCodeController,
                'Postal Code *',
                null,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // â”€â”€ Time Zone â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        _dropdownField(
          label: 'Time Zone *',
          icon: Icons.schedule_rounded,
          value: _timeZone,
          items: const ['Asia/Kolkata (IST +5:30)'],
          onChanged: (value) => setState(() => _timeZone = value!),
        ),
        const SizedBox(height: 24),
        const Text(
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
        const SizedBox(height: 20),
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
        const SizedBox(height: 20),
        _buildProgressIndicator(3),
        const SizedBox(height: 32),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _organizationNameController.text.trim().isEmpty ? 'TechCorp Solutions' : _organizationNameController.text.trim(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _organizationType ?? 'Organization Type',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 18),
                    onPressed: () => setState(() => _step = 1),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _reviewSection('Organization Information', () => setState(() => _step = 1), [
                _reviewRow('Organization Name', _organizationNameController.text.trim(), Icons.business_outlined),
                _reviewRow('Type', _organizationType ?? '-', Icons.apartment_rounded),
                _reviewRow('Website', _websiteController.text.trim().isEmpty ? '-' : _websiteController.text.trim(), Icons.language_rounded),
              ]),
              const SizedBox(height: 16),
              _reviewSection('Contact Information', () => setState(() => _step = 1), [
                _reviewRow('Contact Person', _contactPersonController.text.trim(), Icons.person_outline_rounded),
                _reviewRow('Phone', _contactNumberController.text.trim(), Icons.call_outlined),
                _reviewRow('Email', _contactEmailController.text.trim(), Icons.email_outlined),
              ]),
              const SizedBox(height: 16),
              _reviewSection('Address & Location', () => setState(() => _step = 2), [
                _reviewRow(
                  'Address',
                  _addressLine1Controller.text.trim().isNotEmpty
                      ? _addressLine1Controller.text.trim()
                      : '-',
                  Icons.location_on_outlined,
                ),
                _reviewRow(
                  'City, State',
                  '${_cityController.text.trim()}, ${_state ?? '-'} - ${_postalCodeController.text.trim()}',
                  Icons.public_rounded,
                ),
                if (_latitude != null)
                  _reviewRow(
                    'Coordinates',
                    'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                    Icons.gps_fixed_rounded,
                  ),
                _reviewRow('Time Zone', _timeZone, Icons.schedule_rounded),
              ]),
            ],
          ),
        ),
        const Spacer(),
        const SizedBox(height: 20),
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
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFE9F9EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.apartment_rounded, color: Color(0xFF16A34A), size: 38),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Organization Created Successfully',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your workspace is ready. Next, create the first\nadministrator account.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6EAF2)),
          ),
          child: Column(
            children: [
              _successRow('Organization', _organizationNameController.text.trim()),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFFE5E7EB)),
              ),
              _successRow('Created On', _formatDate(_createdAt)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFFE5E7EB)),
              ),
              _successRow('Workspace', 'Active'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary, size: 24),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next: Admin Setup',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Create the first administrator account',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
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
            final orgData = {
              'companyId': _createdRequestId,
              'companyName': _organizationNameController.text.trim(),
              'website': _websiteController.text.trim(),
              'organizationType': _organizationType ?? '',
              'contactPerson': _contactPersonController.text.trim(),
              'contactNumber': _contactNumberController.text.trim(),
              'contactEmail': _contactEmailController.text.trim().toLowerCase(),
              // Address displayed to user
              'addressLine1': _addressLine1Controller.text.trim(),
              'city': _cityController.text.trim(),
              'state': _state ?? '',
              'country': _country,
              'postalCode': _postalCodeController.text.trim(),
              // Geofencing coordinates stored as individual doubles
              'latitude': _latitude,
              'longitude': _longitude,
              // GeoPoint for Firestore geo-queries
              'location': _latitude != null && _longitude != null
                  ? GeoPoint(_latitude!, _longitude!)
                  : null,
              'timeZone': _timeZone,
              'organizationSize': _organizationSize ?? '',
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            };

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminSetupScreen(organizationData: orgData),
              ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: LayoutBuilder(
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
      ),
    );
  }

  Widget _buildStepHeader(String title, int step) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'STEP $step OF 3',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
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
    List<Widget> children = [];
    for (int i = 0; i < 3; i++) {
      final stepNumber = i + 1;
      final isComplete = stepNumber < activeStep;
      final isActive = stepNumber == activeStep;
      
      final borderColor = (isComplete || isActive) ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB);
      final bgColor = isComplete ? const Color(0xFF5C5CFF) : Colors.white;
      final textColor = isActive ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF);

      children.add(
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: isComplete
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : Text(
                  '$stepNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
        ),
      );

      if (i < 2) {
        children.add(
          Expanded(
            child: Container(
              height: 1.5,
              color: isComplete ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB),
            ),
          ),
        );
      }
    }

    return Row(
      children: children,
    );
  }

  File? _logoFile;

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _logoFile = File(picked.path));
    }
  }

  Widget _uploadCard() {
    return GestureDetector(
      onTap: _pickLogo,
      child: SizedBox(
        width: 327, // Fits exact width padding limits
        height: 72, // Exactly 72 Hug as in the screenshot
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), 
              ),
              child: _logoFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_logoFile!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.upload_outlined, color: AppTheme.textSecondary, size: 24),
                        SizedBox(height: 4),
                        Text(
                          'Logo',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 16),
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
                  const SizedBox(height: 4),
                  const Text(
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

  Widget _buildLabel(String text) {
    if (text.endsWith(' *')) {
      return RichText(
        text: TextSpan(
          text: text.substring(0, text.length - 2),
          style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
          children: const [
            TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
          ],
        ),
      );
    }
    return Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textHint));
  }

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData? icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      height: 51,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          label: _buildLabel(label),
          prefixIcon: icon != null ? Icon(icon, size: 20, color: AppTheme.textHint) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF5C5CFF), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData? icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      height: 51,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        icon: const Icon(Icons.expand_more_rounded, color: AppTheme.textHint, size: 22),
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          label: _buildLabel(label),
          prefixIcon: icon != null ? Icon(icon, size: 20, color: AppTheme.textHint) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF5C5CFF), width: 1.5),
          ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 14)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _reviewSection(String title, VoidCallback onEdit, List<Widget> rows) {
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
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textHint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
          style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
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
    return Center(
      child: SizedBox(
        width: 327,
        height: 51,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5C5CFF),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFB0B2FF),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), 
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
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: SizedBox(
        width: 327,
        height: 51,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Text(
            'â€”',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textHint,
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
