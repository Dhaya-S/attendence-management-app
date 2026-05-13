import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/screens/employee/home_tab.dart';
import 'package:attendance_app/screens/employee/attendance_tab.dart';
import 'package:attendance_app/screens/employee/leave_tab.dart';
import 'package:attendance_app/screens/employee/profile_tab.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    EmployeeHomeTab(),
    EmployeeAttendanceTab(),
    EmployeeLeaveTab(),
    EmployeeProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _tabs[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GNav(
              rippleColor: AppTheme.primary.withOpacity(0.1),
              hoverColor: AppTheme.primary.withOpacity(0.05),
              gap: 8,
              activeColor: AppTheme.primary,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: AppTheme.primary.withOpacity(0.1),
              color: AppTheme.textMuted,
              tabs: const [
                GButton(
                  icon: Icons.home_rounded,
                  text: 'Home',
                ),
                GButton(
                  icon: Icons.access_time_filled_rounded,
                  text: 'Attendance',
                ),
                GButton(
                  icon: Icons.calendar_month_rounded,
                  text: 'Leave',
                ),
                GButton(
                  icon: Icons.person_rounded,
                  text: 'Profile',
                ),
              ],
              selectedIndex: _currentIndex,
              onTabChange: (index) {
                setState(() => _currentIndex = index);
              },
            ),
          ),
        ),
      ),
    );
  }
}
