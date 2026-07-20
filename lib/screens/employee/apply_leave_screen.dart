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
  String selectedType = 'Sick Leave';
  final TextEditingController reasonController = TextEditingController();
  bool isLoading = false;

  final List<String> leaveTypes = ['Sick Leave', 'Casual Leave', 'Paid Leave', 'Unpaid Leave'];

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => isFrom ? fromDate = picked : toDate = picked);
    }
  }

  Future<void> _submit() async {
    if (fromDate == null || toDate == null || reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userQuery = await FirestoreService.usersCol
          .where('email', isEqualTo: user?.email ?? '')
          .limit(1)
          .get();
      final userData = userQuery.docs.isNotEmpty ? userQuery.docs.first.data() : {};
      final userName = userData['name'] ?? user?.email?.split('@')[0] ?? 'Employee';
      final department = userData['department'] ?? 'General';
      final diff = toDate!.difference(fromDate!).inDays + 1;
      final senderRole = (userData['role'] as String?)?.toLowerCase() ?? 'employee';

      await FirestoreService.userLeaveRequestsCol(user!.email ?? '').add({
        'companyId': FirestoreService.companyId,
        'userId': user!.uid,
        'userEmail': user.email,
        'userName': userName,
        'department': department,
        'leaveType': selectedType,
        'fromDate': fromDate,
        'toDate': toDate,
        'durationInDays': diff,
        'reason': reasonController.text.trim(),
        'status': 'pending',
        'requestDate': FieldValue.serverTimestamp(),
        'senderRole': senderRole,
      });

      // 2. Notify the manager and/or admin based on role
      final dateRangeStr = diff == 1
          ? 'on ${DateFormat('MMM dd, yyyy').format(fromDate!)}'
          : 'from ${DateFormat('MMM dd').format(fromDate!)} to ${DateFormat('MMM dd').format(toDate!)} ($diff days)';
      final title = 'New Leave Request ðŸ“';
      final body = '$userName applied for $selectedType $dateRangeStr.';
      final extraData = {'employeeEmail': user.email};

      if (senderRole == 'admin') {
        await NotificationHelper.notifyAdmin(title: title, body: body, type: 'new_leave_request', extraData: extraData);
      } else if (senderRole == 'manager') {
        await NotificationHelper.notifyAdmin(title: title, body: body, type: 'new_leave_request', extraData: extraData);
      } else {
        await NotificationHelper.notifyManager(title: title, body: body, type: 'new_leave_request', extraData: extraData);
        await NotificationHelper.notifyAdmin(title: title, body: body, type: 'new_leave_request', extraData: extraData);
      }

      if (mounted) {
        Future.delayed(Duration.zero, () {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Request submitted successfully!'), backgroundColor: AppTheme.success));
          }
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('Apply for Leave', style: AppTheme.h3),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeSelector(),
              const SizedBox(height: 24),
              _buildDateSection(),
              const SizedBox(height: 24),
              _buildReasonField(),
              const SizedBox(height: 40),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LEAVE TYPE', style: AppTheme.label),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: AppTheme.cardDecoration(),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedType,
              isExpanded: true,
              items: leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: AppTheme.bodyMedium))).toList(),
              onChanged: (v) => setState(() => selectedType = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    return Row(
      children: [
        Expanded(child: _datePickerWidget('START DATE', fromDate, () => _pickDate(context, true))),
        const SizedBox(width: 16),
        Expanded(child: _datePickerWidget('END DATE', toDate, () => _pickDate(context, false))),
      ],
    );
  }

  Widget _datePickerWidget(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.label),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: AppTheme.cardDecoration(),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(date == null ? 'Select' : DateFormat('MMM dd, yyyy').format(date), style: AppTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REASON FOR LEAVE', style: AppTheme.label),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: AppTheme.cardDecoration(),
          child: TextField(
            controller: reasonController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter your reason here...',
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: isLoading ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: AppTheme.buttonRadius),
      ),
      child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Request'),
    );
  }
}
