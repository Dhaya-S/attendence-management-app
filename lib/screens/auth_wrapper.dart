import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/screens/login_screen.dart';
import 'package:attendance_app/screens/unified_dashboard_screen.dart';

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
  String? _error;
  late Future<User?> _initialAuthFuture;
  StreamSubscription<DocumentSnapshot>? _orgSubscription;
  StreamSubscription<DocumentSnapshot>? _legacyOrgSubscription;
  StreamSubscription<QuerySnapshot>? _shiftsSubscription;

  @override
  void dispose() {
    _orgSubscription?.cancel();
    _legacyOrgSubscription?.cancel();
    _shiftsSubscription?.cancel();
    super.dispose();
  }

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
              return const LoginScreen();
            }

            if (_error != null) {
              return _errorScreen(_error!);
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
      // Geofencing off (organization policy or this role's permission) → the web app does not
      // ask for location at all, so neither do we.
      if (AppSession().isReady && !AppSession().hasPermission('geofencing')) {
        return true;
      }
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
    return const UnifiedDashboardScreen();
  }

  Future<void> _loadSession(User user) async {
    // Force asynchronous execution to prevent "setState during build" exceptions
    await Future.microtask(() {});
    
    try {
      final email = user.email?.toLowerCase() ?? '';

      // ── Fast path: session already populated during registration ────────────
      // This happens when a new admin just created their account via the setup
      // flow. AppSession is already populated; no Firestore read needed.
      if (AppSession().isReady && AppSession().uid == user.uid) {
        if (mounted) setState(() { _sessionLoaded = true; _error = null; });
        return;
      }
      // A session left over from a DIFFERENT user (e.g. the previous person on this device
      // logged out without it being cleared) must never be reused — load this user's own.
      if (AppSession().isReady && AppSession().uid != user.uid) {
        AppSession().clear();
      }

      // ── Look up approved_users global mapping ────────────────────────────────
      String? role;
      String? companyId;

      final approvedDoc = await FirestoreService.approvedUserDoc(email).get();
      debugPrint('AUTH DEBUG: email=$email, approvedDoc.exists=${approvedDoc.exists}');
      
      if (approvedDoc.exists && approvedDoc.data() != null) {
        final d = approvedDoc.data()!;
        debugPrint('AUTH DEBUG: approvedDoc data=$d');
        final rawRole = (d['role'] as String? ?? 'employee').toLowerCase().trim();
        role = (rawRole == 'super_admin' ||
                rawRole == 'superadmin' ||
                rawRole == 'admin' ||
                rawRole == 'hr_admin' ||
                rawRole == 'hradmin')
            ? 'hr_admin'
            : rawRole == 'manager'
                ? 'manager'
                : 'employee';

        // NEW: self-registered orgs use 'orgId'; legacy uses 'companyId'
        final orgId = d['orgId'] as String? ?? d['companyId'] as String?;
        companyId = d['companyId'] as String? ?? orgId ?? '';
        debugPrint('AUTH DEBUG: parsed role=$role, orgId=$orgId, companyId=$companyId');

        // ── NEW: Try to load from `organizations` collection first ────────
        if (orgId != null && orgId.isNotEmpty) {
          try {
            debugPrint('AUTH DEBUG: Attempting to load session from organizations/$orgId');
            await _loadSessionFromOrganizations(user, email, role, orgId);
            return;
          } catch (e) {
            debugPrint('AUTH DEBUG: Failed to load from organizations, falling back to legacy: $e');
          }
        }
      } else {
        // ── Fallback 1: find org where this email is the managerEmail ────────
        final companySearch = await FirestoreService.findCompanyByManagerEmail(email);
        debugPrint('AUTH DEBUG: legacy companySearch docs count=${companySearch.docs.length}');
        if (companySearch.docs.isNotEmpty) {
          role = 'manager';
          companyId = companySearch.docs.first.id;
          debugPrint('AUTH DEBUG: found legacy company $companyId for manager');

          // Auto-provision manager into approved_users
          try {
            await FirestoreService.approvedUserDoc(email).set({
              'role': 'manager',
              'companyId': companyId,
              'orgId': companyId,
              'email': email,
              'status': 'approved',
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            debugPrint('Manager auto-provisioned into approved_users.');
          } catch (e) {
            debugPrint('Manager auto-provisioning warning: $e');
          }
        } else {
          // ── Fallback 2: search organizations collection for this email as
          //    admin/super-admin. Web-registered org admins are stored in the
          //    organizations collection directly, NOT in approved_users. ───────
          debugPrint('AUTH DEBUG: searching organizations for admin email=$email');
          String? foundOrgId;
          String? foundRole;

          // Check adminDetails.email field (most web-registered orgs use this)
          try {
            final adminDetailsSearch = await FirebaseFirestore.instance
                .collection('organizations')
                .where('adminDetails.email', isEqualTo: email)
                .limit(1)
                .get();
            if (adminDetailsSearch.docs.isNotEmpty) {
              foundOrgId = adminDetailsSearch.docs.first.id;
              foundRole = 'hr_admin';
              debugPrint('AUTH DEBUG: found org $foundOrgId via adminDetails.email');
            }
          } catch (e) {
            debugPrint('AUTH DEBUG: adminDetails search error: $e');
          }

          // Check superAdminEmail field
          if (foundOrgId == null) {
            try {
              final superAdminSearch = await FirebaseFirestore.instance
                  .collection('organizations')
                  .where('superAdminEmail', isEqualTo: email)
                  .limit(1)
                  .get();
              if (superAdminSearch.docs.isNotEmpty) {
                foundOrgId = superAdminSearch.docs.first.id;
                foundRole = 'hr_admin';
                debugPrint('AUTH DEBUG: found org $foundOrgId via superAdminEmail');
              }
            } catch (e) {
              debugPrint('AUTH DEBUG: superAdminEmail search error: $e');
            }
          }

          // Check contactEmail field
          if (foundOrgId == null) {
            try {
              final contactSearch = await FirebaseFirestore.instance
                  .collection('organizations')
                  .where('contactEmail', isEqualTo: email)
                  .limit(1)
                  .get();
              if (contactSearch.docs.isNotEmpty) {
                foundOrgId = contactSearch.docs.first.id;
                foundRole = 'hr_admin';
                debugPrint('AUTH DEBUG: found org $foundOrgId via contactEmail');
              }
            } catch (e) {
              debugPrint('AUTH DEBUG: contactEmail search error: $e');
            }
          }

          // Last resort: search users subcollection across all orgs
          if (foundOrgId == null) {
            try {
              final userGroupSearch = await FirebaseFirestore.instance
                  .collectionGroup('users')
                  .where('email', isEqualTo: email)
                  .limit(1)
                  .get();
              if (userGroupSearch.docs.isNotEmpty) {
                final ref = userGroupSearch.docs.first.reference;
                // Path: organizations/{orgId}/users/{docId} — extract orgId
                final segments = ref.path.split('/');
                if (segments.length >= 2 && segments[0] == 'organizations') {
                  foundOrgId = segments[1];
                  final userData = userGroupSearch.docs.first.data();
                  final rawR = (userData['role'] as String? ?? 'employee').toLowerCase();
                  foundRole = (rawR == 'super_admin' || rawR == 'superadmin' ||
                          rawR == 'admin' || rawR == 'hr_admin' || rawR == 'hradmin')
                      ? 'hr_admin'
                      : rawR == 'manager'
                          ? 'manager'
                          : 'employee';
                  debugPrint('AUTH DEBUG: found org $foundOrgId via collectionGroup users');
                }
              }
            } catch (e) {
              debugPrint('AUTH DEBUG: collectionGroup users search error: $e');
            }
          }

          if (foundOrgId != null && foundRole != null) {
            role = foundRole;
            companyId = foundOrgId;

            // Auto-provision this admin into approved_users so future logins are fast
            try {
              await FirestoreService.approvedUserDoc(email).set({
                'role': role,
                'companyId': companyId,
                'orgId': companyId,
                'email': email,
                'status': 'approved',
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              debugPrint('AUTH DEBUG: auto-provisioned $email → org $companyId into approved_users');
            } catch (e) {
              debugPrint('AUTH DEBUG: auto-provision warning: $e');
            }

            // Load directly from organizations and return early
            try {
              await _loadSessionFromOrganizations(user, email, role, companyId);
              return;
            } catch (e) {
              debugPrint('AUTH DEBUG: _loadSessionFromOrganizations failed after org discovery: $e');
              // Fall through so the error message is shown
              role = null;
              companyId = null;
            }
          } else {
            debugPrint('AUTH DEBUG: email=$email not found in any org. User is not registered.');
          }
        }
      }

      debugPrint('AUTH DEBUG: final role=$role, companyId=$companyId');
      if (role == null || companyId == null || companyId.isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'Your account is not assigned to any organization. Please contact your administrator.';
            _sessionLoaded = true;
          });
        }
        return;
      }

      // ── Load from `organizations` collection ────────────────
      final companyDoc = await FirestoreService.companyDoc(companyId).get();
      if (!companyDoc.exists || companyDoc.data() == null) {
        // Company doc not found — could be a stale companyId or data mismatch.
        // Proceeding anyway since we have the companyId and role.
        debugPrint('AuthWrapper: companyDoc($companyId) not found, proceeding anyway.');
      }
      final cd = companyDoc.data() ?? {};

      // Restore user name
      String? userName;
      String? department;
      final userDoc = await FirestoreService.companyDoc(companyId)
          .collection('users')
          .doc(email)
          .get();
      String? userShiftId;
      if (userDoc.exists && userDoc.data() != null) {
        final ud = userDoc.data()!;
        userName = ud['name'] as String?;
        department = ud['department'] as String?;
        userShiftId = FirestoreService.userShiftKey(ud);
      } else {
        final q = await FirestoreService.companyDoc(companyId)
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final ud = q.docs.first.data();
          userName = ud['name'] as String?;
          department = ud['department'] as String?;
          userShiftId = FirestoreService.userShiftKey(ud);
        }
      }

      int? parseInt(dynamic v) =>
          v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

      // Fetch dynamic shift from organizations/{companyId}/shifts
      final shiftData = await FirestoreService.fetchApplicableShift(
        companyId: companyId,
        shiftId: userShiftId,
        department: department,
      );

      // Extract isGeofencingEnabled from org doc
      bool? geoEnabled;
      if (cd.containsKey('isGeofencingEnabled')) {
        final gv = cd['isGeofencingEnabled'];
        if (gv is bool) geoEnabled = gv;
        else if (gv is String) geoEnabled = gv.toLowerCase() == 'true';
      }

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
        featurePermissions: cd['featurePermissions'] as Map<String, dynamic>?,
        isGeofencingEnabled: geoEnabled,
        userName: userName,
        department: department,
      );

      // Apply dynamic shift configuration from database
      if (shiftData != null) {
        AppSession().updateShiftFromMap(shiftData);
      }

      AppSession().updateOfficeLocationFromMap(cd);
      await FirestoreService.resolveOfficeForCurrentUser(orgData: cd);

      NotificationService().onUserLogin();

      if (mounted) {
        setState(() { _sessionLoaded = true; _error = null; });
      }

      // ── Set up real-time listener on shifts collection ───────────────────
      _shiftsSubscription?.cancel();
      _shiftsSubscription = FirestoreService.orgShiftsCol(companyId)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.docs.isNotEmpty) {
          final updatedShift = await FirestoreService.fetchApplicableShift(
            companyId: companyId,
            shiftId: userShiftId,
            department: AppSession().department,
          );
          if (updatedShift != null) {
            AppSession().updateShiftFromMap(updatedShift);
            if (mounted) setState(() {});
          }
        }
      });

      // ── Set up real-time listener on legacy company doc ──────────────────
      _legacyOrgSubscription?.cancel();
      _legacyOrgSubscription = FirestoreService.companyDoc(companyId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final liveData = snapshot.data()!;
          Map<String, dynamic>? newPerms;
          bool? newGeo;
          if (liveData.containsKey('featurePermissions')) {
            newPerms = liveData['featurePermissions'] as Map<String, dynamic>;
          }
          if (liveData.containsKey('isGeofencingEnabled')) {
            final gv = liveData['isGeofencingEnabled'];
            if (gv is bool) newGeo = gv;
            else if (gv is String) newGeo = gv.toLowerCase() == 'true';
          }
          AppSession().updatePermissions(
            newPermissions: newPerms,
            newGeofencingEnabled: newGeo,
          );
          AppSession().updateOfficeLocationFromMap(liveData);
          FirestoreService.resolveOfficeForCurrentUser(orgData: liveData);
          if (mounted) setState(() {});
        }
      });
    } catch (e) {
      debugPrint('AuthWrapper Load Error: $e');
      if (mounted) setState(() { _error = e.toString(); });
    }
  }

  /// Load session from the new `organizations/{orgId}/members/{uid}` structure.
  Future<void> _loadSessionFromOrganizations(
      User user, String email, String role, String orgId) async {
    try {
      // Load org master doc initially
      final orgDocRef = FirestoreService.orgDoc(orgId);
      final orgDoc = await orgDocRef.get();
      if (!orgDoc.exists || orgDoc.data() == null) {
        throw Exception('Organization record not found.');
      }
      final od = orgDoc.data()!;

      // Load member profile from members, users collection, or adminDetails
      final memberDoc = await FirestoreService.orgMemberDoc(orgId, user.uid).get();
      String? userName;
      String? department;
      String? userShiftId;
      if (memberDoc.exists && memberDoc.data() != null) {
        final md = memberDoc.data()!;
        userName = (md['fullName'] ?? md['name']) as String?;
        department = (md['department'] ?? md['dept']) as String?;
        userShiftId = FirestoreService.userShiftKey(md);
      }

      // Check users subcollection if not found in members
      if (userName == null || department == null) {
        final userDoc = await FirestoreService.companyDoc(orgId)
            .collection('users')
            .doc(email.toLowerCase())
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final ud = userDoc.data()!;
          userName ??= (ud['name'] ?? ud['fullName'] ?? '${ud['firstName'] ?? ''} ${ud['lastName'] ?? ''}'.trim()) as String?;
          department ??= (ud['department'] ?? ud['dept']) as String?;
          userShiftId ??= FirestoreService.userShiftKey(ud);
        } else {
          final q = await FirestoreService.companyDoc(orgId)
              .collection('users')
              .where('email', isEqualTo: email.toLowerCase())
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            final ud = q.docs.first.data();
            userName ??= (ud['name'] ?? ud['fullName'] ?? '${ud['firstName'] ?? ''} ${ud['lastName'] ?? ''}'.trim()) as String?;
            department ??= (ud['department'] ?? ud['dept']) as String?;
            userShiftId ??= FirestoreService.userShiftKey(ud);
          }
        }
      }

      // Fallback to adminDetails on the org document if current user is the admin
      if ((userName == null || department == null) && od.containsKey('adminDetails')) {
        final ad = od['adminDetails'] as Map<String, dynamic>? ?? {};
        final adminEmail = (ad['email'] as String? ?? '').toLowerCase().trim();
        if (adminEmail == email.toLowerCase().trim()) {
          userName ??= (ad['name'] ?? '${ad['firstName'] ?? ''} ${ad['lastName'] ?? ''}'.trim()) as String?;
          department ??= (ad['department'] ?? ad['dept']) as String?;
        }
      }

      int? parseInt(dynamic v) =>
          v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

      // Fetch dynamic shift from organizations/{orgId}/shifts
      final shiftData = await FirestoreService.fetchApplicableShift(
        companyId: orgId,
        shiftId: userShiftId,
        department: department,
      );

      // Extract isGeofencingEnabled from org doc
      bool? geoEnabled;
      if (od.containsKey('isGeofencingEnabled')) {
        final gv = od['isGeofencingEnabled'];
        if (gv is bool) geoEnabled = gv;
        else if (gv is String) geoEnabled = gv.toLowerCase() == 'true';
      }

      final rawRole = role.toLowerCase().trim();
      final cleanRole = (rawRole == 'super_admin' ||
              rawRole == 'superadmin' ||
              rawRole == 'admin' ||
              rawRole == 'hr_admin' ||
              rawRole == 'hradmin')
          ? 'hr_admin'
          : rawRole == 'manager'
              ? 'manager'
              : 'employee';

      AppSession().populate(
        uid: user.uid,
        email: email,
        role: cleanRole,
        companyId: orgId,
        companyName: od['companyName'] as String? ?? od['name'] as String?,
        shiftStartTime: od['shiftStartTime'] as String?,
        shiftEndTime: od['shiftEndTime'] as String?,
        gracePeriod: parseInt(od['gracePeriod']),
        paidLeavesPerYear: parseInt(od['paidLeavesPerYear']),
        featurePermissions: od['featurePermissions'] as Map<String, dynamic>?,
        isGeofencingEnabled: geoEnabled,
        userName: userName,
        department: department,
      );

      // Apply dynamic shift configuration from database
      if (shiftData != null) {
        AppSession().updateShiftFromMap(shiftData);
      }

      AppSession().updateOfficeLocationFromMap(od);
      await FirestoreService.resolveOfficeForCurrentUser(orgData: od);

      NotificationService().onUserLogin();

      if (mounted) {
        setState(() { _sessionLoaded = true; _error = null; });
      }

      // ── Set up real-time listener on shifts collection ───────────────────
      _shiftsSubscription?.cancel();
      _shiftsSubscription = FirestoreService.orgShiftsCol(orgId)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.docs.isNotEmpty) {
          final updatedShift = await FirestoreService.fetchApplicableShift(
            companyId: orgId,
            shiftId: userShiftId,
            department: AppSession().department,
          );
          if (updatedShift != null) {
            AppSession().updateShiftFromMap(updatedShift);
            if (mounted) setState(() {});
          }
        }
      });

      // ── Set up real-time listener for permissions, geofencing & location ──
      _orgSubscription?.cancel();
      _orgSubscription = orgDocRef.snapshots().listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final liveData = snapshot.data()!;
          Map<String, dynamic>? newPerms;
          bool? newGeo;
          if (liveData.containsKey('featurePermissions')) {
            newPerms = liveData['featurePermissions'] as Map<String, dynamic>;
          }
          if (liveData.containsKey('isGeofencingEnabled')) {
            final gv = liveData['isGeofencingEnabled'];
            if (gv is bool) newGeo = gv;
            else if (gv is String) newGeo = gv.toLowerCase() == 'true';
          }
          AppSession().updatePermissions(
            newPermissions: newPerms,
            newGeofencingEnabled: newGeo,
          );
          AppSession().updateOfficeLocationFromMap(liveData);
          FirestoreService.resolveOfficeForCurrentUser(orgData: liveData);
          if (mounted) setState(() {});
        }
      });
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
