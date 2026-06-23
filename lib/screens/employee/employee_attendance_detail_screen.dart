import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/screens/employee/employee_attendance_correction_screen.dart';
import 'package:attendance_app/utils/app_session.dart';

class EmployeeAttendanceDetailScreen extends StatelessWidget {
  final DateTime date;
  final Map<String, dynamic> data;

  const EmployeeAttendanceDetailScreen({
    super.key,
    required this.date,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final checkInTs = data['checkIn'] as Timestamp?;
    final checkOutTs = data['checkOut'] as Timestamp?;
    
    String cin = checkInTs != null ? DateFormat('hh:mm a').format(checkInTs.toDate()) : '--:--';
    String cout = checkOutTs != null ? DateFormat('hh:mm a').format(checkOutTs.toDate()) : '--:--';
    
    String status = 'Absent';
    if (checkInTs != null) status = 'Present';
    if (data['status'] == 'late') status = 'Late';
    if (data['status'] == 'holiday') status = 'Holiday';
    if (data['status'] == 'leave') status = 'Leave';

    String hoursText = '--h --m';
    if (checkInTs != null) {
      if (checkOutTs != null) {
        final diff = checkOutTs.toDate().difference(checkInTs.toDate());
        hoursText = '${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        final now = DateTime.now();
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          final diff = now.difference(checkInTs.toDate());
          hoursText = '${diff.inHours}h ${diff.inMinutes % 60}m';
        } else {
          hoursText = 'Missing Out';
        }
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Top Gradient Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B66FF), Color(0xFF5C5CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM d, yyyy').format(date),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(color: Color(0xFF5C5CFF), fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        hoursText,
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('d').format(date),
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          DateFormat('MMM').format(date),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Check In / Check Out boxes
            Row(
              children: [
                Expanded(child: _buildTimeBox('Check In', cin, Icons.access_time_filled, AppTheme.success)),
                const SizedBox(width: 16),
                Expanded(child: _buildTimeBox('Check Out', cout, Icons.access_time_filled, AppTheme.danger)),
              ],
            ),
            const SizedBox(height: 24),
            // Details Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 24),
                  _buildDetailRow('Total Hours', hoursText),
                  const SizedBox(height: 20),
                  _buildDetailRow('Manager', data['manager'] ?? 'Sarah Mitchell'),
                  const SizedBox(height: 20),
                  _buildDetailRow('Shift', 'General Shift (${AppSession().shiftStartTime}–${AppSession().shiftEndTime})'),
                  const SizedBox(height: 20),
                  _buildDetailRow('Location', data['location'] ?? 'Headquarters'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Request Correction Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeAttendanceCorrectionScreen(date: date)));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFFDF5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Request Correction', style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox(String label, String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
