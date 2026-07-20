import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/location_service.dart';
import 'manager_request_correction_screen.dart';

class ManagerAttendanceDetailScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  const ManagerAttendanceDetailScreen({super.key, this.onTabChange});

  @override
  State<ManagerAttendanceDetailScreen> createState() => _ManagerAttendanceDetailScreenState();
}

class _ManagerAttendanceDetailScreenState extends State<ManagerAttendanceDetailScreen> {
  final user = FirebaseAuth.instance.currentUser;
  late final CollectionReference<Map<String, dynamic>> _todayRef;
  late final Stream<DocumentSnapshot> _todayAttendanceStream;
  DateTime _currentDate = DateTime.now();
  LocationData? _currentLocationData;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final userEmail = user?.email ?? '';
    _todayRef = FirestoreService.userAttendanceCol(userEmail);
    _todayAttendanceStream = _todayRef.doc(_getAttendanceDocId(_currentDate)).snapshots();
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    LocationService().startRealtimeTracking();
    LocationService.getStream().listen((data) {
      if (mounted && data.position != null) {
        setState(() => _currentLocationData = data);
      }
    });
  }

  String _getAttendanceDocId(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  void _changeDate(int days) {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: days));
      _initStream();
    });
  }

  String _getWorkingDuration(Timestamp? checkIn, Timestamp? checkOut) {
    if (checkIn == null) return '0h 0m';
    final diff = (checkOut?.toDate() ?? DateTime.now()).difference(checkIn.toDate());
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  String _getOvertimeDuration(Timestamp? checkIn, Timestamp? checkOut) {
    if (checkIn == null) return '0 min';
    final now = checkOut?.toDate() ?? DateTime.now();
    try {
      final sParts = AppSession().shiftStartTime.split(':');
      final eParts = AppSession().shiftEndTime.split(':');
      final shiftDur = Duration(hours: int.parse(eParts[0]), minutes: int.parse(eParts[1])) -
          Duration(hours: int.parse(sParts[0]), minutes: int.parse(sParts[1]));
      final worked = now.difference(checkIn.toDate());
      if (worked > shiftDur) {
        final ot = worked - shiftDur;
        return ot.inHours > 0 ? '${ot.inHours}h ${ot.inMinutes % 60}m' : '${ot.inMinutes} min';
      }
    } catch (_) {}
    return '0 min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('E, d MMM yyyy').format(_currentDate),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: _todayAttendanceStream,
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final checkIn = data?['checkIn'] as Timestamp?;
                if (checkIn == null) return const SizedBox.shrink();
                
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      border: Border.all(color: const Color(0xFF10B981)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Present',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E7EB), height: 1),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _todayAttendanceStream,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final checkIn = data?['checkIn'] as Timestamp?;
          final checkOut = data?['checkOut'] as Timestamp?;
          final loc = data?['checkInLocation'] as String?;
          final checkInLoc = (loc != null && loc != 'Unknown') 
              ? loc 
              : (_currentLocationData?.address ?? (AppSession().companyName != null ? '${AppSession().companyName} HQ' : 'Bengaluru HQ â€“ Prestige Tech Park'));
          final workMode = data?['workMode'] as String? ?? 'office';
          
          final inStr = checkIn != null ? DateFormat('hh:mm a').format(checkIn.toDate()) : '--:--';
          final outStr = checkOut != null ? DateFormat('hh:mm a').format(checkOut.toDate()) : (checkIn != null ? 'Ongoing' : '--:--');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Top Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTimeBox(inStr, 'Check In', const Color(0xFFECFDF5), const Color(0xFF10B981))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTimeBox(outStr, 'Check Out', const Color(0xFFFFFBEB), const Color(0xFFF59E0B))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildSmallBox(_getWorkingDuration(checkIn, checkOut), 'Working Hours')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildSmallBox(_getOvertimeDuration(checkIn, checkOut), 'Overtime')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildSmallBox('1h 00m', 'Break')), // Mocked break
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Details Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DETAILS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                      const SizedBox(height: 16),
                      _buildDetailRow('Shift', 'General Shift'),
                      _buildDivider(),
                      _buildDetailRow('Work Mode', workMode == 'wfh' ? 'WFH' : 'Office'),
                      _buildDivider(),
                      _buildDetailRow('Attendance Method', 'Biometric + GPS'),
                      _buildDivider(),
                      _buildDetailRow('GPS Accuracy', 'High (Â±3m)'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Location Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CHECK-IN LOCATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.location_on_outlined, color: Color(0xFF5C5CFF), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(checkInLoc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                                const SizedBox(height: 2),
                                const Text('GPS Verified - Inside office range', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Timeline Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DAY TIMELINE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                      const SizedBox(height: 20),
                      _buildTimelineItem(
                        iconColor: const Color(0xFF5C5CFF),
                        title: 'Check In',
                        subtitle: checkInLoc,
                        time: inStr,
                        timeColor: const Color(0xFF5C5CFF),
                        isLast: false,
                      ),
                      _buildTimelineItem(
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Check Out',
                        subtitle: checkOut == null ? 'Expected by 06:00 PM' : (data?['checkOutLocation'] as String? ?? checkInLoc),
                        time: outStr,
                        timeColor: const Color(0xFFF59E0B),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManagerRequestCorrectionScreen(
                            attendanceDate: _currentDate,
                            initialCheckIn: checkIn != null ? DateFormat('hh:mm a').format(checkIn.toDate()) : null,
                            initialCheckOut: checkOut != null ? DateFormat('hh:mm a').format(checkOut.toDate()) : null,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C5CFF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Request Correction', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.download_rounded, color: Color(0xFF6B7280), size: 18),
                        SizedBox(width: 8),
                        Text('Download Record', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildTimeBox(String value, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: Color(0xFFF3F4F6), height: 1),
    );
  }

  Widget _buildTimelineItem({
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required Color timeColor,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: const Color(0xFFF3F4F6),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
        ),
        Text(time, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: timeColor)),
      ],
    );
  }
}
