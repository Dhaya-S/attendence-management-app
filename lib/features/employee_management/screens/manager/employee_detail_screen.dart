import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/widgets/notification_action.dart';
import 'package:attendance_app/screens/employee/attendance_history_screen.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/file_export_helper.dart';

class EmployeeDetailScreen extends StatelessWidget {
  final String employeeId;
  final Map<String, dynamic> employeeData;

  const EmployeeDetailScreen({
    super.key,
    required this.employeeId,
    required this.employeeData,
  });

  @override
  Widget build(BuildContext context) {
    final name = employeeData['name'] ??
        employeeData['email']?.toString().split('@')[0] ??
        'Employee';
    final role = employeeData['designation'] ?? 'Employee';
    final empId = employeeData['employeeId'] ??
        'EMP-${employeeId.substring(0, 4).toUpperCase()}';
    final imageUrl = employeeData['profileImageUrl'] as String?;
    // Attendance stored under Firebase Auth UID, not email
    final authUid = employeeData['uid'] as String? ?? employeeId;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Employee Details',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          NotificationAction(isManager: true),
          PopupMenuButton<String>(
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: const Icon(Icons.more_horiz,
                  color: AppTheme.textSecondary, size: 22),
            ),
            onSelected: (value) {
              if (value == 'remove') {
                _handleRemoveEmployee(context, employeeData['email'] ?? employeeId, name.toString());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    const Icon(Icons.person_remove_outlined, color: AppTheme.danger, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Remove Employee',
                      style: TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.userAttendanceCol(employeeData['email'] ?? employeeId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.danger, size: 40),
                    const SizedBox(height: 16),
                    Text('Error loading stats', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(), textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final records = snapshot.data!.docs;
          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final todayRecord = records.any((d) => d.id == todayStr) 
              ? records.firstWhere((d) => d.id == todayStr).data() as Map<String, dynamic>
              : null;

          // Stats Calculations
          final now = DateTime.now();
          final currentMonthRecords = records.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final dateTs = data['date'] as Timestamp?;
            if (dateTs == null) return false;
            final date = dateTs.toDate();
            return date.month == now.month && date.year == now.year;
          }).toList();

          int presentCount = currentMonthRecords.length;
          int lateCount = 0;
          double totalHours = 0;
          
          for (var doc in currentMonthRecords) {
            final data = doc.data() as Map<String, dynamic>;
            final checkInTs = data['checkIn'] as Timestamp?;
            final checkOutTs = data['checkOut'] as Timestamp?;
            
            if (checkInTs != null) {
              final checkIn = checkInTs.toDate();
              final sParts = AppSession().shiftStartTime.split(':');
              final threshold = DateTime(checkIn.year, checkIn.month, checkIn.day, 
                  int.parse(sParts[0]), int.parse(sParts[1]))
                  .add(Duration(minutes: AppSession().gracePeriod));
              if (checkIn.isAfter(threshold)) lateCount++;
              
              if (checkOutTs != null) {
                totalHours += checkOutTs.toDate().difference(checkIn).inMinutes / 60.0;
              }
            }
          }

          // Find employee joining date (earliest check-in)
          DateTime joiningDate = now;
          if (records.isNotEmpty) {
            final sortedIds = records.map((d) => d.id).toList()..sort();
            joiningDate = DateFormat('yyyy-MM-dd').parse(sortedIds.first);
          }

          // Total work days (Mon-Fri) from start of month or joining date (whichever is later)
          int startDay = 1;
          if (joiningDate.year == now.year && joiningDate.month == now.month) {
            startDay = joiningDate.day;
          }

          int totalWorkDaysInMonth = 0;
          for (int i = startDay; i <= now.day; i++) {
            final d = DateTime(now.year, now.month, i);
            if (d.weekday <= 5) totalWorkDaysInMonth++;
          }

          final attendanceRate = totalWorkDaysInMonth > 0 
              ? (presentCount / totalWorkDaysInMonth * 100).clamp(0.0, 100.0).toInt()
              : 0;
          final onTimeRate = presentCount > 0 ? ((presentCount - lateCount) / presentCount * 100).toInt() : 0;

          // Current Status
          String statusText = 'Absent';
          Color statusColor = AppTheme.danger;
          String? currentWorkMode = todayRecord?['workMode'] as String?;

          if (todayRecord != null) {
            statusText = 'Present';
            statusColor = AppTheme.success;
            final checkInTs = todayRecord['checkIn'] as Timestamp?;
            if (checkInTs != null) {
              final checkIn = checkInTs.toDate();
              final sParts = AppSession().shiftStartTime.split(':');
              final lateThreshold = DateTime(checkIn.year, checkIn.month, checkIn.day,
                  int.parse(sParts[0]), int.parse(sParts[1]))
                  .add(Duration(minutes: AppSession().gracePeriod));
              if (checkIn.isAfter(lateThreshold)) {
                statusText = 'Late';
                statusColor = AppTheme.warning;
              }
            }
            if (todayRecord['status'] == 'checked_out') {
              statusText = 'Checked Out';
            }
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profile Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 3),
                        ),
                        child: ClipOval(
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? (imageUrl.startsWith('http')
                                  ? Image.network(imageUrl, fit: BoxFit.cover)
                                  : Image.memory(base64Decode(imageUrl), fit: BoxFit.cover))
                              : Container(
                                  color: AppTheme.primarySurface,
                                  child: const Icon(Icons.person, color: AppTheme.primary, size: 40),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        name.toString(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role,
                        style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                statusText,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                              ),
                              if (currentWorkMode == 'wfh') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5C5CFF).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.home_work_rounded, size: 10, color: Color(0xFF5C5CFF)),
                                      SizedBox(width: 4),
                                      Text(
                                        'WFH',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF5C5CFF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• $empId',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Attendance Summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Attendance Summary',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$attendanceRate% Rate',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: attendanceRate / 100,
                          backgroundColor: AppTheme.primarySurface,
                          valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _summaryItem('Days Present', '$presentCount'),
                          _summaryItem('Working Days', '$totalWorkDaysInMonth'),
                          _summaryItem('Late Days', lateCount.toString().padLeft(2, '0')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Performance Stats
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Performance Stats',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      _performanceRow(Icons.timer_outlined, 'Total Work Hours',
                          '${totalHours.toInt()}h', AppTheme.textPrimary),
                      const SizedBox(height: 14),
                      _performanceRow(Icons.check_circle_outline, 'On-time Rate',
                          '$onTimeRate%', onTimeRate >= 90 ? AppTheme.success : AppTheme.warning),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Personal Information
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal Information',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      _infoDetailRow(Icons.email_outlined, 'Personal Email', employeeData['personalEmail'] ?? 'Not provided'),
                      const SizedBox(height: 12),
                      _infoDetailRow(Icons.calendar_today_outlined, 'Joining Date', employeeData['joiningDate'] ?? 'Not provided'),
                      const SizedBox(height: 12),
                      _infoDetailRow(Icons.phone_outlined, 'Phone', employeeData['phone'] ?? 'Not provided'),
                      const SizedBox(height: 12),
                      _infoDetailRow(Icons.location_on_outlined, 'Address', employeeData['address'] ?? 'Not provided'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Full History View
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AttendanceHistoryScreen(
                            userId: employeeData['email'] ?? employeeId,
                            userName: name.toString(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history_rounded, size: 20),
                    label: const Text('View Full Attendance History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Download Monthly Report
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadMonthlyReport(context),
                    icon: const Icon(Icons.download_for_offline_outlined, size: 20, color: AppTheme.primary),
                    label: const Text('Download Monthly Report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Leave History
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave History',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 14),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirestoreService.userLeaveRequestsCol(employeeData['email'] ?? employeeId)
                            .orderBy('requestDate', descending: true)
                            .limit(5)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Text(
                              'No leave history',
                              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                            );
                          }

                          return Column(
                            children: snapshot.data!.docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return _leaveHistoryItem(data);
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _performanceRow(
      IconData icon, String label, String value, Color valueColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _leaveHistoryItem(Map<String, dynamic> data) {
    final reason = data['reason'] ?? 'Leave';
    final status = data['status'] ?? 'pending';
    final from = data['fromDate'] as Timestamp?;
    final to = data['toDate'] as Timestamp?;

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = AppTheme.success;
        break;
      case 'rejected':
        statusColor = AppTheme.danger;
        break;
      default:
        statusColor = AppTheme.warning;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (from != null && to != null)
                  Text(
                    '${DateFormat('MMM dd').format(from.toDate())} - ${DateFormat('MMM dd, yyyy').format(to.toDate())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRemoveEmployee(BuildContext context, String email, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
        title: const Text('Remove Employee'),
        content: Text('Are you sure you want to remove $name? This will delete their profile and login access from this company.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );

      try {
        final normalizedEmail = email.toLowerCase();
        
        // 1. Delete from approved_users (removes login/company link)
        await FirestoreService.approvedUserDoc(normalizedEmail).delete();
        
        // 2. Delete from company's users subcollection
        await FirestoreService.employeeDoc(normalizedEmail).delete();

        if (context.mounted) {
          Navigator.pop(context); // Pop loading
          Navigator.pop(context); // Pop Detail Screen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name has been removed'),
              backgroundColor: AppTheme.textPrimary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Pop loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove employee: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  Widget _infoDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _downloadMonthlyReport(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Month for Report',
    );

    if (picked == null) return;

    final monthStr = DateFormat('yyyy-MM').format(picked);
    final email = (employeeData['email'] ?? '').toString().toLowerCase();
    final name = employeeData['name'] ??
        employeeData['email']?.toString().split('@')[0] ??
        'Employee';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      final snapshot = await FirestoreService.usersCol
          .doc(email)
          .collection('attendance')
          .get();

      // Map records by date
      Map<String, Map<String, dynamic>> attendanceMap = {};
      for (var doc in snapshot.docs) {
        if (doc.id.startsWith(monthStr)) {
          attendanceMap[doc.id] = doc.data();
        }
      }

      List<List<dynamic>> rows = [];
      rows.add([
        "Date",
        "Employee Name",
        "Email",
        "Check-In",
        "Check-Out",
        "Total Hours",
        "Status",
        "Work Mode",
        "Late"
      ]);

      // Calculate days in the selected month
      final daysInMonth = DateTime(picked.year, picked.month + 1, 0).day;
      final now = DateTime.now();

      for (int day = 1; day <= daysInMonth; day++) {
        final dateObj = DateTime(picked.year, picked.month, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(dateObj);
        
        if (dateObj.isAfter(now)) continue;

        final record = attendanceMap[dateStr];
        final dateForExcel = "'$dateStr";

        if (record != null) {
          final checkInTs = record['checkIn'] as Timestamp?;
          final checkOutTs = record['checkOut'] as Timestamp?;
          final workMode = record['workMode'] ?? 'office';

          String lateStatus = '--';
          if (checkInTs != null) {
            final checkIn = checkInTs.toDate();
            final sParts = AppSession().shiftStartTime.split(':');
            final targetIn = DateTime(checkIn.year, checkIn.month, checkIn.day, 
                int.parse(sParts[0]), int.parse(sParts[1]));
            final lateThreshold = targetIn.add(Duration(minutes: AppSession().gracePeriod));
            if (checkIn.isAfter(lateThreshold)) {
              lateStatus = 'LATE';
            } else {
              lateStatus = 'ON TIME';
            }
          }

          rows.add([
            dateForExcel,
            name,
            email,
            checkInTs != null ? DateFormat('HH:mm:ss').format(checkInTs.toDate()) : '--',
            checkOutTs != null ? DateFormat('HH:mm:ss').format(checkOutTs.toDate()) : '--',
            record['totalHours'] ?? '0.0',
            record['status']?.toString().toUpperCase() ?? 'PRESENT',
            workMode.toString().toUpperCase(),
            lateStatus
          ]);
        } else {
          rows.add([
            dateForExcel,
            name,
            email,
            '--',
            '--',
            '0.0',
            'ABSENT',
            '--',
            '--'
          ]);
        }
      }

      String csv = _mapToCsv(rows);
      final fileName = "attendance_${name.toString().replaceAll(' ', '_')}_${monthStr}.csv";
      await saveAndShareFile(csv, fileName);

      if (context.mounted) {
        Navigator.pop(context); // Pop loading
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  String _mapToCsv(List<List<dynamic>> rows) {
    String csv = rows.map((row) {
      return row.map((cell) {
        final String cellStr = cell?.toString() ?? '';
        if (cellStr.contains(',') || cellStr.contains('\n') || cellStr.contains('"')) {
          return '"${cellStr.replaceAll('"', '""')}"';
        }
        return cellStr;
      }).join(',');
    }).join('\n');
    return '\uFEFF$csv';
  }
}
