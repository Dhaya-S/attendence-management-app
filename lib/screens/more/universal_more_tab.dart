import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/screens/login_screen.dart';
import 'package:attendance_app/screens/employee/notifications_screen.dart';
import 'package:attendance_app/screens/employee/documents_screen.dart';
import 'package:attendance_app/screens/employee/history_screen.dart';
import 'package:attendance_app/screens/profile/universal_profile_screen.dart';

class UniversalMoreTab extends StatefulWidget {
  const UniversalMoreTab({super.key});

  @override
  State<UniversalMoreTab> createState() => _UniversalMoreTabState();
}

class _UniversalMoreTabState extends State<UniversalMoreTab> {
  Future<void> _handleSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UniversalProfileScreen()),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Slightly off-white background matching mockup
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: user != null ? FirestoreService.userStreamByEmail(user.email ?? '') : const Stream.empty(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? {};
            final userName = data['name'] ?? AppSession().userName ?? 'User';
            final initials = userName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join();
            
            final roleDisplay = data['designation'] ?? (AppSession().isManager ? 'Manager' : AppSession().isEmployee ? 'Employee' : 'Admin');
            final department = data['department'] ?? 'Not provided';
            final employeeId = data['employeeId'] ?? AppSession().uid?.substring(0, 8).toUpperCase() ?? 'Not provided';

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Profile Header Card
                        _buildProfileHeader(userName, initials, roleDisplay, department, employeeId),
                        const SizedBox(height: 16),
                        
                        // Menu Items
                    _buildMenuItem(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      subtitle: 'Personal & work information',
                      iconColor: const Color(0xFF4F46E5),
                      iconBgColor: const Color(0xFFEEF2FF),
                      onTap: _navigateToProfile,
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Icons.notifications_none_outlined,
                      title: 'Notifications',
                      subtitle: 'Alerts, mentions & updates',
                      iconColor: const Color(0xFFD97706),
                      iconBgColor: const Color(0xFFFFFBEB),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeNotificationsScreen())),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Icons.description_outlined,
                      title: 'Documents',
                      subtitle: 'Policies, slips & certificates',
                      iconColor: const Color(0xFF6366F1),
                      iconBgColor: const Color(0xFFEEF2FF),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeDocumentsScreen())),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Icons.history_rounded,
                      title: 'History',
                      subtitle: 'Tasks & past requests',
                      iconColor: const Color(0xFF8B5CF6),
                      iconBgColor: const Color(0xFFF5F3FF),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeHistoryScreen())),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Icons.adjust,
                      title: 'Settings',
                      subtitle: 'Appearance, privacy & security',
                      iconColor: const Color(0xFF7C3AED),
                      iconBgColor: const Color(0xFFF5F3FF),
                      onTap: () => _showComingSoon('Settings'),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      icon: Icons.info_outline,
                      title: 'Help & Support',
                      subtitle: 'FAQs, contact HR & tickets',
                      iconColor: const Color(0xFFDC2626),
                      iconBgColor: const Color(0xFFFEF2F2),
                      onTap: () => _showComingSoon('Help & Support'),
                    ),
                    const SizedBox(height: 24),

                    // Sign Out Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _handleSignOut,
                        icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF2F2), // Red tinted bg
                          side: const BorderSide(color: Color(0xFFFECACA)), // Light red border
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  ),
);
  }

  Widget _buildProfileHeader(String name, String initials, String role, String department, String employeeId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C5CFF), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$role Â· $employeeId',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  department,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
