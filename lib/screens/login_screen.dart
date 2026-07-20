import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:attendance_app/screens/auth_wrapper.dart';
import 'package:attendance_app/screens/common/password_recovery_flow.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/message_helper.dart';
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
  final TextEditingController confirmPasswordController = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  bool isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isProcessingLogin = false;
  bool _isSignupMode = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _confirmPasswordFocus.addListener(() => setState(() {}));

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animController.forward();
  }

  Future<void> _checkAutoLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (_isProcessingLogin) return;

    _isProcessingLogin = true;
    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);

    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => isLoading = false);
      _isProcessingLogin = false;
      MessageHelper.showWarning(context, 'Please enter email and password');
      return;
    }

    if (_isSignupMode) {
      final confirm = confirmPasswordController.text.trim();
      if (password != confirm) {
        setState(() => isLoading = false);
        _isProcessingLogin = false;
        MessageHelper.showWarning(context, 'Passwords do not match');
        return;
      }
      if (password.length < 6) {
        setState(() => isLoading = false);
        _isProcessingLogin = false;
        MessageHelper.showWarning(context, 'Password must be at least 6 characters');
        return;
      }
    }

    try {
      UserCredential credential;
      
      if (_isSignupMode) {
        // 1. Verify user is invited first
        final approvedDoc = await FirestoreService.approvedUserDoc(email).get();
        if (!approvedDoc.exists || approvedDoc.data() == null) {
          setState(() => isLoading = false);
          _isProcessingLogin = false;
          MessageHelper.showError(
            context,
            'This email is not invited by any admin. Please contact your administrator.',
          );
          return;
        }

        // 2. Create the Auth record
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // Standard login
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      final currentUser = credential.user!;
      await currentUser.getIdToken(true);

      String? role;
      String? companyId;

      final approvedDoc = await FirestoreService.approvedUserDoc(email).get();
      if (approvedDoc.exists && approvedDoc.data() != null) {
        final data = approvedDoc.data()!;
        role = (data['role'] as String? ?? 'employee').toLowerCase();
        companyId = data['companyId'] as String? ?? '';
      } else {
        final companySearch =
            await FirestoreService.findCompanyByManagerEmail(email);
        if (companySearch.docs.isNotEmpty) {
          final compDoc = companySearch.docs.first;
          role = 'manager';
          companyId = compDoc.id;

          try {
            await FirestoreService.approvedUserDoc(email).set({
              'role': 'manager',
              'companyId': companyId,
              'email': email,
              'status': 'approved',
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('Manager auto-provisioning warning: $e');
          }
        }
      }

      if (role == null || companyId == null || companyId.isEmpty) {
        // User may be an admin who hasn't completed organization setup.
        // Pass control to AuthWrapper which handles incomplete setups.
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
          );
        }
        return;
      }

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
        final companyDoc = await FirestoreService.companyDoc(companyId).get();
        if (companyDoc.exists && companyDoc.data() != null) {
          final d = companyDoc.data()!;
          final companyStatus =
              (d['status'] as String? ?? 'pending').trim().toLowerCase();

          if (companyStatus != 'approved' && companyStatus != 'active') {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              MessageHelper.showError(
                context,
                'Company access blocked. Status: ${companyStatus.toUpperCase()}',
              );
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
      }

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

      try {
        final userDoc = await FirestoreService.userDocByEmail(email).get();
        if (userDoc.exists && userDoc.data()?['name'] != null) {
          fetchedUserName = userDoc.data()?['name'] as String?;
        } else {
          final q = await FirestoreService.usersCol
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
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

      if (fetchedUserName != null && fetchedUserName.trim().isNotEmpty) {
        AppSession().userName = fetchedUserName;
      }

      NotificationService().onUserLogin();

      try {
        final loginData = <String, dynamic>{
          'email': email,
          'uid': currentUser.uid,
          'role': role,
          'companyId': companyId,
          'last_login': FieldValue.serverTimestamp(),
        };

        if (currentUser.displayName != null &&
            currentUser.displayName!.isNotEmpty) {
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

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = _isSignupMode ? 'Setup failed' : 'Authentication failed';
      if (e.code == 'user-not-found') {
        message = 'No account found for this email. If you are a new user, tap "Set your password".';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for this email. Please sign in instead.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      }
      if (mounted) {
        MessageHelper.showError(context, message);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        MessageHelper.showError(context, 'Login failed. Please try again.');
      }
    } finally {
      _isProcessingLogin = false;
      if (mounted) {
        setState(() => isLoading = false);
      }
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 22,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 22),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/signin logo.png',
                                height: 40,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 12),
                              RichText(
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Attendance',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'OS',
                                      style: TextStyle(
                                        color: Color(0xFF5C5CFF),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                           Text(
                            _isSignupMode ? 'Set Password' : 'Welcome Back',
                            style: AppTheme.h1.copyWith(
                              fontSize: 28,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isSignupMode
                                ? 'Create a password for your invited email'
                                : 'Sign in to your account to continue',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildInputField(
                            controller: emailController,
                            focusNode: _emailFocus,
                            hint: 'Work Email',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildInputField(
                            controller: passwordController,
                            focusNode: _passwordFocus,
                            hint: _isSignupMode ? 'Create Password' : 'Password',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            isVisible: _isPasswordVisible,
                            onToggleVisibility: () {
                              setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              );
                            },
                          ),
                          if (_isSignupMode) ...[
                            const SizedBox(height: 16),
                            _buildInputField(
                              controller: confirmPasswordController,
                              focusNode: _confirmPasswordFocus,
                              hint: 'Confirm Password',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              isVisible: _isConfirmPasswordVisible,
                              onToggleVisibility: () {
                                setState(
                                  () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (!_isSignupMode)
                            Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PasswordRecoveryFlow(
                                      isChangePassword: false,
                                    ),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF5C5CFF),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              ),
                            ),
                          const Spacer(),
                          Center(
                            child: SizedBox(
                              width: 327,
                              height: 51,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5C5CFF),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                                        _isSignupMode ? 'Set Password & Login' : 'Sign In',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_isSignupMode) ...[
                            Center(
                              child: SizedBox(
                                width: 327,
                                height: 51,
                                child: OutlinedButton(
                                  onPressed: () {
                                    MessageHelper.showWarning(
                                      context,
                                      'Google sign-in is not configured yet.',
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.textPrimary,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppTheme.textPrimary,
                                            width: 1.5,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'G',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Sign in with Google',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          // Toggle between login and set password mode
                          Center(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _isSignupMode = !_isSignupMode;
                                  passwordController.clear();
                                  confirmPasswordController.clear();
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF5C5CFF),
                              ),
                              child: Text(
                                _isSignupMode
                                    ? 'Already have a password? Sign in'
                                    : 'First time user? Set your password',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggleVisibility,
  }) {
    final isFocused = focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? AppTheme.primary : const Color(0xFFE5E7EB),
          width: isFocused ? 1.4 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: isPassword && !isVisible,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF667085),
          ),
          prefixIcon: Icon(
            icon,
            size: 20,
            color: isFocused ? AppTheme.primary : const Color(0xFF667085),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: onToggleVisibility,
                  icon: Icon(
                    isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: const Color(0xFF667085),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
