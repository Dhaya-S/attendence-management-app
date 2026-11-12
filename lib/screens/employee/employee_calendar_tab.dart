import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/widgets/calendar_tab_view.dart';

/// "View Attendance Calendar" page (opened from Attendance → Overview → Quick Actions).
class EmployeeCalendarTab extends StatelessWidget {
  const EmployeeCalendarTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1.5)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: Color(0xFF1F2937)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Attendance Calendar',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937))),
                        const SizedBox(height: 2),
                        Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: CalendarTabView()),
          ],
        ),
      ),
    );
  }
}
