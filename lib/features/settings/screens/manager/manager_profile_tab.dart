import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/screens/login_screen.dart';
import 'package:attendance_app/features/settings/screens/manager/privacy_policy_screen.dart';
import 'package:attendance_app/features/settings/screens/manager/contact_support_screen.dart';
import 'package:attendance_app/features/employee_management/screens/manager/employee_list_screen.dart';
import 'package:attendance_app/features/leave_management/screens/manager/leave_approval_screen.dart';
import 'package:attendance_app/features/attendance/screens/manager/manager_reports_tab.dart';
import 'package:attendance_app/features/settings/screens/manager/manager_edit_profile_screen.dart';
import 'package:attendance_app/features/settings/screens/manager/manager_notifications_screen.dart';
import 'package:attendance_app/features/settings/screens/manager/company_settings_screen.dart';
import 'package:attendance_app/widgets/notification_action.dart';
import 'package:attendance_app/screens/common/password_recovery_flow.dart';
import 'package:attendance_app/utils/file_export_helper.dart';
import 'package:intl/intl.dart';

class ManagerProfileTab extends StatefulWidget {
  final Function(int)? onTabChange;
  const ManagerProfileTab({super.key, this.onTabChange});

  @override
  State<ManagerProfileTab> createState() => _ManagerProfileTabState();
}

class _ManagerProfileTabState extends State<ManagerProfileTab> {
  String get todayDocId {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  DateTime _selectedReportMonth = DateTime.now();

  late final Stream<QuerySnapshot> _usersStream =
      FirestoreService.companyUsersQuery.snapshots();
  late final Stream<QuerySnapshot> _leaveRequestsStream =
      FirestoreService.companyLeaveRequestsQuery.snapshots();
  late final Stream<QuerySnapshot> _attendanceRecordsStream =
      FirestoreService.allAttendanceRecordsCol
          .snapshots();
  late final Stream<DocumentSnapshot> _currentUserStream =
      FirestoreService.userStreamByEmail(FirebaseAuth.instance.currentUser?.email ?? '');
  late final Stream<QuerySnapshot> _unreadNotificationsStream = 
      FirestoreService.allNotificationsQuery.where('isRead', isEqualTo: false).snapshots();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 18),
          onPressed: () async {
            final didPop = await Navigator.maybePop(context);
            if (!didPop) {
              widget.onTabChange?.call(0);
            }
          },
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: _currentUserStream,
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final sessionName = AppSession().userName;
            final authName = user?.displayName;
            
            String name = 'Manager';
            if (data?['name'] != null && data!['name'].toString().trim().isNotEmpty) {
              name = data['name'].toString();
            } else if (sessionName != null && sessionName.trim().isNotEmpty) {
              name = sessionName;
            } else if (authName != null && authName.trim().isNotEmpty) {
              name = authName;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'WELCOME BACK',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textHint,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            );
          },
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            _buildProfileCard(context, user),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 24),
            _buildDownloadSection(context),
            const SizedBox(height: 24),
            _buildAccountSettings(context),
            const SizedBox(height: 24),
            _buildSupportPrivacy(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, User? user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _currentUserStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final sessionName = AppSession().userName;
        final authName = user?.displayName;
        
        String name = 'Manager';
        if (data?['name'] != null && data!['name'].toString().trim().isNotEmpty) {
          name = data['name'].toString();
        } else if (sessionName != null && sessionName.trim().isNotEmpty) {
          name = sessionName;
        } else if (authName != null && authName.trim().isNotEmpty) {
          name = authName;
        }

        String role = data?['designation'] ?? 'HR Manager';
        String empId = data?['employeeId'] ?? 'MGR-1024';
        String? imageUrl = data?['profileImageUrl'];

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Top purple curve/line
              Container(
                height: 40,
                decoration: const BoxDecoration(
                  color: AppTheme.primarySurface, // or a purple gradient
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusXL)),
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 20),
                  // Avatar with status dot
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: ClipOval(
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? (imageUrl.startsWith('http')
                                  ? Image.network(imageUrl, fit: BoxFit.cover)
                                  : Image.memory(base64Decode(imageUrl),
                                      fit: BoxFit.cover))
                              : Container(
                                  color: AppTheme.primarySurface,
                                  child: const Icon(Icons.person,
                                      color: AppTheme.primary, size: 40),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      empId,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textHint,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _quickActionBtn(context, Icons.people_outline, 'Manage\nEmployees',
                AppTheme.primary, AppTheme.primarySurface, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EmployeeListScreen()));
            }),
            _quickActionBtn(context, Icons.fact_check_outlined,
                'Approve\nLeaves', AppTheme.info, AppTheme.infoLight, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LeaveApprovalScreen()));
            }),
            _quickActionBtn(context, Icons.bar_chart_rounded, 'View\nReports',
                AppTheme.warning, AppTheme.warningLight, () {
              widget.onTabChange?.call(2);
            }),
          ],
        ),
      ],
    );
  }

  Widget _quickActionBtn(BuildContext context, IconData icon, String label,
      Color iconColor, Color bgColor, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildDownloadSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REPORTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textHint,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
          ),
          child: Column(
            children: [
              _settingsItem(
                  Icons.download_rounded,
                  'Employee Details',
                  AppTheme.primary,
                  AppTheme.primarySurface,
                  () => _showReportConfigModal(context, type: 'details')),
              _settingsItem(
                  Icons.assessment_outlined,
                  'Monthly Attendance Report',
                  const Color(0xFF8B93FF),
                  const Color(0xFF8B93FF).withOpacity(0.1),
                  () => _showReportConfigModal(context, type: 'summary')),
             
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showReportConfigModal(BuildContext parentContext, {required String type}) async {
    DateTime tempDate = _selectedReportMonth;
    final List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    await showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  type == 'summary' ? 'Attendance Report' : 'Employee Details',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the period you want to export',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),
                
                // Year Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
                        onPressed: () => setModalState(() => tempDate = DateTime(tempDate.year - 1, tempDate.month)),
                      ),
                      Text(
                        '${tempDate.year}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: AppTheme.primary),
                        onPressed: tempDate.year < DateTime.now().year 
                          ? () => setModalState(() => tempDate = DateTime(tempDate.year + 1, tempDate.month))
                          : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Month Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final isSelected = tempDate.month == index + 1;
                    final isFuture = tempDate.year == DateTime.now().year && index + 1 > DateTime.now().month;
                    
                    return GestureDetector(
                      onTap: isFuture ? null : () => setModalState(() => tempDate = DateTime(tempDate.year, index + 1)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : (isFuture ? Colors.transparent : AppTheme.surface),
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected ? null : Border.all(color: Colors.grey[100]!),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          months[index].substring(0, 3),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : (isFuture ? Colors.grey[300] : AppTheme.textPrimary),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                
                // Download Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedReportMonth = tempDate;
                      });
                      Navigator.pop(context); // This pops the Modal
                      if (type == 'summary') {
                        _downloadAttendanceSummaryReport(parentContext);
                      } else {
                        _downloadEmployeeDetails(parentContext);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.file_download_outlined, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          'DOWNLOAD ${type == 'summary' ? 'REPORT' : 'DETAILS'}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _downloadEmployeeDetails(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      final snapshot = await FirestoreService.companyUsersQuery.get();
      List<List<dynamic>> rows = [];

      rows.add([
        "Employee ID",
        "Name",
        "Email",
        "Personal Email",
        "Phone",
        "Department",
        "Designation",
        "Joining Date",
        "Blood Group",
        "Aadhaar",
        "Address",
        "Status"
      ]);

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Filter: only show employees, skip managers/others
        if ((data['role'] ?? 'employee').toString().toLowerCase() != 'employee') continue;
        
        // Use leading quote to force Excel to treat numbers and dates as text
        // This prevents scientific notation and '####' date errors
        final phone = data['phone'] != null ? "'${data['phone']}" : '';
        final aadhaar = data['aadhaar'] != null ? "'${data['aadhaar']}" : '';
        final empId = data['employeeId'] != null ? "'${data['employeeId']}" : '';
        final joiningDate = data['joiningDate'] != null ? "'${data['joiningDate']}" : '';

        rows.add([
          empId,
          data['name'] ?? '',
          data['email'] ?? '',
          data['personalEmail'] ?? '',
          phone,
          data['department'] ?? '',
          data['designation'] ?? '',
          joiningDate,
          data['bloodGroup'] ?? '',
          aadhaar,
          data['address'] ?? '',
          data['status'] ?? ''
        ]);
      }

      String csv = _mapToCsv(rows);
      final fileName = "employee_details_full_${DateTime.now().millisecondsSinceEpoch}.csv";
      await saveAndShareFile(csv, fileName);

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Download failed: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  Future<void> _downloadAttendanceReport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      // 1. Get all employees
      final usersSnapshot = await FirestoreService.companyUsersQuery.get();
      final employees = usersSnapshot.docs.where((d) => (d.data()['role'] ?? 'employee').toString().toLowerCase() == 'employee').toList();
      
      // 2. Get all attendance for the month
      final attendanceSnapshot = await FirestoreService.allAttendanceRecordsCol.get();
      final monthStr = DateFormat('yyyy-MM').format(_selectedReportMonth);
      
      // Map to store records by email and date: { email: { date: data } }
      Map<String, Map<String, dynamic>> attendanceMap = {};
      for (var doc in attendanceSnapshot.docs) {
        if (!doc.id.startsWith(monthStr)) continue;
        final data = doc.data() as Map<String, dynamic>;
        final email = (data['email'] ?? '').toString().toLowerCase();
        if (email.isNotEmpty) {
          attendanceMap.putIfAbsent(email, () => {})[doc.id] = data;
        }
      }

      List<List<dynamic>> rows = [];
      rows.add([
        "Date",
        "Employee Name",
        "Email",
        "Check-In",
        "Check-Out",
        "Total Hours",
        "Status",
        "Work Mode",
        "Late"
      ]);

      // Calculate days in the selected month
      final daysInMonth = DateTime(_selectedReportMonth.year, _selectedReportMonth.month + 1, 0).day;
      final now = DateTime.now();

      for (var empDoc in employees) {
        final empData = empDoc.data() as Map<String, dynamic>;
        final email = (empData['email'] ?? '').toString().toLowerCase();
        final name = empData['name'] ?? 'Unknown';

        for (int day = 1; day <= daysInMonth; day++) {
          final dateObj = DateTime(_selectedReportMonth.year, _selectedReportMonth.month, day);
          final dateStr = DateFormat('yyyy-MM-dd').format(dateObj);
          
          // Skip future dates
          if (dateObj.isAfter(now)) continue;

          final record = attendanceMap[email]?[dateStr];
          final dateForExcel = "'$dateStr"; // Leading quote to prevent #### and preserve format

          if (record != null) {
            final checkInTs = record['checkIn'] as Timestamp?;
            final checkOutTs = record['checkOut'] as Timestamp?;
            final workMode = record['workMode'] ?? 'office';
            
            String lateStatus = '--';
            if (checkInTs != null) {
              final checkIn = checkInTs.toDate();
              final sParts = AppSession().shiftStartTime.split(':');
              final targetIn = DateTime(checkIn.year, checkIn.month, checkIn.day, 
                  int.parse(sParts[0]), int.parse(sParts[1]));
              final lateThreshold = targetIn.add(Duration(minutes: AppSession().gracePeriod));
              if (checkIn.isAfter(lateThreshold)) {
                lateStatus = 'LATE';
              } else {
                lateStatus = 'ON TIME';
              }
            }

            rows.add([
              dateForExcel,
              name,
              email,
              checkInTs != null ? DateFormat('HH:mm:ss').format(checkInTs.toDate()) : '--',
              checkOutTs != null ? DateFormat('HH:mm:ss').format(checkOutTs.toDate()) : '--',
              record['totalHours'] ?? '0.0',
              record['status']?.toString().toUpperCase() ?? 'PRESENT',
              workMode.toString().toUpperCase(),
              lateStatus
            ]);
          } else {
            // Mark as ABSENT
            rows.add([
              dateForExcel,
              name,
              email,
              '--',
              '--',
              '0.0',
              'ABSENT',
              '--',
              '--'
            ]);
          }
        }
      }

      String csv = _mapToCsv(rows);
      final fileName = "attendance_full_${monthStr}.csv";
      await saveAndShareFile(csv, fileName);

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Download failed: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }


  Widget _buildAccountSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
          ),
          child: Column(
            children: [
              _settingsItem(Icons.person_outline, 'Edit Profile',
                  AppTheme.primary, AppTheme.primarySurface, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManagerEditProfileScreen()));
              }),
              _divider(),
              StreamBuilder<QuerySnapshot>(
                stream: _unreadNotificationsStream,
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return _settingsItem(Icons.notifications_outlined, 'Notifications',
                      AppTheme.warning, AppTheme.warningLight, () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ManagerNotificationsScreen()));
                  }, trailingText: count > 0 ? count.toString() : null);
                },
              ),
              _divider(),
              _settingsItem(Icons.business_outlined, 'Company Settings',
                  AppTheme.primary, const Color(0xFFEEF2FF), () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CompanySettingsScreen()));
              }),
              _divider(),
              _settingsItem(Icons.lock_outline, 'Change Password',
                  AppTheme.success, AppTheme.successLight, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PasswordRecoveryFlow(isChangePassword: true)));
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportPrivacy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Support & Privacy',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
          ),
          child: Column(
            children: [
              _settingsItem(Icons.shield_outlined, 'Privacy Policy',
                  AppTheme.textSecondary, AppTheme.surface, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()));
              }),
              _divider(),
              _settingsItem(Icons.help_outline_rounded, 'Contact Support',
                  AppTheme.info, AppTheme.infoLight, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ContactSupportScreen()));
              }),
              _divider(),
              _settingsItem(Icons.logout_rounded, 'Logout', AppTheme.danger,
                  AppTheme.dangerLight, () => _showLogoutConfirmation(context), isDestructive: true),
            ],
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded, color: AppTheme.danger, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.textPrimary)),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out\nof your management account?',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textHint, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Text('CANCEL', style: TextStyle(color: AppTheme.textHint, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                    AppSession().clear();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('LOGOUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(
        height: 1,
        thickness: 1,
        color: AppTheme.divider,
        indent: 60,
        endIndent: 20);
  }

  Widget _settingsItem(IconData icon, String label, Color iconColor,
      Color iconBgColor, VoidCallback onTap,
      {bool isDestructive = false, String? trailingText}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDestructive ? AppTheme.danger : AppTheme.textPrimary,
                ),
              ),
            ),
            if (trailingText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trailingText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              )
            else
              Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAttendanceSummaryReport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      // 1. Get all employees
      final usersSnapshot = await FirestoreService.companyUsersQuery.get();
      final employees = usersSnapshot.docs.where((d) => (d.data()['role'] ?? 'employee').toString().toLowerCase() == 'employee').toList();
      
      // 2. Get attendance and leave requests
      final attendanceSnapshot = await FirestoreService.allAttendanceRecordsCol.get();
      final leaveSnapshot = await FirestoreService.allLeaveRequestsQuery.get();
      
      final monthStr = DateFormat('yyyy-MM').format(_selectedReportMonth);
      final daysInMonth = DateTime(_selectedReportMonth.year, _selectedReportMonth.month + 1, 0).day;
      final now = DateTime.now();
      
      // Calculate active days so far for the month
      int activeDays = daysInMonth;
      if (_selectedReportMonth.year == now.year && _selectedReportMonth.month == now.month) {
        activeDays = now.day;
      }

      List<List<dynamic>> rows = [];
      rows.add([
        "Employee ID",
        "Name",
        "Email",
        "Present Days",
        "WFH Days",
        "Late Days",
        "Paid Leave",
        "Absent",
        "Applied Leave"
      ]);

      for (var empDoc in employees) {
        final empData = empDoc.data() as Map<String, dynamic>;
        final email = (empData['email'] ?? '').toString().toLowerCase();
        final name = empData['name'] ?? 'Unknown';
        final empId = empData['employeeId'] != null ? "'${empData['employeeId']}" : '--';

        // Map to track status for each day of the month
        Map<int, String> dayStatus = {}; // 1: PRESENT, 2: LEAVE, 0: NOTHING/ABSENT

        // 1. Mark Present Days
        for (var doc in attendanceSnapshot.docs) {
          if (!doc.id.startsWith(monthStr)) continue;
          final data = doc.data() as Map<String, dynamic>;
          final docEmail = (data['email'] ?? data['userId'] ?? '').toString().toLowerCase();
          
          if (docEmail == email) {
            try {
              final day = int.parse(doc.id.split('-').last);
              dayStatus[day] = 'PRESENT';
            } catch (_) {}
          }
        }

        // 2. Mark Leave Days
        int appliedLeaveCount = 0;
        for (var doc in leaveSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final docEmail = (data['email'] ?? data['userId'] ?? '').toString().toLowerCase();
          
          if (docEmail != email) continue;

          final start = (data['startDate'] as Timestamp? ?? data['fromDate'] as Timestamp?)?.toDate();
          final end = (data['endDate'] as Timestamp? ?? data['toDate'] as Timestamp?)?.toDate();
          final status = data['status']?.toString().toLowerCase();

          if (start == null || end == null) continue;

          // Check if leave request overlaps with selected month
          DateTime monthStart = DateTime(_selectedReportMonth.year, _selectedReportMonth.month, 1);
          DateTime monthEnd = DateTime(_selectedReportMonth.year, _selectedReportMonth.month + 1, 0);

          if (start.isAfter(monthEnd) || end.isBefore(monthStart)) continue;
          
          appliedLeaveCount++;

          if (status == 'approved') {
            // Mark every day of the leave that falls within this month
            DateTime current = start.isBefore(monthStart) ? monthStart : start;
            DateTime last = end.isAfter(monthEnd) ? monthEnd : end;

            while (current.isBefore(last) || current.isAtSameMomentAs(last)) {
              if (current.year == _selectedReportMonth.year && current.month == _selectedReportMonth.month) {
                // Only mark as LEAVE if not already marked PRESENT
                if (dayStatus[current.day] != 'PRESENT') {
                  dayStatus[current.day] = 'LEAVE';
                }
              }
              current = current.add(const Duration(days: 1));
            }
          }
        }

        int presentCount = dayStatus.values.where((s) => s == 'PRESENT').length;
        int paidLeaveCount = dayStatus.values.where((s) => s == 'LEAVE').length;
        int absentCount = 0;
        int wfhCount = 0;
        int lateCount = 0;

        // 1.1 Calculate WFH and Late for the summary
        for (var doc in attendanceSnapshot.docs) {
          if (!doc.id.startsWith(monthStr)) continue;
          final data = doc.data() as Map<String, dynamic>;
          final docEmail = (data['email'] ?? data['userId'] ?? '').toString().toLowerCase();
          if (docEmail != email) continue;

          if (data['workMode'] == 'wfh') wfhCount++;
          
          final checkInTs = data['checkIn'] as Timestamp?;
          if (checkInTs != null) {
            final checkIn = checkInTs.toDate();
            final sParts = AppSession().shiftStartTime.split(':');
            final targetIn = DateTime(checkIn.year, checkIn.month, checkIn.day, 
                int.parse(sParts[0]), int.parse(sParts[1]));
            final lateThreshold = targetIn.add(Duration(minutes: AppSession().gracePeriod));
            if (checkIn.isAfter(lateThreshold)) lateCount++;
          }
        }

        // 3. Count Absents (Days passed - Present - Leave, excluding Sundays)
        for (int day = 1; day <= activeDays; day++) {
          if (dayStatus[day] == null) {
            final date = DateTime(_selectedReportMonth.year, _selectedReportMonth.month, day);
            // Exclude Sundays from being counted as Absent
            if (date.weekday != DateTime.sunday) {
              absentCount++;
            }
          }
        }

        rows.add([
          empId,
          name,
          email,
          presentCount,
          wfhCount,
          lateCount,
          paidLeaveCount,
          absentCount,
          appliedLeaveCount
        ]);
      }

      String csv = _mapToCsv(rows);
      final fileName = "attendance_summary_${monthStr}.csv";
      await saveAndShareFile(csv, fileName);

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  String _mapToCsv(List<List<dynamic>> rows) {
    String csv = rows.map((row) {
      return row.map((cell) {
        final String cellStr = cell?.toString() ?? '';
        if (cellStr.contains(',') || cellStr.contains('\n') || cellStr.contains('"')) {
          return '"${cellStr.replaceAll('"', '""')}"';
        }
        return cellStr;
      }).join(',');
    }).join('\n');
    return '\uFEFF$csv';
  }
}
