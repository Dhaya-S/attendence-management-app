import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StreakCard extends StatelessWidget {
  final List<DateTime> checkInDates;
  const StreakCard({super.key, required this.checkInDates});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = List.generate(7, (i) => firstDayOfWeek.add(Duration(days: i)));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFD9E2FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBanner(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F4FF),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays.map((date) => _dayColumn(date, checkInDates)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      height: 120, // Specific height for the banner area
      decoration: const BoxDecoration(
        color: Color(0xFFD9E2FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        image: DecorationImage(
          image: AssetImage('assets/streak_celebration.png'),
          fit: BoxFit.cover,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
            child: const Text('KEEP THE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4361EE), letterSpacing: 1))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
            child: const Text('STREAK GOING', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.1, color: Color(0xFF4361EE)))),
        ],
      ),
    );
  }

  Widget _dayColumn(DateTime date, List<DateTime> attendance) {
    final isToday = _isSameDay(date, DateTime.now());
    final isCheckedIn = attendance.where((d) {
      try {
        return _isSameDay(d, date);
      } catch (_) {
        return false;
      }
    }).isNotEmpty;
    final label = DateFormat('E').format(date);
    final dayNum = date.day.toString();

    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: isToday ? const Color(0xFF4361EE) : const Color(0xFF94A3B8), fontWeight: isToday ? FontWeight.w900 : FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCheckedIn ? const Color(0xFFF59E0B) : Colors.white,
          ),
          child: Center(
            child: isCheckedIn 
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
              : Text(dayNum, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
