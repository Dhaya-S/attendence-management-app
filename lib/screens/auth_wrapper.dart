import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/screens/pre_login_screen.dart';
import 'package:attendance_app/screens/organization_setup_screen.dart';
import 'package:attendance_app/screens/admin_dashboard_screen.dart';
import 'package:attendance_app/screens/employee/employee_main_screen.dart';
import 'package:attendance_app/features/manager_main_screen.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/notification_service.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _sessionLoaded = false;
  bool _needsSetup = false;
  String? _error;
  late Future<User?> _initialAuthFuture;

  @override
  void initState() {
    super.initState();
    // Capture the first event from Firebase with a safety timeout to prevent hanging
    _initialAuthFuture = FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 3), onTimeout: () => FirebaseAuth.instance.currentUser);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _initialAuthFuture,
      builder: (context, authSnapshot) {
        // 1. Still waiting for Firebase (with a safety timeout active)
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return _loadingScreen();
        }

        final initialUser = authSnapshot.data ?? FirebaseAuth.instance.currentUser;

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          initialData: initialUser,
          builder: (context, snapshot) {
            final user = snapshot.data;

            // 2. No user found -> Show pre-login landing screen
            if (user == null) {
              _sessionLoaded = false;
              return const PreLoginScreen();
            }

            if (_error != null) {
              return _errorScreen(_error!);
            }

            if (_needsSetup) {
              return const OrganizationSetupScreen();
            }

            // 3. User exists -> Load Session if not already loaded
            if (!_sessionLoaded) {
              return FutureBuilder(
                future: _loadSession(user),
                builder: (context, sessionSnap) {
                  if (sessionSnap.connectionState == ConnectionState.waiting) {
                    return _loadingScreen();
                  }
                  
                  if (sessionSnap.hasError || _error != null) {
                    return _errorScreen(sessionSnap.error?.toString() ?? _error ?? 'Unknown error occurred.');
                  }

                  return _checkLocationAndNavigate();
                },
              );
            }

            return _checkLocationAndNavigate();
          },
        );
      },
    );
  }

  Widget _checkLocationAndNavigate() {
    return FutureBuilder<bool>(
      future: _checkAndRequestLocation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingScreen();
        }
        
        final hasLocation = snapshot.data ?? false;
        if (!hasLocation) {
          return LocationRequiredScreen(
            onRetry: () {
              setState(() {
                // This triggers a rebuild, causing FutureBuilder to run _checkAndRequestLocation again
              });
            },
          );
        }
        
        return _navigateToMain();
      },
    );
  }

  Future<bool> _checkAndRequestLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking location: $e');
      return false;
    }
  }

  Widget _loadingScreen() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }

  Widget _errorScreen(String message) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Session Restore Failed',
                style: AppTheme.h2,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => setState(() {
                  _error = null;
                }),
                child: const Text('RETRY'),
              ),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  AppSession().clear();
                },
                child: const Text('BACK TO LOGIN', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navigateToMain() {
    if (AppSession().role == 'admin') return const AdminDashboardScreen();
    if (AppSession().role == 'manager') return const ManagerMainScreen();
    return const EmployeeMainScreen();
  }

  Future<void> _loadSession(User user) async {
    // Force asynchronous execution to prevent "setState during build" exceptions
    await Future.microtask(() {});
    
    try {
      final email = user.email?.toLowerCase() ?? '';

      // ── Fast path: session already populated during registration ────────────
      // This happens when a new admin just created their account via the setup
      // flow. AppSession is already populated; no Firestore read needed.
      if (AppSession().isReady) {
        if (mounted) setState(() { _sessionLoaded = true; _error = null; });
        return;
      }

      // ── Look up approved_users global mapping ────────────────────────────────
      String? role;
      String? companyId;

      final approvedDoc = await FirestoreService.approvedUserDoc(email).get();
      if (approvedDoc.exists && approvedDoc.data() != null) {
        final d = approvedDoc.data()!;
        role = (d['role'] as String? ?? 'employee').toLowerCase();

        // NEW: self-registered orgs use 'orgId'; legacy uses 'companyId'
        final orgId = d['orgId'] as String?;
        companyId = d['companyId'] as String? ?? orgId ?? '';

        // ── NEW: Load from `organizations` collection ──────────────────────
        if (orgId != null && orgId.isNotEmpty) {
          await _loadSessionFromOrganizations(user, email, role, orgId);
          return;
        }
      } else {
        // Fallback: find legacy company by managerEmail field
        final companySearch = await FirestoreService.findCompanyByManagerEmail(email);
        if (companySearch.docs.isNotEmpty) {
          role = 'manager';
          companyId = companySearch.docs.first.id;

          // Auto-provision manager into approved_users
          try {
            await FirestoreService.approvedUserDoc(email).set({
              'role': 'manager',
              'companyId': companyId,
              'email': email,
              'status': 'approved',
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            debugPrint('Manager auto-provisioned into approved_users.');
          } catch (e) {
            debugPrint('Manager auto-provisioning warning: $e');
          }
        }
      }

      if (role == null || companyId == null || companyId.isEmpty) {
        // Brand new admins won't have a record yet; route them to the setup flow.
        if (mounted) {
          setState(() {
            _needsSetup = true;
            _error = null;
            _sessionLoaded = true;
          });
        }
        return;
      }

      // ── LEGACY: Load from `approved_companies` collection ────────────────
      final companyDoc = await FirestoreService.companyDoc(companyId).get();
      if (!companyDoc.exists || companyDoc.data() == null) {
        throw Exception('Company record not found.');
      }
      final cd = companyDoc.data()!;

      // Restore user name
      String? userName;
      final userDoc = await FirestoreService.companyDoc(companyId)
          .collection('users')
          .doc(email)
          .get();
      if (userDoc.exists && userDoc.data()?['name'] != null) {
        userName = userDoc.data()?['name'] as String?;
      } else {
        final q = await FirestoreService.companyDoc(companyId)
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          userName = q.docs.first.data()['name'] as String?;
        }
      }

      double? parseDouble(dynamic v) =>
          v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
      int? parseInt(dynamic v) =>
          v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

      AppSession().populate(
        uid: user.uid,
        email: email,
        role: role,
        companyId: companyId,
        companyName: cd['companyName'] as String?,
        shiftStartTime: cd['shiftStartTime'] as String?,
        shiftEndTime: cd['shiftEndTime'] as String?,
        gracePeriod: parseInt(cd['gracePeriod']),
        paidLeavesPerYear: parseInt(cd['paidLeavesPerYear']),
        userName: userName,
      );

      final loc = cd['location'] as Map<String, dynamic>?;
      if (loc != null) {
        AppSession().officeLat = parseDouble(loc['latitude']);
        AppSession().officeLng = parseDouble(loc['longitude']);
      }
      AppSession().allowedRadius = parseDouble(cd['allowedRadius']) ?? 500;

      NotificationService().onUserLogin();

      if (mounted) {
        setState(() { _sessionLoaded = true; _error = null; });
      }
    } catch (e) {
      debugPrint('AuthWrapper Load Error: $e');
      if (mounted) setState(() { _error = e.toString(); });
      rethrow;
    }
  }

  /// Load session from the new `organizations/{orgId}/members/{uid}` structure.
  Future<void> _loadSessionFromOrganizations(
      User user, String email, String role, String orgId) async {
    try {
      // Load org master doc
      final orgDoc = await FirestoreService.orgDoc(orgId).get();
      if (!orgDoc.exists || orgDoc.data() == null) {
        throw Exception('Organization record not found.');
      }
      final od = orgDoc.data()!;

      // Load member profile
      final memberDoc = await FirestoreService.orgMemberDoc(orgId, user.uid).get();
      String? userName;
      if (memberDoc.exists && memberDoc.data() != null) {
        userName = memberDoc.data()!['fullName'] as String?;
      }

      AppSession().populate(
        uid: user.uid,
        email: email,
        role: role,
        companyId: orgId,
        companyName: od['companyName'] as String? ?? od['name'] as String?,
        userName: userName,
      );

      NotificationService().onUserLogin();

      if (mounted) {
        setState(() { _sessionLoaded = true; _error = null; });
      }
    } catch (e) {
      debugPrint('_loadSessionFromOrganizations error: $e');
      rethrow;
    }
  }
}

class LocationRequiredScreen extends StatefulWidget {
  final VoidCallback onRetry;

  const LocationRequiredScreen({super.key, required this.onRetry});

  @override
  State<LocationRequiredScreen> createState() => _LocationRequiredScreenState();
}

class _LocationRequiredScreenState extends State<LocationRequiredScreen> {
  bool _isChecking = false;

  Future<void> _openSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    size: 64,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Location Access Required',
                  style: AppTheme.h1.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'To proceed and use the app, location services must be enabled and permissions granted. This ensures correct shift proximity checks and attendance logs.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isChecking
                        ? null
                        : () async {
                            setState(() => _isChecking = true);
                            widget.onRetry();
                            await Future.delayed(const Duration(milliseconds: 500));
                            if (mounted) setState(() => _isChecking = false);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'RETRY / ENABLE',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _openSettings,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'OPEN APP SETTINGS',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _openLocationSettings,
                  child: const Text(
                    'Turn on GPS / Location Services',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                TextButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    AppSession().clear();
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                  label: const Text(
                    'SIGN OUT',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
