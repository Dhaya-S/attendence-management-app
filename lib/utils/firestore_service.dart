import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  static CollectionReference<Map<String, dynamic>> get organizationSetupRequestsCol =>
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
  static CollectionReference<Map<String, dynamic>> orgMembersCol(String orgId) =>
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

  // â”€â”€ Company-Scoped Subcollections â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // All operational data lives UNDER the company document so that
  // Firestore console shows everything nested per company.

  /// `/organizations/{companyId}/users` â€” user profiles
  static CollectionReference<Map<String, dynamic>> get employeesCol =>
      companyDoc().collection('users');

  /// Filtered query for approved employees in the current company
  static Query<Map<String, dynamic>> get companyUsersQuery =>
      employeesCol.where('status', isEqualTo: 'approved');

  /// `/organizations/{companyId}/employees/{email}`
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

  /// `/organizations/{companyId}/users/{email}/attendance`
  static CollectionReference<Map<String, dynamic>> userAttendanceCol(String email) =>
      employeeDoc(email).collection('attendance');

  /// `/organizations/{companyId}/users/{email}/leave_requests`
  static CollectionReference<Map<String, dynamic>> userLeaveRequestsCol(String email) =>
      employeeDoc(email).collection('leave_requests');

  /// `/organizations/{companyId}/users/{email}/notifications`
  static CollectionReference<Map<String, dynamic>> userNotificationsCol(String email) =>
      employeeDoc(email).collection('notifications');

  /// `/organizations/{companyId}/users/{email}/overtime_requests`
  static CollectionReference<Map<String, dynamic>> userOvertimeRequestsCol(String email) =>
      employeeDoc(email).collection('overtime_requests');

  // â”€â”€ Collection Group Queries (Manager Access) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  /// All attendance corrections for the current company via collection group query (if sub-collections) or flat
  static Query<Map<String, dynamic>> get allAttendanceCorrectionsQuery {
    return companyDoc().collection('attendance_corrections');
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

  /// All notifications for the current company via collection group query.
  static Query<Map<String, dynamic>> get allNotificationsQuery {
    return _db.collectionGroup('notifications').where('companyId', isEqualTo: _cid);
  }

  /// All tasks for the current company via collection group query.
  static Query<Map<String, dynamic>> get allTasksQuery {
    return _db.collectionGroup('tasks').where('companyId', isEqualTo: _cid);
  }

  /// Alias for backward compatibility
  static Query<Map<String, dynamic>> get companyLeaveRequestsQuery => allLeaveRequestsQuery;

  // â”€â”€ Global Company Notifications â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // These are notifications meant for the entire company, not a specific user.
  
  /// `/organizations/{companyId}/global_notifications`
  static CollectionReference<Map<String, dynamic>> get globalNotificationsCol =>
      companyDoc().collection('global_notifications');

  /// `/organizations/{companyId}/announcements`
  static CollectionReference<Map<String, dynamic>> get announcementsCol =>
      orgDoc(_cid).collection('announcements');

  /// `/organizations/{companyId}/company_calendar`
  static CollectionReference<Map<String, dynamic>> get companyCalendarCol =>
      companyDoc().collection('company_calendar');

  /// `/organizations/{companyId}/tasks`
  static CollectionReference<Map<String, dynamic>> get tasksCol =>
      companyDoc().collection('tasks');

  /// `/organizations/{companyId}/feed_posts`
  static CollectionReference<Map<String, dynamic>> get feedPostsCol =>
      companyDoc().collection('feed_posts');

  // â”€â”€ Legacy / Flat Collections (To be removed after migration) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€ Legacy Compatibility Aliases â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // These aliases keep existing UI code working without mass renames.

  /// Alias for `employeesCol` â€” backward compatible with old `usersCol` calls
  static CollectionReference<Map<String, dynamic>> get usersCol => employeesCol;

  /// Alias for `employeeDoc(uid)` â€” backward compatible
  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      employeesCol.doc(uid);

  /// Alias for `employeeDoc(email)` â€” backward compatible
  static DocumentReference<Map<String, dynamic>> userDocByEmail(
          String email) =>
      employeesCol.doc(email.toLowerCase());

  /// Find a company where the given email is the manager.
  /// This is used for login fallback when the manager isn't in 'approved_users'.
  static Future<QuerySnapshot<Map<String, dynamic>>> findCompanyByManagerEmail(
          String email) =>
      _db
          .collection('organizations')
          .where('managerEmail', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
}
