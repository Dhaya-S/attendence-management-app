import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/notification_prefs.dart';

/// Notification settings — live. Every switch is saved the moment it is changed and is
/// applied immediately to the notification list, the bell badge and the on-device alerts.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late final String _email =
      (FirebaseAuth.instance.currentUser?.email ?? AppSession().email ?? '').toLowerCase();
  late final Stream<NotificationPrefs> _stream = NotificationPrefs.stream(_email);

  Future<void> _change(Map<String, bool> changes) async {
    try {
      await NotificationPrefs.set(_email, changes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Settings',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<NotificationPrefs>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final p = snap.data!;
          final anyOn = NotificationPrefs.allKeys.any(p.flag);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Choose which notifications you receive. Each change is saved instantly and applies right away.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5C5CFF), height: 1.4, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'WORK NOTIFICATIONS',
                  items: [
                    _switchItem('Leave Notifications', 'Approvals, rejections, leave updates',
                        p.flag(NotificationPrefs.leave), (v) => _change({NotificationPrefs.leave: v})),
                    _switchItem('Attendance Alerts', 'Check-in reminders, late marks, corrections',
                        p.flag(NotificationPrefs.attendance), (v) => _change({NotificationPrefs.attendance: v})),
                    _switchItem('Event Reminders', 'Company events, holidays, birthdays',
                        p.flag(NotificationPrefs.events), (v) => _change({NotificationPrefs.events: v})),
                    _switchItem('Task Status Updates', 'Assigned tasks, deadlines, completions',
                        p.flag(NotificationPrefs.tasks), (v) => _change({NotificationPrefs.tasks: v})),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'TEAM & COMMUNICATION',
                  items: [
                    _switchItem('Team Communication', 'Announcements, feed posts, mentions and comments',
                        p.flag(NotificationPrefs.team), (v) => _change({NotificationPrefs.team: v})),
                  ],
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => _change({for (final k in NotificationPrefs.allKeys) k: !anyOn}),
                  child: Text(
                    anyOn ? 'Turn Off All Notifications' : 'Turn On All Notifications',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> items}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...List.generate(items.length, (i) => Column(children: [
                if (i > 0) const Divider(height: 1, color: Color(0xFFF3F4F6)),
                items[i],
              ])),
        ],
      ),
    );
  }

  Widget _switchItem(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Switch.adaptive(value: value, activeColor: const Color(0xFF5C5CFF), onChanged: onChanged),
        ],
      ),
    );
  }
}
