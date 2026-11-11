# Web ⇄ Mobile Firestore contract

The **web app is the master**. The mobile app writes exactly what the web writes and reads both old and new shapes.
Both apps use one Firebase project (`attendence-a56dd`) and one tenant tree: `organizations/{companyId}/…`.

## Values both apps use

| Thing | Value |
|---|---|
| Request status | `Pending` · `Approved` · `Rejected` (Cancelled for leave). Title Case. Readers compare case-insensitively. |
| Task status | `Todo` · `In Progress` · `Overdue` · `Done` · `Archived` |
| Attendance status | `Present` · `Late` · `WFH` (later `attendanceStatus: "Checked Out"`); check-out never changes `status` |
| Attendance date key | LOCAL `yyyy-MM-dd` (web used the UTC date before; fixed with `localDateKey()`) |
| Attendance `date` field | the same `yyyy-MM-dd` **string** (never a Timestamp) |
| Attendance `userId` | Firebase Auth uid; `email` = lower-case email |
| Times | `checkInTime` / `checkOutTime` = `"09:05 AM"`; `checkIn` / `checkOut` = Timestamp; `hoursWorked` = `"7h 30m"` |
| Roles | `hr_admin` · `manager` · `employee` (legacy `admin` / `super_admin` map to `hr_admin`) |

## Who writes what

| Data | Path | Created by | Mobile |
|---|---|---|---|
| Attendance | `users/{email}/attendance/{date}` + `attendance/{email}_{date}` + live status on `users/{email}` | both | writes all three, web format |
| Leave request | `leave_requests/{id}` + `users/{email}/leave_requests/{id}` | both | `FirestoreService.submitLeaveRequest` (both copies) |
| Leave decision | both copies | both | `FirestoreService.reviewRequest` → `Approved/Rejected` + `approvedBy/At` |
| Attendance correction | `attendance_issues/ISS<ms>` (`createdBy`, `date`, `requestedCheckIn/Out`) | both | `FirestoreService.submitAttendanceIssue`; approval fixes the day's attendance (2 copies + live status) |
| Tasks | `tasks/{id}` | **web only** | view + update status/timer/comments only (`updateTaskStatus`); never creates or deletes |
| Announcements | `announcements` (all / departments) and `team_announcements` (particular members) | both | web fields (`body`, `audienceType`, `status: Published`) |
| Team feed | `team_feed/F_<ms>_<rand>` (`author`, `reactions: [{emoji, users[]}]`, `comments[]`, `createdAt` = epoch ms) | both | web shape |
| Support ticket | `support_tickets/TKT-xxxxxx` (`subject`, `status: Open`) | both | web shape |
| Policies, shifts, holidays, departments, org profile, permission matrix | web only | web | read only (mobile no longer seeds demo policies) |
| Notifications | `users/{email}/notifications`, `global_notifications` | mobile | needed for push; rules added |

## Same logic on both sides
- **Permission matrix**: `organizations/{cid}.featurePermissions` — keys `approval`, `task_creation`, `announcement_creation`, `organization`, `geofencing`; HR Admin bypass; geofencing checked first.
- **Geofencing on/off**: enabled when `isGeofencingEnabled`, `attendancePolicy.isGeofencingEnabled` or `wfhPolicy.geofenceRequired == "Yes"` is set.
- **Office location + radius**: employee lat/lng → employee branch → first org location/branch → org lat/lng; radius text such as `"200m"` is parsed.
- **Shift**: the shift whose id or NAME matches the employee's `shift` ("General" also matches "General Shift"), else the first shift.
- **Late**: after `shift check-in + grace` (default 15 min).

## Firestore rules
`firestore.rules` in the **web** project is the one to deploy (`firebase deploy --only firestore:rules`).
It now also covers the mobile paths: personal notifications, overtime requests, manager alerts (`global_notifications`), announcement comments/likes, and the login lookup `collectionGroup("users")` by own email.
The older `firestore.rules` in this mobile project is obsolete — do not deploy it.

## Left as is on purpose
- `shift_requests`, `department_requests`, `task_requests`, `company_calendar`, `isAdjustmentRequest/remarkStatus`: the web app never writes these, so the mobile screens that read them stay empty.
- The third legacy attendance copy `users/{email}/attendance` (web writes it, nothing reads it) is not written by mobile.
