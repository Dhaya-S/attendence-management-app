import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/screens/employee/apply_leave_screen.dart';

class UniversalLeaveTab extends StatefulWidget {
  const UniversalLeaveTab({super.key});

  @override
  State<UniversalLeaveTab> createState() => _UniversalLeaveTabState();
}

class _UniversalLeaveTabState extends State<UniversalLeaveTab> {
  int _selectedTopTab = 0; // 0: Overview, 1: Apply, 2: History, 3: Calendar, 4: Policy
  
  final user = FirebaseAuth.instance.currentUser;
  late Stream<QuerySnapshot> _leaveRequestsStream;
  late Stream<QuerySnapshot> _leaveTypesStream; // organization leave types (annual / sick / casual) – live
  late Stream<DocumentSnapshot> _orgDocStream; // organization leave policy – live
  late Stream<QuerySnapshot> _holidaysStream; // company holidays – live
  late Stream<QuerySnapshot> _policiesStream; // written company policies – live

  // Apply Form State
  String _selectedLeaveType = 'Casual Leave';
  String _leaveDuration = 'Full Day';
  DateTime _fromDate = DateTime.now().add(const Duration(days: 1));
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  // History Tab State
  int _selectedHistorySubTab = 0; // 0: All, 1: Pending, 2: Approved, 3: Rejected, 4: Cancelled

  // Calendar Tab State
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _leaveRequestsStream = FirestoreService.leaveRequestsCol.snapshots();
    _leaveTypesStream = FirestoreService.companyDoc().collection('leave_types').snapshots();
    _orgDocStream = FirestoreService.companyDoc().snapshots();
    _holidaysStream = FirestoreService.orgHolidaysCol(FirestoreService.companyId).snapshots();
    _policiesStream = FirestoreService.policiesCol.snapshots();
  }

  // ── Date / field helpers (leaves made on the web store from/to "yyyy-MM-dd" strings) ──
  DateTime? _leaveStart(Map data) =>
      FirestoreService.parseAnyDate(data['fromDate'] ?? data['from'] ?? data['startDate']);
  DateTime? _leaveEnd(Map data) =>
      FirestoreService.parseAnyDate(data['toDate'] ?? data['to'] ?? data['endDate']) ?? _leaveStart(data);
  String _leaveTypeName(Map data) =>
      (data['leaveType'] ?? data['type'] ?? data['category'] ?? 'Leave').toString();
  int _leaveDays(Map data) {
    final v = data['days'] ?? data['durationInDays'];
    if (v is num) return v.toInt();
    final p = int.tryParse((v ?? '').toString().replaceAll(RegExp(r'[^0-9]'), ''));
    if (p != null && p > 0) return p;
    final s = _leaveStart(data), e = _leaveEnd(data);
    if (s == null || e == null) return 1;
    return DateTime(e.year, e.month, e.day).difference(DateTime(s.year, s.month, s.day)).inDays + 1;
  }

  /// Yearly entitlement per type: organization leave types → leave policy → defaults.
  List<int> _leaveLimits(QuerySnapshot? types, Map<String, dynamic>? org) {
    int? asInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString().replaceAll(RegExp(r'[^0-9]'), ''));
    }

    int? fromTypes(String key) {
      for (final d in types?.docs ?? const <QueryDocumentSnapshot>[]) {
        final m = d.data() as Map<String, dynamic>;
        final id = d.id.toLowerCase();
        final name = (m['name'] ?? '').toString().toLowerCase();
        if (id == key || name.contains(key)) {
          final days = asInt(m['days']);
          if (days != null) return days;
        }
      }
      return null;
    }

    final policy = (org?['leavePolicy'] is Map) ? org!['leavePolicy'] as Map : const {};
    final annual = fromTypes('annual') ??
        asInt(policy['annualLeave']) ??
        (AppSession().paidLeavesPerYear > 0 ? AppSession().paidLeavesPerYear : 12);
    final sick = fromTypes('sick') ?? asInt(policy['sickLeave']) ?? 7;
    final casual = fromTypes('casual') ?? asInt(policy['casualLeave']) ?? 5;
    return [annual, sick, casual];
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submitLeave() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a reason')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final email = user?.email;
      final rawRole = (AppSession().role ?? 'employee').toLowerCase().trim();
      final senderRole = (rawRole == 'admin' ||
              rawRole == 'super_admin' ||
              rawRole == 'superadmin' ||
              rawRole == 'hr_admin' ||
              rawRole == 'hradmin')
          ? 'hr_admin'
          : rawRole == 'manager'
              ? 'manager'
              : 'employee';

      bool reqManager = senderRole == 'employee';
      bool reqAdmin = true;

      int calculateWorkingDays(DateTime from, DateTime to) {
        final start = DateTime(from.year, from.month, from.day);
        final end = DateTime(to.year, to.month, to.day);
        int count = 0;
        DateTime current = start;
        while (!current.isAfter(end)) {
          if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
            count++;
          }
          current = current.add(const Duration(days: 1));
        }
        return count;
      }

      int durationInDays = 1;
      if (_leaveDuration == 'Full Day') {
        durationInDays = calculateWorkingDays(_fromDate, _toDate);
      } else {
        durationInDays = 1;
      }

      final userMail = email ?? AppSession().email ?? '';
      final uName = AppSession().userName ?? userMail.split('@').first;
      await FirestoreService.submitLeaveRequest(data: {
        'companyId': FirestoreService.companyId,
        'userId': AppSession().uid,
        'email': userMail,
        'employeeEmail': userMail,
        'userEmail': userMail,
        'applicantEmail': userMail,
        'userName': uName,
        'applicantName': uName,
        'leaveType': _selectedLeaveType,
        'type': _selectedLeaveType,
        'duration': _leaveDuration,
        'durationInDays': durationInDays,
        'days': durationInDays,
        'fromDate': Timestamp.fromDate(_fromDate),
        'toDate': Timestamp.fromDate(_toDate),
        'from': DateFormat('yyyy-MM-dd').format(_fromDate),
        'to': DateFormat('yyyy-MM-dd').format(_toDate),
        'reason': _reasonController.text.trim(),
        'requestDate': Timestamp.now(),
        'status': 'Pending',
        'requiresManagerApproval': reqManager,
        'requiresAdminApproval': reqAdmin,
        'approverRemarks': '',
        'senderRole': senderRole,
        'targetRoles': (senderRole == 'hr_admin' || senderRole == 'manager')
            ? ['hr_admin']
            : ['manager', 'hr_admin'],
        'approver': (senderRole == 'hr_admin' || senderRole == 'manager')
            ? 'HR Admin'
            : 'Reporting Manager',
      });
      
      // Notify based on sender role
      final dateRangeStr = durationInDays == 1
          ? 'on ${DateFormat('MMM dd, yyyy').format(_fromDate)}'
          : 'from ${DateFormat('MMM dd').format(_fromDate)} to ${DateFormat('MMM dd').format(_toDate)}';
      final title = 'New Leave Request 📝';
      final body = '${AppSession().userName ?? "Employee"} applied for $_selectedLeaveType $dateRangeStr.';
      final extraData = {'employeeEmail': email};

      if (senderRole == 'hr_admin') {
        await NotificationHelper.notifyAdmin(
            title: title,
            body: body,
            type: 'new_leave_request',
            extraData: extraData);
      } else if (senderRole == 'manager') {
        await NotificationHelper.notifyAdmin(title: title, body: body, type: 'new_leave_request', extraData: extraData);
      } else {
        await NotificationHelper.notifyManager(title: title, body: body, type: 'new_leave_request', extraData: extraData);
        await NotificationHelper.notifyAdmin(title: title, body: body, type: 'new_leave_request', extraData: extraData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave applied successfully!'), backgroundColor: Color(0xFF10B981)));
        setState(() {
          _selectedTopTab = 2; // Move to History
          _selectedHistorySubTab = 1; // Pending
          _reasonController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: Navigator.canPop(context)
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('Leave', style: AppTheme.h1.copyWith(fontSize: 18)),
            )
          : null,
      body: SafeArea(
        top: Navigator.canPop(context) == false, // below the status bar when it has no title bar
        bottom: false,
        child: StreamBuilder<QuerySnapshot>(
        stream: _leaveRequestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final userEmail = (user?.email ?? AppSession().email ?? '').toLowerCase();
          final currentCompanyId = AppSession().companyId;
          final allDocs = snapshot.data?.docs ?? [];
          
          // DEBUG - remove after fix
          debugPrint('=== LEAVE DEBUG ===');
          debugPrint('companyId: ${AppSession().companyId}');
          debugPrint('userEmail: $userEmail');
          debugPrint('total docs from Firestore: ${allDocs.length}');
          for (var doc in allDocs) {
            final d = doc.data() as Map<String, dynamic>;
            debugPrint('  doc: applicantEmail=${d['applicantEmail']}, employeeEmail=${d['employeeEmail']}, email=${d['email']}, status=${d['status']}');
          }
          
          final docs = allDocs.where((doc) {
            if (!FirestoreService.isDocInCurrentCompany(doc)) {
              return false;
            }
            final d = doc.data() as Map<String, dynamic>;
            final e1 = (d['applicantEmail'] ?? '').toString().toLowerCase();
            final e2 = (d['employeeEmail'] ?? '').toString().toLowerCase();
            final e3 = (d['email'] ?? '').toString().toLowerCase();
            return e1 == userEmail || e2 == userEmail || e3 == userEmail;
          }).toList();
          
          debugPrint('docs after email filter: ${docs.length}');
          debugPrint('===================');
          
          return Column(
            children: [
              _buildTopNavigation(),
              Expanded(
                child: _buildSelectedTabContent(docs),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _buildTopNavigation() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildTopTab('Overview', 0),
          _buildTopTab('Apply', 1),
          _buildTopTab('History', 2),
          _buildTopTab('Calendar', 3),
          _buildTopTab('Policy', 4),
        ],
      ),
    );
  }

  Widget _buildTopTab(String label, int index) {
    final isActive = _selectedTopTab == index;
    return GestureDetector(
      onTap: () {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ApplyLeaveScreen()),
          );
        } else {
          setState(() => _selectedTopTab = index);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(List<QueryDocumentSnapshot> requests) {
    switch (_selectedTopTab) {
      case 0:
        return _buildOverviewTab(requests);
      case 1:
        return _buildApplyTab();
      case 2:
        return _buildHistoryTab(requests);
      case 3:
        return _buildCalendarTab(requests);
      case 4:
        return _buildPolicyTab(requests);
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }

  // ===================== OVERVIEW TAB =====================

  Widget _buildOverviewTab(List<QueryDocumentSnapshot> requests) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeaveBalanceCard(requests),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildPendingCard(requests)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildUpcomingCard(requests)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickActionsCard(),
            const SizedBox(height: 24),
            const Text('RECENT REQUESTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
            const SizedBox(height: 12),
            _buildRecentRequestsFeed(requests),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveBalanceCard(List<QueryDocumentSnapshot> requests) {
    final usage = _leaveUsage(requests);
    final usedAnnual = usage[0], usedSick = usage[1], usedCasual = usage[2];

    return StreamBuilder<QuerySnapshot>(
      stream: _leaveTypesStream,
      builder: (context, typesSnap) => StreamBuilder<DocumentSnapshot>(
        stream: _orgDocStream,
        builder: (context, orgSnap) {
          final limits = _leaveLimits(
              typesSnap.data, orgSnap.data?.data() as Map<String, dynamic>?);
          return _leaveBalanceContent(
              usedAnnual, usedSick, usedCasual, limits[0], limits[1], limits[2]);
        },
      ),
    );
  }

  Widget _leaveBalanceContent(int usedAnnual, int usedSick, int usedCasual,
      int maxAnnual, int maxSick, int maxCasual) {
    int totalUsed = usedAnnual + usedSick + usedCasual;
    int totalMax = maxAnnual + maxSick + maxCasual;
    int remaining = totalMax - totalUsed;
    if (remaining < 0) remaining = 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('LEAVE BALANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
              GestureDetector(
                onTap: () => setState(() => _selectedTopTab = 4), // go to policy
                child: Row(
                  children: const [
                    Text('View Policy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: AppTheme.primary, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$remaining', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.0)),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('days remaining', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildLeaveProgress('Casual Leave', usedCasual, maxCasual, const Color(0xFF5C5CFF)),
          const SizedBox(height: 16),
          _buildLeaveProgress('Sick Leave', usedSick, maxSick, const Color(0xFF10B981)),
          const SizedBox(height: 16),
          _buildLeaveProgress('Annual Leave', usedAnnual, maxAnnual, const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildLeaveProgress(String label, int used, int total, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
            Text('$used/$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: total > 0 ? used / total : 0,
          backgroundColor: color.withOpacity(0.1),
          color: color,
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildPendingCard(List<QueryDocumentSnapshot> requests) {
    final pendingCount = requests.where((d) => FirestoreService.statusIs((d.data() as Map)['status'], 'pending')).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Text(pendingCount.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFFD97706), height: 1.0)),
          const SizedBox(height: 4),
          Text(pendingCount == 1 ? 'request' : 'requests', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          const Spacer(),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedTopTab = 2;
                _selectedHistorySubTab = 1; // Pending
              });
            },
            child: Row(
              children: const [
                Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: AppTheme.primary, size: 14),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUpcomingCard(List<QueryDocumentSnapshot> requests) {
    // Next approved leave that has not finished yet (starting later, or already in progress).
    // Works for leaves created on the web (from/to "yyyy-MM-dd") and on the app (Timestamps).
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    Map? upcoming;
    DateTime? upStart;
    DateTime? upEnd;
    for (final doc in requests) {
      final data = doc.data() as Map;
      if (!FirestoreService.statusIs(data['status'], 'approved')) continue;
      final s = _leaveStart(data);
      final e = _leaveEnd(data);
      if (s == null || e == null) continue;
      final end = DateTime(e.year, e.month, e.day);
      if (end.isBefore(todayDate)) continue; // already over
      if (upStart == null || s.isBefore(upStart)) {
        upcoming = data;
        upStart = DateTime(s.year, s.month, s.day);
        upEnd = end;
      }
    }

    String title = 'None';
    String line1 = 'No upcoming leaves';
    String? line2;
    if (upcoming != null && upStart != null && upEnd != null) {
      title = _leaveTypeName(upcoming).replaceAll(RegExp(r'\s*leave$', caseSensitive: false), '').trim();
      if (title.isEmpty) title = 'Leave';
      final sameDay = upStart == upEnd;
      line1 = sameDay
          ? DateFormat('MMM d').format(upStart)
          : '${DateFormat('MMM d').format(upStart)} – ${DateFormat('MMM d').format(upEnd)}';
      final started = !upStart.isAfter(todayDate);
      final days = _leaveDays(upcoming);
      line2 = started ? 'Ongoing · ${days}d' : 'In ${upStart.difference(todayDate).inDays} day(s) · ${days}d';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('UPCOMING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.0),
          ),
          const SizedBox(height: 4),
          Text(line1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          if (line2 != null) ...[
            const SizedBox(height: 2),
            Text(line2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
          ],
          const Spacer(),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _selectedTopTab = 3), // Calendar
            child: Row(
              children: const [
                Text('Calendar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: AppTheme.primary, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('QUICK ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ApplyLeaveScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_task, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 12),
                        const Text('Apply Leave', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTopTab = 3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 12),
                        const Text('View Calendar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRecentRequestsFeed(List<QueryDocumentSnapshot> requests) {
    if (requests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('No recent requests.', style: TextStyle(color: Color(0xFF6B7280)))),
      );
    }
    
    // Sort and take top 3
    DateTime made(QueryDocumentSnapshot d) {
      final m = d.data() as Map;
      return FirestoreService.parseAnyDate(m['createdAt'] ?? m['requestDate']) ??
          _leaveStart(m) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    final sorted = List.of(requests)..sort((a, b) => made(b).compareTo(made(a)));
    
    final recent = sorted.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        children: recent.map((doc) => _buildHistoryCard(doc.data() as Map, isCompact: true)).toList(),
      ),
    );
  }

  // ===================== APPLY TAB =====================

  Widget _buildApplyTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Leave Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Annual Leave', 'Sick Leave', 'Casual Leave', 'Comp Off'].map((type) {
                      final isSelected = _selectedLeaveType == type;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedLeaveType = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('From', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _fromDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (date != null) {
                                  setState(() {
                                    _fromDate = date;
                                    if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  DateFormat('dd-MM-yyyy').format(_fromDate),
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                                ),
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
                            const Text('To', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _toDate,
                                  firstDate: _fromDate,
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (date != null) {
                                  setState(() => _toDate = date);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  DateFormat('dd-MM-yyyy').format(_toDate),
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Reason', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _reasonController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Brief reason...',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _selectedTopTab = 0),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitLeave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C5CFF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ===================== HISTORY TAB =====================

  Widget _buildHistoryTab(List<QueryDocumentSnapshot> requests) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildHistorySubTab('All', 0),
              _buildHistorySubTab('Pending', 1),
              _buildHistorySubTab('Approved', 2),
              _buildHistorySubTab('Rejected', 3),
              _buildHistorySubTab('Cancelled', 4),
            ],
          ),
        ),
        Expanded(
          child: _buildHistoryList(requests),
        ),
      ],
    );
  }

  Widget _buildHistorySubTab(String label, int index) {
    final isActive = _selectedHistorySubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedHistorySubTab = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<QueryDocumentSnapshot> requests) {
    String filterStatus = 'all';
    if (_selectedHistorySubTab == 1) filterStatus = 'pending';
    else if (_selectedHistorySubTab == 2) filterStatus = 'approved';
    else if (_selectedHistorySubTab == 3) filterStatus = 'rejected';
    else if (_selectedHistorySubTab == 4) filterStatus = 'cancelled';

    final filtered = requests.where((doc) {
      if (filterStatus == 'all') return true;
      final status = ((doc.data() as Map)['status'] ?? '').toString().toLowerCase();
      return status == filterStatus.toLowerCase();
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text('No $filterStatus requests found.', style: const TextStyle(color: Color(0xFF6B7280))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: index * 50),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: _buildHistoryCard(
                {...(filtered[index].data() as Map), '_docId': filtered[index].id},
                isCompact: false),
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(Map data, {required bool isCompact}) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    Color statusColor;
    Color statusBg;
    String statusText;

    if (status == 'approved') {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFECFDF5);
      statusText = 'Approved';
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFFEF2F2);
      statusText = 'Rejected';
    } else if (status == 'cancelled') {
      statusColor = const Color(0xFF6B7280);
      statusBg = const Color(0xFFF3F4F6);
      statusText = 'Cancelled';
    } else {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFFBEB);
      statusText = 'Pending';
    }

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is Timestamp) return d.toDate();
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    final fromDate = parseDate(data['fromDate'] ?? data['from']);
    final toDate = parseDate(data['toDate'] ?? data['to']);
    final requestDate = parseDate(data['requestDate'] ?? data['createdAt'] ?? data['applied']);
    
    final int days = ((data['durationInDays'] ?? data['days']) as num?)?.toInt() ?? 1;
    String leaveType = (data['leaveType'] ?? data['type'] ?? data['category'] ?? '').toString();
    if (leaveType.isEmpty || leaveType.toLowerCase() == 'leave') {
      final r = (data['reason'] ?? '').toString();
      if (r.isNotEmpty && r.length < 25) {
        leaveType = '${r[0].toUpperCase()}${r.substring(1)} Leave';
      } else {
        leaveType = 'Casual Leave';
      }
    }
    final reason = (data['reason'] ?? '').toString();

    String dateRangeStr = 'Unknown Dates';
    if (fromDate != null) {
      final fromStr = DateFormat('MMM d').format(fromDate);
      if (toDate != null) {
        if (fromDate.year == toDate.year && fromDate.month == toDate.month && fromDate.day == toDate.day) {
          dateRangeStr = fromStr;
        } else {
          final toStr = DateFormat('MMM d').format(toDate);
          dateRangeStr = '$fromStr – $toStr';
        }
      } else {
        dateRangeStr = fromStr;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_month, color: AppTheme.primary, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(leaveType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          if (isCompact)
                            Text('$dateRangeStr · ${days}d${reason.isNotEmpty ? ' · "$reason"' : ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis)
                          else
                            Text('Applied ${requestDate != null ? DateFormat('MMM d').format(requestDate) : ''}${reason.isNotEmpty ? ' · "$reason"' : ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
            ],
          ),
          if (!isCompact) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.event_outlined, color: Color(0xFF9CA3AF), size: 14),
                const SizedBox(width: 6),
                Text('$dateRangeStr  Â·  $days days', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showLeaveDetails(data),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: const Color(0xFFF9FAFB),
                    ),
                    child: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ),
                ),
                if (status == 'pending') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmCancelLeave(data),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: const Color(0xFFFEF2F2),
                      ),
                      child: const Text('Cancel Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                    ),
                  ),
                ],
              ],
            )
          ]
        ],
      ),
    );
  }

  // ===================== CALENDAR TAB =====================

  Widget _buildCalendarTab(List<QueryDocumentSnapshot> requests) {
    // Collect leave events for dots
    Map<DateTime, List<String>> events = {};
    for (var doc in requests) {
      final data = doc.data() as Map;
      final start = _leaveStart(data);
      final end = _leaveEnd(data);
      final status = (data['status'] as String?)?.toLowerCase();

      if (start != null && end != null && status != null) {
        DateTime current = DateTime(start.year, start.month, start.day);
        final endNormalized = DateTime(end.year, end.month, end.day);
        while (current.isBefore(endNormalized) || current.isAtSameMomentAs(endNormalized)) {
          if (events[current] == null) events[current] = [];
          events[current]!.add(status);
          current = current.add(const Duration(days: 1));
        }
      }
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                children: [
                  // Legend
                  Padding(
                    padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                    child: Row(
                      children: [
                        _buildLegendItem(const Color(0xFF10B981), 'Approved'),
                        const SizedBox(width: 12),
                        _buildLegendItem(const Color(0xFFF59E0B), 'Pending/Holiday'),
                        const SizedBox(width: 12),
                        _buildLegendItem(AppTheme.primary, 'Today'),
                      ],
                    ),
                  ),
                  TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    eventLoader: (day) {
                      final normalized = DateTime(day.year, day.month, day.day);
                      return events[normalized] ?? [];
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, evs) {
                        if (evs.isEmpty) return null;
                        return Positioned(
                          bottom: 4,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: evs.map((event) {
                              Color c = const Color(0xFFD1D5DB);
                              if (event == 'approved') c = const Color(0xFF10B981);
                              else if (event == 'pending') c = const Color(0xFFF59E0B);
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                      weekendTextStyle: const TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('SCHEDULED LEAVES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                children: requests.where((doc) {
                  final status = ((doc.data() as Map)['status'] ?? '').toString().toLowerCase();
                  return status == 'approved' || status == 'pending';
                }).map((doc) => _buildScheduledLeaveItem(doc.data() as Map)).toList(),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildScheduledLeaveItem(Map data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final color = status == 'approved' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final fromDate = _leaveStart(data);
    final toDate = _leaveEnd(data);
    final days = _leaveDays(data);

    final dateRangeStr = (fromDate != null && toDate != null)
        ? '${DateFormat('MMM d').format(fromDate)} â€“ ${DateFormat('MMM d').format(toDate)}'
        : 'Unknown Dates';

    return ListTile(
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(_leaveTypeName(data), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      subtitle: Text('$dateRangeStr Â· ${days}d Â· ${status == 'approved' ? 'Approved' : 'Pending'}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
    );
  }

  // ===================== LEAVE DETAILS / CANCEL =====================

  void _showLeaveDetails(Map data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final from = _leaveStart(data);
    final to = _leaveEnd(data);
    final applied = FirestoreService.parseAnyDate(data['createdAt'] ?? data['requestDate']);
    String range = 'Unknown dates';
    if (from != null) {
      range = (to == null || DateFormat('yyyyMMdd').format(from) == DateFormat('yyyyMMdd').format(to))
          ? DateFormat('EEE, MMM d, yyyy').format(from)
          : '${DateFormat('MMM d, yyyy').format(from)} – ${DateFormat('MMM d, yyyy').format(to)}';
    }
    final decidedBy = (data['approvedBy'] ?? data['rejectedBy'] ?? '').toString();
    final decidedAt = FirestoreService.parseAnyDate(data['approvedAt'] ?? data['rejectedAt'] ?? data['cancelledAt']);
    final rejectReason = (data['rejectReason'] ?? data['rejectNote'] ?? '').toString();

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 110,
                child: Text(k, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600))),
            Expanded(
                child: Text(v, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
          ]),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Text(_leaveTypeName(data), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            row('Status', status.isEmpty ? 'Pending' : '${status[0].toUpperCase()}${status.substring(1)}'),
            row('Dates', range),
            row('Days', '${_leaveDays(data)}'),
            if ((data['reason'] ?? '').toString().isNotEmpty) row('Reason', data['reason'].toString()),
            if (applied != null) row('Applied on', DateFormat('MMM d, yyyy · hh:mm a').format(applied)),
            if ((data['approver'] ?? '').toString().isNotEmpty) row('Approver', data['approver'].toString()),
            if (decidedBy.isNotEmpty) row(status == 'approved' ? 'Approved by' : 'Decision by', decidedBy),
            if (decidedAt != null) row('Decided on', DateFormat('MMM d, yyyy').format(decidedAt)),
            if (rejectReason.isNotEmpty) row('Reason given', rejectReason),
            if (status == 'pending') ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmCancelLeave(data);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: const Color(0xFFFEF2F2),
                  ),
                  child: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmCancelLeave(Map data) async {
    final id = (data['_docId'] ?? data['id'] ?? '').toString();
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel leave request?'),
        content: Text('Your ${_leaveTypeName(data)} request will be cancelled. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirestoreService.cancelLeaveRequest(
        requestId: id,
        applicantEmail: FirestoreService.requesterEmail(Map<String, dynamic>.from(data)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Leave request cancelled'), backgroundColor: Color(0xFF10B981)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not cancel: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  // ===================== POLICY TAB (real time) =====================

  /// Days used per type [annual, sick, casual] — approved + pending requests.
  List<int> _leaveUsage(List<QueryDocumentSnapshot> requests) {
    int annual = 0, sick = 0, casual = 0;
    for (final doc in requests) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status != 'approved' && status != 'pending') continue;
      final type = _leaveTypeName(data).toLowerCase();
      final days = _leaveDays(data);
      if (type.contains('sick')) {
        sick += days;
      } else if (type.contains('casual')) {
        casual += days;
      } else {
        annual += days;
      }
    }
    return [annual, sick, casual];
  }

  DateTime? _holidayDate(Map m) {
    final iso = FirestoreService.parseAnyDate(m['rawDate'] ?? m['date']);
    if (iso != null) return iso;
    final text = (m['date'] ?? m['rawDate'] ?? '').toString().trim();
    for (final f in ['MMM d, yyyy', 'MMMM d, yyyy', 'd MMM yyyy', 'dd/MM/yyyy', 'dd-MM-yyyy']) {
      try {
        return DateFormat(f).parseStrict(text);
      } catch (_) {}
    }
    final y = int.tryParse('${m['year'] ?? ''}');
    final mo = int.tryParse('${m['month'] ?? ''}');
    final d = int.tryParse('${m['day'] ?? ''}');
    if (y != null && mo != null && d != null) return DateTime(y, mo, d);
    return null;
  }

  String _yesNo(dynamic v) {
    if (v == true) return 'Yes';
    if (v == false) return 'No';
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return '';
    final l = s.toLowerCase();
    if (l == 'yes' || l == 'true') return 'Yes';
    if (l == 'no' || l == 'false') return 'No';
    return s;
  }

  Widget _policySection(String title, List<Widget> children, {String? trailing}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
          if (trailing != null)
            Text(trailing, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        ]),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _policyRow(String label, String value, {Color? dot, String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (dot != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            if (sub != null && sub.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ),
      ]),
    );
  }

  Widget _faqTile(String q, String a) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 14, right: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: AppTheme.primary,
        collapsedIconColor: const Color(0xFFD1D5DB),
        title: Text(q, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        children: [Text(a, style: const TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF4B5563)))],
      ),
    );
  }

  Widget _buildPolicyTab(List<QueryDocumentSnapshot> requests) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _orgDocStream,
      builder: (context, orgSnap) => StreamBuilder<QuerySnapshot>(
        stream: _leaveTypesStream,
        builder: (context, typesSnap) => StreamBuilder<QuerySnapshot>(
          stream: _holidaysStream,
          builder: (context, holSnap) => StreamBuilder<QuerySnapshot>(
            stream: _policiesStream,
            builder: (context, polSnap) {
              final org = (orgSnap.data?.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
              final limits = _leaveLimits(typesSnap.data, org);
              final usage = _leaveUsage(requests);
              final totalMax = limits[0] + limits[1] + limits[2];
              final totalUsed = usage[0] + usage[1] + usage[2];
              final remaining = (totalMax - totalUsed) < 0 ? 0 : totalMax - totalUsed;

              const typeColors = [Color(0xFF8B5CF6), Color(0xFF10B981), Color(0xFF5C5CFF)];

              // ── Leave types ──
              final typeRows = <Widget>[];
              final typeDocs = (typesSnap.data?.docs ?? []).map((d) => d.data() as Map<String, dynamic>).toList();
              if (typeDocs.isNotEmpty) {
                for (var i = 0; i < typeDocs.length; i++) {
                  final t = typeDocs[i];
                  if (t['enabled'] == false) continue;
                  final days = t['days'];
                  final carry = t['carry'];
                  String? carryText;
                  if (carry is num && carry > 0) {
                    carryText = 'Carry forward up to ${carry.toInt()} days';
                  } else if (carry == true || _yesNo(carry) == 'Yes') {
                    carryText = 'Unused days can be carried forward';
                  } else if (carry == false || _yesNo(carry) == 'No') {
                    carryText = 'No carry forward';
                  }
                  typeRows.add(_policyRow(
                    (t['name'] ?? 'Leave').toString(),
                    days == null ? '—' : '$days days / year',
                    dot: typeColors[i % typeColors.length],
                    sub: carryText,
                  ));
                }
              }
              if (typeRows.isEmpty) {
                typeRows.addAll([
                  _policyRow('Annual Leave', '${limits[0]} days / year', dot: typeColors[0]),
                  _policyRow('Sick Leave', '${limits[1]} days / year', dot: typeColors[1]),
                  _policyRow('Casual Leave', '${limits[2]} days / year', dot: typeColors[2]),
                ]);
              }

              // ── Company leave rules (only what the organization has configured) ──
              final leavePolicy = org['leavePolicy'] is Map ? org['leavePolicy'] as Map : const {};
              final wfh = org['wfhPolicy'] is Map ? org['wfhPolicy'] as Map : const {};
              final att = org['attendancePolicy'] is Map ? org['attendancePolicy'] as Map : const {};
              final carryAllowed = _yesNo(leavePolicy['carryoverAllowed']);
              final wfhAllowed = _yesNo(wfh['wfhAllowed']);
              final maxWfh = (wfh['maxWfhDaysMonth'] ?? '').toString().trim();
              final halfDay = (att['halfDayThreshold'] ?? '').toString().trim();
              final graceMin = AppSession().gracePeriod;
              final ruleRows = <Widget>[
                if (carryAllowed.isNotEmpty) _policyRow('Carry forward unused leave', carryAllowed),
                if (wfhAllowed.isNotEmpty) _policyRow('Work from home', wfhAllowed),
                if (maxWfh.isNotEmpty && maxWfh != '0') _policyRow('Max WFH days per month', maxWfh),
                if (halfDay.isNotEmpty) _policyRow('Half-day threshold', halfDay),
                _policyRow('Late mark after', '$graceMin min grace'),
                _policyRow('Approval', 'Manager / HR Admin'),
              ];

              // leave-related written policies from the Organization → Policies tab
              final leaveDocs = (polSnap.data?.docs ?? [])
                  .map((d) => d.data() as Map<String, dynamic>)
                  .where((m) =>
                      (m['category'] ?? '').toString().toLowerCase().contains('leave') ||
                      (m['title'] ?? '').toString().toLowerCase().contains('leave'))
                  .toList();
              for (final m in leaveDocs) {
                final bullets = m['bullets'] is List ? (m['bullets'] as List).map((e) => '• $e').join('\n') : '';
                ruleRows.add(Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((m['title'] ?? 'Policy').toString(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    if ((m['description'] ?? m['body'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text((m['description'] ?? m['body']).toString(),
                            style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF4B5563))),
                      ),
                    if (bullets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(bullets, style: const TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF4B5563))),
                      ),
                  ]),
                ));
              }

              // ── Upcoming holidays ──
              final today = DateTime.now();
              final todayDate = DateTime(today.year, today.month, today.day);
              final holidays = <MapEntry<DateTime, String>>[];
              for (final d in holSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
                final m = d.data() as Map<String, dynamic>;
                final dt = _holidayDate(m);
                if (dt == null) continue;
                final day = DateTime(dt.year, dt.month, dt.day);
                if (day.isBefore(todayDate)) continue;
                holidays.add(MapEntry(day, (m['name'] ?? 'Holiday').toString()));
              }
              holidays.sort((a, b) => a.key.compareTo(b.key));
              final nextHolidays = holidays.take(5).toList();

              // ── FAQ (answers use this organization's real values) ──
              final nextHolidayText = nextHolidays.isEmpty
                  ? 'No upcoming holidays have been published yet.'
                  : 'The next holiday is ${nextHolidays.first.value} on ${DateFormat('EEE, MMM d').format(nextHolidays.first.key)}.';
              final carryAnswer = carryAllowed == 'Yes'
                  ? 'Yes. Your organization allows unused leave to be carried forward. The limit for each leave type is shown under Leave Types above.'
                  : carryAllowed == 'No'
                      ? 'No. Your organization does not carry unused leave into the next year.'
                      : 'Your organization has not published a carry-forward rule yet. Please check with HR.';
              final faqs = <List<String>>[
                [
                  'How do I apply for leave?',
                  'Open Leave → Apply (or tap the + button → Apply Leave). Choose the leave type, the dates and a reason, then submit. Your request goes to your reporting manager / HR Admin and appears under History as Pending.'
                ],
                [
                  'How many leaves do I receive?',
                  'Your organization allows ${limits[0]} Annual, ${limits[1]} Sick and ${limits[2]} Casual days per year ($totalMax in total). You have used $totalUsed so far, so $remaining days remain. These numbers update live if HR changes the policy.'
                ],
                [
                  'How is my leave balance calculated?',
                  'Pending and approved requests are counted using the number of days saved on each request. Rejected and cancelled requests do not reduce your balance.'
                ],
                [
                  'Can I cancel a leave request?',
                  'Yes, while it is still Pending: open Leave → History, then tap Cancel Request. After it has been approved or rejected, please contact your manager or HR Admin.'
                ],
                [
                  'How will I know if my leave is approved or rejected?',
                  'You receive a notification and the status in History, Overview and Calendar updates instantly — on the app and on the web. If a request is rejected, the reason from your approver is shown in the request details.'
                ],
                [
                  'Can I carry forward unused leave?',
                  carryAnswer,
                ],
                [
                  'Can I apply for a half-day leave?',
                  'The Apply form takes whole days. For a half day, apply for that day, write "half day" in the reason and let your manager or HR Admin know before it is approved.'
                ],
                [
                  'What documents are required for sick leave?',
                  'This is decided by your organization. Add the reason when you apply; HR or your manager may ask for a medical certificate, which you can share with HR. Anything your organization has published is shown under Company Leave Rules above.'
                ],
                [
                  'When is the next company holiday?',
                  nextHolidayText,
                ],
              ];

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _policySection('LEAVE TYPES', typeRows),
                    _policySection('MY LEAVE ALLOCATION — ${today.year}', [
                      _buildLeaveProgress('Annual Leave', usage[0], limits[0], typeColors[0]),
                      const SizedBox(height: 14),
                      _buildLeaveProgress('Sick Leave', usage[1], limits[1], typeColors[1]),
                      const SizedBox(height: 14),
                      _buildLeaveProgress('Casual Leave', usage[2], limits[2], typeColors[2]),
                      const SizedBox(height: 14),
                      _policyRow('Remaining', '$remaining of $totalMax days'),
                    ]),
                    _policySection('COMPANY LEAVE RULES', ruleRows),
                    if (nextHolidays.isNotEmpty)
                      _policySection('UPCOMING HOLIDAYS', [
                        for (final h in nextHolidays)
                          _policyRow(h.value, DateFormat('EEE, MMM d').format(h.key), dot: const Color(0xFFEF4444)),
                      ]),
                    _policySection('FREQUENTLY ASKED QUESTIONS', [
                      for (var i = 0; i < faqs.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _faqTile(faqs[i][0], faqs[i][1]),
                      ],
                    ]),
                    const SizedBox(height: 80),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
