import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/screens/login_screen.dart';
import 'package:attendance_app/screens/auth_wrapper.dart';
import 'package:attendance_app/screens/employee/employee_main_screen.dart';
import 'package:attendance_app/features/manager_main_screen.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/widgets/animated_mesh_gradient.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 1.0, curve: Curves.easeIn)),
    );

    _controller.forward().then((_) => _checkAuthAndNavigate());
  }

  /// After splash animation completes, decide where to go.
  Future<void> _checkAuthAndNavigate() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    // No logged-in user → show login
    if (currentUser == null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
      return;
    }

    // Reload token to ensure it's still valid
    try {
      await currentUser.reload();
    } catch (_) {
      // Token invalid / user deleted → go to login
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
      return;
    }

    final email = currentUser.email?.toLowerCase() ?? '';

    try {
      // Restore role & companyId from approved_users
      String? role;
      String? companyId;

      final approvedDoc =
          await FirestoreService.approvedUserDoc(email).get();
      if (approvedDoc.exists && approvedDoc.data() != null) {
        final d = approvedDoc.data()!;
        role = (d['role'] as String? ?? 'employee').toLowerCase();
        companyId = d['companyId'] as String? ?? '';
      } else {
        // Fallback: check companies collection for manager
        final companySearch =
            await FirestoreService.findCompanyByManagerEmail(email);
        if (companySearch.docs.isNotEmpty) {
          role = 'manager';
          companyId = companySearch.docs.first.id;
        }
      }

      if (role == null || companyId == null || companyId.isEmpty) {
        throw Exception('User record not found.');
      }

      // Restore company details
      double? officeLat;
      double? officeLng;
      double? allowedRadius;
      String? companyName;
      String? shiftStartTime;
      String? shiftEndTime;
      int? gracePeriod;
      int? paidLeavesPerYear;

      final companyDoc =
          await FirestoreService.companyDoc(companyId).get();
      if (companyDoc.exists && companyDoc.data() != null) {
        final d = companyDoc.data()!;
        final companyStatus =
            (d['status'] as String? ?? 'pending').trim().toLowerCase();
        if (companyStatus != 'approved' && companyStatus != 'active') {
          throw Exception('Company access blocked.');
        }
        companyName = d['companyName'] as String?;
        shiftStartTime = d['shiftStartTime'] as String?;
        shiftEndTime = d['shiftEndTime'] as String?;
        gracePeriod = (d['gracePeriod'] as num?)?.toInt();
        paidLeavesPerYear = (d['paidLeavesPerYear'] as num?)?.toInt();
        final loc = d['location'] as Map<String, dynamic>?;
        if (loc != null) {
          final lat = loc['latitude'];
          final lng = loc['longitude'];
          officeLat = lat is String
              ? double.tryParse(lat)
              : (lat as num?)?.toDouble();
          officeLng = lng is String
              ? double.tryParse(lng)
              : (lng as num?)?.toDouble();
        }
        allowedRadius = (d['allowedRadius'] as num?)?.toDouble();
      }

      // Restore user name
      String? userName;
      try {
        final userDoc =
            await FirestoreService.userDocByEmail(email).get();
        userName = userDoc.data()?['name'] as String?;
        if (userName == null || userName.trim().isEmpty) {
          final q = await FirestoreService.usersCol
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            userName = q.docs.first.data()['name'] as String?;
          }
        }
      } catch (_) {
        userName = currentUser.displayName;
      }

      // Populate session
      AppSession().populate(
        uid: currentUser.uid,
        email: email,
        role: role,
        companyId: companyId,
        companyName: companyName,
        officeLat: officeLat,
        officeLng: officeLng,
        allowedRadius: allowedRadius,
        shiftStartTime: shiftStartTime,
        shiftEndTime: shiftEndTime,
        gracePeriod: gracePeriod,
        paidLeavesPerYear: paidLeavesPerYear,
      );
      if (userName != null && userName.trim().isNotEmpty) {
        AppSession().userName = userName;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'manager'
              ? const ManagerMainScreen()
              : const EmployeeMainScreen(),
        ),
      );
    } catch (e) {
      debugPrint('Auto-login failed: $e');
      // Session restore failed — sign out and show login
      await FirebaseAuth.instance.signOut();
      AppSession().clear();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedMeshGradient(
        child: SafeArea(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SizedBox.expand(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  const Spacer(flex: 3),

                  // App Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // App Name
                  const Text(
                    "ATTENDANCE",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: 3,
                    ),
                  ),
                  const Text(
                    "TRACKER",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primary,
                      letterSpacing: 6,
                    ),
                  ),


                  const SizedBox(height: 12),

                  // 📝 Corporate Tagline
                  const Text(
                    "Enterprise Presence System",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const Spacer(flex: 4),

                  // Loading indicator while auth check runs
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 🧾 Footer
                  const Text(
                    "SECURE • RELIABLE • ENTERPRISE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textHint,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
