import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class OvertimeTrackerScreen extends StatelessWidget {
  const OvertimeTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Overtime Tracker', style: AppTheme.h1.copyWith(fontSize: 18)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.userOvertimeRequestsCol(user?.email ?? '')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          
          // Sort manually if needed to avoid index issues initially
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = (aData['requestDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final bDate = (bData['requestDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });

          final totalOvertime = _calculateTotalOvertime(docs);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overtime', style: AppTheme.h1.copyWith(fontSize: 32)),
                  Text('Track your extra working hours', style: AppTheme.bodySmall),
                  const SizedBox(height: 32),
                  _buildTotalOvertimeCard(totalOvertime),
                  const SizedBox(height: 32),
                  _buildWeeklyBreakdown(docs),
                  const SizedBox(height: 32),
                  _buildDailyAnalysis(docs),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _calculateTotalOvertime(List<QueryDocumentSnapshot> docs) {
    int totalMinutes = 0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'approved') {
        totalMinutes += (data['durationInMinutes'] as int? ?? 0);
      }
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Widget _buildTotalOvertimeCard(String total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          Text('TOTAL OVERTIME (APPROVED)', style: AppTheme.label.copyWith(fontSize: 10, letterSpacing: 1, color: AppTheme.textHint)),
          const SizedBox(height: 12),
          Text(total, style: AppTheme.h1.copyWith(fontSize: 48, color: AppTheme.primary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, color: AppTheme.success, size: 14),
                const SizedBox(width: 6),
                Text('Real-time Verified', style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBreakdown(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // Initialize 4 weeks for the current month
    Map<int, int> weeklyMinutes = {1: 0, 2: 0, 3: 0, 4: 0};
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] != 'approved') continue;
      
      final date = (data['requestDate'] as Timestamp?)?.toDate();
      if (date == null || date.month != currentMonth || date.year != currentYear) continue;

      // Determine week of month (1-31) -> (1-4)
      int week = ((date.day - 1) ~/ 7) + 1;
      if (week > 4) week = 4;
      
      weeklyMinutes[week] = (weeklyMinutes[week] ?? 0) + (data['durationInMinutes'] as int? ?? 0);
    }

    // Calculate trend: Current week vs Last week
    int currentWeekNum = ((now.day - 1) ~/ 7) + 1;
    if (currentWeekNum > 4) currentWeekNum = 4;
    
    int prevWeekNum = currentWeekNum > 1 ? currentWeekNum - 1 : 1;
    int currentWeekTotal = weeklyMinutes[currentWeekNum] ?? 0;
    int prevWeekTotal = weeklyMinutes[prevWeekNum] ?? 0;
    int diffMinutes = currentWeekTotal - prevWeekTotal;
    
    String trendText = diffMinutes >= 0 
        ? '+${diffMinutes ~/ 60}h ${diffMinutes % 60}m from last week'
        : '-${(-diffMinutes) ~/ 60}h ${(-diffMinutes) % 60}m from last week';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Weekly Breakdown', style: AppTheme.h3),
            if (currentWeekTotal > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: Colors.orange.shade700, size: 10),
                    const SizedBox(width: 4),
                    Text(trendText, style: TextStyle(color: Colors.orange.shade700, fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            children: [
              for (int w = 1; w <= 4; w++) ...[
                _breakdownRow(
                  'Week $w', 
                  '${weeklyMinutes[w]! ~/ 60}h ${weeklyMinutes[w]! % 60}m', 
                  (weeklyMinutes[w]! / 600).clamp(0.0, 1.0) // Assume a max of 10h per week for the bar
                ),
                if (w < 4) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _breakdownRow(String label, String value, double percent) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            Text(value, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percent,
          backgroundColor: AppTheme.primary.withOpacity(0.05),
          color: AppTheme.primary,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildDailyAnalysis(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    List<int> dailyMinutes = List.filled(7, 0);
    List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] != 'approved') continue;
      
      final date = (data['requestDate'] as Timestamp?)?.toDate();
      if (date == null) continue;
      
      if (date.year == startOfWeek.year && date.month == startOfWeek.month && date.day >= startOfWeek.day && date.day <= startOfWeek.day + 6) {
         int dayIndex = date.weekday - 1;
         dailyMinutes[dayIndex] += (data['durationInMinutes'] as int? ?? 0);
      }
    }

    int maxMins = dailyMinutes.fold(1, (max, e) => e > max ? e : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Analysis (This Week)', style: AppTheme.h3),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            children: List.generate(7, (i) {
               double fill = dailyMinutes[i] / maxMins;
               String val = dailyMinutes[i] == 0 ? '-' : '${dailyMinutes[i] ~/ 60}h ${dailyMinutes[i] % 60}m';
               return Padding(
                 padding: EdgeInsets.only(bottom: i < 6 ? 16 : 0),
                 child: Row(
                   children: [
                     SizedBox(width: 30, child: Text(days[i], style: AppTheme.label.copyWith(fontSize: 10))),
                     const SizedBox(width: 12),
                     Expanded(
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(4),
                         child: LinearProgressIndicator(
                           value: fill,
                           minHeight: 12,
                           backgroundColor: AppTheme.primary.withOpacity(0.05),
                           valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                         ),
                       ),
                     ),
                     const SizedBox(width: 12),
                     SizedBox(width: 50, child: Text(val, textAlign:TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                   ],
                 )
               );
            }),
          ),
        ),
      ],
    );
  }
}
