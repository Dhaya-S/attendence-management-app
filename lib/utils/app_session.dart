import 'package:flutter/foundation.dart';

/// AppSession – Global in-memory state for the authenticated user.
///
/// After a successful login, [companyId], [role], and company location
/// are stored here so every screen can access them without re-querying
/// Firestore on every navigation push.
///
/// Permission Matrix (parity with Workzy web app):
///   - featurePermissions is a Map<role, List<permissionKey>> fetched from
///     organizations/{companyId}.featurePermissions
///   - hasPermission(featureKey) evaluates based on the spec below.
class AppSession {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final AppSession _instance = AppSession._internal();
  factory AppSession() => _instance;
  AppSession._internal();

  // ── Authenticated User Info ──────────────────────────────────────────────
  String? uid;
  String? email;
  String? role; // 'hr_admin' | 'manager' | 'employee' (legacy 'super_admin' | 'admin' map to 'hr_admin')
  String? companyId;
  String? companyName;
  String? userName;
  String? department;
  String? get userDepartment => department;

  // ── Company Office Location (fetched from organizations doc) ────────────
  double? officeLat;
  double? officeLng;

  /// Radius (in metres) within which check-in is allowed.
  double allowedRadius = 500;

  /// Shift start time in HH:mm format (24h)
  String shiftStartTime = "09:00";

  /// Shift end time in HH:mm format (24h)
  String shiftEndTime = "18:00";

  /// Grace period in minutes
  int gracePeriod = 15;

  /// Annual paid leave entitlement per employee (days)
  int paidLeavesPerYear = 12;

  /// Whether geofencing is enabled at the organization level.
  /// This is read from organizations/{companyId}.isGeofencingEnabled.
  /// Defaults to true (enforce geofencing when featurePermissions says so).
  bool isGeofencingEnabled = true;

  // ── Role helpers ─────────────────────────────────────────────────────────

  /// HR Admin is the main administrator and head of the company.
  /// Any legacy super_admin or admin roles map directly to HR Admin.
  bool get isHrAdmin =>
      role?.toLowerCase() == 'hr_admin' ||
      role?.toLowerCase() == 'hradmin' ||
      role?.toLowerCase() == 'super_admin' ||
      role?.toLowerCase() == 'superadmin' ||
      role?.toLowerCase() == 'admin';

  /// Legacy alias: admin operations now belong to HR Admin.
  bool get isAdmin => isHrAdmin;

  /// Legacy alias: super admin operations now belong to HR Admin.
  bool get isSuperAdmin => isHrAdmin;

  bool get isManager => role?.toLowerCase() == 'manager';

  /// True if current user is HR Admin or Manager (elevated privileges)
  bool get isManagerOrAbove => isHrAdmin || isManager;

  bool get isEmployee =>
      role?.toLowerCase() == 'employee' ||
      (!isHrAdmin && !isManager);

  /// Grouped getter for administrative dashboards (HR Admin is head of organization)
  bool get hasAdminAccess => isHrAdmin;

  /// Clean display title for the 3 webapp roles (HR Admin, Manager, Employee)
  String get displayRole {
    final r = (role ?? 'employee').toLowerCase().replaceAll('_', ' ').trim();
    if (r == 'super admin' ||
        r == 'superadmin' ||
        r == 'admin' ||
        r == 'hr admin' ||
        r == 'hradmin') {
      return 'HR Admin';
    }
    if (r == 'manager') return 'Manager';
    if (r == 'employee') return 'Employee';
    return r
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  // ── Dynamic Permission Matrix (from Firestore) ───────────────────────────

  /// ValueNotifier to notify UI widgets when permissions change in real-time
  final ValueNotifier<int> permissionsNotifier = ValueNotifier<int>(0);

  /// Raw featurePermissions map: { roleKey: [permissionKey, ...], ... }
  /// Example: { "manager": ["approval", "geofencing"], "employee": [] }
  Map<String, dynamic> featurePermissions = {};

  /// Default permissions applied when featurePermissions is not configured.
  static const Map<String, List<String>> _defaultPermissions = {
    'admin': [
      'approval',
      'task_creation',
      'announcement_creation',
      'organization',
      'geofencing',
    ],
    'hr_admin': [
      'approval',
      'task_creation',
      'announcement_creation',
      'organization',
      'geofencing',
    ],
    'manager': [
      'approval',
      'task_creation',
      'announcement_creation',
      'geofencing',
    ],
    'employee': ['geofencing'],
  };

  /// Baseline features always accessible to every logged-in user regardless
  /// of role or organisation permissions.
  static const List<String> _baselineFeatures = [
    'my-space',
    'dashboard',
    'attendance',
    'leave',
    'tasks',
    'documents',
    'team',
    'calendar',
    'announcements-view',
    'announcements',
    'reports',
    'settings',
    'support',
    'history',
    'notifications',
  ];

  // ── Alias resolution ──────────────────────────────────────────────────────

  /// Returns the canonical permission key that corresponds to [featureKey],
  /// or null if the featureKey is not an action-based permission.
  String? _resolveAlias(String featureKey) {
    final k = featureKey.toLowerCase();
    // approval
    if (k == 'approval' ||
        k == 'approvals' ||
        k == 'approve-leave' ||
        k == 'approve-attendance' ||
        k == 'dashboard-approval' ||
        k == 'team-approval') {
      return 'approval';
    }
    // task_creation
    if (k == 'task_creation' ||
        k == 'task-creation' ||
        k == 'create-task' ||
        k == 'task_create') {
      return 'task_creation';
    }
    // announcement_creation
    if (k == 'announcement_creation' ||
        k == 'announcement-creation' ||
        k == 'create-announcement') {
      return 'announcement_creation';
    }
    // organization
    if (k == 'organization' ||
        k == 'org' ||
        k == 'organization_management') {
      return 'organization';
    }
    // geofencing
    if (k == 'geofencing' || k == 'geofence' || k == 'geo-fencing') {
      return 'geofencing';
    }
    return null;
  }

  // ── Permission Evaluation ────────────────────────────────────────────────

  /// Central permission check — mirrors the Workzy web app logic exactly.
  ///
  /// Parity with Web App AuthContext.tsx:
  ///   1. GEOFENCING: Evaluated FIRST (before admin bypass).
  ///      If org-level isGeofencingEnabled is false, returns false for all roles.
  ///      Otherwise checks role's permission in featurePermissions (including HR Admin).
  ///   2. HR Admin bypass → always true for all OTHER modules & actions.
  ///   3. Baseline features → always true for all authenticated employees.
  ///   4. Action-based keys resolved via alias map against role's permission list.
  bool hasPermission(String featureKey) {
    final k = featureKey.toLowerCase().trim();

    // 1. GEOFENCING: Unified permission for GPS location detection & geofence validation
    // Checked BEFORE admin bypass (identical to Web App AuthContext.tsx)!
    if (k == 'geofencing' ||
        k == 'geofence' ||
        k == 'geo-fencing' ||
        k == 'geo_fencing') {
      if (!isGeofencingEnabled) return false;

      // If geofencing policy is ON, check if the role has it enabled in the Permission Matrix
      if (isHrAdmin || isAdmin || isSuperAdmin) {
        final List<dynamic> hrPerms = featurePermissions.containsKey('hr_admin')
            ? (featurePermissions['hr_admin'] as List<dynamic>? ?? [])
            : featurePermissions.containsKey('admin')
                ? (featurePermissions['admin'] as List<dynamic>? ?? [])
                : (_defaultPermissions['hr_admin'] ?? []);
        return hrPerms.contains('geofencing') || hrPerms.contains('geofence');
      }

      final rKey = _normaliseRoleKey(role ?? 'employee');
      final List<dynamic> rolePerms = featurePermissions.containsKey(rKey)
          ? (featurePermissions[rKey] as List<dynamic>? ?? [])
          : (_defaultPermissions[rKey] ?? []);
      return rolePerms.contains('geofencing') || rolePerms.contains('geofence');
    }

    // 2. HR Admin (`hr_admin` / legacy `admin` / `super_admin`) is head of organization with full administrative access to all other modules & actions
    if (isHrAdmin || isAdmin || isSuperAdmin) return true;

    // 3. Baseline features always allowed to all authenticated employees
    if (_baselineFeatures.contains(k)) return true;

    // 4. Resolve alias → canonical key
    final canonical = _resolveAlias(k) ?? k;

    // Get this role's permission list (from Firestore or defaults)
    final rKey = _normaliseRoleKey(role ?? 'employee');
    final List<dynamic> rolePerms = featurePermissions.containsKey(rKey)
        ? (featurePermissions[rKey] as List<dynamic>? ?? [])
        : (_defaultPermissions[rKey] ?? []);

    return rolePerms.contains(canonical) || rolePerms.contains(k);
  }

  /// Normalise role strings to the keys used in featurePermissions.
  /// In Firestore featurePermissions, keys are: 'hr_admin', 'manager', 'employee' (legacy: 'admin').
  String _normaliseRoleKey(String r) {
    final l = r.toLowerCase().trim();
    if (l == 'super_admin' ||
        l == 'superadmin' ||
        l == 'admin' ||
        l == 'hr_admin' ||
        l == 'hradmin') {
      return 'hr_admin';
    }
    if (l == 'manager') return 'manager';
    return 'employee';
  }

  /// True only when the session has been fully populated after login.
  bool get isReady => uid != null && companyId != null && role != null;

  // ── Office Location Helpers ───────────────────────────────────────────────

  /// Update office location from Firestore organization/company map.
  /// Supports both the new `locations` array and legacy root-level fields.
  void updateOfficeLocationFromMap(Map<dynamic, dynamic>? data) {
    if (data == null) return;
    double? parseDouble(dynamic v) =>
        v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

    double? foundLat;
    double? foundLng;

    // 1. Try 'locations' list (array of branch maps)
    final locations = data['locations'];
    if (locations is List && locations.isNotEmpty) {
      for (final item in locations) {
        if (item is Map) {
          final lat = parseDouble(item['latitude'] ?? item['lat']);
          final lng = parseDouble(item['longitude'] ?? item['lng']);
          if (lat != null && lng != null) {
            foundLat = lat;
            foundLng = lng;
            break;
          }
        }
      }
    }

    // 2. Try 'location' object (singular map)
    if (foundLat == null || foundLng == null) {
      final loc = data['location'];
      if (loc is Map) {
        foundLat = parseDouble(loc['latitude'] ?? loc['lat']);
        foundLng = parseDouble(loc['longitude'] ?? loc['lng']);
      }
    }

    // 3. Try root-level fields: latitude / longitude or lat / lng
    if (foundLat == null || foundLng == null) {
      foundLat = parseDouble(data['latitude'] ?? data['lat']);
      foundLng = parseDouble(data['longitude'] ?? data['lng']);
    }

    if (foundLat != null && foundLng != null) {
      officeLat = foundLat;
      officeLng = foundLng;
    }

    if (data.containsKey('allowedRadius')) {
      allowedRadius = parseDouble(data['allowedRadius']) ?? 500;
    }

    // Read org-level geofencing master switch
    // Checks root isGeofencingEnabled, attendancePolicy.isGeofencingEnabled, and wfhPolicy.geofenceRequired
    if (data.containsKey('isGeofencingEnabled')) {
      final v = data['isGeofencingEnabled'];
      if (v is bool) {
        isGeofencingEnabled = v;
      } else if (v is String) {
        isGeofencingEnabled = v.toLowerCase() == 'true';
      }
    } else if (data['attendancePolicy'] is Map &&
        (data['attendancePolicy'] as Map).containsKey('isGeofencingEnabled')) {
      final v = (data['attendancePolicy'] as Map)['isGeofencingEnabled'];
      if (v is bool) {
        isGeofencingEnabled = v;
      } else if (v is String) {
        isGeofencingEnabled = v.toLowerCase() == 'true';
      }
    } else if (data['wfhPolicy'] is Map &&
        (data['wfhPolicy'] as Map).containsKey('geofenceRequired')) {
      final v = (data['wfhPolicy'] as Map)['geofenceRequired'];
      isGeofencingEnabled = (v?.toString().toLowerCase() == 'yes');
    }
  }

  // ── Session Lifecycle ─────────────────────────────────────────────────────

  /// Populate the session after successful login + approved_users look-up.
  void populate({
    required String uid,
    required String email,
    required String role,
    required String companyId,
    String? companyName,
    String? userName,
    String? department,
    double? officeLat,
    double? officeLng,
    double? allowedRadius,
    String? shiftStartTime,
    String? shiftEndTime,
    int? gracePeriod,
    int? paidLeavesPerYear,
    Map<String, dynamic>? featurePermissions,
    bool? isGeofencingEnabled,
  }) {
    this.uid = uid;
    this.email = email;
    this.role = role;
    this.companyId = companyId;
    this.companyName = companyName;
    this.userName = userName;
    this.department = department;
    if (officeLat != null) this.officeLat = officeLat;
    if (officeLng != null) this.officeLng = officeLng;
    if (allowedRadius != null) this.allowedRadius = allowedRadius;
    if (shiftStartTime != null) this.shiftStartTime = shiftStartTime;
    if (shiftEndTime != null) this.shiftEndTime = shiftEndTime;
    if (gracePeriod != null) this.gracePeriod = gracePeriod;
    if (paidLeavesPerYear != null) this.paidLeavesPerYear = paidLeavesPerYear;
    if (featurePermissions != null) {
      this.featurePermissions = featurePermissions;
    }
    if (isGeofencingEnabled != null) {
      this.isGeofencingEnabled = isGeofencingEnabled;
    }
    permissionsNotifier.value++;
  }

  /// Live update permissions and notify listeners in real-time
  void updatePermissions({
    Map<String, dynamic>? newPermissions,
    bool? newGeofencingEnabled,
  }) {
    if (newPermissions != null) {
      featurePermissions = newPermissions;
    }
    if (newGeofencingEnabled != null) {
      isGeofencingEnabled = newGeofencingEnabled;
    }
    permissionsNotifier.value++;
  }

  /// Clear everything on sign-out.
  void clear() {
    uid = null;
    email = null;
    role = null;
    companyId = null;
    companyName = null;
    userName = null;
    department = null;
    officeLat = null;
    officeLng = null;
    allowedRadius = 500;
    shiftStartTime = "09:00";
    shiftEndTime = "18:00";
    gracePeriod = 15;
    paidLeavesPerYear = 12;
    featurePermissions = {};
    isGeofencingEnabled = true;
    permissionsNotifier.value++;
  }
}
