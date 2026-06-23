import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import 'all_milestones_screen.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

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
        title: Text('Awards & Achievements', style: AppTheme.h1.copyWith(fontSize: 18)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.userAttendanceCol(user?.email ?? '')
            .orderBy('checkIn', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          final stats = _calculateAchievements(docs);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('ACHIEVEMENTS', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -1)),
                   const SizedBox(height: 8),
                   Text('Track your attendance milestones and performance rewards.', style: AppTheme.bodySmall),
                   const SizedBox(height: 24),
                   _buildPill('${stats['unlockedCount']} Badges Earned', const Color(0xFFE0E7FF), const Color(0xFF4F46E5), Icons.emoji_events_rounded),
                   const SizedBox(height: 24),
                   _buildMainBadgeCard(stats['streak']),
                   const SizedBox(height: 24),
                   _buildNextAchievementProgress(stats['streak']),
                   const SizedBox(height: 32),
                   _buildBadgesGrid(context, stats),
                   const SizedBox(height: 32),
                   _buildPerformanceStats(stats),
                   const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _calculateAchievements(List<QueryDocumentSnapshot> docs) {
    int streak = 0;
    int lateArrivals = 0;
    int earlyBirds = 0;
    DateTime? lastDate;
    
    for (int i = 0; i < docs.length; i++) {
      final date = DateTime.parse(docs[i].id);
      final data = docs[i].data() as Map<String, dynamic>;
      
      if (lastDate == null) {
          streak = 1;
          lastDate = date;
      } else {
          final diff = lastDate.difference(date).inDays;
          if (diff == 1) {
              streak++;
              lastDate = date;
          } else if (diff > 1) {
              // Check if all skipped days were weekends
              bool onlyWeekends = true;
              for (int d = 1; d < diff; d++) {
                  if (lastDate.subtract(Duration(days: d)).weekday <= 5) {
                      onlyWeekends = false;
                      break;
                  }
              }
              if (onlyWeekends) {
                  streak++;
                  lastDate = date;
              } else {
                  break; // Gap!
              }
          }
      }

      final checkIn = data['checkIn'] as Timestamp?;
      if (checkIn != null) {
        final time = checkIn.toDate();
        final parts = AppSession().shiftStartTime.split(':');
        final shiftStart = DateTime(time.year, time.month, time.day,
            int.parse(parts[0]), int.parse(parts[1]));
        final lateThreshold = shiftStart.add(Duration(minutes: AppSession().gracePeriod));

        if (time.isBefore(shiftStart)) {
          earlyBirds++;
        } else if (time.isAfter(lateThreshold)) {
          lateArrivals++;
        }
      }
    }

    int unlocked = 0;
    if (streak >= 7) unlocked++; // Perfect Week
    if (earlyBirds >= 5) unlocked++; // Early Bird
    if (docs.length >= 30) unlocked++; // 1 Month

    return {
      'streak': streak,
      'present': docs.length,
      'late': lateArrivals,
      'earlyBirds': earlyBirds,
      'unlockedCount': unlocked,
    };
  }

  Widget _buildPill(String label, Color bg, Color text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: text, size: 14),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildMainBadgeCard(int streak) {
    String title = streak >= 5 ? '5 Day Perfect Attendance' : 'Start your streak!';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFFF97316), const Color(0xFFFB923C)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: Text(streak >= 5 ? 'EARNED' : 'IN PROGRESS', style: const TextStyle(color: Color(0xFFF97316), fontSize: 8, fontWeight: FontWeight.bold))),
              const SizedBox(height: 24),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text(streak >= 5 ? "You haven't missed a single clock-in this week. Keep the fire burning!" : "Complete 5 consecutive days to earn this badge.", style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5)),
            ],
          ),
          const Positioned(top: 0, right: 0, child: Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 40)),
        ],
      ),
    );
  }

  Widget _buildNextAchievementProgress(int streak) {
    int target = streak >= 10 ? 30 : 10;
    double progress = (streak / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEXT ACHIEVEMENT', style: AppTheme.label.copyWith(fontSize: 8)),
                  Text('$target Day Perfect Attendance', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ],
              ),
              Text('$streak/$target days', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress, backgroundColor: AppTheme.primary.withOpacity(0.05), color: AppTheme.primary, minHeight: 8, borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }

  Widget _buildBadgesGrid(BuildContext context, Map<String, dynamic> stats) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your Badges', style: AppTheme.h3),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllMilestonesScreen(streak: stats['streak']))),
              child: const Text('View All', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _badgeCard('Perfect Week', stats['streak'] >= 7 ? 'Unlocked' : 'Locked', Icons.star_outline_rounded, stats['streak'] >= 7, AppTheme.warning)),
            const SizedBox(width: 12),
            Expanded(child: _badgeCard('Early Bird', stats['earlyBirds'] >= 5 ? 'Unlocked' : 'Locked', Icons.wb_sunny_outlined, stats['earlyBirds'] >= 5, AppTheme.primary)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _badgeCard('1 Month Hero', stats['present'] >= 30 ? 'Unlocked' : 'Locked', Icons.workspace_premium_outlined, stats['present'] >= 30, AppTheme.success)),
            const SizedBox(width: 12),
            Expanded(child: _badgeCard('Team Player', 'Locked', Icons.group_outlined, false, AppTheme.textHint)),
          ],
        ),
      ],
    );
  }

  Widget _badgeCard(String label, String sub, IconData icon, bool isUnlocked, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          Stack(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.05), shape: BoxShape.circle), child: Icon(icon, color: isUnlocked ? color : AppTheme.textHint, size: 32)),
              if (!isUnlocked) Positioned(top: 0, right: 0, child: Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.textHint)),
            ],
          ),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
          Text(sub, style: AppTheme.label.copyWith(fontSize: 8, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  Widget _buildPerformanceStats(Map<String, dynamic> stats) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance Stats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem('${(stats['present'] > 0 ? (100 - (stats['late'] / stats['present'] * 100)).toInt() : 0)}%', 'ATTENDANCE'),
              _statItem(stats['streak'].toString(), 'MAX STREAK'),
              _statItem(stats['present'].toString(), 'TOTAL DAYS'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Color(0xFF5C5CFF), fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ],
    );
  }
}
