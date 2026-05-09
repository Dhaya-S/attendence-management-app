import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/widgets/live_attendance_builder.dart';

class TopEmployeesScreen extends StatefulWidget {
  const TopEmployeesScreen({super.key});

  @override
  State<TopEmployeesScreen> createState() => _TopEmployeesScreenState();
}

class _TopEmployeesScreenState extends State<TopEmployeesScreen> {
  static const Color _indigo = Color(0xFF6366F1);
  static const Color _teal = Color(0xFF10B981);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _slate = Color(0xFF1E293B);
  
  DateTime _currentDate = DateTime.now();
  String _selectedMetric = 'Highest Score'; // Highest Score, Most Hours, Best Attendance

  void _previousMonth() => setState(() => _currentDate = DateTime(_currentDate.year, _currentDate.month - 1));
  void _nextMonth() => setState(() => _currentDate = DateTime(_currentDate.year, _currentDate.month + 1));
  String get _monthName => DateFormat('MMMM yyyy').format(_currentDate);

  int _getWorkingDaysForUser(int year, int month, DateTime? createdAt) {
    int daysInMonth = DateTime(year, month + 1, 0).day;
    DateTime today = DateTime.now();
    int workingDays = 0;
    
    for (int i = 1; i <= daysInMonth; i++) {
      DateTime currentDay = DateTime(year, month, i);
      if (currentDay.isAfter(today)) continue;
      
      if (createdAt != null) {
         DateTime startDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
         if (currentDay.isBefore(startDay)) continue;
      }
      
      if (currentDay.weekday < 6) workingDays++;
    }
    return workingDays;
  }

  @override
  Widget build(BuildContext context) {
    DateTime startOfMonth = DateTime(_currentDate.year, _currentDate.month, 1);
    DateTime endOfMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0, 23, 59, 59);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text('Top Employees', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.companyUsersQuery.snapshots(),
        builder: (context, usersSnap) {
          if (!usersSnap.hasData) return const Center(child: CircularProgressIndicator());
          final usersDocs = usersSnap.data!.docs.where((u) {
            final d = u.data() as Map<String, dynamic>;
            return (d['role']?.toString().toLowerCase() ?? 'employee') == 'employee';
          }).toList();
          final uidToEmail = <String, String>{};
          final emailToUid = <String, String>{};
          for (var doc in usersDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final uid = data['uid'] as String?;
            if (uid != null) {
              uidToEmail[uid] = doc.id; // doc.id is email
              emailToUid[doc.id] = uid;
            }
          }

          final identifiers = <String>[
            ...usersDocs.map((u) => u.id), // All Emails
            ...uidToEmail.keys, // All UIDs
          ];

          return LiveAttendanceBuilder(
            userIds: identifiers,
            builder: (context, liveRecords) {
              final Map<String, bool> isLive = {};
              for (var r in liveRecords) {
                final id = r['userId'] as String?;
                final email = uidToEmail[id] ?? id;
                if (email != null) isLive[email] = true;
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.allAttendanceRecordsCol.snapshots(),
                builder: (context, recordsSnap) {
                  if (!recordsSnap.hasData) return const Center(child: CircularProgressIndicator());
                  final records = recordsSnap.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final dateTs = data['date'] as Timestamp?;
                    if (dateTs == null) return false;
                    if (data['status'] == 'DUMMY_NONE') return false;
                    final date = dateTs.toDate();
                    return !date.isBefore(startOfMonth) && !date.isAfter(endOfMonth);
                  }).toList();

                  // Calculate Metrics
                  Map<String, double> scores = {};
                  Map<String, int> attendanceCounts = {};
                  Map<String, double> workHours = {};
                  Map<String, int> earlyIns = {};

                  for (var doc in records) {
                    final String? rawId = doc.reference.parent.parent?.id;
                    final String? email = uidToEmail[rawId] ?? rawId;
                    if (email == null) continue;

                    final data = doc.data() as Map<String, dynamic>;
                    scores[email] = (scores[email] ?? 0.0) + 10.0;
                    attendanceCounts[email] = (attendanceCounts[email] ?? 0) + 1;

                    final checkInTs = data['checkIn'] as Timestamp?;
                    final checkOutTs = data['checkOut'] as Timestamp?;
                    
                    if (checkInTs != null) {
                      final checkIn = checkInTs.toDate();
                      final sParts = AppSession().shiftStartTime.split(':');
                      final targetIn = DateTime(checkIn.year, checkIn.month, checkIn.day,
                          int.parse(sParts[0]), int.parse(sParts[1]));
                      final lateBuffer = targetIn.add(Duration(minutes: AppSession().gracePeriod));
                      if (checkIn.isBefore(targetIn)) {
                        scores[email] = scores[email]! + 5.0;
                        earlyIns[email] = (earlyIns[email] ?? 0) + 1;
                      } else if (checkIn.isAfter(lateBuffer)) {
                        scores[email] = scores[email]! - 2.0;
                      }
                      
                      if (checkOutTs != null) {
                        final checkOut = checkOutTs.toDate();
                        workHours[email] = (workHours[email] ?? 0.0) + (checkOut.difference(checkIn).inMinutes / 60.0);
                        final eParts = AppSession().shiftEndTime.split(':');
                        final targetOut = DateTime(checkOut.year, checkOut.month, checkOut.day,
                            int.parse(eParts[0]), int.parse(eParts[1]));
                        if (checkOut.isAfter(targetOut)) scores[email] = scores[email]! + 5.0;
                      }
                    }
                  }

                  List<Map<String, dynamic>> rankings = [];
                  for (var userDoc in usersDocs) {
                    final uid = userDoc.id;
                    final data = userDoc.data() as Map<String, dynamic>;
                    
                    DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    int userWorkingDays = _getWorkingDaysForUser(_currentDate.year, _currentDate.month, createdAt);

                    int count = attendanceCounts[uid] ?? 0;
                    double rawScore = scores[uid] ?? 0.0;
                    double attendancePercent = (userWorkingDays > 0) ? (count / userWorkingDays * 100) : 0.0;
                    double finalScore = (rawScore * 0.4) + (attendancePercent * 0.6);
                    double hours = workHours[uid] ?? 0.0;
                    int earlyCount = earlyIns[uid] ?? 0;

                    rankings.add({
                      'name': data['name'] ?? 'Employee',
                      'score': finalScore.clamp(0.0, 100.0).toInt(),
                      'attendance': attendancePercent.toInt(),
                      'hours': hours.toInt(),
                      'earlyCount': earlyCount,
                      'uid': uid,
                      'designation': data['designation'] ?? 'Employee',
                      'absences': (userWorkingDays - count).clamp(0, userWorkingDays),
                      'isPresentToday': isLive[uid] ?? false,
                    });
                  }

                  // Sort based on selected metric
                  if (_selectedMetric == 'Highest Score') {
                    rankings.sort((a, b) => b['score'].compareTo(a['score']));
                  } else if (_selectedMetric == 'Most Hours') {
                    rankings.sort((a, b) => b['hours'].compareTo(a['hours']));
                  } else {
                    rankings.sort((a, b) => b['attendance'].compareTo(a['attendance']));
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildMonthSelector(),
                        const SizedBox(height: 32),
                        if (rankings.isNotEmpty) _buildRankingChart(rankings.take(5).toList()),
                        const SizedBox(height: 24),
                        if (rankings.isNotEmpty) _buildTopPerformerSpotlight(rankings.first),
                        const SizedBox(height: 24),
                        _buildMetricTabs(),
                        const SizedBox(height: 24),
                        ...rankings.map((emp) => _buildEmployeeRow(emp)),
                      ],
                    ),
                  );
                },
              );
            }
          );
        },
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              icon: Icon(Icons.chevron_left_rounded, color: Colors.grey[400]),
              onPressed: _previousMonth),
          Column(
            children: [
              Text('Select Month',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(_monthName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _slate)),
            ],
          ),
          IconButton(
              icon: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              onPressed: _nextMonth),
        ],
      ),
    );
  }

  Widget _buildRankingChart(List<Map<String, dynamic>> top5) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _indigo,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: _indigo.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Rankings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: top5.asMap().entries.map((entry) {
              int idx = entry.key;
              var emp = entry.value;
              double score = emp['score'].toDouble();
              // Normalize height: max 100
              double height = (score / 100) * 120;
              if (height < 10) height = 10;

              return Column(
                children: [
                   Text('${score.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                   const SizedBox(height: 8),
                   AnimatedContainer(
                     duration: Duration(milliseconds: 500 + (idx * 100)),
                     width: 40,
                     height: height,
                     decoration: BoxDecoration(
                       color: Colors.white.withOpacity(idx == 0 ? 1.0 : 0.4 - (idx * 0.05)),
                       borderRadius: BorderRadius.circular(12),
                     ),
                   ),
                   const SizedBox(height: 12),
                   Text(emp['name'].split(' ').first, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  Widget _buildTopPerformerSpotlight(Map<String, dynamic> topUser) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: _indigo.withOpacity(0.04), blurRadius: 40, offset: const Offset(0, 20))],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F5F9),
                  border: Border.all(color: _indigo, width: 4),
                ),
                alignment: Alignment.center,
                child: Text(
                  topUser['name'][0].toUpperCase(),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _indigo),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: _indigo,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(topUser['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _slate)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, size: 14, color: _indigo),
                const SizedBox(width: 4),
                const Text('TOP PERFORMER', style: TextStyle(color: _indigo, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${topUser['score']}%', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: _slate, height: 1)),
              const SizedBox(width: 8),
              Text('SCORE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _selectedMetric == 'Highest Score' ? 'Highest attendance score this month' : 
            _selectedMetric == 'Most Hours' ? '${topUser['hours']}h logged this month' :
            '${topUser['attendance']}% attendance rate',
            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['Highest Score', 'Most Hours', 'Best Attendance'].map((metric) {
          bool isActive = _selectedMetric == metric;
          return GestureDetector(
            onTap: () => setState(() => _selectedMetric = metric),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? Colors.transparent : Colors.grey[300]!, width: 1),
                boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))] : [],
              ),
              child: Text(
                metric,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isActive ? _slate : Colors.grey[500],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmployeeRow(Map<String, dynamic> emp) {
    // Determine tag
    Widget tag;
    if (emp['earlyCount'] > 5) {
      tag = _buildTag('Early Bird', Icons.bolt, const Color(0xFFEA580C));
    } else if (emp['hours'] > 150) {
      tag = _buildTag('${emp['hours']} Hours', Icons.schedule, const Color(0xFFD97706));
    } else if (emp['absences'] == 0) {
      tag = _buildTag('Perfect Attendance', Icons.check_circle, _teal);
    } else {
      tag = _buildTag('Regular', Icons.face, Colors.grey[600]!);
    }

    String displayValue = '';
    String displayLabel = '';
    
    if (_selectedMetric == 'Highest Score') {
      displayValue = '${emp['score']}%';
      displayLabel = 'ACCURACY';
    } else if (_selectedMetric == 'Most Hours') {
      displayValue = '${emp['hours']}h';
      displayLabel = 'TOTAL';
    } else {
      displayValue = '${emp['absences']}';
      displayLabel = 'ABSENCES';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  emp['name'][0].toUpperCase(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _slate),
                ),
              ),
              if (emp['isPresentToday'] == true)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emp['name'], style: const TextStyle(fontWeight: FontWeight.w900, color: _slate, fontSize: 16)),
                const SizedBox(height: 6),
                tag,
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(displayValue, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _slate)),
              Text(displayLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
