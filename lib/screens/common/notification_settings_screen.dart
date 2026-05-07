import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _attendanceAlerts = true;
  bool _leaveAlerts = true;
  bool _systemAlerts = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final querySnapshot = await FirestoreService.usersCol
          .where('email', isEqualTo: user.email ?? '')
          .limit(1)
          .get();
      
      DocumentSnapshot? doc;
      if (querySnapshot.docs.isNotEmpty) {
        doc = querySnapshot.docs.first;
      } else {
        doc = await FirestoreService.userDocByEmail(user.email ?? '').get();
      }

      if (doc != null && doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _attendanceAlerts = data['notif_attendance'] ?? true;
          _leaveAlerts = data['notif_leave'] ?? true;
          _systemAlerts = data['notif_system'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSetting(String key, bool val) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final querySnapshot = await FirestoreService.usersCol
          .where('email', isEqualTo: user.email ?? '')
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({key: val});
      } else {
        await FirestoreService.userDocByEmail(user.email ?? '').update({key: val});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notification Settings', style: AppTheme.h3),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PREFERENCES', style: AppTheme.label.copyWith(fontSize: 10, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Container(
              decoration: AppTheme.cardDecoration(),
              child: Column(
                children: [
                  _toggleItem('Attendance Alerts', 'Get notified on check-in/out', _attendanceAlerts, (v) {
                    setState(() => _attendanceAlerts = v);
                    _updateSetting('notif_attendance', v);
                  }),
                  const Divider(indent: 20, endIndent: 20),
                  _toggleItem('Leave Updates', 'Approvals and rejections', _leaveAlerts, (v) {
                    setState(() => _leaveAlerts = v);
                    _updateSetting('notif_leave', v);
                  }),
                  const Divider(indent: 20, endIndent: 20),
                  _toggleItem('System Announcements', 'Company-wide updates', _systemAlerts, (v) {
                    setState(() => _systemAlerts = v);
                    _updateSetting('notif_system', v);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleItem(String title, String sub, bool val, Function(bool) onChanged) {
    return SwitchListTile(
      value: val,
      onChanged: onChanged,
      title: Text(title, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      subtitle: Text(sub, style: AppTheme.label.copyWith(fontSize: 10)),
      activeColor: AppTheme.primary,
    );
  }
}
