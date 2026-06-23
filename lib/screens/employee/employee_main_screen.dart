import 'package:flutter/material.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/screens/employee/home_tab.dart';
import 'package:attendance_app/screens/employee/attendance_tab.dart';
import 'package:attendance_app/screens/employee/leave_tab.dart';
import 'package:attendance_app/screens/employee/employee_attendance_correction_screen.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _currentIndex = 0;
  bool _isMenuOpen = false;
  Offset? _dragPosition;
  Offset? _fabPosition;
  final GlobalKey _fabKey = GlobalKey();

  final List<Widget> _tabs = const [
    EmployeeHomeTab(),
    EmployeeAttendanceTab(),
    EmployeeLeaveTab(),
  ];

  void _onItemTapped(int index) {
    if (index == 3) {
      _showMoreBottomSheet();
    } else if (index < 3) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _handleMenuAction(int actionId) {
    if (actionId == 0) {
      // Quick Check-In -> Switch to Attendance tab
      setState(() => _currentIndex = 1);
    } else if (actionId == 1) {
      // Apply Leave -> Switch to Leave tab
      setState(() => _currentIndex = 2);
    } else if (actionId == 2) {
      // Raise Correction -> Navigate to correction screen
      Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeAttendanceCorrectionScreen()));
    }
  }

  Offset _getFabCenter() {
    if (_fabPosition != null) {
      return Offset(_fabPosition!.dx + 32, _fabPosition!.dy + 32); // 32 is half of FAB size 64
    }
    final size = MediaQuery.of(context).size;
    return Offset(size.width / 2, size.height - 65);
  }

  int? _getHoveredItem(Offset? dragPos) {
    if (dragPos == null) return null;
    final fabCenter = _getFabCenter();
    final items = [
      Offset(fabCenter.dx, fabCenter.dy - 160), // 0: Top
      Offset(fabCenter.dx - 110, fabCenter.dy - 70), // 1: Left
      Offset(fabCenter.dx + 110, fabCenter.dy - 70), // 2: Right
    ];
    for (int i = 0; i < items.length; i++) {
      if ((dragPos - items[i]).distance < 50) {
        return i;
      }
    }
    return null;
  }

  void _showMoreBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Profile header
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        'AH',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alex Harrison',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1F2937)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Product Designer · EMP-2024-0142',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 32),
                // Grid of items
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / 4;
                    return Wrap(
                      runSpacing: 24,
                      children: [
                        SizedBox(width: itemWidth, child: _buildSheetItem(Icons.access_time, 'Attendance', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF))),
                        SizedBox(width: itemWidth, child: _buildSheetItem(Icons.calendar_today, 'Leave', const Color(0xFFF0FDF4), const Color(0xFF22C55E))),
                        SizedBox(width: itemWidth, child: _buildSheetItem(Icons.bar_chart, 'Reports', const Color(0xFFECFEFF), const Color(0xFF06B6D4))),
                        SizedBox(width: itemWidth, child: _buildSheetItem(Icons.apartment, 'Holidays', const Color(0xFFFFF7ED), const Color(0xFFF59E0B))),
                        SizedBox(width: itemWidth, child: _buildSheetItem(Icons.people_outline, 'Organization', const Color(0xFFF5F3FF), const Color(0xFF8B5CF6))),
                        SizedBox(width: itemWidth, child: _buildSheetItem(Icons.help_outline, 'Help Center', const Color(0xFFF3F4F6), const Color(0xFF6B7280))),
                        SizedBox(width: itemWidth, child: _buildSheetItem(Icons.settings_outlined, 'Settings', const Color(0xFFF3F4F6), const Color(0xFF6B7280))),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 32),
                // Active Workspace
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F1FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Active: Employee Workspace',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.logout, color: AppTheme.danger),
                    label: const Text('Logout',
                        style: TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dangerLight,
                      foregroundColor: AppTheme.danger,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetItem(IconData icon, String label, Color bgColor, Color iconColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.surface,
          body: IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          floatingActionButton: GestureDetector(
            onLongPressStart: (details) {
              final RenderBox? renderBox = _fabKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                _fabPosition = renderBox.localToGlobal(Offset.zero);
              }
              setState(() {
                _isMenuOpen = true;
                _dragPosition = details.globalPosition;
              });
            },
            onLongPressMoveUpdate: (details) {
              setState(() {
                _dragPosition = details.globalPosition;
              });
            },
            onLongPressEnd: (details) {
              final selectedItem = _getHoveredItem(_dragPosition);
              setState(() {
                _isMenuOpen = false;
                _dragPosition = null;
              });
              if (selectedItem != null) {
                _handleMenuAction(selectedItem);
              }
            },
            child: Container(
              height: 64,
              width: 64,
              margin: const EdgeInsets.only(top: 30), // adjust positioning slightly
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SizedBox(
                key: _fabKey,
                child: FloatingActionButton(
                  onPressed: () {
                    final RenderBox? renderBox = _fabKey.currentContext?.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      _fabPosition = renderBox.localToGlobal(Offset.zero);
                    }
                    setState(() {
                      _isMenuOpen = !_isMenuOpen;
                    });
                  },
                  backgroundColor: AppTheme.primary,
                  elevation: 0,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add, color: Colors.white, size: 32),
                ),
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ]
            ),
            child: BottomAppBar(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                    _buildNavItem(1, Icons.access_time, Icons.access_time_filled, 'Attendance'),
                    const SizedBox(width: 48), // Space for FAB
                    _buildNavItem(2, Icons.calendar_today, Icons.calendar_month, 'Leave'),
                    _buildNavItem(3, Icons.more_horiz, Icons.more_horiz, 'More'),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Radial Menu Overlay
        if (_isMenuOpen)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: GestureDetector(
                onTap: () {
                  setState(() => _isMenuOpen = false);
                },
                // Dark overlay background
                child: Container(
                  color: const Color(0xFF1F2937).withValues(alpha: 0.4),
                  child: Stack(
                  children: [
                    // Item 0: Quick Check-In
                    _buildOverlayItem(
                      index: 0,
                      icon: Icons.access_time_rounded,
                      iconColor: const Color(0xFF5C5CFF),
                      bgColor: const Color(0xFFEEF2FF),
                      label: 'Quick Check-In',
                      dx: 0,
                      dy: -160,
                    ),
                    // Item 1: Apply Leave
                    _buildOverlayItem(
                      index: 1,
                      icon: Icons.calendar_today_rounded,
                      iconColor: const Color(0xFF22C55E),
                      bgColor: const Color(0xFFF0FDF4),
                      label: 'Apply Leave',
                      dx: -110,
                      dy: -70,
                    ),
                    // Item 2: Raise Correction
                    _buildOverlayItem(
                      index: 2,
                      icon: Icons.error_outline_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      bgColor: const Color(0xFFFFF7ED),
                      label: 'Raise Correction',
                      dx: 110,
                      dy: -70,
                    ),

                    // Redraw the X FAB in the overlay so it's on top of the dark background
                    if (_fabPosition != null)
                      Positioned(
                        top: _fabPosition!.dy,
                        left: _fabPosition!.dx,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _isMenuOpen = false);
                          },
                          child: Container(
                            height: 64,
                            width: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF374151),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 30),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlayItem({
    required int index,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required double dx,
    required double dy,
  }) {
    final hovered = _getHoveredItem(_dragPosition) == index;
    final scale = hovered ? 1.15 : 1.0;
    
    final size = MediaQuery.of(context).size;
    final fabCenter = Offset(size.width / 2, size.height - 65);
    final itemCenter = Offset(fabCenter.dx + dx, fabCenter.dy + dy);

    return Positioned(
      left: itemCenter.dx - 65, // half of 130 width
      top: itemCenter.dy - 60,   // half of 120 height
      child: SizedBox(
        width: 130,
        child: GestureDetector(
          onTap: () {
            setState(() => _isMenuOpen = false);
            _handleMenuAction(index);
          },
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 150),
            tween: Tween<double>(begin: 1.0, end: scale),
            builder: (context, double val, child) {
              return Transform.scale(
                scale: val,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(icon, color: iconColor, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = _currentIndex == index && index < 3;
    final color = isSelected ? AppTheme.primary : const Color(0xFF9CA3AF);

    return InkWell(
      onTap: () => _onItemTapped(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? iconFilled : iconOutlined,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
