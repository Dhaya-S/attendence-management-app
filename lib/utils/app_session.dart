/// AppSession â€” Global in-memory state for the authenticated user.
///
/// After a successful login, [companyId], [role], and company location
/// are stored here so every screen can access them without re-querying
/// Firestore on every navigation push.
class AppSession {
  // â”€â”€ Singleton â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final AppSession _instance = AppSession._internal();
  factory AppSession() => _instance;
  AppSession._internal();

  // â”€â”€ Authenticated User Info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String? uid;
  String? email;
  String? role; // 'manager' | 'employee'
  String? companyId;
  String? companyName;
  String? userName;

  // â”€â”€ Company Office Location (fetched from organizations doc) â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  bool get isManager => role?.toLowerCase() == 'manager';
  bool get isEmployee => role?.toLowerCase() == 'employee';

  /// True only when the session has been fully populated after login.
  bool get isReady =>
      uid != null && companyId != null && role != null;

  /// Populate the session after successful login + approved_users look-up.
  void populate({
    required String uid,
    required String email,
    required String role,
    required String companyId,
    String? companyName,
    String? userName,
    double? officeLat,
    double? officeLng,
    double? allowedRadius,
    String? shiftStartTime,
    String? shiftEndTime,
    int? gracePeriod,
    int? paidLeavesPerYear,
  }) {
    this.uid = uid;
    this.email = email;
    this.role = role;
    this.companyId = companyId;
    this.companyName = companyName;
    this.userName = userName;
    this.officeLat = officeLat;
    this.officeLng = officeLng;
    if (allowedRadius != null) this.allowedRadius = allowedRadius;
    if (shiftStartTime != null) this.shiftStartTime = shiftStartTime;
    if (shiftEndTime != null) this.shiftEndTime = shiftEndTime;
    if (gracePeriod != null) this.gracePeriod = gracePeriod;
    if (paidLeavesPerYear != null) this.paidLeavesPerYear = paidLeavesPerYear;
  }

  /// Clear everything on sign-out.
  void clear() {
    uid = null;
    email = null;
    role = null;
    companyId = null;
    companyName = null;
    userName = null;
    officeLat = null;
    officeLng = null;
    allowedRadius = 500;
    shiftStartTime = "09:00";
    shiftEndTime = "18:00";
    gracePeriod = 15;
    paidLeavesPerYear = 12;
  }
}
