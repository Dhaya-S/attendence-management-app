import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/message_helper.dart';
import 'package:attendance_app/features/manager_main_screen.dart';
import 'package:attendance_app/screens/admin_dashboard_screen.dart';
import 'package:attendance_app/screens/workspace_ready_screen.dart';
import 'package:intl/intl.dart';

// â”€â”€ Models â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HolidayModel {
  String id;
  String name;
  DateTime date;
  String type; // 'National' or 'Company'

  _HolidayModel({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
  });
}

class _ShiftModel {
  String id;
  String name;
  TimeOfDay startTime;
  TimeOfDay endTime;
  int breakDurationMins;
  String appliesTo;
  Color color;

  _ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.breakDurationMins,
    required this.appliesTo,
    this.color = AppTheme.primary,
  });
}

class _LeaveModel {
  String id;
  String name;
  String initials;
  Color color;
  int allocationDays;
  bool approvalRequired;
  bool carryForward;
  bool attachmentRequired;

  _LeaveModel({
    required this.id,
    required this.name,
    required this.initials,
    required this.color,
    required this.allocationDays,
    required this.approvalRequired,
    required this.carryForward,
    required this.attachmentRequired,
  });
}

class _NotificationModel {
  String id;
  String name;
  bool emailEnabled;
  bool pushEnabled;

  _NotificationModel({
    required this.id,
    required this.name,
    required this.emailEnabled,
    required this.pushEnabled,
  });
}

class _AttendancePolicy {
  TimeOfDay shiftStart;
  int gracePeriodMins;
  TimeOfDay lateMarkAfter;
  TimeOfDay halfDayAfter;
  bool overtimeEnabled;
  bool geofenceEnabled;
  bool wfhEnabled;

  _AttendancePolicy({
    required this.shiftStart,
    required this.gracePeriodMins,
    required this.lateMarkAfter,
    required this.halfDayAfter,
    required this.overtimeEnabled,
    required this.geofenceEnabled,
    required this.wfhEnabled,
  });
}

// â”€â”€ Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class OrganizationConfigurationScreen extends StatefulWidget {
  final String orgId;
  final String orgName;

  const OrganizationConfigurationScreen({
    Key? key,
    required this.orgId,
    required this.orgName,
  }) : super(key: key);

  @override
  State<OrganizationConfigurationScreen> createState() =>
      _OrganizationConfigurationScreenState();
}

class _OrganizationConfigurationScreenState
    extends State<OrganizationConfigurationScreen> {
  int _step = 0;
  bool _isSaving = false;

  // Data Holders
  final List<_HolidayModel> _holidays = [];
  final List<_ShiftModel> _shifts = [];
  final List<_LeaveModel> _leaveTypes = [];
  final List<_NotificationModel> _notifications = [];
  late _AttendancePolicy _attendancePolicy;

  // Shift form state
  final _shiftNameCtrl = TextEditingController();
  TimeOfDay? _newShiftStart;
  TimeOfDay? _newShiftEnd;
  String _newShiftAppliesTo = 'Organization';

  // Holiday form state
  final _holidayNameCtrl = TextEditingController();
  DateTime? _newHolidayDate;
  String _newHolidayType = 'National Holiday';

  // Leave form state
  String? _expandedLeaveId = 'sl'; // Default expanded for UI

  // ... (rest of the file to be implemented incrementally)

  @override
  void initState() {
    super.initState();
    // Default config
    _attendancePolicy = _AttendancePolicy(
      shiftStart: const TimeOfDay(hour: 9, minute: 0),
      gracePeriodMins: 15,
      lateMarkAfter: const TimeOfDay(hour: 9, minute: 15),
      halfDayAfter: const TimeOfDay(hour: 11, minute: 0),
      overtimeEnabled: true,
      geofenceEnabled: false,
      wfhEnabled: true,
    );

    _notifications.addAll([
      _NotificationModel(id: 'att_rem', name: 'Attendance Reminder', emailEnabled: true, pushEnabled: true),
      _NotificationModel(id: 'late_alert', name: 'Late Check-In Alert', emailEnabled: true, pushEnabled: true),
      _NotificationModel(id: 'leave_req', name: 'Leave Approval Alert', emailEnabled: true, pushEnabled: true),
      _NotificationModel(id: 'leave_upd', name: 'Leave Balance Update', emailEnabled: true, pushEnabled: false),
      _NotificationModel(id: 'app_not', name: 'Approval Notification', emailEnabled: true, pushEnabled: true),
      _NotificationModel(id: 'bday_rem', name: 'Birthday Reminder', emailEnabled: false, pushEnabled: false),
      _NotificationModel(id: 'ann_alert', name: 'Announcement Alert', emailEnabled: true, pushEnabled: true),
      _NotificationModel(id: 'org_upd', name: 'Organization Updates', emailEnabled: true, pushEnabled: false),
    ]);

    _leaveTypes.addAll([
      _LeaveModel(id: 'cl', name: 'Casual Leave', initials: 'CL', color: const Color(0xFF6B7280), allocationDays: 12, approvalRequired: true, carryForward: true, attachmentRequired: false),
      _LeaveModel(id: 'sl', name: 'Sick Leave', initials: 'SL', color: const Color(0xFF5C5CFF), allocationDays: 12, approvalRequired: true, carryForward: true, attachmentRequired: true),
      _LeaveModel(id: 'el', name: 'Earned Leave', initials: 'EL', color: const Color(0xFF10B981), allocationDays: 15, approvalRequired: true, carryForward: true, attachmentRequired: false),
      _LeaveModel(id: 'lop', name: 'Loss of Pay', initials: 'LOP', color: const Color(0xFFEF4444), allocationDays: 0, approvalRequired: true, carryForward: false, attachmentRequired: true),
    ]);
  }

  @override
  void dispose() {
    _shiftNameCtrl.dispose();
    _holidayNameCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  String _stepTitle() {
    switch (_step) {
      case 1:
        return 'Holiday Setup';
      case 2:
        return 'Shift Management';
      case 3:
        return 'Attendance Policy';
      case 4:
        return 'Leave Policy';
      case 5:
        return 'Notifications';
      case 6:
        return 'Review Configuration';
      default:
        return '';
    }
  }

  Widget _padded(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      );

  Widget _scrollable({
    required List<Widget> children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) =>
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                children: children,
              ),
            ),
          ),
        ),
      );

  Widget _primaryBtn(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          disabledBackgroundColor: const Color(0xFFD0D5DD),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _secondaryBtn(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _statBox(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _configStepItem(String title, String subtitle, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStep() {
    return Column(
      children: [
        Expanded(
          child: _scrollable(
            children: [
              _padded(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF0F1FF), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.settings_outlined, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SYSTEM-06', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w700, letterSpacing: 1)),
                            Text('Organization Configuration', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: const [
                        Text('Org > Admin > Depts > ', style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                        Text('Config', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Stats
                    Row(
                      children: [
                        _statBox('24', 'Holidays', Icons.calendar_today_rounded, const Color(0xFF8B5CF6)),
                        const SizedBox(width: 12),
                        _statBox('3', 'Shifts', Icons.access_time_rounded, const Color(0xFF3B82F6)),
                        const SizedBox(width: 12),
                        _statBox('â€”', 'Policies', Icons.assignment_outlined, const Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Progress Bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SETUP PROGRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textHint, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              value: 0.1,
                              minHeight: 6,
                              backgroundColor: Color(0xFFF3F4F6),
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Configuration', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                              Text('5 steps remaining', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text('Configure Your Organization', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    const Text('Set up holidays, shifts, attendance rules, and leave policies before going live.', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
                    const SizedBox(height: 24),
                    // Steps List
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.settings_suggest_outlined, size: 18, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Text('Configuration Steps', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _configStepItem('Holiday Setup', 'Add national and company holidays', Icons.calendar_month_outlined, const Color(0xFF8B5CF6)),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _configStepItem('Shift Setup', 'Define work schedules', Icons.schedule_outlined, const Color(0xFF3B82F6)),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _configStepItem('Attendance Policy', 'Grace periods, late marks, OT rules', Icons.assignment_turned_in_outlined, const Color(0xFF8B5CF6)),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _configStepItem('Leave Policy', 'Leave types and allocation', Icons.description_outlined, const Color(0xFF3B82F6)),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _configStepItem('Notifications', 'Alerts and communication preferences', Icons.people_outline, const Color(0xFF8B5CF6)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
        _padded(
          Column(
            children: [
              const SizedBox(height: 16),
              _primaryBtn('Start Configuration', () => setState(() => _step = 1)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallStatBox(String value, String label, Color color) {
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
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidayStep() {
    return Column(
      children: [
        Expanded(
          child: _scrollable(
            children: [
              _padded(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text('Add organization holidays that apply across attendance and leave tracking.',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _smallStatBox('${_holidays.length}', 'Total', AppTheme.primary),
                        const SizedBox(width: 12),
                        _smallStatBox('${_holidays.where((h) => h.type == 'National').length}', 'National', const Color(0xFF3B82F6)),
                        const SizedBox(width: 12),
                        _smallStatBox('${_holidays.where((h) => h.type == 'Company').length}', 'Company', const Color(0xFF8B5CF6)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Holidays List
                    ..._holidays.map((h) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: const Color(0xFFF0F1FF), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.calendar_today_rounded, color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(h.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 4),
                                    Text(DateFormat('dd MMM yyyy').format(h.date), style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: h.type == 'National' ? const Color(0xFFEBF5FF) : const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(h.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: h.type == 'National' ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6))),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => setState(() => _holidays.remove(h)),
                                    child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textHint),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )),
                    // Add form
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDDE0FF), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Add Holiday', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                          const SizedBox(height: 16),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _holidayNameCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Holiday Name',
                                hintStyle: TextStyle(fontSize: 14, color: AppTheme.textHint),
                                prefixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.textHint),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _newHolidayDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (date != null) setState(() => _newHolidayDate = date);
                              },
                              child: Container(
                                color: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.textHint),
                                    const SizedBox(width: 12),
                                    Text(
                                      _newHolidayDate != null ? DateFormat('dd MMM yyyy').format(_newHolidayDate!) : 'Date',
                                      style: TextStyle(fontSize: 14, color: _newHolidayDate != null ? AppTheme.textPrimary : AppTheme.textHint),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _newHolidayType,
                                items: ['National Holiday', 'Company Holiday']
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary))))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _newHolidayType = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_holidayNameCtrl.text.trim().isEmpty || _newHolidayDate == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all holiday details')));
                                      return;
                                    }
                                    setState(() {
                                      _holidays.add(_HolidayModel(
                                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                                        name: _holidayNameCtrl.text.trim(),
                                        date: _newHolidayDate!,
                                        type: _newHolidayType == 'National Holiday' ? 'National' : 'Company',
                                      ));
                                      _holidayNameCtrl.clear();
                                      _newHolidayDate = null;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                    minimumSize: const Size(0, 44),
                                  ),
                                  child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _holidayNameCtrl.clear();
                                      _newHolidayDate = null;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.textPrimary,
                                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    minimumSize: const Size(0, 44),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
        _padded(
          Column(
            children: [
              const SizedBox(height: 16),
              _primaryBtn('Continue', () => setState(() => _step = 2)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => setState(() => _step = 2),
                  child: const Text('Skip', style: TextStyle(fontSize: 15, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShiftStep() {
    return Column(
      children: [
        Expanded(
          child: _scrollable(
            children: [
              _padded(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text('Define working schedules for employees.',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
                    const SizedBox(height: 24),
                    // Shifts List
                    ..._shifts.map((s) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: s.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                    child: Icon(Icons.access_time_rounded, color: s.color, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                        const SizedBox(height: 4),
                                        Text('${s.startTime.format(context)} â€“ ${s.endTime.format(context)}', style: TextStyle(fontSize: 12, color: s.color, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {}, // Edit
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                                          child: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textSecondary),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => setState(() => _shifts.remove(s)),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), border: Border.all(color: const Color(0xFFFECACA)), borderRadius: BorderRadius.circular(8)),
                                          child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.danger),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Color(0xFFF3F4F6)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Break', style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                                      Text('${s.breakDurationMins} min', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Applies To', style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                                      Text(s.appliesTo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    ],
                                  ),
                                  const SizedBox(width: 40), // Spacer equivalent
                                ],
                              )
                            ],
                          ),
                        )),
                    // Add form
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDDE0FF), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Add Shift', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                          const SizedBox(height: 16),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _shiftNameCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Shift Name',
                                hintStyle: TextStyle(fontSize: 14, color: AppTheme.textHint),
                                prefixIcon: Icon(Icons.access_time_rounded, size: 18, color: AppTheme.textHint),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(12)),
                                  child: GestureDetector(
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: _newShiftStart ?? const TimeOfDay(hour: 9, minute: 0),
                                      );
                                      if (time != null) setState(() => _newShiftStart = time);
                                    },
                                    child: Container(
                                      color: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 18, color: AppTheme.textHint),
                                          const SizedBox(width: 12),
                                          Text(
                                            _newShiftStart != null ? _newShiftStart!.format(context) : 'Start Time',
                                            style: TextStyle(fontSize: 14, color: _newShiftStart != null ? AppTheme.textPrimary : AppTheme.textHint),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(12)),
                                  child: GestureDetector(
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: _newShiftEnd ?? const TimeOfDay(hour: 18, minute: 0),
                                      );
                                      if (time != null) setState(() => _newShiftEnd = time);
                                    },
                                    child: Container(
                                      color: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 18, color: AppTheme.textHint),
                                          const SizedBox(width: 12),
                                          Text(
                                            _newShiftEnd != null ? _newShiftEnd!.format(context) : 'End Time',
                                            style: TextStyle(fontSize: 14, color: _newShiftEnd != null ? AppTheme.textPrimary : AppTheme.textHint),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Assign To', style: TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                height: 48,
                                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(12)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _newShiftAppliesTo,
                                    items: ['Organization', 'Specific Department']
                                        .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary))))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _newShiftAppliesTo = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_shiftNameCtrl.text.trim().isEmpty || _newShiftStart == null || _newShiftEnd == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all shift details')));
                                      return;
                                    }
                                    setState(() {
                                      _shifts.add(_ShiftModel(
                                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                                        name: _shiftNameCtrl.text.trim(),
                                        startTime: _newShiftStart!,
                                        endTime: _newShiftEnd!,
                                        breakDurationMins: 60,
                                        appliesTo: _newShiftAppliesTo,
                                      ));
                                      _shiftNameCtrl.clear();
                                      _newShiftStart = null;
                                      _newShiftEnd = null;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                    minimumSize: const Size(0, 44),
                                  ),
                                  child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _shiftNameCtrl.clear();
                                      _newShiftStart = null;
                                      _newShiftEnd = null;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.textPrimary,
                                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    minimumSize: const Size(0, 44),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
        _padded(
          Column(
            children: [
              const SizedBox(height: 16),
              _primaryBtn('Continue', () {
                if (_shifts.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one shift')));
                  return;
                }
                setState(() => _step = 3);
              }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gracePill(String text, bool isSelected, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F1FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primary : const Color(0xFFE5E7EB)),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? AppTheme.primary : AppTheme.textHint)),
      ),
    );
  }

  Widget _policyRow(String title, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          trailing,
        ],
      ),
    );
  }

  Widget _toggleRow(String title, String subtitle, bool value, {Function(bool)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary)),
    );
  }

  String _calculateHalfDayStr() {
    if (_shifts.isEmpty) return "4.5 Hours";
    
    double totalHours = 0;
    for (final s in _shifts) {
      double start = s.startTime.hour + s.startTime.minute / 60.0;
      double end = s.endTime.hour + s.endTime.minute / 60.0;
      if (end < start) end += 24; // Cross midnight
      totalHours += (end - start);
    }
    double avgHours = totalHours / _shifts.length;
    double halfDay = avgHours / 2;
    
    if (halfDay == halfDay.toInt()) {
      return "${halfDay.toInt()} Hours";
    } else {
      return "${halfDay.toStringAsFixed(1)} Hours";
    }
  }

  Widget _buildAttendanceStep() {
    return Column(
      children: [
        Expanded(
          child: _scrollable(
            children: [
              _padded(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Check-in Rules Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: const Color(0xFFF0F1FF), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 12),
                              const Text('Check-In Rules', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          const SizedBox(height: 8),
                          _policyRow(
                            'Shift Start',
                            Text(
                              _shifts.isEmpty ? 'Not Set' : (_shifts.length == 1 ? _shifts.first.name : 'All Shift'),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Grace Period', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _gracePill('No Grace', _attendancePolicy.gracePeriodMins == 0, onTap: () => setState(() => _attendancePolicy.gracePeriodMins = 0)),
                              _gracePill('5 Minutes', _attendancePolicy.gracePeriodMins == 5, onTap: () => setState(() => _attendancePolicy.gracePeriodMins = 5)),
                              _gracePill('10 Minutes', _attendancePolicy.gracePeriodMins == 10, onTap: () => setState(() => _attendancePolicy.gracePeriodMins = 10)),
                              _gracePill('15 Minutes', _attendancePolicy.gracePeriodMins == 15, onTap: () => setState(() => _attendancePolicy.gracePeriodMins = 15)),
                              _gracePill('30 Minutes', _attendancePolicy.gracePeriodMins == 30, onTap: () => setState(() => _attendancePolicy.gracePeriodMins = 30)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _policyRow(
                            'Late Mark After',
                            Text(
                              _attendancePolicy.gracePeriodMins == 0 ? 'No Grace' : '${_attendancePolicy.gracePeriodMins} Minutes',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)
                            ),
                          ),
                          _policyRow(
                            'Half Day After',
                            Text(
                              _calculateHalfDayStr(),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Overtime & Location
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: const Color(0xFFF0F1FF), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.badge_outlined, size: 16, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 12),
                              const Text('Overtime & Work Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _toggleRow(
                            'Overtime Eligibility',
                            'Allow overtime after shift hours',
                            _attendancePolicy.overtimeEnabled,
                            onChanged: (v) => setState(() => _attendancePolicy.overtimeEnabled = v),
                          ),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _toggleRow(
                            'Geofence Attendance',
                            'Restrict check-in to location radius',
                            _attendancePolicy.geofenceEnabled,
                            onChanged: (v) => setState(() => _attendancePolicy.geofenceEnabled = v),
                          ),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _toggleRow(
                            'Work From Home',
                            'Enable WFH attendance mode',
                            _attendancePolicy.wfhEnabled,
                            onChanged: (v) => setState(() => _attendancePolicy.wfhEnabled = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Summary row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _summaryPill('Grace: ${_attendancePolicy.gracePeriodMins} Minutes'),
                        _summaryPill('OT: ${_attendancePolicy.overtimeEnabled ? 'On' : 'Off'}'),
                        _summaryPill('Geo: ${_attendancePolicy.geofenceEnabled ? 'On' : 'Off'}'),
                        _summaryPill('WFH: ${_attendancePolicy.wfhEnabled ? 'On' : 'Off'}'),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
        _padded(
          Column(
            children: [
              const SizedBox(height: 16),
              _primaryBtn('Save & Continue', () => setState(() => _step = 4)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _leavePill(String text, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF0F1FF) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive ? AppTheme.primary : AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _leaveTypeCard(_LeaveModel leave, bool isExpanded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? AppTheme.primary : const Color(0xFFE5E7EB)),
        boxShadow: isExpanded ? const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))] : null,
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                if (_expandedLeaveId == leave.id) {
                  _expandedLeaveId = null;
                } else {
                  _expandedLeaveId = leave.id;
                }
              });
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isExpanded ? AppTheme.primary.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(leave.initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isExpanded ? AppTheme.primary : AppTheme.textPrimary)),
            ),
            title: Text(leave.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            subtitle: Text(leave.allocationDays == 0 ? 'Unlimited' : '${leave.allocationDays} Days / Year', style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
            trailing: Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: isExpanded ? AppTheme.primary : AppTheme.textHint),
          ),
          if (!isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(76, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _leavePill('Approval Required', leave.approvalRequired),
                      _leavePill('Carry Forward', leave.carryForward),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _leavePill('Attachment Required', leave.attachmentRequired),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) {
                      List<String> activeRules = [];
                      if (leave.approvalRequired) activeRules.add('Approval Required');
                      if (leave.carryForward) activeRules.add('Carry Forward');
                      else activeRules.add('No Carry Forward');
                      if (leave.attachmentRequired) activeRules.add('Attachment Required');
                      return Text(activeRules.join(' Â· '), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary));
                    }
                  ),
                ],
              ),
            ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 16),
                  const Text('ANNUAL ALLOCATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            IconButton(onPressed: () {
                              if (leave.allocationDays > 0) {
                                setState(() => leave.allocationDays--);
                              }
                            }, icon: const Icon(Icons.remove, size: 16, color: AppTheme.textPrimary), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 40, minHeight: 40)),
                            Container(width: 40, alignment: Alignment.center, child: Text('${leave.allocationDays}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                            IconButton(onPressed: () {
                              setState(() => leave.allocationDays++);
                            }, icon: const Icon(Icons.add, size: 16, color: AppTheme.textPrimary), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 40, minHeight: 40)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('days / year', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('POLICY RULES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        _toggleRow('Approval Required', 'Manager must approve before leave is granted', leave.approvalRequired, onChanged: (v) => setState(() => leave.approvalRequired = v)),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _toggleRow('Carry Forward', 'Unused days carry over to next year', leave.carryForward, onChanged: (v) => setState(() => leave.carryForward = v)),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _toggleRow('Attachment Required', 'Supporting document needed on request', leave.attachmentRequired, onChanged: (v) => setState(() => leave.attachmentRequired = v)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeaveStep() {
    return Column(
      children: [
        Expanded(
          child: _scrollable(
            children: [
              _padded(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text('Configure leave types and annual allocation for your organization.',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
                    const SizedBox(height: 24),
                    // Leave List
                    ..._leaveTypes.map((l) => _leaveTypeCard(l, l.id == _expandedLeaveId)),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
        _padded(
          Column(
            children: [
              const SizedBox(height: 16),
              _primaryBtn('Save & Continue', () => setState(() => _step = 5)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _customCheckbox(bool value) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: value ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: value ? AppTheme.primary : const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: value ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
    );
  }

  Widget _buildNotificationStep() {
    return Column(
      children: [
        Expanded(
          child: _scrollable(
            children: [
              _padded(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Expanded(flex: 3, child: Text('NOTIFICATION TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textHint, letterSpacing: 1))),
                        Expanded(flex: 1, child: Center(child: Text('Email', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textHint, letterSpacing: 1)))),
                        Expanded(flex: 1, child: Center(child: Text('Push', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textHint, letterSpacing: 1)))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._notifications.map((n) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(n.name, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500))),
                              Expanded(flex: 1, child: Center(child: GestureDetector(onTap: () => setState(() => n.emailEnabled = !n.emailEnabled), child: _customCheckbox(n.emailEnabled)))),
                              Expanded(flex: 1, child: Center(child: GestureDetector(onTap: () => setState(() => n.pushEnabled = !n.pushEnabled), child: _customCheckbox(n.pushEnabled)))),
                            ],
                          ),
                        )),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
        _padded(
          Column(
            children: [
              const SizedBox(height: 16),
              _primaryBtn('Continue', () => setState(() => _step = 6)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewItem(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF0F1FF), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFFF0F1FF), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      children: [
        Expanded(
          child: _scrollable(
            children: [
              _padded(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text('Verify everything before launching your workspace.',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
                    const SizedBox(height: 24),
                    // Success Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('All sections configured', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                SizedBox(height: 2),
                                Text('Organization is ready to launch', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
                              ],
                            ),
                          ),
                          const Text('100%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Review Items
                    _reviewItem('Organization', widget.orgName, Icons.business_outlined),
                    _reviewItem('Holidays', '${_holidays.length} holidays configured', Icons.calendar_today_rounded),
                    _reviewItem('Shifts', '${_shifts.length} shifts - ${_shifts.map((s) => s.name).join(', ')}', Icons.access_time_rounded),
                    _reviewItem('Attendance Policy', 'Grace: ${_attendancePolicy.gracePeriodMins} min Â· Late mark: ${_attendancePolicy.lateMarkAfter.format(context)}', Icons.assignment_turned_in_outlined),
                    _reviewItem('Leave Policy', _leaveTypes.map((l) => l.initials).join(' Â· '), Icons.description_outlined),
                    _reviewItem('Notifications', '${_notifications.where((n) => n.emailEnabled || n.pushEnabled).length} alerts active', Icons.notifications_outlined),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
        _padded(
          Column(
            children: [
              const SizedBox(height: 16),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : _primaryBtn('Launch Workspace', _launchWorkspace),
              const SizedBox(height: 12),
              if (!_isSaving)
                _secondaryBtn('Back', _goBack),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchWorkspace() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = FieldValue.serverTimestamp();

      // 1. Save Holidays
      for (final h in _holidays) {
        final ref = FirestoreService.orgHolidaysCol(widget.orgId).doc(h.id);
        batch.set(ref, {
          'id': h.id,
          'name': h.name,
          'date': Timestamp.fromDate(h.date),
          'type': h.type,
          'createdAt': now,
        });
      }

      // 2. Save Shifts
      for (final s in _shifts) {
        final ref = FirestoreService.orgShiftsCol(widget.orgId).doc(s.id);
        batch.set(ref, {
          'id': s.id,
          'name': s.name,
          'startHour': s.startTime.hour,
          'startMinute': s.startTime.minute,
          'endHour': s.endTime.hour,
          'endMinute': s.endTime.minute,
          'breakDurationMins': s.breakDurationMins,
          'appliesTo': s.appliesTo,
          'createdAt': now,
        });
      }

      // 3. Save Attendance Policy
      final attRef = FirestoreService.orgPolicyDoc(widget.orgId, 'attendance');
      batch.set(attRef, {
        'shiftStartHour': _attendancePolicy.shiftStart.hour,
        'shiftStartMinute': _attendancePolicy.shiftStart.minute,
        'gracePeriodMins': _attendancePolicy.gracePeriodMins,
        'lateMarkAfterHour': _attendancePolicy.lateMarkAfter.hour,
        'lateMarkAfterMinute': _attendancePolicy.lateMarkAfter.minute,
        'halfDayAfterHour': _attendancePolicy.halfDayAfter.hour,
        'halfDayAfterMinute': _attendancePolicy.halfDayAfter.minute,
        'overtimeEnabled': _attendancePolicy.overtimeEnabled,
        'geofenceEnabled': _attendancePolicy.geofenceEnabled,
        'wfhEnabled': _attendancePolicy.wfhEnabled,
        'updatedAt': now,
      });

      // 4. Save Leave Types (Policies)
      for (final l in _leaveTypes) {
        final ref = FirestoreService.orgPolicyDoc(widget.orgId, 'leave_${l.id}');
        batch.set(ref, {
          'id': l.id,
          'name': l.name,
          'initials': l.initials,
          'colorValue': l.color.value,
          'allocationDays': l.allocationDays,
          'approvalRequired': l.approvalRequired,
          'carryForward': l.carryForward,
          'attachmentRequired': l.attachmentRequired,
          'updatedAt': now,
        });
      }

      // 5. Save Notifications Settings
      for (final n in _notifications) {
        final ref = FirestoreService.orgPolicyDoc(widget.orgId, 'notify_${n.id}');
        batch.set(ref, {
          'id': n.id,
          'name': n.name,
          'emailEnabled': n.emailEnabled,
          'pushEnabled': n.pushEnabled,
          'updatedAt': now,
        });
      }

      // 6. Finalize Org setupStep
      final orgRef = FirestoreService.orgDoc(widget.orgId);
      batch.update(orgRef, {
        'setupStep': 'live', // Changed from 'complete' to 'live'
        'updatedAt': now,
      });

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      
      // Navigate to Workspace Ready screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WorkspaceReadyScreen(
            orgId: widget.orgId,
            orgName: widget.orgName,
          ),
        ),
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      MessageHelper.showError(context, 'Failed to launch workspace: $e');
    }
  }

  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: Colors.white,
      child: Row(
        children: List.generate(5, (index) {
          int stepNum = index + 1;
          bool isCompleted = _step > stepNum || _step == 6; // 6 is review step, so all 5 completed
          bool isCurrent = _step == stepNum;
          
          Widget circle;
          if (isCompleted) {
            circle = Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            );
          } else if (isCurrent) {
            circle = Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 1.5),
              ),
              child: Text('$stepNum', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            );
          } else {
            circle = Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
              ),
              child: Text('$stepNum', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textHint)),
            );
          }

          if (index == 4) return circle;
          
          bool lineActive = _step > stepNum || _step == 6;
          Widget line = Expanded(
            child: Container(
              height: 1.5,
              color: lineActive ? AppTheme.primary : const Color(0xFFE5E7EB),
            ),
          );

          return Expanded(
            child: Row(
              children: [
                circle,
                const SizedBox(width: 8),
                line,
                const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 0:
        return _buildOverviewStep();
      case 1:
        return _buildHolidayStep();
      case 2:
        return _buildShiftStep();
      case 3:
        return _buildAttendanceStep();
      case 4:
        return _buildLeaveStep();
      case 5:
        return _buildNotificationStep();
      case 6:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: _step > 0 && _step < 7
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppTheme.textPrimary, size: 24),
                onPressed: _goBack,
              ),
              title: _step > 0 && _step < 6 ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP $_step OF 5',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textHint,
                        letterSpacing: 1.0),
                  ),
                  Text(
                    _stepTitle(),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                ],
              ) : Text(
                _stepTitle(),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              centerTitle: false,
              actions: [
                if (_step > 0 && _step < 6)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.textHint),
                      ),
                    ),
                  )
              ],
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              if (_step > 0 && _step < 6) _buildStepper(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_step),
                    child: _buildBody(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
