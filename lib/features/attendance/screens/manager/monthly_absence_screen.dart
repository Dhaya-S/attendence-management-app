import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class MonthlyAbsenceScreen extends StatefulWidget {
  const MonthlyAbsenceScreen({super.key});

  @override
  State<MonthlyAbsenceScreen> createState() => _MonthlyAbsenceScreenState();
}

class _MonthlyAbsenceScreenState extends State<MonthlyAbsenceScreen> {
  static const Color _indigo = Color(0xFF5C5CFF);
  static const Color _rose = Color(0xFFF43F5E);
  static const Color _teal = Color(0xFF10B981);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _slate = Color(0xFF1E293B);

  String _selectedFilter = 'All'; // 'All', 'High Absence', 'On Track'
  final _filters = ['All', 'High Absence', 'On Track'];

  DateTime _currentDate = DateTime.now();

  String get _monthName => DateFormat('MMMM yyyy').format(_currentDate);

  void _previousMonth() => setState(() {
        _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
      });

  void _nextMonth() => setState(() {
        _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
      });

  int _getWorkingDaysForUser(int year, int month, DateTime? createdAt, [DateTime? firstCheckIn]) {
    int daysInMonth = DateTime(year, month + 1, 0).day;
    DateTime today = DateTime.now();
    int workingDays = 0;
    
    // User Joining Date priority: 
    // 1. First ever check-in (if available)
    // 2. Created at date
    DateTime? effectiveStart = firstCheckIn ?? createdAt;

    for (int i = 1; i <= daysInMonth; i++) {
      DateTime currentDay = DateTime(year, month, i);
      if (currentDay.isAfter(today)) continue;
      
      if (effectiveStart != null) {
        DateTime startDay =
            DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
        if (currentDay.isBefore(startDay)) continue;
      }
      if (currentDay.weekday < 6) workingDays++;
    }
    return workingDays;
  }

  @override
  Widget build(BuildContext context) {
    final startOfMonth = DateTime(_currentDate.year, _currentDate.month, 1);
    final endOfMonth =
        DateTime(_currentDate.year, _currentDate.month + 1, 0, 23, 59, 59);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _slate, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Monthly Absence Overview',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.companyUsersQuery.snapshots(),
        builder: (context, usersSnap) {
          if (!usersSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final usersDocs = usersSnap.data!.docs;

          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.allAttendanceRecordsCol
                .snapshots(),
            builder: (context, recordsSnap) {
              // Filter in-memory to avoid index issues
              final allDocs = recordsSnap.data?.docs ?? [];
              final monthRecords = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final dateTs = data['date'] as Timestamp? ?? data['checkIn'] as Timestamp?;
                if (dateTs == null) return false;
                if (data['status'] == 'DUMMY_NONE') return false;
                final date = dateTs.toDate();
                return !date.isBefore(startOfMonth) &&
                    !date.isAfter(endOfMonth);
              }).toList();

              // Calculate first check-in for every employee to determine effective joining date
              final Map<String, DateTime> firstCheckInDates = {};
              for (var doc in allDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final dateTs = data['date'] as Timestamp? ?? data['checkIn'] as Timestamp?;
                final uid = data['userId'] ?? data['uid'] ?? doc.reference.parent.parent?.id;
                if (dateTs != null && uid != null) {
                  final date = dateTs.toDate();
                  if (firstCheckInDates[uid] == null || date.isBefore(firstCheckInDates[uid]!)) {
                    firstCheckInDates[uid] = date;
                  }
                }
              }

              // Count presence per UID
              Map<String, int> presenceCount = {};
              for (var doc in monthRecords) {
                final uid = doc.reference.parent.parent?.id;
                if (uid != null) {
                  presenceCount[uid] = (presenceCount[uid] ?? 0) + 1;
                }
              }

              // Build absence summary for employee-only users
              List<Map<String, dynamic>> allSummary = [];
              int totalAbsentDays = 0;
              int totalWorkingDays = 0;
              int highAbsenceCount = 0;
              int onTrackCount = 0;

              for (var u in usersDocs) {
                final data = u.data() as Map<String, dynamic>;
                if ((data['role']?.toString().toLowerCase() ?? 'employee') !=
                    'employee') continue;

                DateTime? createdAt =
                    (data['createdAt'] as Timestamp?)?.toDate();
                DateTime? firstCheckIn = firstCheckInDates[u.id];
                int userWorkingDays = _getWorkingDaysForUser(
                    _currentDate.year, _currentDate.month, createdAt, firstCheckIn);

                final int presentDays = presenceCount[u.id] ?? 0;
                final int absentDays =
                    (userWorkingDays - presentDays).clamp(0, userWorkingDays);
                final int rate = userWorkingDays > 0
                    ? (presentDays / userWorkingDays * 100).toInt()
                    : 0;

                totalWorkingDays += userWorkingDays;
                totalAbsentDays += absentDays;
                if (absentDays > 3) highAbsenceCount++;
                if (absentDays <= 1) onTrackCount++;

                allSummary.add({
                  'name': data['name'] ?? 'Employee',
                  'designation': data['designation'] ?? 'Employee',
                  'absent': absentDays,
                  'present': presentDays,
                  'total': userWorkingDays,
                  'rate': rate,
                });
              }

              // Sort by most absent
              allSummary.sort(
                  (a, b) => (b['absent'] as int).compareTo(a['absent'] as int));

              // Apply filter
              List<Map<String, dynamic>> displayList;
              if (_selectedFilter == 'High Absence') {
                displayList =
                    allSummary.where((e) => e['absent'] > 3).toList();
              } else if (_selectedFilter == 'On Track') {
                displayList =
                    allSummary.where((e) => e['absent'] <= 1).toList();
              } else {
                displayList = allSummary;
              }

              double overallRate = totalWorkingDays > 0
                  ? ((totalWorkingDays - totalAbsentDays) /
                          totalWorkingDays *
                          100)
                      .clamp(0.0, 100.0)
                  : 0.0;

              return Column(
                children: [
                  // ── Overview Header (white card, like EmployeesOnLeave) ──
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month selector row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left_rounded,
                                  color: Colors.grey[400]),
                              onPressed: _previousMonth,
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month_rounded,
                                      size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 6),
                                  Text(
                                    _monthName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _slate),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.chevron_right_rounded,
                                  color: Colors.grey[400]),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Label
                        const Text(
                          'ABSENCE OVERVIEW',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textHint,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Total count headline
                        Text(
                          'Total Employees Tracked: ${allSummary.length}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Colored multi-segment bar (On Track | High Absence)
                        _buildSegmentBar(
                            allSummary.length, onTrackCount, highAbsenceCount),
                        const SizedBox(height: 12),
                        // Legend row
                        Row(
                          children: [
                            _legend(_teal, 'On Track ($onTrackCount)'),
                            const SizedBox(width: 16),
                            _legend(_rose,
                                'High Absence ($highAbsenceCount)'),
                            const SizedBox(width: 16),
                            _legend(_amber,
                                'Avg Rate ${overallRate.toStringAsFixed(0)}%'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📊 Overall attendance rate: ${overallRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 14),
                        // Filter chips
                        Row(
                          children: _filters.map((f) {
                            final isActive = _selectedFilter == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedFilter = f),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppTheme.primary
                                        : AppTheme.surface,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSM),
                                  ),
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isActive
                                          ? Colors.white
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // ── Employee List ──────────────────────────────────────
                  Expanded(
                    child: displayList.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            physics: const BouncingScrollPhysics(),
                            itemCount: displayList.length,
                            itemBuilder: (context, index) {
                              return _absenceCard(displayList[index]);
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Segment Bar ─────────────────────────────────────────────────────────
  Widget _buildSegmentBar(int total, int onTrack, int highAbsence) {
    if (total == 0) return const SizedBox.shrink();
    double onTrackFrac = onTrack / total;
    double highFrac = highAbsence / total;
    double midFrac = (1 - onTrackFrac - highFrac).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          if (onTrackFrac > 0)
            Flexible(
              flex: (onTrackFrac * 100).round(),
              child: Container(height: 10, color: _teal),
            ),
          if (midFrac > 0)
            Flexible(
              flex: (midFrac * 100).round(),
              child: Container(height: 10, color: _amber),
            ),
          if (highFrac > 0)
            Flexible(
              flex: (highFrac * 100).round(),
              child: Container(height: 10, color: _rose),
            ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Employee Absence Card (mirrors EmployeesOnLeave style) ───────────────
  Widget _absenceCard(Map<String, dynamic> e) {
    final int absent = e['absent'];
    final int present = e['present'];
    final int total = e['total'];
    final int rate = e['rate'];
    final String name = e['name'];
    final String designation = e['designation'];

    Color statusColor;
    String statusLabel;
    if (rate >= 90) {
      statusColor = _teal;
      statusLabel = 'EXCELLENT';
    } else if (rate >= 75) {
      statusColor = _amber;
      statusLabel = 'AVERAGE';
    } else {
      statusColor = _rose;
      statusLabel = 'LOW';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: statusColor.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: statusColor,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + designation + tags
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  designation,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Absent days badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (absent > 0 ? _rose : _teal).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            absent > 0
                                ? Icons.cancel_outlined
                                : Icons.check_circle_outline,
                            size: 10,
                            color: absent > 0 ? _rose : _teal,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$absent Day${absent != 1 ? 's' : ''} Absent',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: absent > 0 ? _rose : _teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Present days info
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text(
                          '$present / $total days',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? (present / total).clamp(0.0, 1.0) : 0.0,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: Rate + Status badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$rate%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 64, color: _teal.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('Perfect Attendance!',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _slate)),
          const SizedBox(height: 8),
          Text('No absences recorded for this filter.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
