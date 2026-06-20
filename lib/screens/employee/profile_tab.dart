import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_action.dart';
import '../login_screen.dart';
import '../auth_wrapper.dart';
import '../common/notification_settings_screen.dart';
import '../common/password_recovery_flow.dart';
import 'notifications_screen.dart';
import 'personal_details_screen.dart';
import 'achievements_screen.dart';
import 'package:intl/intl.dart';
import '../../utils/location_service.dart';
import '../../features/settings/screens/manager/privacy_policy_screen.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/features/settings/screens/manager/contact_support_screen.dart';

class EmployeeProfileTab extends StatefulWidget {
  const EmployeeProfileTab({super.key});

  @override
  State<EmployeeProfileTab> createState() => _EmployeeProfileTabState();
}

class _EmployeeProfileTabState extends State<EmployeeProfileTab> {
  final user = FirebaseAuth.instance.currentUser;
  
  Timer? _timer;
  late final Stream<DocumentSnapshot> _userStream;
  late final Stream<DocumentSnapshot> _companyStream;
  
  @override
  void initState() {
    super.initState();
    _userStream = FirestoreService.userStreamByEmail(user?.email ?? '');
    _companyStream = FirestoreService.companyDoc().snapshots();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatHours(double hours) {
    int h = hours.toInt();
    int m = ((hours - h) * 60).toInt();
    if (h == 0 && m == 0) return "0h 0m";
    if (h > 0) {
      return "${h}h ${m}m";
    } else {
      return "${m}m";
    }
  }

  int _getWorkingDaysInMonthSoFar() {
    DateTime now = DateTime.now();
    int workingDays = 0;
    for (int i = 1; i <= now.day; i++) {
      DateTime date = DateTime(now.year, now.month, i);
      // Simple Mon-Fri calculation
      if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) {
        workingDays++;
      }
    }
    return workingDays == 0 ? 1 : workingDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        leadingWidth: 64,
        leading: Navigator.canPop(context) ? Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: Icon(Icons.arrow_back_rounded, color: Colors.black, size: 20),
            ),
          ),
        ) : null,
        title: StreamBuilder<DocumentSnapshot>(
          stream: _userStream,
          builder: (context, snap) {
            final data = snap.data?.data() as Map<String, dynamic>?;
            final rawName = data?['name']?.toString() ?? AppSession().userName ?? user?.displayName ?? 'Employee';
            final name = rawName.trim().isEmpty ? 'Employee' : rawName.trim();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WELCOME BACK', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                Text(name, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            );
          }
        ),
        actions: const [
          NotificationAction(isManager: false),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: Column(
            children: [
              _buildProfileCard(),
              const SizedBox(height: 20),
              _buildWorkSummaryCard(),
              const SizedBox(height: 20),
              _buildEmployeeInformationCard(),
              const SizedBox(height: 20),
              _buildAchievementsCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('Account Settings'),
              const SizedBox(height: 12),
              _buildAccountSettings(),
              const SizedBox(height: 24),
              _buildSectionTitle('Support & Privacy'),
              const SizedBox(height: 12),
              _buildSupportPrivacy(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
      ),
    );
  }

  Widget _buildProfileCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final rawName = data?['name']?.toString() ?? user?.displayName ?? 'Employee';
        final name = rawName.trim().isEmpty ? 'Employee' : rawName.trim();
        final role = data?['role'] ?? 'Employee';
        final img = data?['profileImageUrl'] as String?;
        final approvedBy = data?['approvedBy'] as String?;

        return StreamBuilder<DocumentSnapshot>(
          stream: _companyStream,
          builder: (context, companySnap) {
            final companyData = companySnap.data?.data() as Map<String, dynamic>?;
            final companyName = companyData?['companyName'] ?? companyData?['name'] ?? '';

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 3),
                    ),
                    child: ClipOval(
                      child: img != null && img.isNotEmpty
                          ? Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.grey, size: 40),
                            )
                          : const Icon(Icons.person, color: Colors.grey, size: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueAccent)),
                  if (companyName.toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.business_rounded, size: 12, color: Color(0xFF6366F1)),
                          const SizedBox(width: 4),
                          Text(companyName.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text('Employee ID: ${data?['employeeId'] ?? 'EMP-1024'}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 12),
                  // Active employee badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('ACTIVE EMPLOYEE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                  if (approvedBy != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 12, color: Colors.green),
                          const SizedBox(width: 6),
                          Text('Approved by $approvedBy', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAchievementsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.userAttendanceCol(user!.email ?? '')
          .orderBy('checkIn', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        bool perfectWeek = false;
        bool earlyBird = false;
        bool monthHero = false;

        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          int streak = 0;
          int earlyBirds = 0;
          DateTime? lastDate;

          for (int i = 0; i < docs.length; i++) {
            final date = DateTime.tryParse(docs[i].id);
            if(date == null) continue;
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
                        break;
                    }
                }
            }

            final checkInTs = data['checkIn'] as Timestamp?;
            if (checkInTs != null) {
              final sParts = AppSession().shiftStartTime.split(':');
              if (checkInTs.toDate().hour < int.parse(sParts[0])) earlyBirds++;
            }
          }
          perfectWeek = streak >= 7;
          earlyBird = earlyBirds >= 5;
          monthHero = docs.length >= 30;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ACHIEVEMENTS', style: AppTheme.label.copyWith(fontSize: 10, letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text('Your Milestones', style: AppTheme.h3),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.keyboard_arrow_right_rounded, color: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _achievementBadgeItem(Icons.star_rounded, perfectWeek ? const Color(0xFFFEF3C7) : Colors.grey.shade50, perfectWeek ? const Color(0xFFD97706) : Colors.grey.shade400, 'Perfect\nWeek'),
                    _achievementBadgeItem(Icons.wb_sunny_rounded, earlyBird ? const Color(0xFFE0E7FF) : Colors.grey.shade50, earlyBird ? const Color(0xFF4F46E5) : Colors.grey.shade400, 'Early\nBird'),
                    _achievementBadgeItem(Icons.workspace_premium_rounded, monthHero ? const Color(0xFFF9E8FF) : Colors.grey.shade50, monthHero ? const Color(0xFF9333EA) : Colors.grey.shade400, '1 Month\nHero'),
                    _achievementBadgeItem(Icons.arrow_forward_rounded, Colors.grey.shade50, Colors.grey.shade400, 'All\nBadges'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _achievementBadgeItem(IconData icon, Color bg, Color color, String label) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.bodySmall.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkSummaryCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.userAttendanceCol(user!.email ?? '').snapshots(),
      builder: (context, attendanceSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.userLeaveRequestsCol(user!.email ?? '')
              .where('status', isEqualTo: 'approved')
              .snapshots(),
          builder: (context, leaveSnap) {
            final attendanceDocs = attendanceSnap.data?.docs ?? [];
            final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
            final DateTime now = DateTime.now();
            
            // Calculate Monthly stats
            int monthPresentCount = 0;
            double monthTotalHours = 0;
            int monthLateArrivals = 0;
            
            for (var doc in attendanceDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final recordDate = DateTime.tryParse(doc.id);
              
              if (recordDate != null && recordDate.month == now.month && recordDate.year == now.year) {
                monthPresentCount++;
                
                // Live calculation for hours if checked in right now
                if (doc.id == todayDate && data['status'] == 'checked_in' && data['checkIn'] != null) {
                  final checkInTs = data['checkIn'] as Timestamp?;
                  if (checkInTs != null) {
                    final checkInTime = checkInTs.toDate();
                    monthTotalHours += now.difference(checkInTime).inSeconds / 3600.0;
                  }
                } else if (data['checkIn'] != null && data['checkOut'] != null) {
                  final checkInTs = data['checkIn'] as Timestamp;
                  final checkOutTs = data['checkOut'] as Timestamp;
                  monthTotalHours += checkOutTs.toDate().difference(checkInTs.toDate()).inSeconds / 3600.0;
                } else if (data['totalHours'] != null) {
                  monthTotalHours += (data['totalHours'] as num).toDouble();
                }
                
                // Dynamic Late arrivals for this month
                final checkIn = data['checkIn'] as Timestamp?;
                if (checkIn != null) {
                  final time = checkIn.toDate();
                  final parts = AppSession().shiftStartTime.split(':');
                  final threshold = DateTime(time.year, time.month, time.day, 
                      int.parse(parts[0]), int.parse(parts[1]))
                      .add(Duration(minutes: AppSession().gracePeriod));
                      
                  if (time.isAfter(threshold)) {
                    monthLateArrivals++;
                  }
                }
              }
            }

            // Calculate Attendance Rate properly
            int totalWorkingDays = _getWorkingDaysInMonthSoFar();
            double rate = (monthPresentCount / totalWorkingDays).clamp(0.0, 1.0);

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: const Border(left: BorderSide(color: Colors.orange, width: 4)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${DateFormat('MMMM').format(now).toUpperCase()} SUMMARY', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange, letterSpacing: 1.2)),
                      Icon(Icons.trending_up_rounded, color: Colors.grey.shade400, size: 18),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Days Present', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('$monthPresentCount / $totalWorkingDays', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Hours Worked', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(_formatHours(monthTotalHours), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Attendance Rate', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                      Text('${(rate * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: rate,
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Late Arrivals', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(monthLateArrivals.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      ),
                      if (monthTotalHours > 0) Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Average/Day', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(_formatHours(monthTotalHours / (monthPresentCount > 0 ? monthPresentCount : 1)), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmployeeInformationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirestoreService.userStreamByEmail(user!.email ?? ''),
        builder: (context, snap) {
           final data = snap.data?.data() as Map<String, dynamic>?;
            final email = data?['email'] ?? user?.email ?? 'email@company.com';
            final phone = data?['phone'] ?? '+1 (555) 123-4567';
            final dept = data?['department'] ?? 'Product Design Team';
            final manager = data?['reportingManager'] ?? 'Not Assigned';
            final location = data?['location'] ?? 'Not Assigned';
            final approvedBy = data?['approvedBy'];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Employee Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 20),
                _infoRow(Icons.mail_outline_rounded, 'EMAIL', email),
                _infoRow(Icons.email_outlined, 'PERSONAL EMAIL', data?['personalEmail'] ?? 'Not Provided'),
                _infoRow(Icons.phone_outlined, 'PHONE', phone),
                _infoRow(Icons.calendar_today_outlined, 'JOINING DATE', data?['joiningDate'] ?? 'Not Provided'),
                _infoRow(Icons.badge_outlined, 'DEPARTMENT', dept),
                _infoRow(Icons.group_outlined, 'REPORTING MANAGER', manager),
                _infoRow(Icons.location_on_outlined, 'OFFICE LOCATION', location, isLast: approvedBy == null),
                if (approvedBy != null)
                  _infoRow(Icons.verified_user_outlined, 'APPROVED BY', approvedBy, isLast: true),
              ],
            );
        }
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF7F9FC), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.blueAccent, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        ],
      ),
    );
  }


  Widget _buildAccountSettings() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
      ),
      child: Column(
        children: [
          _menuItem(Icons.person_outline_rounded, const Color(0xFFE8EAF6), Colors.blueAccent, 'Edit Profile', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()));
          }),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF7F9FC)),
          _menuItem(Icons.notifications_none_rounded, const Color(0xFFFFF3E0), Colors.orange, 'Notifications', trailingBadge: '3', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeNotificationsScreen()));
          }),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF7F9FC)),
          _menuItem(Icons.lock_reset_outlined, const Color(0xFFE8F5E9), Colors.green, 'Change Password', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordRecoveryFlow(isChangePassword: true)));
          }),
        ],
      ),
    );
  }

  Widget _buildSupportPrivacy() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
      ),
      child: Column(
        children: [
          _menuItem(Icons.privacy_tip_outlined, const Color(0xFFF7F9FC), Colors.blueGrey, 'Privacy Policy', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
          }),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF7F9FC)),
          _menuItem(Icons.help_outline_rounded, const Color(0xFFEEF2FF), const Color(0xFF5C6BC0), 'Contact Support', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportScreen()));
          }),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF7F9FC)),
          _menuItem(Icons.logout_rounded, const Color(0xFFFFEBEE), Colors.redAccent, 'Logout', isDestructive: true, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, Color iconBg, Color iconColor, String title, {String? trailingBadge, bool isDestructive = false, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDestructive ? Colors.redAccent : Colors.black87)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingBadge != null)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              child: Text(trailingBadge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 8),
          if (!isDestructive) Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
        ],
      ),
      onTap: onTap ?? () {},
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out\nof your account?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
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
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                    AppSession().clear();
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthWrapper()), (r) => false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
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

  void _handleLogout() {
    _showLogoutConfirmation();
  }
}
