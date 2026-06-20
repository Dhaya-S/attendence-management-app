import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:attendance_app/screens/employee/employee_main_screen.dart';
import 'package:attendance_app/features/manager_main_screen.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/message_helper.dart';
import 'package:attendance_app/screens/auth_wrapper.dart';
import 'package:attendance_app/screens/common/password_recovery_flow.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool _isPasswordVisible = false;
  bool _isProcessingLogin = false;
  int _selectedRole = 1; // 0 = Employee, 1 = Manager

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  Future<void> _checkAutoLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // If already logged in, navigate to AuthWrapper to restore session
      // We use pushReplacement to AuthWrapper which will handle the data loading
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (_isProcessingLogin) return;
    _isProcessingLogin = true;
    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);
    bool isNavigating = false;

    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => isLoading = false);
      MessageHelper.showWarning(context, "Please enter email and password");
      return;
    }

    try {
      // ── Step 1: Firebase Auth sign-in ────────────────────────────────────
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final currentUser = credential.user!;
      await currentUser.getIdToken(true);

      // ── Step 2: Global approved_users look-up (with Manager fallback) ───
      String? role;
      String? companyId;
      final approvedDoc = await FirestoreService.approvedUserDoc(email).get();

      if (approvedDoc.exists && approvedDoc.data() != null) {
        final data = approvedDoc.data()!;
        role = (data['role'] as String? ?? 'employee').toLowerCase();
        companyId = data['companyId'] as String? ?? '';
      } else if (_selectedRole == 1) {
        // Fallback for Managers: Check 'companies' collection directly
        final companySearch =
            await FirestoreService.findCompanyByManagerEmail(email);
        if (companySearch.docs.isNotEmpty) {
          final compDoc = companySearch.docs.first;
          role = 'manager';
          companyId = compDoc.id;

          // Auto-provision manager into approved_users global mapping to restore full Firestore rule privileges
          try {
            await FirestoreService.approvedUserDoc(email).set({
              'role': 'manager',
              'companyId': companyId,
              'email': email,
              'status': 'approved',
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            debugPrint('Manager successfully auto-provisioned into approved_users.');
          } catch (e) {
            debugPrint('Manager auto-provisioning warning: $e');
          }
        }
      }

      if (role == null || companyId!.isEmpty) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          MessageHelper.showError(
            context,
            'Your account is not recognized or matching the selected role. '
            'Please contact your admin.',
          );
        }
        return;
      }

      // ── Step 3: Role vs selected-tab validation ──────────────────────────
      final selectedRoleStr = _selectedRole == 0 ? 'employee' : 'manager';
      if (role != selectedRoleStr) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          MessageHelper.showError(
            context,
            'Access Denied: This account is registered as '
            '${role.toUpperCase()}. Please use the correct login portal.',
          );
        }
        return;
      }

      // ── Step 4: Fetch company details (location) ─────────────────────────
      double? officeLat;
      double? officeLng;
      double? allowedRadius;
      String? companyName;
      String? fetchedUserName;
      String? shiftStartTime;
      String? shiftEndTime;
      int? gracePeriod;
      int? paidLeavesPerYear;

      try {
        final companyDoc =
            await FirestoreService.companyDoc(companyId).get();
        if (companyDoc.exists && companyDoc.data() != null) {
          final d = companyDoc.data()!;
          
          final companyStatus =
              (d['status'] as String? ?? 'pending').trim().toLowerCase();
          if (companyStatus != 'approved' && companyStatus != 'active') {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              MessageHelper.showError(context,
                  'Company access blocked. Status: ${companyStatus.toUpperCase()}');
            }
            return;
          }

          companyName = d['companyName'] as String?;
          shiftStartTime = d['shiftStartTime'] as String?;
          shiftEndTime = d['shiftEndTime'] as String?;
          gracePeriod = (d['gracePeriod'] as num?)?.toInt();
          paidLeavesPerYear = (d['paidLeavesPerYear'] as num?)?.toInt();
          final loc = d['location'] as Map<String, dynamic>?;
          if (loc != null) {
            // Support both Number and String formats for coordinates
            final lat = loc['latitude'];
            final lng = loc['longitude'];
            officeLat =
                lat is String ? double.tryParse(lat) : (lat as num?)?.toDouble();
            officeLng =
                lng is String ? double.tryParse(lng) : (lng as num?)?.toDouble();
          }
          allowedRadius = (d['allowedRadius'] as num?)?.toDouble();
        }
      } catch (e) {
        debugPrint('Company fetch warning: $e');
        // Non-fatal — continue login; geofencing may fall back to defaults.
      }

      // ── Step 4.5: Populate global session early ──────────────────────────
      // Must be done before FirestoreService calls that depend on companyId
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

      // ── Step 5: Fetch user name for session ─────────────────────────────
      try {
        final userDoc = await FirestoreService.userDocByEmail(email).get();
        if (userDoc.exists && userDoc.data()?['name'] != null) {
          fetchedUserName = userDoc.data()?['name'] as String?;
        } else {
          // Fallback: limited query if doc ID isn't the email
          final q = await FirestoreService.usersCol.where('email', isEqualTo: email).limit(1).get();
          if (q.docs.isNotEmpty && q.docs.first.data()['name'] != null) {
            fetchedUserName = q.docs.first.data()['name'] as String?;
          } else {
            fetchedUserName = currentUser.displayName;
          }
        }
      } catch (e) {
        debugPrint('User name fetch warning: $e');
        fetchedUserName = currentUser.displayName;
      }

      // Update session with fetched userName
      if (fetchedUserName != null && fetchedUserName!.trim().isNotEmpty) {
        AppSession().userName = fetchedUserName;
      }

      // Initialize notifications for user
      NotificationService().onUserLogin();

      // ── Step 6: Update last_login in company employees sub-collection ────
      try {
        final loginData = <String, dynamic>{
          'email': email,
          'uid': currentUser.uid,
          'role': role,
          'companyId': companyId,
          'last_login': FieldValue.serverTimestamp(),
        };
        // Also seed the name from Auth displayName if the doc doesn't
        // already have one (merge:true preserves existing fields).
        if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
          loginData['name'] = currentUser.displayName;
        }
        final querySnapshot = await FirestoreService.usersCol
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          await querySnapshot.docs.first.reference.set(
            loginData,
            SetOptions(merge: true),
          );
        } else {
          await FirestoreService.userDocByEmail(email).set(
            loginData,
            SetOptions(merge: true),
          );
        }
      } catch (e) {
        debugPrint('last_login update warning: $e');
      }

      isNavigating = true;
      // Note: The root AuthWrapper stream listener automatically handles the auth state change,
      // loads the global session data, and redirects to the correct dashboard tab,
      // completely eliminating double-routing/navigator lock conflicts.
    } on FirebaseAuthException catch (e) {
      String message = 'Authentication failed';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is badly formatted.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      }
      if (mounted) MessageHelper.showError(context, message);
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        MessageHelper.showError(context, 'Login failed. Please try again.');
      }
    } finally {
      _isProcessingLogin = false;
      if (mounted && !isNavigating) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: 28,
                right: 28,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Attendance Pro',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage your workforce with ease',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Role Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _roleTab('Employee', 0),
                        _roleTab('Manager', 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Email Field
                  _buildInputField(
                    controller: emailController,
                    focusNode: _emailFocus,
                    label: 'Email Address',
                    hint: 'manager@company.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 18),

                  // Password Field
                  _buildInputField(
                    controller: passwordController,
                    focusNode: _passwordFocus,
                    label: 'Password',
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    isVisible: _isPasswordVisible,
                    onToggleVisibility: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  ),
                  const SizedBox(height: 8),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PasswordRecoveryFlow(isChangePassword: false),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMD),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Login as ${_selectedRole == 0 ? "Employee" : "Manager"}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bottom links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Need help accessing your account?',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Contact Support',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 14, color: AppTheme.textHint),
                      const SizedBox(width: 4),
                      Text(
                        'Protected by Secure Auth',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ),
                      Text('·',
                          style: TextStyle(
                              color: AppTheme.textHint, fontSize: 11)),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Terms of Service',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleTab(String label, int index) {
    final isActive = _selectedRole == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppTheme.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggleVisibility,
  }) {
    final isFocused = focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isFocused ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            border: Border.all(
              color: isFocused ? AppTheme.primary : AppTheme.divider,
              width: isFocused ? 1.5 : 1,
            ),
            color: AppTheme.surface,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword && !isVisible,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon,
                  color: isFocused ? AppTheme.primary : AppTheme.textHint,
                  size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        isVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppTheme.textHint,
                        size: 20,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
              hintText: hint,
              hintStyle: TextStyle(
                color: AppTheme.textHint,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
