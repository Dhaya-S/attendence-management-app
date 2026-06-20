import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:convert';
import 'dart:async';

import '../../theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/message_helper.dart';

class EmployeeAttendanceTab extends StatefulWidget {
  const EmployeeAttendanceTab({super.key});

  @override
  State<EmployeeAttendanceTab> createState() => _EmployeeAttendanceTabState();
}

class _EmployeeAttendanceTabState extends State<EmployeeAttendanceTab> {
  final user = FirebaseAuth.instance.currentUser;
  late Stream<QuerySnapshot> _attendanceStream;
  DateTime _focusedDay = DateTime.now();
  final String _apiKey = 'AIzaSyCvsRp7brHoYQdglX9YH2dtl15VSUdwS-M';
  final String _calendarId = 'en.indian%23holiday%40group.v.calendar.google.com';
  List<dynamic> _holidays = [];
  bool _isLoadingHolidays = false;
  StreamSubscription? _holidaySubscription;

  @override
  void initState() {
    super.initState();
    _attendanceStream = FirestoreService.userAttendanceCol(user?.email ?? '').snapshots();
    _listenHolidays();
  }

  @override
  void dispose() {
    _holidaySubscription?.cancel();
    super.dispose();
  }

  void _listenHolidays() {
    setState(() => _isLoadingHolidays = true);
    try {
      final cid = FirestoreService.companyId;
      _holidaySubscription?.cancel();
      _holidaySubscription = FirebaseFirestore.instance
          .collection('approved_companies')
          .doc(cid)
          .collection('company_calendar')
          .snapshots()
          .listen((snapshot) {
        final List<dynamic> parsed = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final date = (data['date'] as Timestamp).toDate();
          parsed.add({
            'summary': data['reason'] ?? (data['type'] == 'leave' ? 'Company Holiday' : 'WFH Day'),
            'start': {'date': DateFormat('yyyy-MM-dd').format(date)},
            'type': data['type'], // 'leave' or 'wfh'
            'isCompanyEvent': true,
          });
        }

        parsed.sort((a, b) {
          final dateA = DateTime.parse(a['start']?['date'] ?? a['start']?['dateTime']);
          final dateB = DateTime.parse(b['start']?['date'] ?? b['start']?['dateTime']);
          return dateA.compareTo(dateB);
        });

        if (mounted) {
          setState(() {
            _holidays = parsed;
            _isLoadingHolidays = false;
          });
        }
      }, onError: (e) {
        debugPrint('Error listening to company holidays: $e');
        if (mounted) setState(() => _isLoadingHolidays = false);
      });
    } catch (e) {
      debugPrint('Error listening to company holidays: $e');
      if (mounted) setState(() => _isLoadingHolidays = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context) ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ) : null,
        title: Text('My Attendance', style: AppTheme.h1.copyWith(fontSize: 18)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirestoreService.userStreamByEmail(user?.email ?? ''),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data() as Map<String, dynamic>?;
          final DateTime? createdAt = (userData?['createdAt'] as Timestamp?)?.toDate();

          return StreamBuilder<QuerySnapshot>(
            stream: _attendanceStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              // Parse records
              final Map<String, String> attendanceMap = {};
              final currentMonthRecords = [];
              
              DateTime? firstCheckIn;

              for (var doc in snapshot.data!.docs) {
                final dateStr = doc.id;
                final data = doc.data() as Map<String, dynamic>?;
                
                final date = DateTime.tryParse(dateStr);
                if (date != null) {
                  // Track earliest record
                  final dateTs = data?['date'] as Timestamp? ?? data?['checkIn'] as Timestamp?;
                  if (dateTs != null) {
                    final d = dateTs.toDate();
                    if (firstCheckIn == null || d.isBefore(firstCheckIn)) {
                      firstCheckIn = d;
                    }
                  }

                  // Check if it's WFH or regular Present
                  String status = 'Present';
                  if (data?['mode'] == 'WFH') status = 'WFH';
                  
                  attendanceMap[dateStr] = status;
                  
                  if (date.month == _focusedDay.month && date.year == _focusedDay.year) {
                    currentMonthRecords.add(data);
                  }
                }
              }

              final DateTime? effectiveStart = firstCheckIn ?? createdAt;

              int presentCount = 0;
              int lateCount = 0;

          for (var data in currentMonthRecords) {
            final checkIn = data['checkIn'] as Timestamp?;
            final remarkStatus = data['remarkStatus'] as String?;
            if (checkIn != null && remarkStatus != 'approved') {
              presentCount++;
              final time = checkIn.toDate();
              
              // Dynamic Late Calculation
              final parts = AppSession().shiftStartTime.split(':');
              final threshold = DateTime(time.year, time.month, time.day, 
                  int.parse(parts[0]), int.parse(parts[1]))
                  .add(Duration(minutes: AppSession().gracePeriod));
                  
              if (time.isAfter(threshold)) {
                lateCount++;
              }
            } else if (checkIn != null) {
              presentCount++;
            }
          }

          // Calculate working days passed
          final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
          int daysPassedInMonth = daysInMonth; 
          
          if (_focusedDay.month == DateTime.now().month && _focusedDay.year == DateTime.now().year) {
             daysPassedInMonth = DateTime.now().day;
          } else if (_focusedDay.isAfter(DateTime.now())) {
             daysPassedInMonth = 0;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.userLeaveRequestsCol(user?.email ?? '')
                .where('status', isEqualTo: 'approved')
                .snapshots(),
            builder: (context, leaveSnap) {
              final approvedLeaves = leaveSnap.data?.docs ?? [];
              final Set<String> leaveDates = {};
              
              for (var doc in approvedLeaves) {
                final d = doc.data() as Map<String, dynamic>;
                final start = (d['fromDate'] as Timestamp?)?.toDate();
                final end = (d['toDate'] as Timestamp?)?.toDate();
                if (start != null && end != null) {
                  DateTime curr = DateTime(start.year, start.month, start.day);
                  DateTime last = DateTime(end.year, end.month, end.day);
                  while (!curr.isAfter(last)) {
                    leaveDates.add(DateFormat('yyyy-MM-dd').format(curr));
                    curr = curr.add(const Duration(days: 1));
                  }
                }
              }

              int absentCount = 0;
              int leaveCount = 0;
              int workingDaysPassed = 0;

              for (int i = 1; i <= daysPassedInMonth; i++) {
                final d = DateTime(_focusedDay.year, _focusedDay.month, i);
                final dStr = DateFormat('yyyy-MM-dd').format(d);
                
                // Track weekends and holidays for exclusion
                bool isWeekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
                bool isHoliday = _holidays.any((h) {
                  final hStr = h['start']?['date'] ?? h['start']?['dateTime'];
                  bool sameDay = hStr != null && isSameDay(DateTime.parse(hStr), d);
                  if (sameDay && h['type'] == 'wfh') return false; // WFH is not a day off
                  return sameDay;
                });

                if (isWeekend || isHoliday) continue;

                // Stop counting if before effective join date
                if (effectiveStart != null) {
                   DateTime startDay = DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
                   if (d.isBefore(startDay)) continue;
                }

                // If not weekend/holiday and after join date, it's a net working day
                workingDaysPassed++;

                if (attendanceMap.containsKey(dStr)) {
                  // Present
                } else if (leaveDates.contains(dStr)) {
                  leaveCount++;
                } else {
                  absentCount++;
                }
              }

              double attendanceScore = (workingDaysPassed > 0) ? (presentCount / workingDaysPassed) * 100 : 0;
              
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       _buildCalendarCard(attendanceMap),
                       const SizedBox(height: 24),
                       if (_holidays.isNotEmpty) _buildNextHolidayBanner(),
                       const SizedBox(height: 32),
                       Text('${DateFormat('MMMM').format(_focusedDay)} Summary', style: AppTheme.h2.copyWith(fontSize: 18)),
                       const SizedBox(height: 16),
                       GridView.count(
                         shrinkWrap: true,
                         physics: const NeverScrollableScrollPhysics(),
                         crossAxisCount: 2,
                         childAspectRatio: 1.3,
                         crossAxisSpacing: 16,
                         mainAxisSpacing: 16,
                         children: [
                           _buildMetricCard('PRESENT', presentCount.toString(), Icons.check_circle_outline_rounded, const Color(0xFFEEF2FF), const Color(0xFF4F46E5), '+2%'),
                           _buildMetricCard('LATE', lateCount.toString(), Icons.access_time_rounded, const Color(0xFFFFFBEB), const Color(0xFFD97706), '0%'),
                           _buildMetricCard('ABSENT', absentCount.toString(), Icons.cancel_outlined, const Color(0xFFFEF2F2), const Color(0xFFDC2626), '-1%'),
                           _buildMetricCard('LEAVE', leaveCount.toString().padLeft(2, '0'), Icons.calendar_today_outlined, const Color(0xFFF0FDF4), const Color(0xFF16A34A), '+1%'),
                         ],
                       ),
                       const SizedBox(height: 24),
                       _buildAttendanceScoreCard(attendanceScore.toInt()),
                       const SizedBox(height: 32),
                       if (_holidays.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Upcoming Holidays', style: AppTheme.h2.copyWith(fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._buildUpcomingHolidaysList(),
                       ],
                       const SizedBox(height: 100),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  ),
);
}

  Widget _buildCalendarCard(Map<String, String> attendanceMap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            rowHeight: 48,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: AppTheme.h3.copyWith(fontSize: 16),
              leftChevronIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade100), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.chevron_left_rounded, size: 20, color: Colors.black),
              ),
              rightChevronIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade100), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.black),
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: AppTheme.bodySmall.copyWith(color: Colors.grey.shade400, fontWeight: FontWeight.bold),
              weekendStyle: AppTheme.bodySmall.copyWith(color: Colors.grey.shade400, fontWeight: FontWeight.bold),
            ),
            calendarStyle: CalendarStyle(
              todayTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              todayDecoration: const BoxDecoration(color: Color(0xFF5B67F5), shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(color: Color(0xFF5B67F5), shape: BoxShape.circle),
              defaultTextStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              weekendTextStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              outsideDaysVisible: false,
            ),
            onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
            eventLoader: (day) {
              final formattedString = DateFormat('yyyy-MM-dd').format(day);
              
              // Check if it's a holiday from our list
              final holiday = _holidays.firstWhere((h) {
                final dStr = h['start']?['date'] ?? h['start']?['dateTime'];
                if (dStr == null) return false;
                final hDate = DateTime.parse(dStr);
                return isSameDay(hDate, day);
              }, orElse: () => null);
              
              if (holiday != null) return [holiday['type'] == 'wfh' ? 'WFH' : 'Holiday'];
              
              return [];
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox();
                final event = events.first as String;
                
                // Only show markers for Holidays in Red, WFH in Green
                if (event == 'Holiday') {
                  return Positioned(
                    bottom: 6,
                    child: Container(
                      width: 4, height: 4,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    ),
                  );
                } else if (event == 'WFH') {
                  return Positioned(
                    bottom: 6,
                    child: Container(
                      width: 4, height: 4,
                      decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                    ),
                  );
                }
                
                return const SizedBox();
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _calendarLegend('Company Holiday', const Color(0xFFEF4444)),
                const SizedBox(width: 12),
                _calendarLegend('WFH Day', const Color(0xFF10B981)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _calendarLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: AppTheme.bodySmall.copyWith(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color bg, Color color, String trend) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(trend, style: TextStyle(color: trend.startsWith('+') ? Colors.green : (trend.startsWith('-') ? Colors.red : Colors.grey), fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.label.copyWith(fontSize: 10, color: Colors.grey.shade600)),
              Text(value, style: AppTheme.h1.copyWith(fontSize: 24)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceScoreCard(int score) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Pay Period', style: AppTheme.bodySmall.copyWith(color: const Color(0xFF16A34A), fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Attendance Score: $score%', style: AppTheme.h3),
            ],
          ),
          SizedBox(
            width: 48, height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: score / 100, strokeWidth: 4, backgroundColor: Colors.white, color: const Color(0xFF16A34A)),
                Text('$score', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextHolidayBanner() {
    final nextHoliday = _holidays.firstWhere((h) {
      final date = DateTime.parse(h['start']?['date'] ?? h['start']?['dateTime']);
      return date.isAfter(DateTime.now());
    }, orElse: () => null);

    if (nextHoliday == null) return const SizedBox();

    final date = DateTime.parse(nextHoliday['start']?['date'] ?? nextHoliday['start']?['dateTime']);
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(right: BorderSide(color: nextHoliday['type'] == 'wfh' ? const Color(0xFF10B981) : const Color(0xFFEF4444), width: 6)),
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nextHoliday['summary'] ?? 'Holiday', style: AppTheme.h3),
                const SizedBox(height: 4),
                Text(DateFormat('MMMM dd, yyyy').format(date), style: AppTheme.bodySmall),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                  child: Text(nextHoliday['type'] == 'wfh' ? 'Work From Home' : 'Company Holiday', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.flag_outlined, color: Color(0xFF3B82F6), size: 24),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildUpcomingHolidaysList() {
    final futures = _holidays.where((h) {
      final date = DateTime.parse(h['start']?['date'] ?? h['start']?['dateTime']);
      return date.isAfter(DateTime.now());
    }).take(3);

    return futures.map((h) {
      final date = DateTime.parse(h['start']?['date'] ?? h['start']?['dateTime']);
      return _buildHolidayItem(
        h['summary'] ?? 'Holiday', 
        DateFormat('MMM dd').format(date).toUpperCase(), 
        'Public Holiday • ${DateFormat('EEEE').format(date)}', 
        const Color(0xFFEEF2FF), 
        const Color(0xFF4F46E5)
      );
    }).toList();
  }

  Widget _buildHolidayItem(String title, String date, String sub, Color bg, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Text(date.split(' ')[0], style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700)),
                Text(date.split(' ')[1], style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text(sub, style: AppTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
        ],
      ),
    );
  }
}
