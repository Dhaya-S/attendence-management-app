import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/screens/employee/employee_attendance_detail_screen.dart';

class EmployeeAttendanceSummaryScreen extends StatefulWidget {
  const EmployeeAttendanceSummaryScreen({super.key});
  @override
  State<EmployeeAttendanceSummaryScreen> createState() =>
      _EmployeeAttendanceSummaryScreenState();
}

class _EmployeeAttendanceSummaryScreenState
    extends State<EmployeeAttendanceSummaryScreen> {
  final _userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
  bool _isWeeklyView = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String _fmtTime(Timestamp? t) {
    if (t == null) return '--:--';
    return DateFormat('hh:mm a').format(t.toDate());
  }

  void _navigateToDetail(DateTime date, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeAttendanceDetailScreen(
          date: date,
          data: data,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.userAttendanceCol(_userEmail).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        
        // Parse docs into a map for fast lookup
        Map<String, Map<String, dynamic>> recordsByDate = {};
        for (var doc in docs) {
          recordsByDate[doc.id] = doc.data() as Map<String, dynamic>;
        }

        return Container(
          color: const Color(0xFFF9FAFB),
          child: Column(
            children: [
              _buildTopControls(),
              Expanded(
                child: _isWeeklyView
                    ? _buildWeeklyView(recordsByDate)
                    : _buildMonthlyView(recordsByDate),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopControls() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isWeeklyView = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isWeeklyView ? const Color(0xFF5C5CFF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Weekly',
                      style: TextStyle(
                        color: _isWeeklyView ? Colors.white : const Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isWeeklyView = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: !_isWeeklyView ? const Color(0xFF5C5CFF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Monthly',
                      style: TextStyle(
                        color: !_isWeeklyView ? Colors.white : const Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  _isWeeklyView ? 'This Month' : 'Last Week',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyView(Map<String, Map<String, dynamic>> records) {
    // Generate last 7 days list
    final now = DateTime.now();
    List<DateTime> days = [];
    for (int i = 0; i < 7; i++) {
      days.add(now.subtract(Duration(days: i)));
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final date = days[index];
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final data = records[dateStr];
        return _buildWeeklyCard(date, data);
      },
    );
  }

  Widget _buildWeeklyCard(DateTime date, Map<String, dynamic>? data) {
    final now = DateTime.now();
    bool isFuture = date.isAfter(DateTime(now.year, now.month, now.day));
    
    String status = 'Absent';
    Color statusColor = const Color(0xFFEF4444);
    Color statusBg = const Color(0xFFFEF2F2);
    Color statusBorder = const Color(0xFFFECACA);

    if (isFuture) {
      status = 'Upcoming';
      statusColor = const Color(0xFF9CA3AF);
      statusBg = const Color(0xFFF3F4F6);
      statusBorder = const Color(0xFFE5E7EB);
    } else if (data != null) {
      final s = data['status'];
      if (s == 'present' || data['checkIn'] != null) {
        status = 'Present';
        statusColor = const Color(0xFF10B981);
        statusBg = const Color(0xFFECFDF5);
        statusBorder = const Color(0xFFA7F3D0);
      }
      if (s == 'late' || data['isLate'] == true) {
        status = 'Late';
        statusColor = const Color(0xFFF59E0B);
        statusBg = const Color(0xFFFFFBEB);
        statusBorder = const Color(0xFFFDE68A);
      }
      if (data['workMode'] == 'wfh') {
        status = 'WFH';
        statusColor = const Color(0xFF3B82F6);
        statusBg = const Color(0xFFEFF6FF);
        statusBorder = const Color(0xFFBFDBFE);
      }
      if (s == 'leave') {
        status = 'On Leave';
        statusColor = const Color(0xFF8B5CF6);
        statusBg = const Color(0xFFF5F3FF);
        statusBorder = const Color(0xFFDDD6FE);
      }
      if (s == 'holiday') {
        status = 'Holiday';
        statusColor = const Color(0xFF4B5563);
        statusBg = const Color(0xFFF3F4F6);
        statusBorder = const Color(0xFFE5E7EB);
      }
    }

    String timeStr = 'No attendance record';
    String workStr = '0h 00m';

    if (data != null && data['checkIn'] != null) {
      final cin = _fmtTime(data['checkIn'] as Timestamp?);
      final cout = (data['checkOut'] != null) ? _fmtTime(data['checkOut'] as Timestamp?) : 'Ongoing';
      timeStr = '$cin – $cout';
      
      final inTs = (data['checkIn'] as Timestamp).toDate();
      final outTs = (data['checkOut'] as Timestamp?)?.toDate() ?? now;
      final diff = outTs.difference(inTs);
      workStr = '${diff.inHours}h ${diff.inMinutes % 60}m';
    } else if (status == 'On Leave') {
      timeStr = 'Approved Leave';
    }

    return GestureDetector(
      onTap: () {
        if (data != null || date.isBefore(now) || date.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
          _navigateToDetail(date, data ?? {});
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEE').format(date),
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  DateFormat('dd').format(date),
                  style: const TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusBorder),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (data != null && data['checkIn'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    workStr,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Working hrs',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 16),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyView(Map<String, Map<String, dynamic>> records) {
    int present = 0;
    int late = 0;
    int wfh = 0;
    int leave = 0;
    
    // Calculate stats for currently focused month
    records.forEach((dateStr, data) {
      final dt = DateTime.parse(dateStr);
      if (dt.month == _focusedDay.month && dt.year == _focusedDay.year) {
        final s = data['status'];
        if (s == 'leave') leave++;
        else if (data['workMode'] == 'wfh') wfh++;
        else if (s == 'late' || data['isLate'] == true) late++;
        else if (s == 'present' || data['checkIn'] != null) present++;
      }
    });

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.now(),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                
                final dateStr = DateFormat('yyyy-MM-dd').format(selectedDay);
                final data = records[dateStr];
                if (data != null || selectedDay.isBefore(DateTime.now())) {
                  _navigateToDetail(selectedDay, data ?? {});
                }
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                leftChevronIcon: Icon(Icons.chevron_left_rounded, color: Color(0xFF4B5563)),
                rightChevronIcon: Icon(Icons.chevron_right_rounded, color: Color(0xFF4B5563)),
              ),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Color(0xFF5C5CFF),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                selectedTextStyle: TextStyle(color: Color(0xFF5C5CFF), fontWeight: FontWeight.bold),
                defaultTextStyle: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                weekendTextStyle: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
                outsideDaysVisible: false,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600),
                weekendStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  final dateStr = DateFormat('yyyy-MM-dd').format(date);
                  final data = records[dateStr];
                  
                  if (data != null) {
                    Color dotColor = const Color(0xFF10B981); // Present
                    final s = data['status'];
                    if (s == 'leave') dotColor = const Color(0xFF8B5CF6);
                    else if (data['workMode'] == 'wfh') dotColor = const Color(0xFF3B82F6);
                    else if (s == 'late' || data['isLate'] == true) dotColor = const Color(0xFFF59E0B);
                    else if (s == 'holiday') dotColor = const Color(0xFF4B5563);
                    
                    return Positioned(
                      bottom: 8,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
          ),
          
          // Legend
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(const Color(0xFF10B981), 'Present'),
                const SizedBox(width: 12),
                _buildLegendItem(const Color(0xFFF59E0B), 'Late'),
                const SizedBox(width: 12),
                _buildLegendItem(const Color(0xFF3B82F6), 'WFH'),
                const SizedBox(width: 12),
                _buildLegendItem(const Color(0xFF8B5CF6), 'On Leave'),
                const SizedBox(width: 12),
                _buildLegendItem(const Color(0xFF374151), 'Holiday'),
                const SizedBox(width: 12),
                _buildLegendItem(const Color(0xFFEF4444), 'Absent'),
              ],
            ),
          ),

          // Summary Stats Block
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat('MMMM').format(_focusedDay).toUpperCase()} SUMMARY',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMonthStatBox('$present', 'Present', const Color(0xFF10B981), const Color(0xFFECFDF5)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMonthStatBox('$late', 'Late', const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMonthStatBox('$wfh', 'WFH', const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMonthStatBox('$leave', 'Leave', const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMonthStatBox(String value, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
