import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class AllMilestonesScreen extends StatelessWidget {
  final int streak;
  const AllMilestonesScreen({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('All Milestones', style: AppTheme.h3),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _calculateDeepStats(user?.email),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final stats = snapshot.data!;
          final milestones = _getMilestoneData(stats);
          final earnedMilestones = milestones.where((m) => m['isCompleted']).toList();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStreakHeader(streak),
                const SizedBox(height: 32),
                if (earnedMilestones.isNotEmpty) ...[
                  _buildBadgesEarnedSection(earnedMilestones),
                  const SizedBox(height: 32),
                ],
                _buildAllMilestonesSection(milestones),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _calculateDeepStats(String? email) async {
    if (email == null || email.isEmpty) return {};

    final attendanceSnap = await FirestoreService.userAttendanceCol(email).get();
    final overtimeSnap = await FirestoreService.userOvertimeRequestsCol(email).get();

    int earlyBirds = 0;
    double totalHours = 0;
    for (var doc in attendanceSnap.docs) {
      final data = doc.data();
      final checkIn = data['checkIn'] as Timestamp?;
      final checkOut = data['checkOut'] as Timestamp?;
      
      if (checkIn != null) {
        if (checkIn.toDate().hour < 9) earlyBirds++;
        if (checkOut != null) {
          totalHours += checkOut.toDate().difference(checkIn.toDate()).inMinutes / 60;
        }
      }
    }

    int approvedOvertime = 0;
    for (var doc in overtimeSnap.docs) {
      if (doc.data()['status'] == 'approved') approvedOvertime++;
    }

    return {
      'present': attendanceSnap.docs.length,
      'earlyBirds': earlyBirds,
      'totalHours': totalHours,
      'overtimeCount': approvedOvertime,
    };
  }

  List<Map<String, dynamic>> _getMilestoneData(Map<String, dynamic> stats) {
    int present = stats['present'] ?? 0;
    int earlyBirds = stats['earlyBirds'] ?? 0;
    double totalHours = stats['totalHours'] ?? 0;
    int otCount = stats['overtimeCount'] ?? 0;

    return [
      {
        'id': 'perfect_month',
        'title': '1 Month Perfect Attendance',
        'sub': 'Check in every day for 30 days',
        'icon': Icons.star_rounded,
        'bg': const Color(0xFFFDF2F8),
        'color': const Color(0xFFDB2777),
        'isCompleted': present >= 30,
        'progress': (present / 30).clamp(0.0, 1.0),
      },
      {
        'id': 'hours_1000',
        'title': '1000 Hours Milestone',
        'sub': 'Log 1,000 hours of work',
        'icon': Icons.wb_sunny_rounded,
        'bg': const Color(0xFFFFFBEB),
        'color': const Color(0xFFD97706),
        'isCompleted': totalHours >= 1000,
        'progress': (totalHours / 1000).clamp(0.0, 1.0),
      },
      {
        'id': 'early_bird',
        'title': 'Early Bird',
        'sub': 'Clock in before 9 AM, 5 times',
        'icon': Icons.bolt_rounded,
        'bg': const Color(0xFFF0FDF4),
        'color': const Color(0xFF16A34A),
        'isCompleted': earlyBirds >= 5,
        'progress': (earlyBirds / 5).clamp(0.0, 1.0),
      },
      {
        'id': 'consistent',
        'title': 'Consistent Star',
        'sub': 'Maintain a 10-day streak',
        'icon': Icons.auto_awesome_rounded,
        'isCompleted': streak >= 10,
        'progress': (streak / 10).clamp(0.0, 1.0),
      },
      {
        'id': 'night_owl',
        'title': 'Night Owl',
        'sub': 'Log overtime on 10 occasions',
        'icon': Icons.nightlight_round,
        'isCompleted': otCount >= 10,
        'progress': (otCount / 10).clamp(0.0, 1.0),
      },
    ];
  }

  Widget _buildStreakHeader(int streak) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF7ED), shape: BoxShape.circle),
            child: Icon(Icons.local_fire_department_rounded, color: AppTheme.warning, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Streak', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                Text("Don't break the chain!", style: AppTheme.label.copyWith(fontSize: 10, color: AppTheme.textHint)),
              ],
            ),
          ),
          Text(streak.toString(), style: AppTheme.h1.copyWith(fontSize: 32, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildBadgesEarnedSection(List<Map<String, dynamic>> earned) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Badges earned', style: AppTheme.h3),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: earned.length,
            itemBuilder: (context, index) {
              final m = earned[index];
              return _badgeCard(m['title'], m['icon'], m['bg'] ?? AppTheme.surface, m['color'] ?? AppTheme.primary, false);
            },
          ),
        ),
      ],
    );
  }

  Widget _badgeCard(String label, IconData icon, Color bg, Color color, bool isNew) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.1))),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          if (isNew) Positioned(top: 0, right: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFDB2777), borderRadius: BorderRadius.circular(4)), child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildAllMilestonesSection(List<Map<String, dynamic>> milestones) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('All milestones', style: AppTheme.h3),
        const SizedBox(height: 16),
        ...milestones.map((m) => _milestoneTile(m['title'], m['sub'], m['icon'], m['isCompleted'], progress: m['progress'])),
      ],
    );
  }

  Widget _milestoneTile(String title, String sub, IconData icon, bool isCompleted, {double? progress}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCompleted ? AppTheme.primary.withOpacity(0.05) : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isCompleted ? AppTheme.primary : AppTheme.textHint, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                Text(sub, style: AppTheme.label.copyWith(fontSize: 8, color: AppTheme.textHint)),
              ],
            ),
          ),
          if (isCompleted) 
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20)
          else if (progress != null) 
            SizedBox(
              width: 60,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppTheme.surface,
                color: AppTheme.success,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
