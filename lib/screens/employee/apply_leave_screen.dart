import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/notification_helper.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  DateTime? fromDate;
  DateTime? toDate;
  String selectedType = 'Annual Leave';
  final TextEditingController reasonController = TextEditingController();
  bool isLoading = false;

  final List<String> leaveTypes = [
    'Annual Leave',
    'Sick Leave',
    'Casual Leave',
    'Comp Off'
  ];

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (fromDate ?? DateTime.now())
          : (toDate ?? fromDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF5C5CFF)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
          if (toDate != null && toDate!.isBefore(fromDate!)) {
            toDate = fromDate;
          }
        } else {
          toDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (fromDate == null ||
        toDate == null ||
        reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userQuery = await FirestoreService.usersCol
          .where('email', isEqualTo: user?.email ?? '')
          .limit(1)
          .get();
      final userData =
          userQuery.docs.isNotEmpty ? userQuery.docs.first.data() : {};
      final userName =
          userData['name'] ?? user?.email?.split('@')[0] ?? 'Employee';
      final department = userData['department'] ?? 'General';

      int calculateWorkingDays(DateTime from, DateTime to) {
        final start = DateTime(from.year, from.month, from.day);
        final end = DateTime(to.year, to.month, to.day);
        int count = 0;
        DateTime current = start;
        while (!current.isAfter(end)) {
          if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
            count++;
          }
          current = current.add(const Duration(days: 1));
        }
        return count;
      }

      final diff = calculateWorkingDays(fromDate!, toDate!);
      final rawSenderRole =
          (userData['role'] as String?)?.toLowerCase().trim() ?? 'employee';
      final senderRole = (rawSenderRole == 'super_admin' ||
              rawSenderRole == 'superadmin' ||
              rawSenderRole == 'admin' ||
              rawSenderRole == 'hr_admin' ||
              rawSenderRole == 'hradmin')
          ? 'hr_admin'
          : rawSenderRole == 'manager'
              ? 'manager'
              : 'employee';

      await FirestoreService.submitLeaveRequest(data: {
        'companyId': FirestoreService.companyId,
        'userId': user!.uid,
        'userEmail': user.email,
        'applicantEmail': user.email,
        'userName': userName,
        'applicantName': userName,
        'department': department,
        'leaveType': selectedType,
        'type': selectedType,
        'fromDate': fromDate,
        'toDate': toDate,
        'from': DateFormat('yyyy-MM-dd').format(fromDate!),
        'to': DateFormat('yyyy-MM-dd').format(toDate!),
        'durationInDays': diff,
        'days': diff,
        'reason': reasonController.text.trim(),
        'status': 'Pending',
        'senderRole': senderRole,
      });

      // Notify the manager and/or admin based on role
      final dateRangeStr = diff == 1
          ? 'on ${DateFormat('MMM dd, yyyy').format(fromDate!)}'
          : 'from ${DateFormat('MMM dd').format(fromDate!)} to ${DateFormat('MMM dd').format(toDate!)} ($diff days)';
      final title = 'New Leave Request 📝';
      final body = '$userName applied for $selectedType $dateRangeStr.';
      final extraData = {'employeeEmail': user.email};

      if (senderRole == 'hr_admin') {
        await NotificationHelper.notifyAdmin(
            title: title,
            body: body,
            type: 'new_leave_request',
            extraData: extraData);
      } else if (senderRole == 'manager') {
        await NotificationHelper.notifyAdmin(
            title: title,
            body: body,
            type: 'new_leave_request',
            extraData: extraData);
      } else {
        await NotificationHelper.notifyManager(
            title: title,
            body: body,
            type: 'new_leave_request',
            extraData: extraData);
        await NotificationHelper.notifyAdmin(
            title: title,
            body: body,
            type: 'new_leave_request',
            extraData: extraData);
      }

      if (mounted) {
        Future.delayed(Duration.zero, () {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Request submitted successfully!'),
                backgroundColor: AppTheme.success));
          }
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if fields are filled to change the Submit button style or state
    final isFormValid = fromDate != null &&
        toDate != null &&
        reasonController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FA), // Soft grey background matching mock
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leadingWidth: 48,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF4B5563), size: 16),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Apply Leave',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.015),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Leave Type',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: leaveTypes.map((type) {
                        final isSelected = selectedType == type;
                        return GestureDetector(
                          onTap: () => setState(() => selectedType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF5C5CFF)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('From',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1F2937))),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _pickDate(context, true),
                                child: Container(
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFE5E7EB)),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    fromDate == null
                                        ? ''
                                        : DateFormat('dd-MM-yyyy')
                                            .format(fromDate!),
                                    style: const TextStyle(
                                        fontSize: 14, color: Color(0xFF1F2937)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('To',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1F2937))),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _pickDate(context, false),
                                child: Container(
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFE5E7EB)),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    toDate == null
                                        ? ''
                                        : DateFormat('dd-MM-yyyy')
                                            .format(toDate!),
                                    style: const TextStyle(
                                        fontSize: 14, color: Color(0xFF1F2937)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Reason',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937))),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: reasonController,
                        maxLines: 4,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1F2937)),
                        decoration: const InputDecoration(
                          hintText: 'Brief reason...',
                          hintStyle: TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 13.5),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 185, 187, 190),
                          foregroundColor:
                              const Color.fromARGB(255, 120, 126, 139),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5C5CFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
