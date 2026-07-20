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

class UniversalLeaveTab extends StatefulWidget {
  const UniversalLeaveTab({super.key});

  @override
  State<UniversalLeaveTab> createState() => _UniversalLeaveTabState();
}

class _UniversalLeaveTabState extends State<UniversalLeaveTab> {
  int _selectedTopTab = 0; // 0: Overview, 1: Apply, 2: History, 3: Calendar, 4: Policy
  
  final user = FirebaseAuth.instance.currentUser;
  late Stream<QuerySnapshot> _leaveRequestsStream;

  // Apply Form State
  String _selectedLeaveType = 'Casual Leave';
  String _leaveDuration = 'Full Day';
  DateTime _fromDate = DateTime.now().add(const Duration(days: 1));
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  // History Tab State
  int _selectedHistorySubTab = 0; // 0: Pending, 1: Approved, 2: Rejected, 3: Cancelled

  // Calendar Tab State
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _leaveRequestsStream = FirestoreService.userLeaveRequestsCol(user?.email ?? '').snapshots();
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
      final role = AppSession().role;

      bool reqManager = role == 'employee';
      bool reqAdmin = true;

      int durationInDays = 1;
      if (_leaveDuration == 'Full Day') {
        durationInDays = _toDate.difference(_fromDate).inDays + 1;
      } else {
        durationInDays = 1; // Half day logic could be fractional but we use int 1 for now
      }

      final data = {
        'userId': AppSession().uid,
        'email': email,
        'leaveType': _selectedLeaveType,
        'duration': _leaveDuration,
        'durationInDays': durationInDays,
        'fromDate': Timestamp.fromDate(_fromDate),
        'toDate': Timestamp.fromDate(_toDate),
        'reason': _reasonController.text.trim(),
        'requestDate': Timestamp.now(),
        'status': 'pending',
        'requiresManagerApproval': reqManager,
        'requiresAdminApproval': reqAdmin,
        'approverRemarks': '',
        'senderRole': (role ?? 'employee').toLowerCase(),
      };

      await FirestoreService.userLeaveRequestsCol(email ?? '').add(data);
      
      // Notify based on sender role
      final senderRole = (role ?? 'employee').toLowerCase();
      final dateRangeStr = durationInDays == 1
          ? 'on ${DateFormat('MMM dd, yyyy').format(_fromDate)}'
          : 'from ${DateFormat('MMM dd').format(_fromDate)} to ${DateFormat('MMM dd').format(_toDate)}';
      final title = 'New Leave Request ðŸ“';
      final body = '${AppSession().userName ?? "Employee"} applied for $_selectedLeaveType $dateRangeStr.';
      final extraData = {'employeeEmail': email};

      if (senderRole == 'admin') {
        await NotificationHelper.notifyAdmin(title: title, body: body, type: 'new_leave_request', extraData: extraData);
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
          _selectedHistorySubTab = 0; // Pending tab
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context) ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ) : null,
        title: Text('Leave', style: AppTheme.h1.copyWith(fontSize: 18)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _leaveRequestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final docs = snapshot.data?.docs ?? [];
          
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
    );
  }

  Widget _buildTopNavigation() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildTopTab('Overview', 0),
            _buildTopTab('Apply', 1),
            _buildTopTab('History', 2),
            _buildTopTab('Calendar', 3),
            _buildTopTab('Policy', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTab(String label, int index) {
    final isActive = _selectedTopTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTopTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppTheme.primary : const Color(0xFF6B7280),
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
        return _buildPolicyTab();
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
            _buildLeaveBalanceCard(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPendingCard(requests)),
                const SizedBox(width: 16),
                Expanded(child: _buildUpcomingCard(requests)),
              ],
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

  Widget _buildLeaveBalanceCard() {
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
            children: const [
              Text('28', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.0)),
              SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('days remaining', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildLeaveProgress('Casual Leave', 8, 12, const Color(0xFF5C5CFF)),
          const SizedBox(height: 16),
          _buildLeaveProgress('Sick Leave', 8, 10, const Color(0xFF10B981)),
          const SizedBox(height: 16),
          _buildLeaveProgress('Earned Leave', 12, 15, const Color(0xFF8B5CF6)),
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
    final pendingCount = requests.where((d) => (d.data() as Map)['status'] == 'pending').length;
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
          const Text('request', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedTopTab = 2;
                _selectedHistorySubTab = 0;
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
    // Find next approved leave
    QueryDocumentSnapshot? upcoming;
    final now = DateTime.now();
    for(var doc in requests) {
      final data = doc.data() as Map;
      if (data['status'] == 'approved') {
        final start = (data['fromDate'] as Timestamp?)?.toDate();
        if (start != null && start.isAfter(now)) {
          if (upcoming == null) {
            upcoming = doc;
          } else {
            final upStart = ((upcoming.data() as Map)['fromDate'] as Timestamp).toDate();
            if (start.isBefore(upStart)) {
              upcoming = doc;
            }
          }
        }
      }
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
          if (upcoming != null) ...[
            Text(((upcoming.data() as Map)['leaveType'] as String).replaceAll(' Leave', ''), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.0)),
            const SizedBox(height: 8),
            Text(DateFormat('MMM d').format(((upcoming.data() as Map)['fromDate'] as Timestamp).toDate()), style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _selectedTopTab = 3), // Calendar
              child: Row(
                children: const [
                  Text('Calendar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: AppTheme.primary, size: 14),
                ],
              ),
            )
          ] else ...[
            const Text('None', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.0)),
            const SizedBox(height: 8),
            const Text('No upcoming leaves', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ]
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
                  onTap: () => setState(() => _selectedTopTab = 1),
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
    final sorted = List.of(requests)..sort((a, b) {
      final aDate = (a.data() as Map)['requestDate'] as Timestamp?;
      final bDate = (b.data() as Map)['requestDate'] as Timestamp?;
      return bDate?.compareTo(aDate ?? Timestamp.now()) ?? 1;
    });
    
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leave Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedLeaveType,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9CA3AF)),
                  items: ['Casual Leave', 'Sick Leave', 'Earned Leave', 'Loss of Pay'].map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLeaveType = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _fromDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) setState(() {
                            _fromDate = date;
                            if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(DateFormat('MMM dd, yyyy').format(_fromDate), style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
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
                      const Text('End Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _toDate,
                            firstDate: _fromDate,
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) setState(() => _toDate = date);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(DateFormat('MMM dd, yyyy').format(_toDate), style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Leave Duration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _leaveDuration = 'Full Day'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _leaveDuration == 'Full Day' ? AppTheme.primary.withOpacity(0.05) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _leaveDuration == 'Full Day' ? AppTheme.primary : const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _leaveDuration == 'Full Day' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: _leaveDuration == 'Full Day' ? AppTheme.primary : const Color(0xFFD1D5DB),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text('Full Day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _leaveDuration == 'Full Day' ? AppTheme.primary : const Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _leaveDuration = 'Half Day'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _leaveDuration == 'Half Day' ? AppTheme.primary.withOpacity(0.05) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _leaveDuration == 'Half Day' ? AppTheme.primary : const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _leaveDuration == 'Half Day' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: _leaveDuration == 'Half Day' ? AppTheme.primary : const Color(0xFFD1D5DB),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text('Half Day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _leaveDuration == 'Half Day' ? AppTheme.primary : const Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Reason *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
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
                  hintText: 'Briefly describe the reason for your leave...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Attachment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: const [
                  Icon(Icons.upload_file, color: Color(0xFF9CA3AF), size: 28),
                  SizedBox(height: 12),
                  Text('Upload document', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  SizedBox(height: 4),
                  Text('Medical certificate, PDF, Image', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitLeave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Leave Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              _buildHistorySubTab('Pending', 0),
              _buildHistorySubTab('Approved', 1),
              _buildHistorySubTab('Rejected', 2),
              _buildHistorySubTab('Cancelled', 3),
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
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedHistorySubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: isActive ? AppTheme.primary : Colors.transparent, width: 2),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppTheme.primary : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<QueryDocumentSnapshot> requests) {
    String filterStatus;
    if (_selectedHistorySubTab == 0) filterStatus = 'pending';
    else if (_selectedHistorySubTab == 1) filterStatus = 'approved';
    else if (_selectedHistorySubTab == 2) filterStatus = 'rejected';
    else filterStatus = 'cancelled';

    final filtered = requests.where((doc) => (doc.data() as Map)['status'] == filterStatus).toList();

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
            child: _buildHistoryCard(filtered[index].data() as Map, isCompact: false),
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(Map data, {required bool isCompact}) {
    final status = data['status'] as String? ?? 'pending';
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

    final fromDate = (data['fromDate'] as Timestamp?)?.toDate();
    final toDate = (data['toDate'] as Timestamp?)?.toDate();
    final requestDate = (data['requestDate'] as Timestamp?)?.toDate();
    
    final dateRangeStr = (fromDate != null && toDate != null)
        ? '${DateFormat('MMM d').format(fromDate)} â€“ ${DateFormat('MMM d').format(toDate)}'
        : 'Unknown Dates';
    
    final days = data['durationInDays'] ?? 1;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['leaveType'] ?? 'Leave', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      if (isCompact)
                        Text('$dateRangeStr Â· $days${days > 1 ? 'd' : 'd'}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))
                      else
                        Text('Applied ${requestDate != null ? DateFormat('MMM d').format(requestDate) : ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ],
              ),
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
                    onPressed: () {},
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
                      onPressed: () {},
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
      final start = (data['fromDate'] as Timestamp?)?.toDate();
      final end = (data['toDate'] as Timestamp?)?.toDate();
      final status = data['status'] as String?;
      
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
                  final status = (doc.data() as Map)['status'];
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
    final status = data['status'];
    final color = status == 'approved' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final fromDate = (data['fromDate'] as Timestamp?)?.toDate();
    final toDate = (data['toDate'] as Timestamp?)?.toDate();
    final days = data['durationInDays'] ?? 1;

    final dateRangeStr = (fromDate != null && toDate != null)
        ? '${DateFormat('MMM d').format(fromDate)} â€“ ${DateFormat('MMM d').format(toDate)}'
        : 'Unknown Dates';

    return ListTile(
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(data['leaveType'] ?? 'Leave', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      subtitle: Text('$dateRangeStr Â· ${days}d Â· ${status == 'approved' ? 'Approved' : 'Pending'}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
    );
  }

  // ===================== POLICY TAB =====================

  Widget _buildPolicyTab() {
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
                  _buildPolicyListItem('Leave Types', true),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _buildPolicyListItem('Leave Allocation â€” FY 2025â€“26', true),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _buildPolicyListItem('Company Leave Rules', true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Frequently Asked Questions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 16),
                  _buildPolicyListItem('How do I apply for leave?', false),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _buildPolicyListItem('How many casual leaves do I receive?', false),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _buildPolicyListItem('Can I cancel an approved leave?', false),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _buildPolicyListItem('What documents are required for sick leave?', false),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _buildPolicyListItem('How is earned leave calculated?', false),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _buildPolicyListItem('Can I apply for half-day leave?', false),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyListItem(String title, bool isBold) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isBold ? 20 : 0, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }
}
