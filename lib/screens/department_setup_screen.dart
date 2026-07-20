import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:attendance_app/screens/employee_setup_screen.dart';
import 'package:attendance_app/screens/organization_configuration_screen.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/message_helper.dart';

// â”€â”€ Department Data Model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DeptModel {
  final String id;
  String name;
  String code;
  String? description;
  String? parentId;
  String? parentName;
  bool isActive;
  Color color;

  _DeptModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.parentId,
    this.parentName,
    this.isActive = true,
    required this.color,
  });

  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// â”€â”€ Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class DepartmentSetupScreen extends StatefulWidget {
  final String orgId;
  final String orgName;

  const DepartmentSetupScreen({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  State<DepartmentSetupScreen> createState() => _DepartmentSetupScreenState();
}

class _DepartmentSetupScreenState extends State<DepartmentSetupScreen> {
  // 0=intro, 1=list, 2=add/edit form, 3=review, 4=success
  int _step = 0;
  bool _isFinalizing = false;

  // The in-memory list of departments being built
  final List<_DeptModel> _departments = [];

  // Which dept is being edited (null = new)
  _DeptModel? _editingDept;

  // Form controllers (for step 2: Add/Edit)
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String? _parentId;
  bool _deptIsActive = true;

  // Quick-select presets
  static const _quickSelectNames = [
    'Technology',
    'Human Resources',
    'Operations',
    'Sales',
    'Finance',
    'Design',
    'Marketing',
    'Legal',
  ];

  static const _deptColors = [
    Color(0xFF5C5CFF), // Indigo
    Color(0xFF23A6F0), // Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFF22C55E), // Green
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
  ];

  Color _nextColor() => _deptColors[_departments.length % _deptColors.length];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_step == 0 || _step == 4) {
      Navigator.pop(context);
      return;
    }
    if (_step == 2) {
      // Cancel form â†’ back to list
      setState(() => _step = 1);
      return;
    }
    setState(() => _step--);
  }

  // Open the Add / Edit form
  void _openAddForm({_DeptModel? existing}) {
    _editingDept = existing;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _codeCtrl.text = existing.code;
      _descCtrl.text = existing.description ?? '';
      _locationCtrl.text = widget.orgName;
      _parentId = existing.parentId;
      _deptIsActive = existing.isActive;
    } else {
      _nameCtrl.clear();
      _codeCtrl.clear();
      _descCtrl.clear();
      _locationCtrl.text = widget.orgName;
      _parentId = null;
      _deptIsActive = true;
    }
    setState(() => _step = 2);
  }

  void _applyQuickSelect(String name) {
    _nameCtrl.text = name;
    // Auto-generate dept code from name
    final code = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .join();
    _codeCtrl.text = code;
  }

  void _saveDepartment() {
    if (_nameCtrl.text.trim().isEmpty) {
      MessageHelper.showWarning(context, 'Department name is required.');
      return;
    }
    if (_codeCtrl.text.trim().isEmpty) {
      MessageHelper.showWarning(context, 'Department code is required.');
      return;
    }

    setState(() {
      if (_editingDept != null) {
        // Update existing
        _editingDept!.name = _nameCtrl.text.trim();
        _editingDept!.code = _codeCtrl.text.trim();
        _editingDept!.description = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
        _editingDept!.parentId = _parentId;
        _editingDept!.parentName = _parentId != null
            ? _departments.firstWhere((d) => d.id == _parentId, orElse: () => _departments.first).name
            : null;
        _editingDept!.isActive = _deptIsActive;
      } else {
        // Add new
        final parentDept = _parentId != null
            ? _departments.where((d) => d.id == _parentId).firstOrNull
            : null;
        _departments.add(_DeptModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameCtrl.text.trim(),
          code: _codeCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          parentId: _parentId,
          parentName: parentDept?.name,
          isActive: _deptIsActive,
          color: _nextColor(),
        ));
      }
      _editingDept = null;
      _step = 1;
    });

    MessageHelper.showSuccess(context, 'Department saved!');
  }

  void _deleteDepartment(_DeptModel dept) {
    setState(() => _departments.remove(dept));
  }

  Future<void> _finalizeDepartments() async {
    if (_isFinalizing) return;
    if (_departments.isEmpty) {
      MessageHelper.showWarning(context, 'Add at least one department before finalizing.');
      return;
    }

    setState(() => _isFinalizing = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = FieldValue.serverTimestamp();

      for (final dept in _departments) {
        final ref = FirestoreService.orgDepartmentDoc(widget.orgId, dept.id);
        batch.set(ref, {
          'id': dept.id,
          'name': dept.name,
          'code': dept.code,
          'description': dept.description,
          'parentDeptId': dept.parentId,
          'parentDeptName': dept.parentName,
          'isActive': dept.isActive,
          'employeeCount': 0,
          'orgId': widget.orgId,
          'createdAt': now,
          'updatedAt': now,
        });
      }

      // Update org setupStep to "complete"
      batch.update(FirestoreService.orgDoc(widget.orgId), {
        'setupStep': 'complete',
        'updatedAt': now,
      });

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _isFinalizing = false;
        _step = 4; // Success
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFinalizing = false);
      MessageHelper.showError(context, 'Failed to save departments: $e');
    }
  }

  int get _subDeptCount =>
      _departments.where((d) => d.parentId != null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _step > 1 && _step < 4
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppTheme.textPrimary, size: 24),
                onPressed: _goBack,
              ),
              title: Text(
                _stepTitle(),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
              ),
            )
          : null,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 1:
        return 'Departments';
      case 2:
        return _editingDept != null ? 'Edit Department' : 'Add Department';
      case 3:
        return 'Review Departments';
      default:
        return '';
    }
  }

  Widget _buildBody() {
    switch (_step) {
      case 0:
        return _buildIntroStep();
      case 1:
        return _buildListStep();
      case 2:
        return _buildAddEditStep();
      case 3:
        return _buildReviewStep();
      case 4:
        return _buildSuccessStep();
      default:
        return _buildIntroStep();
    }
  }

  // â”€â”€ Step 0: Intro â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildIntroStep() {
    return _padded(_scrollable(children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF0F1FF), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.business_center_rounded, size: 24, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SYSTEM-04', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700)),
              Text('Department Setup', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
      const SizedBox(height: 20),
      _breadcrumb(['Organization', 'Admin', 'Departments', 'Config'], 2),
      const SizedBox(height: 24),
      
      // Hierarchy Graphic
      Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            children: [
            // Top pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF5C5CFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.apartment_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(widget.orgName, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // Vertical line
            Container(width: 1, height: 16, color: const Color(0xFFE5E7EB)),
            // Horizontal line
            Container(
              height: 1,
              width: 220,
              color: const Color(0xFFE5E7EB),
            ),
            // 4 vertical lines connecting the horizontal line to the chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 1, height: 12, color: const Color(0xFFE5E7EB)),
                const SizedBox(width: 65),
                Container(width: 1, height: 12, color: const Color(0xFFE5E7EB)),
                const SizedBox(width: 65),
                Container(width: 1, height: 12, color: const Color(0xFFE5E7EB)),
                const SizedBox(width: 65),
                Container(width: 1, height: 12, color: const Color(0xFFE5E7EB)),
              ],
            ),
            // 4 Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _deptChip('Technology', const Color(0xFFE8E9FB), AppTheme.primary),
                const SizedBox(width: 6),
                _deptChip('HR', const Color(0xFFDFF0FF), const Color(0xFF23A6F0)),
                const SizedBox(width: 6),
                _deptChip('Sales', const Color(0xFFDFF7EA), const Color(0xFF22C55E)),
                const SizedBox(width: 6),
                _deptChip('Finance', const Color(0xFFF3E8FF), const Color(0xFF8B5CF6)),
              ],
            ),
            const SizedBox(height: 16),
            // Bottom small chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _smallOutlineChip('Eng'),
                const SizedBox(width: 8),
                _smallOutlineChip('Product'),
                const SizedBox(width: 8),
                _smallOutlineChip('Design'),
              ],
            ),
          ],
        ),
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Organize Your Teams',
        style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.2),
      ),
      const SizedBox(height: 8),
      const Text(
        'Create departments to structure employees, managers, reporting lines, attendance, and approvals.',
        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
      ),
      const SizedBox(height: 20),
      // Features list
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.apartment_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  const Text('Why set up departments?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _featureItem('Employee Organization', 'Group employees into structured teams'),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _featureItem('Reporting Structure', 'Define clear reporting hierarchies'),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _featureItem('Department Announcements', 'Target announcements by department'),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _featureItem('Attendance Tracking', 'Track attendance per department'),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _featureItem('Leave Approvals', 'Route approvals through department heads'),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Spacer(),
      _primaryBtn('Create Departments', () => setState(() => _step = 1)),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () {
            // Skip â†’ navigate to main app directly
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => OrganizationConfigurationScreen(
                  orgId: widget.orgId,
                  orgName: widget.orgName,
                ),
              ),
              (route) => false,
            );
          },
          child: const Text(
            'Skip for Now',
            style: TextStyle(
                fontSize: 15, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    ]));
  }

  // â”€â”€ Step 1: Department List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildListStep() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _goBack,
                    child: const Icon(Icons.arrow_back, color: AppTheme.textPrimary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Departments',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const Spacer(),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: Color(0xFFE8E9FB), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${_departments.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Start by creating departments for your organization.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        // Quick-add chips
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            children: [
              const Text(
                'Quick add:',
                style: TextStyle(fontSize: 13, color: AppTheme.textHint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickSelectNames
                        .where((n) => !_departments.any((d) => d.name.toLowerCase() == n.toLowerCase()))
                        .map((name) => GestureDetector(
                              onTap: () {
                                _openAddForm();
                                _applyQuickSelect(name);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('+ ', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                                    Text(name,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Department list
        Expanded(
          child: _departments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_outlined,
                          size: 48, color: Color.fromRGBO(156, 163, 175, 0.4)),
                      const SizedBox(height: 12),
                      const Text(
                        'No departments yet',
                        style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap "+ Add Department" to create one',
                        style: TextStyle(fontSize: 12, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: _departments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _deptListTile(_departments[i]),
                ),
        ),
        // Bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
          ),
          child: Column(
            children: [
              OutlinedButton.icon(
                onPressed: () => _openAddForm(),
                icon: const Icon(Icons.people_outline_rounded, size: 20),
                label: const Text('Add Department', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              _primaryBtn(
                'Continue',
                _departments.isEmpty ? null : () => setState(() => _step = 3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _deptListTile(_DeptModel dept) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: dept.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              dept.initials,
              style: TextStyle(
                  color: dept.color, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dept.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '0 Employees Â· No Head',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _openAddForm(existing: dept),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _deleteDepartment(dept),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                border: Border.all(color: const Color(0xFFFECACA)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Step 2: Add / Edit Department â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildAddEditStep() {
    final isEdit = _editingDept != null;
    return _padded(_scrollable(children: [
      // Quick select chips
      _sectionLabel('QUICK SELECT'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _quickSelectNames
            .map((name) => GestureDetector(
                  onTap: () {
                    setState(() => _applyQuickSelect(name));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _nameCtrl.text.trim().toLowerCase() == name.toLowerCase()
                          ? const Color(0xFFE8E9FB)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _nameCtrl.text.trim().toLowerCase() == name.toLowerCase()
                            ? AppTheme.primary
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _nameCtrl.text.trim().toLowerCase() == name.toLowerCase()
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
      const SizedBox(height: 20),
      _sectionLabel('DEPARTMENT DETAILS'),
      const SizedBox(height: 12),
      // Name
      TextField(
        controller: _nameCtrl,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Department Name *',
          prefixIcon: Icon(Icons.apartment_rounded, size: 20, color: AppTheme.textHint),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      const SizedBox(height: 12),
      // Code + Location row
      Row(children: [
        Expanded(
          child: TextField(
            controller: _codeCtrl,
            decoration: const InputDecoration(
              labelText: 'Dept Code *',
              prefixIcon: Icon(Icons.tag_rounded, size: 20, color: AppTheme.textHint),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Location',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20, color: AppTheme.textHint),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      // Description
      TextField(
        controller: _descCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Description',
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: 40),
            child: Icon(Icons.description_outlined, size: 20, color: AppTheme.textHint),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      const SizedBox(height: 20),
      _sectionLabel('STRUCTURE'),
      const SizedBox(height: 12),
      // Parent department
      DropdownButtonFormField<String?>(
        isExpanded: true,
        value: _parentId,
        onChanged: (v) => setState(() => _parentId = v),
        decoration: const InputDecoration(
          labelText: 'Parent Department',
          prefixIcon: Icon(Icons.account_tree_outlined, size: 20, color: AppTheme.textHint),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('None (Root Level)', style: TextStyle(fontSize: 14)),
          ),
          ..._departments
              .where((d) => d.id != _editingDept?.id)
              .map((d) => DropdownMenuItem<String?>(
                    value: d.id,
                    child: Text(d.name, style: const TextStyle(fontSize: 14)),
                  )),
        ],
      ),
      const SizedBox(height: 12),
      // Department Head
      DropdownButtonFormField<String?>(
        isExpanded: true,
        value: null,
        onChanged: (_) {},
        decoration: const InputDecoration(
          labelText: 'Department Head',
          prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: AppTheme.textHint),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        items: const [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('Not Assigned', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
      const SizedBox(height: 20),
      // Active toggle
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.toggle_on_outlined, size: 20, color: AppTheme.textHint),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Department Status',
                  style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
            ),
            Switch(
              value: _deptIsActive,
              activeThumbColor: AppTheme.primary,
              onChanged: (v) => setState(() => _deptIsActive = v),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 14, color: _deptIsActive ? const Color(0xFF22C55E) : AppTheme.textHint),
          const SizedBox(width: 6),
          Text(
            _deptIsActive
                ? 'Department will be active and visible'
                : 'Department will be hidden from employees',
            style: TextStyle(
                fontSize: 11,
                color: _deptIsActive ? const Color(0xFF22C55E) : AppTheme.textHint),
          ),
        ],
      ),
      const Spacer(),
      _primaryBtn(
        isEdit ? 'Update Department' : 'Save Department',
        (_nameCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty)
            ? null
            : _saveDepartment,
      ),
      const SizedBox(height: 10),
      _secondaryBtn('Cancel', () => setState(() => _step = 1)),
    ]));
  }

  // â”€â”€ Step 3: Review â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildReviewStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Review the department structure before finalizing.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _statChip('${_departments.length}', 'Departments', AppTheme.primary),
                  const SizedBox(width: 10),
                  _statChip('$_subDeptCount', 'Sub-depts', AppTheme.primary),
                  const SizedBox(width: 10),
                  _statChip('0', 'Employees', AppTheme.primary),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _departments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _reviewDeptCard(_departments[i]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            children: [
              // Add another dept
              OutlinedButton.icon(
                onPressed: () {
                  _step = 1;
                  _openAddForm();
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Another Department',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              _primaryBtn(
                _isFinalizing ? 'Savingâ€¦' : 'Finalize Structure',
                _isFinalizing ? null : _finalizeDepartments,
              ),
              const SizedBox(height: 10),
              _secondaryBtn('Back', _goBack),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewDeptCard(_DeptModel dept) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: dept.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(dept.initials,
                    style: TextStyle(
                        color: dept.color, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dept.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    Text(
                      '3 sub-departments',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _openAddForm(existing: dept),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 12),
                    SizedBox(width: 4),
                    Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => setState(() => _departments.remove(dept)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppTheme.danger,
                  side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, size: 12),
                    SizedBox(width: 4),
                    Text('Del', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _reviewInfoRow('Department Head', 'Not Assigned'),
          _reviewInfoRow('Parent', dept.parentName ?? 'Organization (Root)'),
          _reviewInfoRow('Employees', '0'),
        ],
      ),
    );
  }

  Widget _reviewInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // â”€â”€ Step 4: Success â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSuccessStep() {
    return _padded(_scrollable(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const Spacer(),
      // Icon
      SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.domain_rounded, color: Color(0xFF16A34A), size: 38),
            ),
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Departments Created\nSuccessfully',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.2),
      ),
      const SizedBox(height: 8),
      const Text(
        'Your organization structure is ready. Next, configure policies, shifts, and attendance settings.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5),
      ),
      const SizedBox(height: 24),
      // Departments created list
      Container(
        width: double.infinity,
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
                const Text(
                  'Departments Created',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF0F1FF), borderRadius: BorderRadius.circular(10)),
                  child: Text('${_departments.length}', style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ..._departments.map((d) => Column(
                  children: [
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF22C55E)),
                          const SizedBox(width: 12),
                          Text(d.name,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const Spacer(),
                          const Text('0 Employees', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                        ],
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // Setup progress
      Container(
        width: double.infinity,
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
                const Text('Setup Progress',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const Spacer(),
                const Text('3 of 6 complete', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _progressItem(true, false, 'Organization Created'),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _progressItem(true, false, 'Administrator Created'),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _progressItem(true, false, 'Departments Created'),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            _progressItem(false, false, 'Holidays Setup'),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _progressItem(false, false, 'Shift Setup'),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _progressItem(false, false, 'Policies Setup'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // Next step banner
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.all(Radius.circular(8))),
              child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next: Employee Setup',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Configure holidays, shifts, and policies',
                      style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
          ],
        ),
      ),
      const Spacer(),
      _primaryBtn(
        'Continue to Configuration',
        () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => OrganizationConfigurationScreen(
              orgId: widget.orgId,
              orgName: widget.orgName,
            ),
          ),
          (route) => false,
        ),
      ),
    ]));
  }

  // â”€â”€ Shared Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _padded(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: child);

  Widget _scrollable({
    required List<Widget> children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return LayoutBuilder(
      builder: (ctx, constraints) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
          ),
        ),
      ),
    );
  }

  Widget _breadcrumb(List<String> steps, int activeIndex) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: steps.asMap().entries.map((e) {
        final isActive = e.key == activeIndex;
        final isPast = e.key < activeIndex;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e.value,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppTheme.primary : (isPast ? AppTheme.textPrimary : AppTheme.textHint),
                fontWeight: isActive ? FontWeight.w700 : (isPast ? FontWeight.w600 : FontWeight.w500),
              ),
            ),
            if (e.key != steps.length - 1) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 12, color: AppTheme.textHint),
              const SizedBox(width: 4),
            ],
          ],
        );
      }).toList(),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        color: AppTheme.textHint,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _featureItem(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF22C55E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deptChip(String label, Color bgColor, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: dotColor)),
        ],
      ),
    );
  }

  Widget _smallOutlineChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    );
  }

  Widget _statChip(String value, String label, Color numColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: numColor)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _progressItem(bool done, bool isNext, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: done ? const Color(0xFF22C55E) : const Color(0xFFE5E7EB),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: done || isNext ? AppTheme.textPrimary : AppTheme.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isNext)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('NEXT',
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _primaryBtn(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB0B2FF),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _secondaryBtn(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
