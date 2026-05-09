import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/features/attendance/screens/manager/top_employees_screen.dart';
import 'package:attendance_app/features/attendance/screens/manager/monthly_absence_screen.dart';
import 'package:attendance_app/features/attendance/screens/manager/late_early_exit_screen.dart';
import 'package:attendance_app/features/attendance/screens/manager/overtime_report_screen.dart';

class ManagerReportsTab extends StatefulWidget {
  final Function(int)? onTabChange;
  const ManagerReportsTab({super.key, this.onTabChange});

  @override
  State<ManagerReportsTab> createState() => _ManagerReportsTabState();
}
class _ManagerReportsTabState extends State<ManagerReportsTab> {
  static const Color _indigo = Color(0xFF6366F1);
  static const Color _teal = Color(0xFF10B981);
  static const Color _rose = Color(0xFFF43F5E);
  static const Color _slate = Color(0xFF1E293B);
  static const Color _violet = Color(0xFF8B5CF6);
  DateTime _currentDate = DateTime.now();

  void _previousMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
    });
  }

  String get _monthName => DateFormat('MMMM yyyy').format(_currentDate);

  late final Stream<QuerySnapshot> _usersStream =
      FirestoreService.companyUsersQuery.snapshots();
  late final Stream<QuerySnapshot> _recordsStream =
      FirestoreService.allAttendanceRecordsCol.snapshots();

  @override
  Widget build(BuildContext context) {
    DateTime startOfMonth = DateTime(_currentDate.year, _currentDate.month, 1);
    DateTime endOfMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0);
    String startStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
    String endStr = DateFormat('yyyy-MM-dd').format(endOfMonth);
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (context, usersSnap) {
        if (usersSnap.hasError) return const Scaffold(body: Center(child: Text('Service Unavailable')));
        if (usersSnap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final usersDocs = usersSnap.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: _recordsStream,
          builder: (context, allRecordsSnap) {
            // Filter everything in-memory to solve all index issues once and for all
            final startOfMonthDt = DateTime(startOfMonth.year, startOfMonth.month, startOfMonth.day);
            final endOfMonthDt = DateTime(endOfMonth.year, endOfMonth.month, endOfMonth.day, 23, 59, 59);

            final allDocs = allRecordsSnap.data?.docs ?? [];
            final allMonthRecords = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final dateTs = data['date'] as Timestamp?;
              if (dateTs == null) return false;
              if (data['status'] == 'DUMMY_NONE') return false;

              final date = dateTs.toDate();
              return !date.isBefore(startOfMonthDt) && !date.isAfter(endOfMonthDt);
            }).toList();
            final todayRecords = allMonthRecords.where((r) {
              final data = r.data() as Map<String, dynamic>;
              if (data['recordDate'] == todayStr) return true;
              // Fallback to doc ID if recordDate missing
              return r.id == todayStr;
            }).toList();

            // Calculate first check-in for every employee to determine effective joining date
            // The user wants to avoid showing "Absent" for days BEFORE their first ever check-in.
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

            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 18),
                  onPressed: () async {
                    final didPop = await Navigator.maybePop(context);
                    if (!didPop) {
                      widget.onTabChange?.call(0);
                    }
                  },
                ),
                centerTitle: true,
                title: const Text('Reports', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              body: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildMonthSelector(),
                    const SizedBox(height: 24),
                    _buildAttendanceRateCard(usersDocs, allMonthRecords, firstCheckInDates),
                    const SizedBox(height: 16),
                    _buildAvgHoursCard(allMonthRecords),
                    const SizedBox(height: 32),
                    _buildTopEmployeesSection(usersDocs, allMonthRecords, firstCheckInDates),
                    const SizedBox(height: 32),
                    _buildLateSection(context, usersDocs, allMonthRecords),
                    const SizedBox(height: 32),
                    _buildMonthlyAbsenceSection(context, usersDocs, allMonthRecords, firstCheckInDates),
                    const SizedBox(height: 32),
                    _buildOvertimeSection(context, usersDocs, allMonthRecords),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: Icon(Icons.chevron_left_rounded, color: Colors.grey[400]), onPressed: _previousMonth),
          Column(
            children: [
              Text('Select Month', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(_monthName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _slate)),
            ],
          ),
          IconButton(icon: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]), onPressed: _nextMonth),
        ],
      ),
    );
  }

  Widget _buildAttendanceRateCard(List<QueryDocumentSnapshot> usersDocs, List<QueryDocumentSnapshot> records, Map<String, DateTime> firstCheckInDates) {
    double rate = 0.0;
    int maxPossible = 0;
    for (var u in usersDocs) {
      final data = u.data() as Map<String, dynamic>;
      if ((data['role']?.toString().toLowerCase() ?? 'employee') != 'employee') continue;
      
      DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      DateTime? firstCheckIn = firstCheckInDates[u.id];
      maxPossible += _getWorkingDaysForUser(_currentDate.year, _currentDate.month, createdAt, firstCheckIn);
    }
    
    int totalRecords = records.length;
    rate = (maxPossible > 0) ? ((totalRecords / maxPossible) * 100.0).clamp(0.0, 100.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: _indigo.withOpacity(0.06), blurRadius: 40, offset: const Offset(0, 20))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance Rate', style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                const SizedBox(height: 10),
                Text('${rate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: _slate, letterSpacing: -1)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded, size: 16, color: _teal),
                    const SizedBox(width: 4),
                    Text('+2.1% from last month', style: TextStyle(fontSize: 11, color: _teal, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _miniBar(0.4, _indigo.withOpacity(0.1)),
              _miniBar(0.6, _indigo.withOpacity(0.2)),
              _miniBar(0.5, _indigo.withOpacity(0.3)),
              _miniBar(1.0, _indigo.withOpacity(0.7)),
              _miniBar(0.8, _indigo),
              _miniBar(0.9, _indigo.withOpacity(0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBar(double heightFactor, Color color) {
    return Container(
      width: 14, // Slightly wider for better visibility
      height: 60 * heightFactor, // Taller bars
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        boxShadow: [
          if (heightFactor > 0.7)
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
    );
  }

  Widget _buildAvgHoursCard(List<QueryDocumentSnapshot> records) {
    double totalHours = 0;
    int presentCount = 0;
    for (var doc in records) {
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final checkIn = data['checkIn'] as Timestamp?;
      final checkOut = data['checkOut'] as Timestamp?;
      if (checkIn != null) {
        presentCount++;
        if (checkOut != null) {
          totalHours += checkOut.toDate().difference(checkIn.toDate()).inMinutes / 60.0;
        }
      }
    }
    double avgHours = (presentCount > 0) ? totalHours / presentCount : 0.0;
    final sParts = AppSession().shiftStartTime.split(':');
    final eParts = AppSession().shiftEndTime.split(':');
    final startH = int.parse(sParts[0]) + int.parse(sParts[1]) / 60.0;
    final endH = int.parse(eParts[0]) + int.parse(eParts[1]) / 60.0;
    final shiftHours = (endH - startH).clamp(1.0, 24.0);
    double progress = (avgHours / shiftHours).clamp(0.0, 1.0);
    final targetLabel = '${shiftHours.toStringAsFixed(1)}H';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: _teal.withOpacity(0.06), blurRadius: 40, offset: const Offset(0, 20))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Avg. Working Hours', style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                const SizedBox(height: 10),
                Text('${avgHours.toStringAsFixed(1)}h', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: _slate, letterSpacing: -1)),
                const SizedBox(height: 8),
                Text(
                  (avgHours >= shiftHours) ? 'ON TRACK (TARGET ${targetLabel})' : 'BELOW TARGET (TARGET ${targetLabel})',
                  style: TextStyle(fontSize: 11, color: (avgHours >= shiftHours) ? _teal : _rose, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: _teal.withOpacity(0.1),
                  color: _teal,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _slate)),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildTopEmployeesSection(List<QueryDocumentSnapshot> usersDocs, List<QueryDocumentSnapshot> records, Map<String, DateTime> firstCheckInDates) {
    // Map to store various metrics for each user
    Map<String, double> scores = {};
    Map<String, int> attendanceCounts = {};
    
    for (var doc in records) {
      // Path: attendance/{uid}/records/{date}
      // doc.reference.parent is 'records' collection
      // doc.reference.parent.parent is the employee document {uid}
      final String? uid = doc.reference.parent.parent?.id;
      if (uid == null) continue;
      
      if (uid == null) continue;

      final data = doc.data() as Map<String, dynamic>;
      double userScore = scores[uid] ?? 0.0;
      attendanceCounts[uid] = (attendanceCounts[uid] ?? 0) + 1;

      userScore += 10.0; // Base points per record

      final checkInTs = data['checkIn'] as Timestamp?;
      if (checkInTs != null) {
        final checkIn = checkInTs.toDate();
        
        final parts = AppSession().shiftStartTime.split(':');
        final targetIn = DateTime(checkIn.year, checkIn.month, checkIn.day, 
            int.parse(parts[0]), int.parse(parts[1]));
        final lateThreshold = targetIn.add(Duration(minutes: AppSession().gracePeriod));

        if (checkIn.isBefore(targetIn) || checkIn.isAtSameMomentAs(targetIn)) {
          userScore += 5.0; 
        } else if (checkIn.isAfter(lateThreshold)) {
          userScore -= 2.0; 
        }
      }

      final checkOutTs = data['checkOut'] as Timestamp?;
      if (checkOutTs != null) {
        final checkOut = checkOutTs.toDate();
        final eParts = AppSession().shiftEndTime.split(':');
        final targetOut = DateTime(checkOut.year, checkOut.month, checkOut.day,
            int.parse(eParts[0]), int.parse(eParts[1]));
        if (checkOut.isAfter(targetOut)) {
          userScore += 5.0;
        }
      }
      scores[uid] = userScore;
    }

    List<Map<String, dynamic>> employeeRankings = [];

    for (var userDoc in usersDocs) {
      final uid = userDoc.id;
      final data = userDoc.data() as Map<String, dynamic>;
      if ((data['role']?.toString().toLowerCase() ?? 'employee') != 'employee') continue;

      DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      DateTime? firstCheckIn = firstCheckInDates[uid];
      int userWorkingDays = _getWorkingDaysForUser(_currentDate.year, _currentDate.month, createdAt, firstCheckIn);

      int count = attendanceCounts[uid] ?? 0;
      double scoreValue = scores[uid] ?? 0.0;
      double attendancePercent = (userWorkingDays > 0) ? (count / userWorkingDays * 100) : 0.0;
      double finalScore = (scoreValue * 0.4) + (attendancePercent * 0.6);

      employeeRankings.add({
        'name': data['name'] ?? 'User',
        'imageUrl': data['profileImageUrl'] as String?,
        'score': finalScore.clamp(0.0, 100.0).toInt(),
        'attendance': attendancePercent.toInt(),
        'uid': uid,
      });
    }

    employeeRankings.sort((a, b) => b['score'].compareTo(a['score']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Top Employees', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _slate)),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TopEmployeesScreen()));
              },
              child: const Text('View All →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _indigo)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (employeeRankings.isEmpty || (employeeRankings.every((e) => e['score'] == 0))) 
            const Text('No ranking data found for this period', style: TextStyle(fontSize: 12, color: Colors.grey))
        else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: employeeRankings.take(3).map((emp) {
              int score = emp['score'];
              return _topPerformerCard(
                name: emp['name'],
                imageUrl: emp['imageUrl'],
                role: (score > 85) ? 'Top Performer' : 'Core Contributor',
                score: '$score%',
                color: (score > 85) ? _indigo : _violet,
                insight: 'Attendance: ${emp['attendance']}%',
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Text('Ranked by consistency, punctuality, and attendance %', style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _topPerformerCard({required String name, String? imageUrl, required String role, required String score, required Color color, required String insight}) {
    return Container(
      width: 220,
      height: 200,
      margin: const EdgeInsets.only(right: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.3), width: 2.5)),
                alignment: Alignment.center,
                child: ClipOval(
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? (imageUrl.startsWith('http')
                          ? Image.network(imageUrl, width: 52, height: 52, fit: BoxFit.cover)
                          : Image.memory(base64Decode(imageUrl), width: 52, height: 52, fit: BoxFit.cover))
                      : Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('VALUE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey[400], letterSpacing: 1)),
                  Text(score, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _slate)),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w900, color: _slate, fontSize: 14, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon((role == 'Top Performer') ? Icons.emoji_events_rounded : Icons.local_fire_department_rounded, size: 10, color: color),
                const SizedBox(width: 4),
                Text(role, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required bool isShowingAll, required VoidCallback onViewAll, required Widget child}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _slate)),
            TextButton(
              onPressed: onViewAll, 
              child: Text(
                isShowingAll ? 'SHOW LESS' : 'VIEW ALL', 
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _indigo)
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
          child: child,
        ),
      ],
    );
  }

  Widget _buildLateSection(BuildContext context, List<QueryDocumentSnapshot> usersDocs, List<QueryDocumentSnapshot> monthRecords) {
    List<Map<String, dynamic>> lateEmployees = [];
    for (var doc in monthRecords) {
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final checkInTs = data['checkIn'] as Timestamp?;
      if (checkInTs != null) {
        final checkIn = checkInTs.toDate();
        
        final parts = AppSession().shiftStartTime.split(':');
        final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day, 
            int.parse(parts[0]), int.parse(parts[1]))
            .add(Duration(minutes: AppSession().gracePeriod));
            
        if (checkIn.isAfter(lateThreshold)) {
          final uid = doc.reference.parent.parent?.id;
          final userMatches = usersDocs.where((u) => u.id == uid).toList();
          String userName = 'Employee';
          String? profileImageUrl;
          if (userMatches.isNotEmpty) {
            final userDataMap = userMatches.first.data() as Map<String, dynamic>?;
            userName = userDataMap?['name'] ?? 'Employee';
            profileImageUrl = userDataMap?['profileImageUrl'] as String?;
          }
          final recordDate = data['recordDate'] ?? DateFormat('MMM dd').format(checkIn);

          lateEmployees.add({
            'name': userName,
            'imageUrl': profileImageUrl,
            'time': DateFormat('hh:mm a').format(checkIn),
            'day': recordDate,
            'lateBy': '${checkIn.difference(lateThreshold).inMinutes} min',
            'sortDate': checkIn,
          });
        }
      }
    }

    // Sort by date descending (most recent first)
    lateEmployees.sort((a, b) => (b['sortDate'] as DateTime).compareTo(a['sortDate'] as DateTime));

    Widget content;
    if (lateEmployees.isEmpty) {
      content = const Text('No late arrivals this month', style: TextStyle(fontSize: 12, color: Colors.grey));
    } else {
      var displayList = lateEmployees.take(3).toList();
      content = Column(
        children: displayList.map((e) {
          return _listItem(e['name'], 'Late by ${e['lateBy']}', e['day'].toString(), Colors.orange, e['imageUrl']);
        }).toList(),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Late Arrivals (This Month)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _slate)),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LateEarlyExitScreen()));
              },
              child: const Text('See All →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _indigo)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: content,
        ),
      ],
    );
  }

  Widget _buildMonthlyAbsenceSection(BuildContext context, List<QueryDocumentSnapshot> usersDocs, List<QueryDocumentSnapshot> allMonthRecords, Map<String, DateTime> firstCheckInDates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Monthly Absence Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _slate)),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyAbsenceScreen()));
              },
              child: const Text('See All →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _indigo)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
          child: _buildMonthlyAbsentList(usersDocs, allMonthRecords, firstCheckInDates),
        ),
      ],
    );
  }

  Widget _buildOvertimeSection(BuildContext context, List<QueryDocumentSnapshot> usersDocs, List<QueryDocumentSnapshot> records) {
    Map<String, double> employeeOT = {};
    Map<String, Map<String, dynamic>> userLookup = {};
    
    // First, map all users for easy lookup
    for (var userDoc in usersDocs) {
      final data = userDoc.data() as Map<String, dynamic>;
      final role = (data['role'] ?? 'employee').toString().toLowerCase();
      if (role == 'employee') {
        userLookup[userDoc.id] = data;
      }
    }

    // Process records for overtime
    for (var doc in records) {
      final data = doc.data() as Map<String, dynamic>;
      final employeeId = data['userId'] ?? data['uid'] ?? doc.reference.parent.parent?.id;
      if (employeeId == null) continue;
      
      final checkInTs = data['checkIn'] as Timestamp?;
      final checkOutTs = data['checkOut'] as Timestamp?;
      
      if (checkInTs != null && checkOutTs != null) {
        final hours = checkOutTs.toDate().difference(checkInTs.toDate()).inMinutes / 60.0;
        final eParts = AppSession().shiftEndTime.split(':');
        final sParts = AppSession().shiftStartTime.split(':');
        final endH = int.parse(eParts[0]) + int.parse(eParts[1]) / 60.0;
        final startH = int.parse(sParts[0]) + int.parse(sParts[1]) / 60.0;
        final standardHours = endH - startH;
        if (hours > standardHours) {
          employeeOT[employeeId] = (employeeOT[employeeId] ?? 0.0) + (hours - standardHours);
          
          // Seed lookup from record data if not already present
          if (!userLookup.containsKey(employeeId) && data['userName'] != null) {
            userLookup[employeeId] = {
              'name': data['userName'],
              'profileImageUrl': data['userAvatar'], // Try common fallback field names
            };
          }
        }
      }
    }

    final sortedOT = employeeOT.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top3OT = sortedOT.take(3).toList();

    Widget content;
    if (top3OT.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No overtime recorded this month', style: TextStyle(fontSize: 12, color: Colors.grey))),
      );
    } else {
      content = Column(
        children: top3OT.map((e) {
          final hours = e.value;
          final userData = userLookup[e.key] ?? {};
          final name = userData['name'] ?? 'Employee';
          final imageUrl = userData['profileImageUrl'] as String?;
          
          return _listItem(
            name, 
            'Total Overtime: ${hours.toStringAsFixed(1)}h', 
            'Rank #${top3OT.indexOf(e) + 1}', 
            _indigo, 
            imageUrl
          );
        }).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Month Overtime Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _slate)),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OvertimeReportScreen()));
              },
              child: const Text('View All →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _indigo)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: content,
        ),
      ],
    );
  }

  Widget _buildMonthlyAbsentList(List<QueryDocumentSnapshot> usersDocs, List<QueryDocumentSnapshot> allMonthRecords, Map<String, DateTime> firstCheckInDates) {
    final now = _currentDate;
    
    // Count presence per UID
    Map<String, int> presenceCount = {};
    for (var doc in allMonthRecords) {
      final uid = doc.reference.parent.parent?.id;
      if (uid != null) {
        presenceCount[uid] = (presenceCount[uid] ?? 0) + 1;
      }
    }

    List<Map<String, dynamic>> absentSummary = [];
    for (var u in usersDocs) {
      final data = u.data() as Map<String, dynamic>;
      if ((data['role']?.toString().toLowerCase() ?? 'employee') != 'employee') continue;
      
      DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      DateTime? firstCheckIn = firstCheckInDates[u.id];
      int userWorkingDays = _getWorkingDaysForUser(now.year, now.month, createdAt, firstCheckIn);
      
      final int presentDays = presenceCount[u.id] ?? 0;
      final int absentDays = (userWorkingDays - presentDays).clamp(0, userWorkingDays);
      
      if (absentDays > 0) {
        absentSummary.add({
          'name': data['name'] ?? 'Employee',
          'imageUrl': data['profileImageUrl'] as String?,
          'absent': absentDays,
          'present': presentDays,
        });
      }
    }

    // Sort by most absences
    absentSummary.sort((a, b) => (b['absent'] as int).compareTo(a['absent'] as int));

    if (absentSummary.isEmpty) return const Text('No absences recorded this month', style: TextStyle(fontSize: 12, color: Colors.grey));
    
    var displayList = absentSummary.take(3).toList();
    return Column(
      children: displayList.map((e) {
        return _listItem(e['name'], '${e['absent']} Days Absent', '${e['present']} Days Present', _rose, e['imageUrl']);
      }).toList(),
    );
  }

  Widget _listItem(String name, String sub, String date, Color color, String? imageUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFF1F5F9), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? (imageUrl.startsWith('http')
                      ? Image.network(imageUrl, width: 44, height: 44, fit: BoxFit.cover)
                      : Image.memory(base64Decode(imageUrl), width: 44, height: 44, fit: BoxFit.cover))
                  : Text((name.isNotEmpty == true) ? name[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.w900, color: _indigo.withOpacity(0.6), fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w900, color: _slate, fontSize: 13, letterSpacing: -0.2)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 11, color: (sub.contains('Absent') == true) ? _rose : (Colors.grey[500] ?? Colors.grey), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: (date == 'Today' || date.contains('Today') == true) ? const Color(0xFFFFB800) : Colors.grey[300])),
                  const SizedBox(width: 8),
                  Text(date, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

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
      
      // Stop counting if the day is in the future
      if (currentDay.isAfter(today)) {
        continue;
      }
      
      // Only count days after or equal to their start date
      if (effectiveStart != null) {
         DateTime startDay = DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
         if (currentDay.isBefore(startDay)) continue;
      }
      
      if (currentDay.weekday < 6) workingDays++;
    }
    return workingDays;
  }
}
