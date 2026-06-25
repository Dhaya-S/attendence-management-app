import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'app_session.dart';

/// FirestoreService — Single source of truth for all Firestore collection
/// and document references.
///
/// **Company-Centric Model:**
/// All operational data (employees, attendance, leave requests, etc.) is stored
/// as subcollections under `approved_companies/{companyId}/...`.
/// This ensures that when you view a company in the Firestore console, you can
/// see all related employees, attendance, and leave data nested under it.
///
/// Never call `FirebaseFirestore.instance.collection(...)` directly in UI code
/// — use the static helpers here instead.
class FirestoreService {
  FirestoreService._(); // No instances needed — all members are static.

  static final _db = FirebaseFirestore.instance;

  // ── Convenience accessor ─────────────────────────────────────────────────

  static String get _cid {
    final id = AppSession().companyId;
    assert(id != null, 'AppSession.companyId is null — was login completed?');
    return id!;
  }

  /// Public getter for the current tenant's companyId
  static String get companyId => _cid;

  // ── Global (cross-company) refs ──────────────────────────────────────────

  /// `approved_users/{email}` — global login / company mapping.
  static DocumentReference<Map<String, dynamic>> approvedUserDoc(
          String email) =>
      _db.collection('approved_users').doc(email.toLowerCase());

  /// `approved_companies/{companyId}` — company master document.
  static DocumentReference<Map<String, dynamic>> companyDoc(
          [String? companyId]) =>
      _db.collection('approved_companies').doc(companyId ?? _cid);

  /// `organization_setup_requests/{requestId}` — pre-login organization setup submissions.
  static CollectionReference<Map<String, dynamic>> get organizationSetupRequestsCol =>
      _db.collection('organization_setup_requests');

  // ── New: Organizations (self-registration flow) ──────────────────────────
  // Used when a company admin registers directly via the app.
  // Structure: organizations/{orgId}/members/{uid}
  //                                /departments/{deptId}

  /// `organizations` — top-level collection for self-registered companies.
  static CollectionReference<Map<String, dynamic>> get orgCol =>
      _db.collection('organizations');

  /// `organizations/{orgId}` — company master document.
  static DocumentReference<Map<String, dynamic>> orgDoc(String orgId) =>
      orgCol.doc(orgId);

  /// `organizations/{orgId}/members` — all admin/employee profiles for this org.
  static CollectionReference<Map<String, dynamic>> orgMembersCol(String orgId) =>
      orgDoc(orgId).collection('members');

  /// `organizations/{orgId}/members/{uid}` — a single member's profile.
  static DocumentReference<Map<String, dynamic>> orgMemberDoc(
          String orgId, String uid) =>
      orgMembersCol(orgId).doc(uid);

  /// `organizations/{orgId}/departments` — department list for this org.
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
  static CollectionReference<Map<String, dynamic>> orgShiftsCol(
          String orgId) =>
      orgDoc(orgId).collection('shifts');

  /// `organizations/{orgId}/policies`
  static CollectionReference<Map<String, dynamic>> orgPoliciesCol(
          String orgId) =>
      orgDoc(orgId).collection('policies');

  /// `organizations/{orgId}/policies/{policyId}`
  static DocumentReference<Map<String, dynamic>> orgPolicyDoc(
          String orgId, String policyId) =>
      orgPoliciesCol(orgId).doc(policyId);

  // ── Company-Scoped Subcollections ────────────────────────────────────────
  // All operational data lives UNDER the company document so that
  // Firestore console shows everything nested per company.

  /// `/approved_companies/{companyId}/users` — user profiles
  static CollectionReference<Map<String, dynamic>> get employeesCol =>
      companyDoc().collection('users');

  /// Filtered query for approved employees in the current company
  static Query<Map<String, dynamic>> get companyUsersQuery =>
      employeesCol.where('status', isEqualTo: 'approved');

  /// `/approved_companies/{companyId}/employees/{email}`
  static DocumentReference<Map<String, dynamic>> employeeDoc(String email) =>
      employeesCol.doc(email.toLowerCase());

  /// Get a stream of the employee document by email.
  /// Primary lookup is by document ID (email), with a fallback query.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> userStreamByEmail(String email) {
    final normalizedEmail = email.toLowerCase();
    return employeesCol.doc(normalizedEmail).snapshots().asyncMap((doc) async {
      if (doc.exists) return doc;
      
      // Fallback: search for a document where the 'email' FIELD matches
      try {
        final qs = await employeesCol.where('email', isEqualTo: normalizedEmail).limit(1).get();
        if (qs.docs.isNotEmpty) return qs.docs.first;
      } catch (e) {
        debugPrint('userStreamByEmail fallback query failed: $e');
      }
      return doc; // Return the empty doc if fallback fails
    });
  }

  /// `/approved_companies/{companyId}/users/{email}/attendance`
  static CollectionReference<Map<String, dynamic>> userAttendanceCol(String email) =>
      employeeDoc(email).collection('attendance');

  /// `/approved_companies/{companyId}/users/{email}/leave_requests`
  static CollectionReference<Map<String, dynamic>> userLeaveRequestsCol(String email) =>
      employeeDoc(email).collection('leave_requests');

  /// `/approved_companies/{companyId}/users/{email}/notifications`
  static CollectionReference<Map<String, dynamic>> userNotificationsCol(String email) =>
      employeeDoc(email).collection('notifications');

  /// `/approved_companies/{companyId}/users/{email}/overtime_requests`
  static CollectionReference<Map<String, dynamic>> userOvertimeRequestsCol(String email) =>
      employeeDoc(email).collection('overtime_requests');

  // ── Collection Group Queries (Manager Access) ──────────────────────────────
  // These allow managers to query all records across all employees in the company.

  /// All attendance records for the current company via collection group query.
  static Query<Map<String, dynamic>> get allAttendanceRecordsCol {
    return _db.collectionGroup('attendance').where('companyId', isEqualTo: _cid);
  }

  /// All leave requests for the current company via collection group query.
  static Query<Map<String, dynamic>> get allLeaveRequestsQuery {
    return _db.collectionGroup('leave_requests').where('companyId', isEqualTo: _cid);
  }

  /// All overtime requests for the current company via collection group query.
  static Query<Map<String, dynamic>> get allOvertimeRequestsQuery {
    return _db.collectionGroup('overtime_requests').where('companyId', isEqualTo: _cid);
  }

  /// All notifications for the current company via collection group query.
  static Query<Map<String, dynamic>> get allNotificationsQuery {
    return _db.collectionGroup('notifications').where('companyId', isEqualTo: _cid);
  }

  /// Alias for backward compatibility
  static Query<Map<String, dynamic>> get companyLeaveRequestsQuery => allLeaveRequestsQuery;

  // ── Global Company Notifications ──────────────────────────────────────────
  // These are notifications meant for the entire company, not a specific user.
  
  /// `/approved_companies/{companyId}/global_notifications`
  static CollectionReference<Map<String, dynamic>> get globalNotificationsCol =>
      companyDoc().collection('global_notifications');

  // ── Legacy / Flat Collections (To be removed after migration) ───────────

  /// @deprecated Use [userAttendanceCol]
  static CollectionReference<Map<String, dynamic>> get attendanceCol =>
      companyDoc().collection('attendance');

  /// @deprecated Use [userAttendanceCol]
  static CollectionReference<Map<String, dynamic>> attendanceRecordsCol(String uidOrEmail) {
    // Attempting to maintain some compatibility during transition
    if (uidOrEmail.contains('@')) return userAttendanceCol(uidOrEmail);
    return attendanceCol.doc(uidOrEmail).collection('records');
  }

  /// @deprecated Use [userLeaveRequestsCol]
  static CollectionReference<Map<String, dynamic>> get leaveRequestsCol =>
      companyDoc().collection('leave_requests');

  /// @deprecated Use [userNotificationsCol]
  static CollectionReference<Map<String, dynamic>> get notificationsCol =>
      companyDoc().collection('notifications');

  /// @deprecated Use [userOvertimeRequestsCol]
  static CollectionReference<Map<String, dynamic>> get overtimeRequestsCol =>
      companyDoc().collection('overtime_requests');

  // ── Legacy Compatibility Aliases ─────────────────────────────────────────
  // These aliases keep existing UI code working without mass renames.

  /// Alias for `employeesCol` — backward compatible with old `usersCol` calls
  static CollectionReference<Map<String, dynamic>> get usersCol => employeesCol;

  /// Alias for `employeeDoc(uid)` — backward compatible
  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      employeesCol.doc(uid);

  /// Alias for `employeeDoc(email)` — backward compatible
  static DocumentReference<Map<String, dynamic>> userDocByEmail(
          String email) =>
      employeesCol.doc(email.toLowerCase());

  /// Find a company where the given email is the manager.
  /// This is used for login fallback when the manager isn't in 'approved_users'.
  static Future<QuerySnapshot<Map<String, dynamic>>> findCompanyByManagerEmail(
          String email) =>
      _db
          .collection('approved_companies')
          .where('managerEmail', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
}
