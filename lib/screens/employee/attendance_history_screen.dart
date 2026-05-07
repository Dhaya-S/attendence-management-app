import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final String? userId;
  final String? userName;

  const AttendanceHistoryScreen({super.key, this.userId, this.userName});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.userStreamByEmail(userEmail),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final currentEmail = userData?['email'] as String? ?? userEmail;
        final targetEmail = widget.userId?.contains('@') == true ? widget.userId : currentEmail;
        final DateTime? createdAt = (userData?['createdAt'] as Timestamp?)?.toDate();

        return Scaffold(
          backgroundColor: AppTheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: AppTheme.textPrimary, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Column(
              children: [
                Text('Attendance History', style: AppTheme.h3),
                if (widget.userName != null)
                  Text(widget.userName!, style: AppTheme.label.copyWith(fontSize: 10, color: AppTheme.primary)),
              ],
            ),
            centerTitle: true,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.userAttendanceCol(targetEmail ?? userEmail)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
                        const SizedBox(height: 16),
                        Text('Failed to load history', style: AppTheme.h3),
                        const SizedBox(height: 8),
                        Text(snapshot.error.toString(), 
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;
              final stats = _calculateStats(docs, createdAt);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMonthlyPerformance(stats),
                      const SizedBox(height: 24),
                      _buildMonthSelector(),
                      const SizedBox(height: 24),
                      _buildDetailedLogs(docs),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Map<String, dynamic> _calculateStats(List<QueryDocumentSnapshot> docs, DateTime? createdAt) {
    int presentDays = 0;
    int lateArrivals = 0;
    double totalHours = 0;

    // Parse selected month/year
    final parts = selectedMonth.split(' ');
    final monthName = parts[0];
    final year = int.parse(parts[1]);
    final month = _monthNumberFromName(monthName);

    // Find first check-in from all docs
    DateTime? firstCheckIn;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dateTs = data['date'] as Timestamp? ?? data['checkIn'] as Timestamp?;
      if (dateTs != null) {
        final d = dateTs.toDate();
        if (firstCheckIn == null || d.isBefore(firstCheckIn)) {
          firstCheckIn = d;
        }
      }
    }

    DateTime? effectiveStart = firstCheckIn ?? createdAt;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dateTs = data['date'] as Timestamp? ?? data['checkIn'] as Timestamp?;
      if (dateTs == null) continue;
      
      final date = dateTs.toDate();
      
      if (date.month == month && date.year == year) {
        presentDays++;
        
        final checkIn = data['checkIn'] as Timestamp?;
        final remarkStatus = data['remarkStatus'] as String?;
        if (checkIn != null && remarkStatus != 'approved') {
          final time = checkIn.toDate();
          if (time.hour > 9 || (time.hour == 9 && time.minute > 15)) {
            lateArrivals++;
          }
        }

        final checkOut = data['checkOut'] as Timestamp?;
        if (checkIn != null && checkOut != null) {
          final diff = checkOut.toDate().difference(checkIn.toDate());
          totalHours += diff.inMinutes / 60;
        }
      }
    }

    int workingDays = 0;
    int daysInMonth = DateTime(year, month + 1, 0).day;
    DateTime today = DateTime.now();

    for (int i = 1; i <= daysInMonth; i++) {
       DateTime currentDay = DateTime(year, month, i);
       if (currentDay.isAfter(today)) continue;
       if (effectiveStart != null) {
         DateTime startDay = DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
         if (currentDay.isBefore(startDay)) continue;
       }
       if (currentDay.weekday < 6) workingDays++;
    }

    final avgHours = presentDays > 0 ? totalHours / presentDays : 0.0;
    return {
      'present': presentDays,
      'totalDays': workingDays,
      'late': lateArrivals,
      'avgHours': avgHours,
    };
  }

  int _monthNumberFromName(String name) {
    return [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ].indexOf(name) + 1;
  }

  int _daysInMonth(int month, int year) {
    return DateTime(year, month + 1, 0).day;
  }

  Widget _buildMonthlyPerformance(Map<String, dynamic> stats) {
    final double percent = stats['present'] / stats['totalDays'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MONTHLY PERFORMANCE', style: AppTheme.label.copyWith(fontSize: 10)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Days Present', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                        const Icon(Icons.trending_up_rounded, color: AppTheme.success, size: 14),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${stats['present']}/${stats['totalDays']}', style: AppTheme.h1.copyWith(fontSize: 24)),
                    const SizedBox(height: 12),
                    LinearPercentIndicator(
                      padding: EdgeInsets.zero,
                      percent: percent.clamp(0.0, 1.0),
                      lineHeight: 6,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      progressColor: AppTheme.primary,
                      barRadius: const Radius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Late Arrivals', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 14),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(stats['late'].toString().padLeft(2, '0'), style: AppTheme.h1.copyWith(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text('Late > 09:15 AM', style: AppTheme.bodySmall.copyWith(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 48, color: AppTheme.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _perfCol('Average Daily Hours', 
                '${stats['avgHours'].floor()}h ${((stats['avgHours'] % 1) * 60).toInt()}m', 
                'Tracking Real-time', 
                Icons.access_time_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _perfCol(String label, String val, String sub, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.05), shape: BoxShape.circle),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.bodySmall),
            Row(
              children: [
                Text(val, style: AppTheme.h2),
                const SizedBox(width: 8),
                Text(sub, style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return DateFormat('MMMM yyyy').format(d);
    });
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          bool isSelected = selectedMonth == months[index];
          return GestureDetector(
            onTap: () => setState(() => selectedMonth = months[index]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
              ),
              child: Text(months[index], style: TextStyle(color: isSelected ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailedLogs(List<QueryDocumentSnapshot> docs) {
    // Filter docs by selected month/year
    final parts = selectedMonth.split(' ');
    final month = _monthNumberFromName(parts[0]);
    final year = int.parse(parts[1]);

    final filteredDocs = docs.where((doc) {
      final date = DateTime.parse(doc.id);
      return date.month == month && date.year == year;
    }).toList();

    if (filteredDocs.isEmpty) return Center(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Text('No logs found for $selectedMonth', style: AppTheme.bodySmall),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DETAILED LOGS', style: AppTheme.label.copyWith(fontSize: 10)),
        const SizedBox(height: 16),
        Column(
          children: filteredDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final checkIn = data['checkIn'] as Timestamp?;
            final checkOut = data['checkOut'] as Timestamp?;
            
            // Re-calculate duration string
            String total = '--:--';
            if (checkIn != null && checkOut != null) {
              final diff = checkOut.toDate().difference(checkIn.toDate());
              total = '${diff.inHours}h ${diff.inMinutes % 60}m';
            }

            final date = DateTime.parse(doc.id);
            final status = data['status'] == 'checked_out' ? 'PRESENT' : 'ON DUTY';
            final workMode = data['workMode'] == 'wfh' ? 'WFH' : 'OFFICE';
            final displayStatus = '$status ($workMode)';
            final color = status == 'PRESENT' ? AppTheme.success : AppTheme.warning;

            return _logCard(
              DateFormat('MMM dd').format(date).toUpperCase(),
              DateFormat('EEEE').format(date),
              checkIn != null ? DateFormat('hh:mm a').format(checkIn.toDate()) : '--:--',
              checkOut != null ? DateFormat('hh:mm a').format(checkOut.toDate()) : '--:--',
              total,
              displayStatus,
              color,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _logCard(String date, String day, String inTime, String outTime, String total, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: AppTheme.label.copyWith(fontSize: 10, color: AppTheme.textHint)),
                  Text(day, style: AppTheme.h3.copyWith(fontSize: 16)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(status, style: AppTheme.label.copyWith(fontSize: 8, color: statusColor)),
              ),
            ],
          ),
          const Divider(height: 32, color: AppTheme.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _logTime('CHECK IN', inTime),
              _logTime('CHECK OUT', outTime),
              _logTime('TOTAL HOURS', total, isBold: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _logTime(String label, String val, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.label.copyWith(fontSize: 8, color: AppTheme.textHint)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: AppTheme.textPrimary)),
      ],
    );
  }
}
