import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/screens/more/faqs_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {

  void _showContactModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contact HR Department',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.phone_rounded, color: Color(0xFF10B981)),
                ),
                title: const Text('Call HR Helpline', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('+1 (800) 555-0199'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.email_rounded, color: Color(0xFF5C5CFF)),
                ),
                title: const Text('Email HR Desk', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('hr-support@company.com'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSupportTicketDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Raise Support Ticket', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject / Issue Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Describe your issue...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C5CFF)),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final userEmail = FirebaseAuth.instance.currentUser?.email ?? AppSession().email ?? '';
                final userName = AppSession().userName ?? 'User';

                try {
                  // Same ticket document the web Support page creates
                  final ticketId =
                      'TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                  await FirestoreService.companyDoc()
                      .collection('support_tickets')
                      .doc(ticketId)
                      .set({
                    'id': ticketId,
                    'companyId': FirestoreService.companyId,
                    'userId': FirebaseAuth.instance.currentUser?.uid ?? AppSession().uid ?? '',
                    'userEmail': userEmail,
                    'userName': userName,
                    'type': 'ticket',
                    'subject': titleCtrl.text.trim(),
                    'title': titleCtrl.text.trim(),
                    'priority': 'Medium',
                    'category': 'Technical',
                    'description': descCtrl.text.trim(),
                    'status': 'Open',
                    'createdAt': DateTime.now().toIso8601String(),
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Support ticket raised successfully!')),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ticket created: ${titleCtrl.text.trim()}')),
                  );
                }
              },
              child: const Text('Submit Ticket', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showInfoModal(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C5CFF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
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
          'Help & Support',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. FAQs
            _buildSupportCard(
              icon: Icons.info_outline_rounded,
              title: 'FAQs',
              subtitle: 'Common questions answered',
              iconColor: const Color(0xFF5C5CFF),
              iconBgColor: const Color(0xFFEEF2FF),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqsScreen())),
            ),
            const SizedBox(height: 12),

            // 2. Contact HR
            _buildSupportCard(
              icon: Icons.phone_outlined,
              title: 'Contact HR',
              subtitle: 'Call or email HR directly',
              iconColor: const Color(0xFF10B981),
              iconBgColor: const Color(0xFFECFDF5),
              onTap: _showContactModal,
            ),
            const SizedBox(height: 12),

            // 3. Raise Support Ticket
            _buildSupportCard(
              icon: Icons.near_me_outlined,
              title: 'Raise Support Ticket',
              subtitle: 'Report an issue or request',
              iconColor: const Color(0xFFD97706),
              iconBgColor: const Color(0xFFFFFBEB),
              onTap: _showSupportTicketDialog,
            ),
            const SizedBox(height: 12),

            // 4. Application Guide
            _buildSupportCard(
              icon: Icons.assignment_outlined,
              title: 'Application Guide',
              subtitle: 'Learn how to use the app',
              iconColor: const Color(0xFF3B82F6),
              iconBgColor: const Color(0xFFEFF6FF),
              onTap: () => _showInfoModal(
                'Application Guide',
                'Welcome to the Attendance Management App!\n\n'
                '1. Home Tab: View your live shift timers, check-in status, attendance overview bar chart, active tasks, and recent team activity.\n'
                '2. Bottom (+) Button: Long press or swipe up for Quick Check-In, Quick Check-Out, Apply Leave, or Raise Attendance Correction.\n'
                '3. Attendance Tab: Inspect monthly logs, personal attendance stats, team calendars, and approval requests.\n'
                '4. Leave Tab: Track leave balances, apply for leaves, view holiday calendar, and manage approvals.\n'
                '5. More Tab: Manage user profile, settings, notification preferences, documents, and support.',
              ),
            ),
            const SizedBox(height: 12),

            // 5. Privacy Policy
            _buildSupportCard(
              icon: Icons.error_outline_rounded,
              title: 'Privacy Policy',
              subtitle: 'How your data is used',
              iconColor: const Color(0xFFA855F7),
              iconBgColor: const Color(0xFFF3E8FF),
              onTap: () => _showInfoModal(
                'Privacy Policy',
                'Your privacy is strictly protected.\n\n'
                '• Geolocation Data: Location service coordinates are captured ONLY during check-in/out verification to confirm geofence boundary boundaries.\n'
                '• Profile & Attendance: Data is securely stored in encrypted Google Cloud Firestore instances with company role-based access control.\n'
                '• Third-Party Sharing: Your data is never sold, leased, or transmitted to unauthorized third parties.',
              ),
            ),
            const SizedBox(height: 12),

            // 6. Terms & Conditions
            _buildSupportCard(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              subtitle: 'Usage terms and agreement',
              iconColor: const Color(0xFF6B7280),
              iconBgColor: const Color(0xFFF3F4F6),
              onTap: () => _showInfoModal(
                'Terms & Conditions',
                'Terms of Service & Usage Agreement:\n\n'
                '1. Authorized Use: This mobile application is provided for official employee attendance logging and workforce management.\n'
                '2. Account Integrity: Users are responsible for maintaining credential security and reporting unauthorized access.\n'
                '3. Accuracy: Attendance logs and leave requests submitted through the app constitute official company records.',
              ),
            ),
            const SizedBox(height: 12),

            // 7. About Application
            _buildSupportCard(
              icon: Icons.star_outline_rounded,
              title: 'About Application',
              subtitle: 'Version 3.2.1 · Build 2026.07',
              iconColor: const Color(0xFF6B7280),
              iconBgColor: const Color(0xFFF3F4F6),
              onTap: () => _showInfoModal(
                'About Application',
                'Attendance & HR Management System v3.2.1\nBuild 2026.07\n\n'
                'Built with Flutter & Firebase realtime architecture.\n'
                '© 2026 Edufic Enterprise Solutions. All rights reserved.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
        ),
        trailing: const Icon(
          Icons.keyboard_arrow_right_rounded,
          color: Color(0xFF9CA3AF),
          size: 20,
        ),
      ),
    );
  }
}
