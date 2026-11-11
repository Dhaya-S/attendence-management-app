import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'app_session.dart';

/// FirestoreService â€” Single source of truth for all Firestore collection
/// and document references.
///
/// **Company-Centric Model:**
/// All operational data (employees, attendance, leave requests, etc.) is stored
/// as subcollections under `organizations/{companyId}/...`.
/// This ensures that when you view a company in the Firestore console, you can
/// see all related employees, attendance, and leave data nested under it.
///
/// Never call `FirebaseFirestore.instance.collection(...)` directly in UI code
/// â€” use the static helpers here instead.
class FirestoreService {
  FirestoreService._(); // No instances needed â€” all members are static.

  static final _db = FirebaseFirestore.instance;

  // â”€â”€ Convenience accessor â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static String get _cid {
    final id = AppSession().companyId;
    assert(id != null, 'AppSession.companyId is null â€” was login completed?');
    return id!;
  }

  /// Public getter for the current tenant's companyId
  static String get companyId => _cid;

  /// Strict multi-tenant guard: returns true ONLY if [doc] belongs to the active company.
  /// Validates explicit tenant fields ('companyId', 'orgId', 'organizationId') and document hierarchy.
  static bool isDocInCurrentCompany(DocumentSnapshot doc) {
    final currentCid = (AppSession().companyId ?? '').trim().toLowerCase();
    if (currentCid.isEmpty) return false;

    final data = doc.data() as Map<String, dynamic>? ?? {};
    final docCid = (data['companyId'] ?? data['orgId'] ?? data['organizationId'])
        ?.toString()
        .trim()
        .toLowerCase();

    // 1. If document explicitly specifies a company/org ID and it DOES NOT match, reject immediately.
    if (docCid != null && docCid.isNotEmpty && docCid != currentCid) {
      return false;
    }

    final path = doc.reference.path.toLowerCase();

    // 2. If document is nested under organizations/, verify root tenant ID segment.
    if (path.startsWith('organizations/')) {
      final segments = path.split('/');
      if (segments.length > 1) {
        final pathOrgId = segments[1];
        if (pathOrgId != currentCid) {
          return false;
        }
        return true;
      }
    }

    // 3. Document explicitly specifies the active company ID
    if (docCid != null && docCid == currentCid) {
      return true;
    }

    // 4. Nested subcollection check for .../organizations/{cid}/...
    return path.contains('/organizations/$currentCid/');
  }

  // â”€â”€ Global (cross-company) refs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// `approved_users/{email}` â€” global login / company mapping.
  static DocumentReference<Map<String, dynamic>> approvedUserDoc(
          String email) =>
      _db.collection('approved_users').doc(email.toLowerCase());

  /// `organizations/{companyId}` â€” company master document.
  static DocumentReference<Map<String, dynamic>> companyDoc(
          [String? companyId]) =>
      _db.collection('organizations').doc(companyId ?? _cid);

  /// `organization_setup_requests/{requestId}` â€” pre-login organization setup submissions.
  static CollectionReference<Map<String, dynamic>>
      get organizationSetupRequestsCol =>
          _db.collection('organization_setup_requests');

  // â”€â”€ New: Organizations (self-registration flow) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Used when a company admin registers directly via the app.
  // Structure: organizations/{orgId}/members/{uid}
  //                                /departments/{deptId}

  /// `organizations` â€” top-level collection for self-registered companies.
  static CollectionReference<Map<String, dynamic>> get orgCol =>
      _db.collection('organizations');

  /// `organizations/{orgId}` â€” company master document.
  static DocumentReference<Map<String, dynamic>> orgDoc(String orgId) =>
      orgCol.doc(orgId);

  /// `organizations/{orgId}/members` â€” all admin/employee profiles for this org.
  static CollectionReference<Map<String, dynamic>> orgMembersCol(
          String orgId) =>
      orgDoc(orgId).collection('members');

  /// `organizations/{orgId}/members/{uid}` â€” a single member's profile.
  static DocumentReference<Map<String, dynamic>> orgMemberDoc(
          String orgId, String uid) =>
      orgMembersCol(orgId).doc(uid);

  /// `organizations/{orgId}/departments` â€” department list for this org.
  static CollectionReference<Map<String, dynamic>> orgDepartmentsCol(
          String orgId) =>
      orgDoc(orgId).collection('departments');

  /// `organizations/{orgId}/departments/{deptId}`
  static DocumentReference<Map<String, dynamic>> orgDepartmentDoc(
          String orgId, String deptId) =>
      orgDepartmentsCol(orgId).doc(deptId);

  /// `organizations/{orgId}/holidays`
  static CollectionReference<Map<String, dynamic>> orgHolidaysCol(
          String orgId) =>
      orgDoc(orgId).collection('holidays');

  /// `organizations/{orgId}/shifts`
  static CollectionReference<Map<String, dynamic>> orgShiftsCol(String orgId) =>
      orgDoc(orgId).collection('shifts');

  /// `organizations/{companyId}/shifts`
  static CollectionReference<Map<String, dynamic>> get shiftsCol =>
      orgShiftsCol(_cid);

  /// Reads which shift a user is assigned to. The web app stores it on the employee
  /// profile as `shift` (a shift NAME or id), with `shiftTemplate` / `shiftName` / `shiftId`
  /// as alternatives.
  static String? userShiftKey(Map<String, dynamic>? m) {
    if (m == null) return null;
    for (final k in ['shift', 'shiftTemplate', 'shiftName', 'shiftId']) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  /// Picks the shift that applies to a user — exactly like the web app does:
  /// the shift whose id or NAME matches the one on the user's profile
  /// ("General" also matches "General Shift"), otherwise the first shift of the company.
  static Future<Map<String, dynamic>?> fetchApplicableShift({
    String? companyId,
    String? shiftId,
    String? department,
  }) async {
    final cid = companyId ?? _cid;
    try {
      final qs = await orgShiftsCol(cid).get();
      if (qs.docs.isEmpty) return null;

      Map<String, dynamic> withId(QueryDocumentSnapshot<Map<String, dynamic>> d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = m['id'] ?? d.id;
        return m;
      }

      final assigned = (shiftId ?? '').trim().toLowerCase();
      if (assigned.isNotEmpty) {
        for (final d in qs.docs) {
          final data = d.data();
          final name = (data['name'] ?? data['shiftName'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (d.id.toLowerCase() == assigned ||
              name == assigned ||
              '$name shift' == assigned) {
            return withId(d);
          }
        }
      }
      return withId(qs.docs.first); // web fallback: first shift
    } catch (e) {
      debugPrint('Error fetching applicable shift for $cid: $e');
    }
    return null;
  }

  /// Works out WHERE this user's office is and how large the geofence is — the same
  /// order the web app uses on check-in:
  ///   1. the employee's own latitude/longitude (+ radius)
  ///   2. the employee's branch (branches/{name_with_underscores}, branches by name/id,
  ///      organization.locations by name)
  ///   3. the first organization location / first branch / first location
  ///   4. the organization's own latitude/longitude
  /// Radius text like "200m" is parsed; default 500 (branch) / 200 (organization).
  static Future<void> resolveOfficeForCurrentUser(
      {Map<String, dynamic>? orgData}) async {
    try {
      final s = AppSession();
      final email = (s.email ?? '').trim().toLowerCase();
      if (email.isEmpty || s.companyId == null) return;

      final org = orgData ?? (await companyDoc().get()).data() ?? <String, dynamic>{};

      bool truthy(dynamic v) =>
          v != null && v.toString().trim().isNotEmpty && v.toString() != '0' && v != 0;
      double num0(dynamic v) =>
          v is num ? v.toDouble() : (double.tryParse((v ?? '').toString()) ?? 0);

      double lat = 0, lng = 0;
      dynamic radiusRaw = 500;

      final u = (await employeeDoc(email).get()).data() ?? <String, dynamic>{};
      final userBranch = (u['branch'] ?? u['location'] ?? '').toString().trim();

      if (truthy(u['latitude'] ?? u['lat'])) {
        lat = num0(u['latitude'] ?? u['lat']);
        lng = num0(u['longitude'] ?? u['lng']);
        if (truthy(u['geofenceRadius'] ?? u['radius'])) {
          radiusRaw = u['geofenceRadius'] ?? u['radius'];
        }
      } else {
        Map<String, dynamic>? matched;
        final orgLocations = org['locations'] is List
            ? (org['locations'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];

        if (userBranch.isNotEmpty) {
          final branchesCol = companyDoc().collection('branches');
          final direct = await branchesCol
              .doc(userBranch.replaceAll(RegExp(r'\s+'), '_'))
              .get();
          if (direct.exists) {
            matched = direct.data();
          } else {
            final all = await branchesCol.get();
            for (final d in all.docs) {
              final b = d.data();
              if ((b['name'] ?? '').toString().trim().toLowerCase() ==
                      userBranch.toLowerCase() ||
                  d.id.toLowerCase() == userBranch.toLowerCase()) {
                matched = b;
                break;
              }
            }
          }
          if (matched == null) {
            for (final l in orgLocations) {
              if ((l['name'] ?? '').toString().trim().toLowerCase() ==
                  userBranch.toLowerCase()) {
                matched = l;
                break;
              }
            }
          }
        }
        if (matched == null && orgLocations.isNotEmpty) matched = orgLocations.first;
        if (matched == null) {
          final b = await companyDoc().collection('branches').limit(1).get();
          if (b.docs.isNotEmpty) {
            matched = b.docs.first.data();
          } else {
            final l = await companyDoc().collection('locations').limit(1).get();
            if (l.docs.isNotEmpty) matched = l.docs.first.data();
          }
        }

        if (matched != null) {
          lat = num0(matched['latitude'] ?? matched['lat']);
          lng = num0(matched['longitude'] ?? matched['lng']);
          if (truthy(matched['geofenceRadius'] ?? matched['radius'])) {
            radiusRaw = matched['geofenceRadius'] ?? matched['radius'];
          }
        } else {
          final loc = org['location'] is Map ? org['location'] as Map : const {};
          lat = num0(org['latitude'] ?? loc['latitude'] ?? org['lat']);
          lng = num0(org['longitude'] ?? loc['longitude'] ?? org['lng']);
          radiusRaw = truthy(org['geofenceRadius'] ?? org['radius'])
              ? (org['geofenceRadius'] ?? org['radius'])
              : '200';
        }
      }

      var radius = 200;
      final parsed = int.tryParse(radiusRaw.toString().replaceAll(RegExp(r'[^0-9]'), ''));
      if (parsed != null && parsed > 0) radius = parsed;

      if (lat != 0 && lng != 0) {
        s.officeLat = lat;
        s.officeLng = lng;
      }
      s.allowedRadius = radius.toDouble();
    } catch (e) {
      debugPrint('resolveOfficeForCurrentUser failed: $e');
    }
  }

  /// `organizations/{orgId}/policies`
  static CollectionReference<Map<String, dynamic>> orgPoliciesCol(
          String orgId) =>
      orgDoc(orgId).collection('policies');

  /// `organizations/{orgId}/policies/{policyId}`
  static DocumentReference<Map<String, dynamic>> orgPolicyDoc(
          String orgId, String policyId) =>
      orgPoliciesCol(orgId).doc(policyId);

  /// `organizations/{orgId}/documents`
  static CollectionReference<Map<String, dynamic>> orgDocumentsCol(
          String orgId) =>
      orgDoc(orgId).collection('documents');

  /// `organizations/{orgId}/documents/{docId}`
  static DocumentReference<Map<String, dynamic>> orgDocumentDoc(
          String orgId, String docId) =>
      orgDocumentsCol(orgId).doc(docId);

  // â”€â”€ Company-Scoped Subcollections â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // All operational data lives UNDER the company document so that
  // Firestore console shows everything nested per company.

  /// `/organizations/{companyId}/users` â€” user profiles
  static CollectionReference<Map<String, dynamic>> get employeesCol =>
      companyDoc().collection('users');

  /// Filtered query for approved employees in the current company
  /// (Web employees have status Active/Inactive, so we do NOT filter on a status value in the
  /// query; use [isActiveUserDoc] / [fetchActiveCompanyUsers] to exclude inactive people.)
  static Query<Map<String, dynamic>> get companyUsersQuery => employeesCol;

  /// `/organizations/{companyId}/employees/{email}`
  static DocumentReference<Map<String, dynamic>> employeeDoc(String email) =>
      employeesCol.doc(email.toLowerCase());

  /// Get a stream of the employee document by email.
  /// Primary lookup is by document ID (email), with a fallback query.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> userStreamByEmail(
      String email) {
    final normalizedEmail = email.toLowerCase();
    return employeesCol.doc(normalizedEmail).snapshots().asyncMap((doc) async {
      if (doc.exists) return doc;

      // Fallback: search for a document where the 'email' FIELD matches
      try {
        final qs = await employeesCol
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (qs.docs.isNotEmpty) return qs.docs.first;
      } catch (e) {
        debugPrint('userStreamByEmail fallback query failed: $e');
      }
      return doc; // Return the empty doc if fallback fails
    });
  }

  /// `/organizations/{companyId}/users/{email}/attendance`
  static CollectionReference<Map<String, dynamic>> userAttendanceCol(
          String email) =>
      employeeDoc(email).collection('attendance');

  /// `/organizations/{companyId}/users/{email}/leave_requests`
  static CollectionReference<Map<String, dynamic>> userLeaveRequestsCol(
          String email) =>
      employeeDoc(email).collection('leave_requests');

  /// `/organizations/{companyId}/users/{email}/notifications`
  static CollectionReference<Map<String, dynamic>> userNotificationsCol(
          String email) =>
      employeeDoc(email).collection('notifications');

  /// `/organizations/{companyId}/users/{email}/overtime_requests`
  static CollectionReference<Map<String, dynamic>> userOvertimeRequestsCol(
          String email) =>
      employeeDoc(email).collection('overtime_requests');

  /// `/organizations/{companyId}/documents` — company documents uploaded via Web / App
  static CollectionReference<Map<String, dynamic>> get documentsCol =>
      companyDoc().collection('documents');

  /// `/organizations/{companyId}/documents/{docId}`
  static DocumentReference<Map<String, dynamic>> documentDoc(String docId) =>
      documentsCol.doc(docId);

  // â”€â”€ Collection Group Queries (Manager Access) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // These allow managers to query all records across all employees in the company.

  /// All attendance records for the current company (strictly scoped)
  static CollectionReference<Map<String, dynamic>> get attendanceCol =>
      companyDoc().collection('attendance');

  static Query<Map<String, dynamic>> get allAttendanceRecordsCol =>
      attendanceCol;

  /// All leave requests for the current company (strictly scoped to company)
  static CollectionReference<Map<String, dynamic>> get leaveRequestsCol =>
      companyDoc().collection('leave_requests');

  static Query<Map<String, dynamic>> get allLeaveRequestsQuery =>
      leaveRequestsCol;

  /// All overtime requests for the current company (strictly scoped)
  static CollectionReference<Map<String, dynamic>> get overtimeRequestsCol =>
      companyDoc().collection('overtime_requests');

  static Query<Map<String, dynamic>> get allOvertimeRequestsQuery =>
      overtimeRequestsCol;

  /// All attendance corrections for the current company
  static Query<Map<String, dynamic>> get allAttendanceIssuesQuery {
    return companyDoc().collection('attendance_issues');
  }

  /// All shift requests for the current company
  static Query<Map<String, dynamic>> get allShiftRequestsQuery {
    return companyDoc().collection('shift_requests');
  }

  /// All department transfer requests for the current company
  static Query<Map<String, dynamic>> get allDepartmentRequestsQuery {
    return companyDoc().collection('department_requests');
  }

  /// All task extension/approval requests for the current company
  static Query<Map<String, dynamic>> get allTaskRequestsQuery {
    return companyDoc().collection('task_requests');
  }

  /// All notifications for the current company
  static Query<Map<String, dynamic>> get allNotificationsQuery {
    return companyDoc().collection('notifications');
  }

  /// All tasks for the current company (strictly scoped)
  static Query<Map<String, dynamic>> get allTasksQuery =>
      tasksCol;

  /// Alias for backward compatibility
  static Query<Map<String, dynamic>> get companyLeaveRequestsQuery =>
      leaveRequestsCol;

  // â”€â”€ Global Company Notifications â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // These are notifications meant for the entire company, not a specific user.

  /// `/organizations/{companyId}/global_notifications`
  static CollectionReference<Map<String, dynamic>> get globalNotificationsCol =>
      companyDoc().collection('global_notifications');

  /// `/organizations/{companyId}/announcements`
  static CollectionReference<Map<String, dynamic>> get announcementsCol =>
      orgDoc(_cid).collection('announcements');

  /// `/organizations/{companyId}/team_announcements`
  static CollectionReference<Map<String, dynamic>> get teamAnnouncementsCol =>
      orgDoc(_cid).collection('team_announcements');

  /// `/organizations/{companyId}/company_calendar`
  static CollectionReference<Map<String, dynamic>> get companyCalendarCol =>
      companyDoc().collection('company_calendar');

  /// `/organizations/{companyId}/policies`
  static CollectionReference<Map<String, dynamic>> get policiesCol =>
      companyDoc().collection('policies');

  /// `/organizations/{companyId}/tasks`
  static CollectionReference<Map<String, dynamic>> get tasksCol =>
      companyDoc().collection('tasks');

  /// `/organizations/{companyId}/team_feed` — unified feed (was feed_posts, now same as teamFeedCol)
  static CollectionReference<Map<String, dynamic>> get feedPostsCol =>
      companyDoc().collection('team_feed');

  /// `/organizations/{companyId}/team_feed`
  static CollectionReference<Map<String, dynamic>> get teamFeedCol =>
      companyDoc().collection('team_feed');

  // â”€â”€ Legacy / Flat Collections (To be removed after migration) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// @deprecated Use [userAttendanceCol]
  static CollectionReference<Map<String, dynamic>> attendanceRecordsCol(
      String uidOrEmail) {
    // Attempting to maintain some compatibility during transition
    if (uidOrEmail.contains('@')) return userAttendanceCol(uidOrEmail);
    return attendanceCol.doc(uidOrEmail).collection('records');
  }

  /// @deprecated Use [userNotificationsCol]
  static CollectionReference<Map<String, dynamic>> get notificationsCol =>
      companyDoc().collection('notifications');

  // â”€â”€ Legacy Compatibility Aliases â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // These aliases keep existing UI code working without mass renames.

  /// Alias for `employeesCol` â€” backward compatible with old `usersCol` calls
  static CollectionReference<Map<String, dynamic>> get usersCol => employeesCol;

  /// Alias for `employeeDoc(uid)` â€” backward compatible
  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      employeesCol.doc(uid);

  /// Alias for `employeeDoc(email)` â€” backward compatible
  static DocumentReference<Map<String, dynamic>> userDocByEmail(String email) =>
      employeesCol.doc(email.toLowerCase());

  /// Find a company where the given email is the manager.
  /// This is used for login fallback when the manager isn't in 'approved_users'.
  /// Find a company where the given email is the manager.
  /// This is used for login fallback when the manager isn't in 'approved_users'.
  static Future<QuerySnapshot<Map<String, dynamic>>> findCompanyByManagerEmail(
          String email) =>
      _db
          .collection('organizations')
          .where('managerEmail', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

  // ═══════════════════════════════════════════════════════════════════════════
  // Web-app compatible write helpers
  //
  // The Workzi WEB app is the master platform. Everything below writes exactly
  // the document shape / values the web app writes, so both platforms read and
  // write the same Firestore documents:
  //   • status values are Title Case:  Pending · Approved · Rejected
  //   • attendance `date` is the LOCAL "yyyy-MM-dd" string (never a Timestamp)
  //   • attendance `userId` is the Firebase Auth uid
  //   • leave / attendance decisions are written to BOTH copies
  // ═══════════════════════════════════════════════════════════════════════════

  /// Case-insensitive status check ("Pending" == "pending").
  static bool statusIs(dynamic status, String expected) =>
      (status ?? '').toString().trim().toLowerCase() == expected.toLowerCase();

  /// Parses a Firestore Timestamp, DateTime, "yyyy-MM-dd" / ISO string or epoch millis.
  static DateTime? parseAnyDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v.trim());
    return null;
  }

  /// Parses "09:00 AM", "9:00 PM", "18:30", "18:30:00" or a Timestamp into a
  /// DateTime on [day]. Returns null if it cannot be parsed.
  static DateTime? parseTimeOnDay(dynamic raw, DateTime day) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    final s = raw.toString().trim();
    if (s.isEmpty || s == '-' || s == '—') return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])?$')
        .firstMatch(s);
    if (m == null) return DateTime.tryParse(s);
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ap = m.group(3)?.toUpperCase();
    if (ap == 'PM' && h < 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
    return DateTime(day.year, day.month, day.day, h, min);
  }

  /// Email of the person who raised a request (web: createdBy; old mobile docs: userId/userEmail).
  static String requesterEmail(Map<String, dynamic> d) {
    for (final k in [
      'createdBy',
      'applicantEmail',
      'employeeEmail',
      'userEmail',
      'email',
      'userId'
    ]) {
      final v = (d[k] ?? '').toString().trim().toLowerCase();
      if (v.contains('@')) return v;
    }
    return '';
  }

  /// Whether a user profile document is an active employee (web uses Active/Inactive,
  /// approved_users uses approved/suspended/removed).
  static bool isActiveUserDoc(Map<String, dynamic> d) {
    final s = (d['status'] ?? 'active').toString().trim().toLowerCase();
    return !(s == 'inactive' ||
        s == 'suspended' ||
        s == 'removed' ||
        s == 'deleted');
  }

  /// All active employees of the current company.
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchActiveCompanyUsers() async {
    final qs = await employeesCol.get();
    return qs.docs.where((d) => isActiveUserDoc(d.data())).toList();
  }

  /// Picks who approves this employee's leave (same order as the web Leave page):
  /// profile.managerEmail → manager looked up by display name → first HR admin.
  static Future<String> resolveApproverId(String email) async {
    try {
      final me = await employeeDoc(email).get();
      final md = me.data() ?? {};
      final direct = (md['managerEmail'] ?? '').toString().trim().toLowerCase();
      if (direct.isNotEmpty) return direct;
      final all = await employeesCol.get();
      final mgrName = (md['manager'] ?? '').toString().trim().toLowerCase();
      if (mgrName.isNotEmpty) {
        for (final d in all.docs) {
          final x = d.data();
          if ((x['name'] ?? '').toString().trim().toLowerCase() == mgrName) {
            return (x['email'] ?? x['workEmail'] ?? d.id)
                .toString()
                .toLowerCase();
          }
        }
      }
      for (final d in all.docs) {
        final r = (d.data()['role'] ?? '').toString().toLowerCase();
        if (r == 'hr_admin' || r == 'super_admin' || r == 'admin') {
          return (d.data()['email'] ?? d.id).toString().toLowerCase();
        }
      }
    } catch (e) {
      debugPrint('resolveApproverId failed: $e');
    }
    return '';
  }

  /// Records an attendance punch in the exact shape the web app uses.
  /// Writes (1) users/{email}/attendance/{date}, (2) the company roll-up
  /// attendance/{email}_{date} and (3) the live status on the employee profile.
  static Future<void> recordAttendancePunch({
    required String email,
    required bool isCheckIn,
    String? status,
    String? location,
    String? address,
    Map<String, dynamic>? additionalData,
  }) async {
    final now = DateTime.now();
    final cleanEmail = email.trim().toLowerCase();
    final timeStr = DateFormat('hh:mm a').format(now);
    final dateKey =
        DateFormat('yyyy-MM-dd').format(now); // LOCAL date, same as web

    final customShift = additionalData?['shiftStartTime'] as String?;
    final customGrace = (additionalData?['gracePeriod'] as num?)?.toInt();
    final isLate = AppSession().isCheckInLate(
      now,
      customShiftStart: customShift,
      customGracePeriod: customGrace,
    );

    String normalizedStatus = 'Present';
    if (status != null && status.isNotEmpty) {
      final s = status.trim().toLowerCase();
      if (s == 'wfh' || s == 'work from home') {
        normalizedStatus = 'WFH';
      } else if (s == 'late') {
        normalizedStatus = 'Late';
      } else if (s == 'half day' || s == 'half_day') {
        normalizedStatus = 'Half Day';
      }
    }
    // Office check-in after shift start + grace is Late (web behaviour).
    if (isCheckIn && isLate && normalizedStatus == 'Present') {
      normalizedStatus = 'Late';
    }

    final workMode = (additionalData?['workMode'] as String?) ??
        (normalizedStatus == 'WFH' ? 'wfh' : 'office');
    final String locStr = location ??
        address ??
        (normalizedStatus == 'WFH' ? 'Work from Home' : 'Work in Office');

    final rawShiftName = AppSession().shiftName.trim();
    final shiftLabel = rawShiftName.toLowerCase().endsWith('shift')
        ? rawShiftName
        : '$rawShiftName Shift'; // web stores "<name> Shift"
    final shiftStart = customShift ?? AppSession().shiftStartTime;
    final shiftEnd =
        additionalData?['shiftEndTime'] as String? ?? AppSession().shiftEndTime;

    final Map<String, dynamic> record = {
      'companyId': _cid,
      'userId': AppSession().uid ?? cleanEmail, // web: Firebase Auth uid
      'email': cleanEmail,
      'workEmail': cleanEmail,
      'employeeId': cleanEmail,
      'name': AppSession().userName ?? cleanEmail,
      'date': dateKey, // String "yyyy-MM-dd" (web queries date >= "yyyy-MM-dd")
      'dateTimestamp':
          Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      'recordDate': dateKey,
      'workMode': workMode,
      'location': locStr,
      'shift': shiftLabel,
      'shiftName': AppSession().shiftName,
      'shiftId': AppSession().shiftId ?? 'default',
      'shiftCheckIn': shiftStart,
      'shiftCheckOut': shiftEnd,
      'shiftStartTime': shiftStart,
      'shiftEndTime': shiftEnd,
      'gracePeriod': customGrace ?? AppSession().gracePeriod,
      'updatedAt': now.toIso8601String(),
    };

    if (isCheckIn) {
      record['status'] = normalizedStatus;
      record['attendanceStatus'] = normalizedStatus;
      record['isLate'] = isLate;
      record['checkIn'] = Timestamp.fromDate(now);
      record['checkInTime'] = timeStr; // "09:05 AM"
      record['checkInTimestamp'] = now.toIso8601String();
      record['checkInLocation'] = locStr;
      record['checkOut'] = null;
      record['checkOutTime'] = null;
      record['checkOutTimestamp'] = null;
      record['checkOutLocation'] = null;
      record['hoursWorked'] = '0h 00m';
      record['hoursNum'] = 0;
    } else {
      // Check-out must NOT overwrite the day's Present/Late/WFH status.
      record['checkOut'] = Timestamp.fromDate(now);
      record['checkOutTime'] = timeStr;
      record['checkOutTimestamp'] = now.toIso8601String();
      record['checkOutLocation'] = locStr;
      record['attendanceStatus'] = 'Checked Out';

      try {
        final existingSnap =
            await userAttendanceCol(cleanEmail).doc(dateKey).get();
        if (existingSnap.exists) {
          final exData = existingSnap.data();
          final cinDate = parseAnyDate(exData?['checkIn']) ??
              parseAnyDate(exData?['checkInTimestamp']);
          if (cinDate != null) {
            final diff = now.difference(cinDate);
            record['hoursWorked'] = '${diff.inHours}h ${diff.inMinutes % 60}m';
            record['hoursNum'] =
                double.parse((diff.inMinutes / 60.0).toStringAsFixed(1));
          }
        }
      } catch (e) {
        debugPrint('Error calculating hoursWorked on checkout: $e');
      }
    }

    // Extra fields from the caller (geofence info, locations …). Identity / date /
    // status fields are owned by this method so they always match the web format.
    const protectedKeys = {
      'date',
      'userId',
      'companyId',
      'recordDate',
      'dateTimestamp',
      'email',
      'status',
      'checkIn',
      'checkOut',
      'checkInTime',
      'checkOutTime',
      'checkInTimestamp',
      'checkOutTimestamp',
      'isLate',
      'attendanceStatus',
    };
    additionalData?.forEach((k, v) {
      if (!protectedKeys.contains(k)) record[k] = v;
    });

    // 1. Employee's own attendance record
    await userAttendanceCol(cleanEmail)
        .doc(dateKey)
        .set(record, SetOptions(merge: true));

    // 2. Company roll-up: organizations/{cid}/attendance/{email}_{date}
    await attendanceCol
        .doc('${cleanEmail}_$dateKey')
        .set(record, SetOptions(merge: true));

    // 3. Live status on the employee profile (same fields/types as web)
    await employeeDoc(cleanEmail).set({
      'attendanceStatus': isCheckIn ? normalizedStatus : 'Checked Out',
      if (isCheckIn) 'lastCheckIn': Timestamp.fromDate(now),
      if (isCheckIn) 'lastCheckInTime': timeStr,
      if (!isCheckIn) 'lastCheckOut': Timestamp.fromDate(now),
      if (!isCheckIn) 'lastCheckOutTime': timeStr,
      'updatedAt': now.toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Submits a leave request exactly like the web Leave page.
  /// Writes the SAME document to the company queue and to the employee's own list.
  static Future<String> submitLeaveRequest({
    required Map<String, dynamic> data,
  }) async {
    final now = DateTime.now();
    final reqId = (data['id'] as String?)?.isNotEmpty == true
        ? data['id'] as String
        : 'lr_${now.millisecondsSinceEpoch}_${(now.microsecond % 1679616).toRadixString(36)}';

    final email = (data['applicantEmail'] ??
            data['userEmail'] ??
            data['email'] ??
            AppSession().email ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    final name = (data['applicantName'] ??
            data['userName'] ??
            AppSession().userName ??
            email)
        .toString()
        .trim();
    final leaveType =
        (data['type'] ?? data['leaveType'] ?? 'Annual Leave').toString().trim();

    DateTime? fromDt;
    DateTime? toDt;
    if (data['fromDate'] is DateTime) fromDt = data['fromDate'];
    if (data['fromDate'] is Timestamp) {
      fromDt = (data['fromDate'] as Timestamp).toDate();
    }
    if (data['from'] is String) fromDt = DateTime.tryParse(data['from']) ?? fromDt;

    if (data['toDate'] is DateTime) toDt = data['toDate'];
    if (data['toDate'] is Timestamp) toDt = (data['toDate'] as Timestamp).toDate();
    if (data['to'] is String) toDt = DateTime.tryParse(data['to']) ?? toDt;

    final fromStr = fromDt != null
        ? DateFormat('yyyy-MM-dd').format(fromDt)
        : (data['from']?.toString() ?? '');
    final toStr = toDt != null
        ? DateFormat('yyyy-MM-dd').format(toDt)
        : (data['to']?.toString() ?? '');

    final dynamic rawDays = data['days'] ?? data['durationInDays'] ?? 1;
    final int days =
        rawDays is int ? rawDays : (int.tryParse(rawDays.toString()) ?? 1);

    final isElevated = AppSession().isHrAdmin || AppSession().isManager;
    final dept = (data['dept'] ?? AppSession().department ?? '').toString();
    final approverId = await resolveApproverId(email);

    final payload = {
      ...data,
      'id': reqId,
      'companyId': _cid,
      'userId': AppSession().uid ?? '',
      'employee': name,
      'employeeEmail': email,
      'applicantName': name,
      'applicantEmail': email,
      'applicantRole': AppSession().role ?? 'employee',
      'userEmail': email,
      'userName': name,
      'type': leaveType,
      'leaveType': leaveType,
      'from': fromStr,
      'to': toStr,
      if (fromDt != null) 'fromDate': Timestamp.fromDate(fromDt),
      if (toDt != null) 'toDate': Timestamp.fromDate(toDt),
      'days': days,
      'durationInDays': days,
      'reason': (data['reason'] ?? '').toString().trim(),
      'status': 'Pending', // Title Case, same as web
      'applied': DateFormat('MMM dd').format(now),
      'createdAt': now.toIso8601String(),
      'dept': dept,
      'approverId': approverId,
      'targetRoles': isElevated ? ['hr_admin'] : ['manager', 'hr_admin'],
      'approver': isElevated ? 'HR Admin' : 'Reporting Manager',
    };

    // 1. Company queue (what approvers read)
    await leaveRequestsCol.doc(reqId).set(payload, SetOptions(merge: true));

    // 2. Employee's own copy
    try {
      await userLeaveRequestsCol(email)
          .doc(reqId)
          .set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('submitLeaveRequest: user copy failed: $e');
    }

    return reqId;
  }

  /// Creates an attendance correction request in the web "attendance_issues" shape.
  /// [requestedCheckIn]/[requestedCheckOut] are 12-hour strings like "09:00 AM".
  static Future<String> submitAttendanceIssue({
    required DateTime date,
    required String requestedCheckIn,
    required String requestedCheckOut,
    required String reason,
    String comment = '',
    String type = 'Missing Check-in',
  }) async {
    final now = DateTime.now();
    final me = (AppSession().email ?? '').trim().toLowerCase();
    final raw = (AppSession().role ?? 'employee').toLowerCase();
    final role = AppSession().isHrAdmin
        ? 'hr_admin'
        : (raw == 'manager' ? 'manager' : 'employee');
    final issueId = 'ISS${now.millisecondsSinceEpoch}';

    await companyDoc().collection('attendance_issues').doc(issueId).set({
      'id': issueId,
      'companyId': _cid,
      'createdBy': me,
      'createdByRole': role,
      'createdByName': AppSession().userName ?? me,
      'targetRoles':
          role == 'employee' ? ['manager', 'hr_admin'] : ['hr_admin'],
      'type': type,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'requestedCheckIn': requestedCheckIn,
      'requestedCheckOut': requestedCheckOut,
      'reason': reason,
      'comment': comment,
      'status': 'Pending',
      'createdAt': now.toIso8601String(),
      'submittedOn': 'Today',
      'rejectNote': '',
    });
    return issueId;
  }

  /// Approves / rejects a request the same way the web app does.
  ///  • leave_requests    → Approved/Rejected + approvedBy/At (rejectedBy/At) on BOTH copies
  ///  • attendance_issues → Approved/Rejected (+ attendance fix on approval)
  ///  • anything else     → status + reviewer on that document
  static Future<void> reviewRequest({
    required DocumentReference ref,
    required bool approve,
    String? note,
  }) async {
    final me = (AppSession().email ?? '').trim().toLowerCase();
    final nowIso = DateTime.now().toIso8601String();
    final collectionName = ref.parent.id;

    final snap = await ref.get();
    final data = Map<String, dynamic>.from(
        (snap.data() as Map<String, dynamic>?) ?? {});
    data['id'] = data['id'] ?? ref.id;

    final payload = <String, dynamic>{
      'status': approve ? 'Approved' : 'Rejected',
      if (approve) 'approvedBy': me,
      if (approve) 'approvedAt': nowIso,
      if (!approve) 'rejectedBy': me,
      if (!approve) 'rejectedAt': nowIso,
      'updatedAt': nowIso,
    };
    if (!approve && note != null && note.trim().isNotEmpty) {
      payload[collectionName == 'attendance_issues'
          ? 'rejectNote'
          : 'rejectReason'] = note.trim();
    }

    if (collectionName == 'leave_requests') {
      var applicant = requesterEmail(data);
      if (applicant.isEmpty) {
        final parts = ref.path.split('/');
        final i = parts.indexOf('users');
        if (i != -1 && i + 1 < parts.length) {
          applicant = parts[i + 1].toLowerCase();
        }
      }
      // Company queue copy
      await leaveRequestsCol.doc(ref.id).set(payload, SetOptions(merge: true));
      // Employee's own copy
      if (applicant.isNotEmpty) {
        try {
          await userLeaveRequestsCol(applicant)
              .doc(ref.id)
              .set(payload, SetOptions(merge: true));
        } catch (e) {
          debugPrint('reviewRequest: employee copy not updated: $e');
        }
      }
      // If the screen opened some other path, keep that document in sync too.
      if (ref.path != leaveRequestsCol.doc(ref.id).path) {
        try {
          await ref.set(payload, SetOptions(merge: true));
        } catch (_) {}
      }
    } else {
      await ref.update(payload);
      if (approve && collectionName == 'attendance_issues') {
        await applyAttendanceCorrectionApproval(requestData: data);
      }
    }
  }

  /// When an attendance correction is approved, fix that day's attendance record
  /// (employee copy + company roll-up + live status) using the web field format.
  /// Understands web issues (date / requestedCheckIn / requestedCheckOut / createdBy)
  /// and older mobile ones (attendanceDate / correctedCheckIn / correctedCheckOut).
  static Future<void> applyAttendanceCorrectionApproval({
    required Map<String, dynamic> requestData,
  }) async {
    try {
      final email = requesterEmail(requestData);
      if (email.isEmpty) return;

      final baseDate = parseAnyDate(requestData['date'] ??
          requestData['attendanceDate'] ??
          requestData['requestedDate']);
      if (baseDate == null) return;
      final day = DateTime(baseDate.year, baseDate.month, baseDate.day);
      final docId = DateFormat('yyyy-MM-dd').format(day);

      final inDt = parseTimeOnDay(
          requestData['requestedCheckIn'] ??
              requestData['correctedCheckIn'] ??
              requestData['checkInTime'] ??
              requestData['checkIn'],
          day);
      final outDt = parseTimeOnDay(
          requestData['requestedCheckOut'] ??
              requestData['correctedCheckOut'] ??
              requestData['checkOutTime'] ??
              requestData['checkOut'],
          day);

      final fmt = DateFormat('hh:mm a');
      final nowIso = DateTime.now().toIso8601String();
      final Map<String, dynamic> payload = {
        'companyId': _cid,
        'email': email,
        'date': docId, // String, like every other attendance record
        'recordDate': docId,
        'status': 'Present',
        'attendanceStatus': 'Present',
        'isLate': false,
        'isCorrection': true,
        'approvedByIssue': (requestData['id'] ?? '').toString(),
        'updatedAt': nowIso,
      };
      if (inDt != null) {
        payload['checkIn'] = Timestamp.fromDate(inDt);
        payload['checkInTime'] = fmt.format(inDt);
        payload['checkInTimestamp'] = inDt.toIso8601String();
      }
      if (outDt != null) {
        payload['checkOut'] = Timestamp.fromDate(outDt);
        payload['checkOutTime'] = fmt.format(outDt);
        payload['checkOutTimestamp'] = outDt.toIso8601String();
      }
      if (inDt != null && outDt != null && outDt.isAfter(inDt)) {
        final diff = outDt.difference(inDt);
        payload['hoursWorked'] = '${diff.inHours}h ${diff.inMinutes % 60}m';
        payload['hoursNum'] =
            double.parse((diff.inMinutes / 60.0).toStringAsFixed(1));
      }

      await userAttendanceCol(email)
          .doc(docId)
          .set(payload, SetOptions(merge: true));
      await attendanceCol
          .doc('${email}_$docId')
          .set(payload, SetOptions(merge: true));

      // Live status on the profile when the corrected day is today
      if (docId == DateFormat('yyyy-MM-dd').format(DateTime.now())) {
        try {
          await employeeDoc(email).set({
            'attendanceStatus': 'Present',
            if (inDt != null) 'lastCheckIn': Timestamp.fromDate(inDt),
            if (inDt != null) 'lastCheckInTime': fmt.format(inDt),
            if (outDt != null) 'lastCheckOut': Timestamp.fromDate(outDt),
            if (outDt != null) 'lastCheckOutTime': fmt.format(outDt),
            'updatedAt': nowIso,
          }, SetOptions(merge: true));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error applying attendance correction timing: $e');
    }
  }

  /// Changes a task's status the same way the web task board does:
  /// status (Todo / In Progress / Overdue / Done / Archived), updatedAt, the
  /// statusHistory counters and an "activity" entry. When a task with a RUNNING timer is
  /// finished, that time is also written as a web "work log" (workLogs / totalLoggedMinutes).
  /// Tasks are CREATED in the web app; the mobile app only views them and updates progress.
  static Future<void> updateTaskStatus(
    DocumentReference ref,
    String newStatus, {
    String? oldStatus,
    Map<String, dynamic>? extra,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final name = (AppSession().userName ?? AppSession().email ?? 'User').trim();
    final entry = {
      'id': 'act_${DateTime.now().millisecondsSinceEpoch}',
      'taskId': ref.id,
      'userId': AppSession().uid ?? '',
      'userName': name,
      'userInitials': _initialsOf(name),
      'type': 'status_change',
      'details': oldStatus == null
          ? 'changed status to $newStatus'
          : 'changed status: $oldStatus → $newStatus',
      'createdAt': nowIso,
    };

    Map<String, dynamic> timeFields = {};
    if (newStatus == 'Done' || newStatus == 'Archived') {
      try {
        final d = (await ref.get()).data() as Map<String, dynamic>? ?? {};
        timeFields = _runningTimeFields(ref.id, d);
      } catch (_) {}
    }

    await ref.update({
      'status': newStatus,
      'updatedAt': nowIso,
      'done': newStatus == 'Done',
      if (newStatus == 'Done' || newStatus == 'In Progress')
        'statusHistory.$newStatus': FieldValue.increment(1),
      'activity': FieldValue.arrayUnion([entry]),
      ...timeFields,
      ...?extra,
    });
  }

  static String _initialsOf(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  /// Fields that close a running timer: elapsed seconds + a web-style work log entry.
  static Map<String, dynamic> _runningTimeFields(String taskId, Map<String, dynamic> d) {
    final st = (d['status'] ?? '').toString().toLowerCase();
    final running = d['isPaused'] != true && (st == 'in progress' || st == 'in_progress');
    final timerStart = parseAnyDate(d['timerStart'] ?? d['startedAt']);
    if (!running || timerStart == null) return {};
    final seg = DateTime.now().difference(timerStart).inSeconds;
    if (seg <= 0) return {};

    final base = (d['totalElapsedSeconds'] as num?)?.toInt() ?? 0;
    final out = <String, dynamic>{'totalElapsedSeconds': base + seg, 'isPaused': true};

    final minutes = seg ~/ 60;
    if (minutes >= 1) {
      final orig = (d['originalEstimateMinutes'] as num?)?.toInt();
      final logged = ((d['totalLoggedMinutes'] as num?)?.toInt() ?? 0) + minutes;
      final remaining = orig == null ? 0 : (orig - logged < 0 ? 0 : orig - logged);
      final name = (AppSession().userName ?? AppSession().email ?? 'User').trim();
      out['workLogs'] = FieldValue.arrayUnion([
        {
          'id': 'wl_${DateTime.now().millisecondsSinceEpoch}',
          'taskId': taskId,
          'userId': AppSession().uid ?? '',
          'userName': name,
          'userInitials': _initialsOf(name),
          'timeSpentMinutes': minutes,
          'remainingMinutes': remaining,
          'startedAt': timerStart.toIso8601String(),
          'description': 'Time tracked in the mobile app',
          'createdAt': DateTime.now().toIso8601String(),
        }
      ]);
      out['totalLoggedMinutes'] = FieldValue.increment(minutes);
      if (orig != null) out['remainingEstimateMinutes'] = remaining;
    }
    return out;
  }

  /// Pause the task timer (writes the time spent so far as a work log).
  static Future<void> pauseTask(DocumentReference ref) async {
    final d = (await ref.get()).data() as Map<String, dynamic>? ?? {};
    final fields = _runningTimeFields(ref.id, d);
    await ref.update(fields.isEmpty ? {'isPaused': true} : fields);
  }

  /// Resume the task timer.
  static Future<void> resumeTask(DocumentReference ref) =>
      ref.update({'isPaused': false, 'timerStart': FieldValue.serverTimestamp()});

  // ── Shift display (always from the shift assigned to the person) ──────────────

  /// "09:00" / "9:00 AM" / Timestamp → "09:00 AM" ('' if it cannot be read).
  static String formatTime12(dynamic raw) {
    final t = parseTimeOnDay(raw, DateTime(2000, 1, 1));
    return t == null ? '' : DateFormat('hh:mm a').format(t);
  }

  /// The shift assigned to a person — same rule as the web app: id or NAME match with
  /// the profile's shift, otherwise the company's first shift.
  static Map<String, dynamic>? pickShiftFor(
      Map<String, dynamic> user, List<Map<String, dynamic>> shifts) {
    if (shifts.isEmpty) return null;
    final key = (userShiftKey(user) ?? '').trim().toLowerCase();
    if (key.isNotEmpty) {
      for (final s in shifts) {
        final name = (s['name'] ?? s['shiftName'] ?? s['title'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if ((s['id'] ?? '').toString().toLowerCase() == key ||
            name == key ||
            '$name shift' == key) {
          return s;
        }
      }
    }
    return shifts.first;
  }

  /// "General Shift · 09:00 AM – 06:00 PM" for a shift document (or the company default
  /// working hours when the company has no shifts).
  static String shiftLabel(Map<String, dynamic>? shift) {
    String name;
    String cin;
    String cout;
    if (shift != null) {
      name = (shift['name'] ?? shift['shiftName'] ?? shift['title'] ?? 'Shift')
          .toString()
          .trim();
      cin = formatTime12(shift['checkin'] ??
          shift['checkIn'] ??
          shift['check_in'] ??
          shift['checkInTime'] ??
          shift['startTime'] ??
          shift['start']);
      cout = formatTime12(shift['checkout'] ??
          shift['checkOut'] ??
          shift['check_out'] ??
          shift['checkOutTime'] ??
          shift['endTime'] ??
          shift['end']);
    } else {
      name = AppSession().shiftName.trim();
      cin = formatTime12(AppSession().shiftStartTime);
      cout = formatTime12(AppSession().shiftEndTime);
    }
    if (!name.toLowerCase().endsWith('shift')) name = '$name Shift';
    final times = (cin.isNotEmpty && cout.isNotEmpty)
        ? '$cin – $cout'
        : (cin.isNotEmpty ? cin : cout);
    return times.isEmpty ? name : '$name · $times';
  }

  /// Looks up this person's assigned shift in Firestore and returns its label.
  static Future<String> shiftLabelForUser(Map<String, dynamic> user) async {
    try {
      final qs = await shiftsCol.get();
      final shifts = qs.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = m['id'] ?? d.id;
        return m;
      }).toList();
      return shiftLabel(pickShiftFor(user, shifts));
    } catch (_) {
      return shiftLabel(null);
    }
  }

  /// Cancels the signed-in employee's own PENDING leave request, like the web Leave page:
  /// status → Cancelled (+ cancelledAt) on the company queue AND the employee's own copy.
  static Future<void> cancelLeaveRequest({
    required String requestId,
    required String applicantEmail,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final payload = {
      'status': 'Cancelled',
      'cancelledAt': nowIso,
      'updatedAt': nowIso,
    };
    await leaveRequestsCol.doc(requestId).update(payload);
    if (applicantEmail.isNotEmpty) {
      try {
        await userLeaveRequestsCol(applicantEmail)
            .doc(requestId)
            .set(payload, SetOptions(merge: true));
      } catch (e) {
        debugPrint('cancelLeaveRequest: employee copy not updated: $e');
      }
    }
  }

  // ── Leave policy numbers (shared by every Leave screen) ──────────────────────

  /// Yearly entitlement [annual, sick, casual]: organization leave types → leave policy → defaults.
  static List<int> leaveLimits(QuerySnapshot? types, Map<String, dynamic>? org) {
    int? asInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString().replaceAll(RegExp(r'[^0-9]'), ''));
    }

    int? fromTypes(String key) {
      for (final d in types?.docs ?? const <QueryDocumentSnapshot>[]) {
        final m = d.data() as Map<String, dynamic>;
        final id = d.id.toLowerCase();
        final name = (m['name'] ?? '').toString().toLowerCase();
        if (id == key || name.contains(key)) {
          final days = asInt(m['days']);
          if (days != null) return days;
        }
      }
      return null;
    }

    final policy = (org?['leavePolicy'] is Map) ? org!['leavePolicy'] as Map : const {};
    final annual = fromTypes('annual') ??
        asInt(policy['annualLeave']) ??
        (AppSession().paidLeavesPerYear > 0 ? AppSession().paidLeavesPerYear : 12);
    final sick = fromTypes('sick') ?? asInt(policy['sickLeave']) ?? 7;
    final casual = fromTypes('casual') ?? asInt(policy['casualLeave']) ?? 5;
    return [annual, sick, casual];
  }

  /// Days used [annual, sick, casual] — approved + pending requests, using the number of
  /// days saved on each request (the web's value).
  static List<int> leaveUsage(Iterable<Map<String, dynamic>> requests) {
    int annual = 0, sick = 0, casual = 0;
    for (final data in requests) {
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status != 'approved' && status != 'pending') continue;
      final type = (data['leaveType'] ?? data['type'] ?? data['category'] ?? 'Annual Leave')
          .toString()
          .toLowerCase();
      int days;
      final raw = data['days'] ?? data['durationInDays'];
      if (raw is num) {
        days = raw.toInt();
      } else {
        final p = int.tryParse((raw ?? '').toString().replaceAll(RegExp(r'[^0-9]'), ''));
        if (p != null && p > 0) {
          days = p;
        } else {
          final s = parseAnyDate(data['fromDate'] ?? data['from']);
          final e = parseAnyDate(data['toDate'] ?? data['to']) ?? s;
          days = (s == null || e == null)
              ? 1
              : DateTime(e.year, e.month, e.day)
                      .difference(DateTime(s.year, s.month, s.day))
                      .inDays +
                  1;
        }
      }
      if (type.contains('sick')) {
        sick += days;
      } else if (type.contains('casual')) {
        casual += days;
      } else {
        annual += days;
      }
    }
    return [annual, sick, casual];
  }
}
