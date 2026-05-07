import 'package:flutter/material.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/features/attendance/screens/manager/manager_home_tab.dart';
import 'package:attendance_app/features/attendance/screens/manager/manager_calendar_tab.dart';
import 'package:attendance_app/features/attendance/screens/manager/manager_reports_tab.dart';
import 'package:attendance_app/features/settings/screens/manager/manager_profile_tab.dart';
import 'package:attendance_app/features/employee_management/screens/manager/add_employee_screen.dart';
import 'package:attendance_app/features/attendance/screens/manager/attendance_correction_screen.dart';

class ManagerMainScreen extends StatefulWidget {
  const ManagerMainScreen({super.key});

  @override
  State<ManagerMainScreen> createState() => _ManagerMainScreenState();
}

class _ManagerMainScreenState extends State<ManagerMainScreen> {
  int _currentIndex = 0;

  List<Widget> get _pages => [
    ManagerHomeTab(onTabChange: (index) => setState(() => _currentIndex = index)),
    ManagerCalendarTab(onTabChange: (index) => setState(() => _currentIndex = index)),
    ManagerReportsTab(onTabChange: (index) => setState(() => _currentIndex = index)),
    ManagerProfileTab(onTabChange: (index) => setState(() => _currentIndex = index)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showQuickActions,
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
              _navItem(Icons.calendar_today_outlined,
                  Icons.calendar_today_rounded, 'Calendar', 1),
              const SizedBox(width: 48), // space for FAB
              _navItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded,
                  'Reports', 2),
              _navItem(
                  Icons.person_outline, Icons.person_rounded, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppTheme.primary : AppTheme.textHint,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppTheme.primary : AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _quickActionItem(
                    Icons.person_add_rounded, 'Add\nEmployee', AppTheme.primary,
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddEmployeeScreen()));
                }),
                _quickActionItem(Icons.edit_calendar_rounded,
                    'Attendance\nCorrection', AppTheme.warning, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AttendanceCorrectionScreen()));
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _quickActionItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
