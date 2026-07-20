import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/location_service.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/utils/notification_service.dart';
import 'manager_attendance_detail_screen.dart';

class ManagerAttendanceTab extends StatefulWidget {
  final Function(int)? onTabChange;
  const ManagerAttendanceTab({super.key, this.onTabChange});

  @override
  State<ManagerAttendanceTab> createState() => _ManagerAttendanceTabState();
}

class _ManagerAttendanceTabState extends State<ManagerAttendanceTab> {
  final user = FirebaseAuth.instance.currentUser;
  late final CollectionReference<Map<String, dynamic>> _todayRef;
  late final Stream<DocumentSnapshot> _todayAttendanceStream;
  late final Stream<QuerySnapshot> _allAttendanceStream;
  int _selectedTopTab = 0; // 0: Overview, 1: Summary, 2: Requests, 3: Analytics
  bool _isWeeklySelected = true;
  bool _isCheckingInOut = false;
  LocationData? _currentLocationData;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final userEmail = user?.email ?? '';
    _todayRef = FirestoreService.userAttendanceCol(userEmail);
    _todayAttendanceStream = _todayRef.doc(_getAttendanceDocId(DateTime.now())).snapshots();
    _allAttendanceStream = _todayRef.orderBy('date', descending: true).snapshots();
    
    _startLocationUpdates();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    LocationService().startRealtimeTracking();
    LocationService.getStream().listen((data) {
      if (mounted && data.position != null) {
        setState(() => _currentLocationData = data);
      }
    });
  }

  String _getAttendanceDocId(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  String _getWorkingDuration(Timestamp? checkIn, Timestamp? checkOut) {
    if (checkIn == null) return '0h 0m';
    final diff = (checkOut?.toDate() ?? DateTime.now()).difference(checkIn.toDate());
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }
  
  Future<void> _handleCheckOut(DocumentReference docRef) async {
    if (_isCheckingInOut) return;
    setState(() => _isCheckingInOut = true);
    try {
      final now = DateTime.now();
      await docRef.update({
        'checkOut': Timestamp.fromDate(now),
        'status': 'present',
      });
      await NotificationService().cancelCheckoutReminder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked out successfully'), backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _isCheckingInOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Background color
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNavigation(),
            Expanded(
              child: _selectedTopTab == 0
                  ? _buildOverviewTab()
                  : _selectedTopTab == 1
                      ? _buildSummaryTab()
                      : Center(child: Text('Coming Soon', style: TextStyle(color: Colors.grey[600]))),
            ),
          ],
        ),
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
            _buildTopTab('Summary', 1),
            _buildTopTab('Requests', 2),
            _buildTopTab('Analytics', 3),
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
              color: isActive ? const Color(0xFF5C5CFF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTodaysAttendanceCard(),
          const SizedBox(height: 16),
          _buildThisWeekCard(),
          const SizedBox(height: 16),
          _buildMonthlySummaryCard(),
          const SizedBox(height: 16),
          _buildTodaysShiftCard(),
          const SizedBox(height: 16),
          _buildQuickActionsCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: child,
    );
  }
  
  Widget _buildSectionHeader(String title, {String? actionText, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.5,
          ),
        ),
        if (actionText != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              children: [
                Text(
                  actionText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C5CFF),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, color: Color(0xFF5C5CFF), size: 14),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTodaysAttendanceCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _todayAttendanceStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final checkIn = data?['checkIn'] as Timestamp?;
        final checkOut = data?['checkOut'] as Timestamp?;
        final isCheckedIn = checkIn != null && checkOut == null;
        final isCheckedOut = checkIn != null && checkOut != null;
        
        final inStr = checkIn != null ? DateFormat('hh:mm a').format(checkIn.toDate()) : '--:--';
        final outStr = checkOut != null ? DateFormat('hh:mm a').format(checkOut.toDate()) : (checkIn != null ? 'Ongoing' : '--:--');

        return _buildCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TODAY\'S ATTENDANCE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                  ),
                  if (checkIn != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Present',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildMiniStat(inStr, 'Check In', const Color(0xFFECFDF5), const Color(0xFF10B981))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMiniStat(outStr, 'Check Out', const Color(0xFFFFFBEB), const Color(0xFFF59E0B))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMiniStat(_getWorkingDuration(checkIn, checkOut), 'Working', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMiniStat('7 min', 'Late Buffer', const Color(0xFFFEF2F2), const Color(0xFFEF4444))), // Mocked late buffer
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFF5C5CFF), size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        (() {
                          final loc = data?['checkInLocation'] as String?;
                          if (loc != null && loc != 'Unknown') return loc;
                          return _currentLocationData?.address ?? (AppSession().companyName != null ? '${AppSession().companyName} HQ' : 'Bengaluru HQ â€“ Prestige Tech Park');
                        })(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Icon(Icons.wifi, color: Color(0xFF10B981), size: 14),
                        Text('GPS\nActive', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: isCheckedIn ? () => _handleCheckOut(_todayRef.doc(_getAttendanceDocId(DateTime.now()))) : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: isCheckedIn ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB)),
                        backgroundColor: isCheckedIn ? const Color(0xFFFEF2F2) : const Color(0xFFF9FAFB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: isCheckedIn ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF), size: 16),
                          const SizedBox(width: 8),
                          Text(isCheckedOut ? 'Checked Out' : 'Check Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isCheckedIn ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ManagerAttendanceDetailScreen(onTabChange: widget.onTabChange),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF6B7280), size: 16),
                          SizedBox(width: 6),
                          Text('Detail', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildMiniStat(String value, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textColor),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildThisWeekCard() {
    return _buildCardContainer(
      child: Column(
        children: [
          _buildSectionHeader('THIS WEEK', actionText: 'View History', onAction: () {}),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDayStatus('Mon', 'P', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF), true),
              _buildDayStatus('Tue', 'L', const Color(0xFFFFFBEB), const Color(0xFFF59E0B), true),
              _buildDayStatus('Wed', 'P', const Color(0xFFECFDF5), const Color(0xFF10B981), true),
              _buildDayStatus('Thu', 'W', const Color(0xFFEFF6FF), const Color(0xFF3B82F6), true),
              _buildDayStatus('Fri', 'P', const Color(0xFFECFDF5), const Color(0xFF10B981), true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayStatus(String day, String status, Color bgColor, Color textColor, bool hasDot) {
    return Column(
      children: [
        Text(day, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
        ),
        const SizedBox(height: 6),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: hasDot ? textColor : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlySummaryCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('JULY 2026 â€“ MONTHLY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMonthlyStatBox('18', 'Present', const Color(0xFFECFDF5), const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildMonthlyStatBox('2', 'Late', const Color(0xFFFFFBEB), const Color(0xFFF59E0B))),
              const SizedBox(width: 8),
              Expanded(child: _buildMonthlyStatBox('3', 'WFH', const Color(0xFFEFF6FF), const Color(0xFF3B82F6))),
              const SizedBox(width: 8),
              Expanded(child: _buildMonthlyStatBox('1', 'Leave', const Color(0xFFF5F3FF), const Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Attendance Rate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5C5CFF))),
                Text('99.5%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF5C5CFF))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatBox(String count, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _buildTodaysShiftCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY\'S SHIFT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.access_time_rounded, color: Color(0xFF5C5CFF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('General Shift', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                    SizedBox(height: 2),
                    Text('09:00 AM â€“ 06:00 PM Â· Office', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text('Manager', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                  SizedBox(height: 2),
                  Text('Sarah M.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('QUICK ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
          const SizedBox(height: 16),
          _buildQuickActionItem(Icons.show_chart_rounded, 'View Attendance History', 'View complete attendance log'),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildQuickActionItem(Icons.edit_document, 'Request Regularization', 'Correct missed attendance'),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildQuickActionItem(Icons.calendar_month_outlined, 'View Attendance Calendar', 'Monthly attendance overview'),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF5C5CFF), size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF5C5CFF), size: 18),
      ],
    );
  }

  Widget _buildSummaryTab() {
    return Column(
      children: [
        // Sub-navigation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isWeeklySelected = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isWeeklySelected ? const Color(0xFF5C5CFF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _isWeeklySelected ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        'Weekly',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isWeeklySelected ? Colors.white : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _isWeeklySelected = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isWeeklySelected ? const Color(0xFF5C5CFF) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: !_isWeeklySelected ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        'Monthly',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: !_isWeeklySelected ? Colors.white : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.filter_alt_outlined, size: 14, color: Color(0xFF6B7280)),
                    SizedBox(width: 6),
                    Text('This Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _allAttendanceStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF5C5CFF)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No attendance records found.', style: TextStyle(color: Color(0xFF6B7280))));
              }

              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return _buildSummaryCard(data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> data) {
    final recordDateStr = data['recordDate'] as String?;
    final date = recordDateStr != null ? DateTime.tryParse(recordDateStr) : (data['date'] as Timestamp?)?.toDate();
    if (date == null) return const SizedBox.shrink();

    final dayStr = DateFormat('E').format(date);
    final dateNum = DateFormat('d').format(date);

    final status = (data['status'] as String?)?.toLowerCase() ?? 'absent';
    Color statusColor;
    Color statusBg;
    String statusText;
    
    if (status == 'present') {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFECFDF5);
      statusText = 'Present';
    } else if (status == 'leave') {
      statusColor = const Color(0xFF8B5CF6);
      statusBg = const Color(0xFFF5F3FF);
      statusText = 'On Leave';
    } else if (data['workMode'] == 'wfh') {
      statusColor = const Color(0xFF3B82F6);
      statusBg = const Color(0xFFEFF6FF);
      statusText = 'WFH';
    } else if (status == 'late') {
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFFFFBEB);
      statusText = 'Late';
    } else {
      statusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFFEF2F2);
      statusText = 'Absent';
    }

    final checkIn = data['checkIn'] as Timestamp?;
    final checkOut = data['checkOut'] as Timestamp?;
    
    String timeRangeStr;
    if (status == 'leave' || status == 'absent') {
      timeRangeStr = 'No attendance record';
    } else {
      final inStr = checkIn != null ? DateFormat('hh:mm a').format(checkIn.toDate()) : '--:--';
      final outStr = checkOut != null ? DateFormat('hh:mm a').format(checkOut.toDate()) : (checkIn != null ? 'Ongoing' : '--:--');
      timeRangeStr = '$inStr - $outStr';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date Column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 6),
                Text(dayStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                const SizedBox(height: 2),
                Text(dateNum, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Status and Time Range
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 8),
                Text(timeRangeStr, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          // Working Hours
          if (status != 'leave' && status != 'absent')
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text(
                      _getWorkingDuration(checkIn, checkOut),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Working hrs', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
              ],
            )
          else
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 18),
        ],
      ),
    );
  }
}
