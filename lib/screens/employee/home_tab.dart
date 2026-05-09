import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/location_service.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/widgets/location_map_card.dart';
import 'package:attendance_app/screens/employee/attendance_history_screen.dart';
import 'package:attendance_app/screens/employee/overtime_tracker_screen.dart';
import 'package:attendance_app/screens/employee/achievements_screen.dart';
import 'package:attendance_app/widgets/streak_card.dart';
import 'package:attendance_app/screens/employee/notifications_screen.dart';
import 'package:attendance_app/screens/employee/attendance_tab.dart';
import 'package:attendance_app/widgets/notification_action.dart';

class EmployeeHomeTab extends StatefulWidget {
  const EmployeeHomeTab({super.key});

  @override
  State<EmployeeHomeTab> createState() => _EmployeeHomeTabState();
}

class _EmployeeHomeTabState extends State<EmployeeHomeTab> {
  final user = FirebaseAuth.instance.currentUser;
  LocationData? _currentLocationData;
  bool _isCheckingInOut = false;
  Timer? _timer;

  // Always uses today's date — avoids Flutter Web field-init ordering issues
  String _getAttendanceDocId() =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  late final CollectionReference<Map<String, dynamic>> _todayRef;
  late final Stream<DocumentSnapshot> _userStream;
  late final Stream<DocumentSnapshot> _todayAttendanceStream;
  late final Stream<QuerySnapshot> _allAttendanceStream;

  @override
  void initState() {
    super.initState();
    final userEmail = user?.email ?? '';
    _todayRef = FirestoreService.userAttendanceCol(userEmail);
    _userStream = FirestoreService.userStreamByEmail(userEmail);
    _todayAttendanceStream = _todayRef.doc(_getAttendanceDocId()).snapshots();
    _allAttendanceStream = _todayRef.snapshots();
    _startLocationUpdates();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    LocationService().startRealtimeTracking();
    LocationService.getStream().listen((data) {
      if (mounted && data.position != null) {
        setState(() {
          _currentLocationData = data;
        });
      }
    });
  }

  Future<void> _handleCheckInOut(String status, bool isCheckIn) async {
    if (_isCheckingInOut) return;
    setState(() => _isCheckingInOut = true);

    try {
      final now = DateTime.now();
      final userEmail = user?.email ?? '';
      final data = {
        'companyId': FirestoreService.companyId,
        'userId': userEmail,
        'status': status,
        if (isCheckIn) 'workMode': (_currentLocationData?.isWithinRadius == true) ? 'office' : 'wfh', 
        if (isCheckIn) 'checkIn': Timestamp.fromDate(now),
        if (isCheckIn) 'checkInLocation': _currentLocationData?.address,
        if (!isCheckIn) 'checkOut': Timestamp.fromDate(now),
        if (!isCheckIn) 'checkOutLocation': _currentLocationData?.address,
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'recordDate': DateFormat('yyyy-MM-dd').format(now),
      };

      await _todayRef.doc(_getAttendanceDocId()).set(data, SetOptions(merge: true));

      // Auto-submit overtime request if worked > 9 hours
      if (!isCheckIn) {
        final doc = await _todayRef.doc(_getAttendanceDocId()).get();
        final checkInTime = (doc.data()?['checkIn'] as Timestamp?)?.toDate();
        if (checkInTime != null) {
          final diff = now.difference(checkInTime);
          final nineHours = const Duration(hours: 9);
          if (diff.inSeconds > nineHours.inSeconds) {
            final otMinutes = diff.inMinutes - nineHours.inMinutes;
            // Get user's name from profile for better notifications
            final querySnapshot = await FirestoreService.usersCol
                .where('email', isEqualTo: user?.email ?? '')
                .limit(1)
                .get();
            final userName = querySnapshot.docs.isNotEmpty 
                ? querySnapshot.docs.first.data()['name'] 
                : user?.displayName ?? 'Employee';
            
            await FirestoreService.userOvertimeRequestsCol(user?.email ?? '').add({
              'companyId': FirestoreService.companyId,
              'userId': user?.uid,
              'userName': userName,
              'requestDate': Timestamp.fromDate(now),
              'durationInMinutes': otMinutes,
              'status': 'pending',
              'isAutoSubmitted': true,
              'checkInTime': Timestamp.fromDate(checkInTime),
              'checkOutTime': Timestamp.fromDate(now),
            });
          }
        }
      }
      
      // Add to Notifications
      await FirestoreService.userNotificationsCol(user?.email ?? '').add({
        'companyId': FirestoreService.companyId,
        'userId': user?.uid,
        'title': isCheckIn ? 'Check-In Successful' : 'Check-Out Successful',
        'body': 'You have successfully ${isCheckIn ? 'checked in' : 'checked out'} at ${DateFormat('hh:mm a').format(now)}.',
        'type': isCheckIn ? 'check_in' : 'check_out',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) _showSuccessModal(isCheckIn ? 'Check In' : 'Check Out', now);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _isCheckingInOut = false);
    }
  }

  void _showSuccessModal(String title, DateTime time) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => ElasticIn(
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 64),
                ),
                const SizedBox(height: 24),
                Text('Successfully', style: AppTheme.h2),
                Text(title, style: AppTheme.h1.copyWith(color: AppTheme.primary, fontSize: 32)),
                const SizedBox(height: 12),
                Text(
                  'You have successfully ${title.toLowerCase()} in\nat ${DateFormat('hh:mm a').format(time)}',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<DocumentSnapshot>(
      stream: _todayAttendanceStream,
      builder: (context, attendanceSnap) {
        final record = attendanceSnap.data?.data() as Map<String, dynamic>?;
        final status = record?['status'];
        final checkInTime = record?['checkIn'] as Timestamp?;
        final checkOutTime = record?['checkOut'] as Timestamp?;

        // Dynamic Calculations
        Duration duration = Duration.zero;
        if (checkInTime != null) {
          final start = checkInTime.toDate();
          final end = checkOutTime?.toDate() ?? DateTime.now();
          duration = end.difference(start);
        }

        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        final double progress = (duration.inMinutes / (9 * 60)).clamp(0.0, 1.0);

        // Calculations for Remaining Time
        final totalMinutes = 9 * 60;
        final remainingMinutes = (totalMinutes - duration.inMinutes).clamp(0, totalMinutes);
        final remHours = remainingMinutes ~/ 60;
        final remMins = remainingMinutes % 60;
        final remStr = '${remHours}h ${remMins}m';

        return StreamBuilder<QuerySnapshot>(
          stream: _allAttendanceStream,
          builder: (context, recordsSnap) {
            final records = recordsSnap.data?.docs ?? [];
            final List<DateTime> checkInDates = records
                .where((d) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d.id))
                .map((d) {
              try {
                return DateTime.parse(d.id);
              } catch (_) {
                return null;
              }
            })
                .whereType<DateTime>()
                .toList();

            return Scaffold(
              backgroundColor: const Color(0xFFFBFBFB),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                toolbarHeight: 90,
                leadingWidth: 80,
                leading: _buildAvatar(),
                title: StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, userSnap) {
                    Map<String, dynamic>? userData = userSnap.data?.data() as Map<String, dynamic>?;

                    final rawName = userData?['name']?.toString() ?? AppSession().userName ?? user?.displayName ?? 'Employee';
                    final fullName = rawName.trim().isEmpty ? 'Employee' : rawName.trim();
                    final firstName = fullName.split(' ')[0];
                    final approvedBy = userData?['approvedBy'];

                    // Time-based greeting
                    final hour = DateTime.now().hour;
                    String greeting = 'Good Morning';
                    if (hour >= 12 && hour < 17) {
                      greeting = 'Good Afternoon';
                    } else if (hour >= 17) {
                      greeting = 'Good Evening';
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$greeting,', style: AppTheme.bodySmall.copyWith(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.2)),
                        const SizedBox(height: 1),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(firstName, style: AppTheme.h1.copyWith(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.black)),
                            ),
                            if (approvedBy != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified, size: 10, color: Colors.green),
                                    const SizedBox(width: 2),
                                    Text('Approved by $approvedBy', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 10, color: Colors.black.withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('EEEE, MMM d').format(DateTime.now()),
                              style: AppTheme.label.copyWith(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                actions: [
                  NotificationAction(isManager: false),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                  await Future.delayed(const Duration(milliseconds: 800));
                },
                color: AppTheme.primary,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      FadeInUp(delay: const Duration(milliseconds: 100), child: _buildOfficeLocationCard()),
                      const SizedBox(height: 24),
                      FadeInUp(delay: const Duration(milliseconds: 200), child: _buildUnifiedStatusCard(status, checkInTime, checkOutTime, progress)),
                      const SizedBox(height: 24),
                      FadeInUp(delay: const Duration(milliseconds: 300), child: _buildShiftOverviewAlt(hours, minutes, progress, remStr)),
                      const SizedBox(height: 24),
                      FadeInUp(delay: const Duration(milliseconds: 400), child: StreakCard(checkInDates: checkInDates)),
                      const SizedBox(height: 24),
                      FadeInUp(delay: const Duration(milliseconds: 500), child: _buildQuickActions()),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final imgUrl = data?['profileImageUrl'] as String?;
        return Container(
          margin: const EdgeInsets.only(left: 24, top: 18, bottom: 18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: imgUrl != null && imgUrl.isNotEmpty
                ? Image.network(
                    imgUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: AppTheme.primaryLight,
                      child: const Icon(Icons.person, color: Colors.white, size: 24),
                    ),
                  )
                : Container(
                    width: 44,
                    height: 44,
                    color: AppTheme.primaryLight,
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildOfficeLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.divider.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Stack(
                children: [
                  LocationMapCard(
                    officeLat: LocationService.officeLat,
                    officeLng: LocationService.officeLng,
                    allowedRadius: LocationService.allowedRadius,
                    userLocation: _currentLocationData?.latLng,
                    userAddress: _currentLocationData?.address,
                    height: 160,
                  ),
                  Positioned.fill(
                    child: Container(color: Colors.black.withOpacity(0.02)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Office Location', style: AppTheme.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: _currentLocationData?.isWithinRadius == true ? AppTheme.success : AppTheme.danger, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(
                            _currentLocationData?.isWithinRadius == true ? 'INSIDE OFFICE RANGE' : 'OUTSIDE OFFICE RANGE',
                            style: AppTheme.label.copyWith(fontSize: 10, color: _currentLocationData?.isWithinRadius == true ? AppTheme.success : AppTheme.danger, letterSpacing: 0.8, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _FullMapScreen(
                          officeLat: LocationService.officeLat,
                          officeLng: LocationService.officeLng,
                          allowedRadius: LocationService.allowedRadius,
                          userLocation: _currentLocationData?.latLng,
                          userAddress: _currentLocationData?.address,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF1FE),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('View Map', style: AppTheme.label.copyWith(color: const Color(0xFF6366F1), fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedStatusCard(String? status, Timestamp? checkIn, Timestamp? checkOut, double progress) {
    bool isCheckedIn = status == 'checked_in';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.divider.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, 15))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isCheckedIn ? AppTheme.success : AppTheme.danger).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: Icon(
                      isCheckedIn ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      color: isCheckedIn ? AppTheme.success : AppTheme.danger,
                      size: 24
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Working Status', style: AppTheme.bodySmall.copyWith(color: AppTheme.textHint, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(isCheckedIn ? 'On Duty' : 'Off Duty', style: AppTheme.h2.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isCheckedIn ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Text(
                  isCheckedIn ? 'ON DUTY' : 'OFF DUTY',
                  style: AppTheme.label.copyWith(
                    fontSize: 10,
                    color: isCheckedIn ? const Color(0xFF166534) : const Color(0xFF991B1B),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5
                  )
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: _statusTimeBox('CHECK-IN', checkIn != null ? DateFormat('hh:mm a').format(checkIn.toDate()) : '--:--')),
              const SizedBox(width: 16),
              Expanded(child: _statusTimeBox('CHECK-OUT', checkOut != null ? DateFormat('hh:mm a').format(checkOut.toDate()) : '--:--')),
            ],
          ),
          const SizedBox(height: 24),
          _buildRemarksSectionSmall(),
          const SizedBox(height: 20),
          _buildElegantSlideButton(status),
        ],
      ),
    );
  }

  Widget _statusTimeBox(String label, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(label, style: AppTheme.label.copyWith(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Text(time, style: AppTheme.h2.copyWith(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildRemarksSectionSmall() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _todayRef.doc(_getAttendanceDocId()).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final currentRemark = data?['remark'] ?? '';
        final remarkStatus = data?['remarkStatus'] ?? 'pending';

        Color statusColor;
        String statusText;
        Color bgColor;

        switch (remarkStatus) {
          case 'approved':
            statusColor = AppTheme.success;
            statusText = 'APPROVED';
            bgColor = const Color(0xFFF0FDF4);
            break;
          case 'denied':
            statusColor = AppTheme.danger;
            statusText = 'DENIED';
            bgColor = const Color(0xFFFEF2F2);
            break;
          default:
            statusColor = const Color(0xFF166534);
            statusText = 'PENDING';
            bgColor = const Color(0xFFF0FDF4);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_edu_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  currentRemark.isEmpty ? 'Late Adjustment Request' : 'Adjustment Request Status', 
                  style: AppTheme.label.copyWith(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w800, letterSpacing: 0.5)
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (currentRemark.isEmpty)
              GestureDetector(
                onTap: () => _showRemarkDialog(currentStatus: data?['status']),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.divider.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Send a request for late entry...',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                            fontSize: 14
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.send_rounded, color: Color(0xFF94A3B8), size: 18),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: statusColor.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(
                        remarkStatus == 'approved' ? Icons.check_rounded : 
                        remarkStatus == 'denied' ? Icons.close_rounded : Icons.access_time_rounded, 
                        color: statusColor, 
                        size: 16
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            remarkStatus == 'approved' ? 'Request Approved' : 
                            remarkStatus == 'denied' ? 'Request Denied' : 'Request Submitted', 
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 14)
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your reason: "$currentRemark"',
                            style: TextStyle(color: statusColor.withOpacity(0.7), fontWeight: FontWeight.w600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5)),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildElegantSlideButton(String? status) {
    if (status == 'checked_out') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success.withOpacity(0.5), size: 18),
            const SizedBox(width: 12),
            Text(
              "ATTENDANCE COMPLETE FOR TODAY",
              style: AppTheme.label.copyWith(
                color: AppTheme.textHint,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.0
              ),
            ),
          ],
        ),
      );
    }

    bool isCheckedIn = status == 'checked_in';
    return SlideAction(
      onSubmit: () => _handleCheckInOut(isCheckedIn ? 'checked_out' : 'checked_in', !isCheckedIn),
      innerColor: Colors.white,
      outerColor: isCheckedIn ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
      elevation: 0,
      height: 60,
      borderRadius: 18,
      sliderButtonIcon: Icon(
        isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
        color: isCheckedIn ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
        size: 20
      ),
      text: isCheckedIn ? "SLIDE TO CHECK OUT" : "SLIDE TO CHECK IN",
      textStyle: AppTheme.bodyMedium.copyWith(
        fontWeight: FontWeight.w900,
        color: Colors.white,
        fontSize: 14,
        letterSpacing: 1.0
      ),
    );
  }

  Widget _buildShiftOverviewAlt(int hours, int minutes, double progress, String remStr) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.divider.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 10))
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SHIFT OVERVIEW', style: AppTheme.label.copyWith(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('Full-time', style: AppTheme.label.copyWith(color: const Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _overviewItemBox('Worked', '${hours}h ${minutes}m', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
              const SizedBox(width: 12),
              _overviewItemBox(
                hours >= 9 ? 'Overtime' : 'Remaining',
                hours >= 9 ? '${hours - 9}h ${minutes}m' : remStr,
                hours >= 9 ? const Color(0xFFE0F2F1) : const Color(0xFFFBE4D6),
                hours >= 9 ? const Color(0xFF00695C) : const Color(0xFFED7D31),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewItemBox(String label, String val, Color bg, Color text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: text.withOpacity(0.7), fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: text, letterSpacing: -0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('QUICK ACTIONS', style: AppTheme.label.copyWith(fontSize: 13, letterSpacing: 1.8, color: AppTheme.textHint, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _actionItemAlt(Icons.history_rounded, 'History', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()));
            }),
            _actionItemAlt(Icons.calendar_today_rounded, 'Calendar', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeAttendanceTab()));
            }),
            _actionItemAlt(Icons.timer_outlined, 'Overtime', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OvertimeTrackerScreen()));
            }),
            _actionItemAlt(Icons.emoji_events_rounded, 'Awards', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()));
            }),
          ],
        ),
      ],
    );
  }

  Widget _actionItemAlt(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.divider.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF6366F1), size: 24),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.2)),
          ],
        ),
      ),
    );
  }

  void _showRemarkDialog({String? currentStatus}) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Adjustment Request', style: AppTheme.h2.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 3,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Enter valid reason for late check-in (e.g. Traffic, Medical)...',
              hintStyle: TextStyle(color: AppTheme.textHint.withOpacity(0.5)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              
              // Fetch the current user's name for manager visibility
              final userQuery = await FirestoreService.usersCol
                  .where('email', isEqualTo: user?.email ?? '')
                  .limit(1)
                  .get();
              final userData = userQuery.docs.isNotEmpty ? userQuery.docs.first.data() : {};
              final userName = (userData['name'] ?? user?.email?.split('@')[0] ?? 'Employee') as String;
              
              final docId = _getAttendanceDocId();
              await _todayRef.doc(docId).set({
                'companyId': FirestoreService.companyId,
                'remark': controller.text.trim(),
                'isAdjustmentRequest': true,
                'remarkStatus': 'pending',
                'requestTime': FieldValue.serverTimestamp(),
                'userId': user?.uid,
                'userEmail': user?.email,
                'userName': userName,
                'recordDate': docId,
                'status': currentStatus, // Keep existing status
              }, SetOptions(merge: true));
              
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Adjustment request sent successfully!',
                            style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.all(20),
                    elevation: 10,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('Send to Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          ],
        ),
      ),
    );
  }
}

class _FullMapScreen extends StatelessWidget {
  final double officeLat;
  final double officeLng;
  final double allowedRadius;
  final LatLng? userLocation;
  final String? userAddress;

  const _FullMapScreen({
    required this.officeLat,
    required this.officeLng,
    required this.allowedRadius,
    this.userLocation,
    this.userAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16, top: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
        children: [
          LocationMapCard(
            officeLat: officeLat,
            officeLng: officeLng,
            allowedRadius: allowedRadius,
            userLocation: userLocation,
            userAddress: userAddress,
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: FadeInUp(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 15))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.location_on, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Office Range Area', style: AppTheme.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                'You must be within ${allowedRadius.toInt()}m to check-in.',
                                style: AppTheme.bodySmall.copyWith(color: AppTheme.textHint, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
