import 'package:flutter/material.dart';
import 'package:attendance_app/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last updated: March 2025',
              style: TextStyle(fontSize: 12, color: AppTheme.textHint),
            ),
            const SizedBox(height: 20),
            _section('1. Information We Collect',
                'We collect information including your name, email, phone number, and attendance data to provide our services.'),
            _section('2. How We Use Your Information',
                'Your information is used to manage attendance, generate reports, and improve our services. We do not sell your data.'),
            _section('3. Data Storage',
                'All data is securely stored in Firebase cloud infrastructure with encryption at rest and in transit.'),
            _section('4. Data Retention',
                'We retain your data for the duration of your employment. You may request deletion at any time by contacting support.'),
            _section('5. Your Rights',
                'You have the right to access, modify, or delete your personal data. Contact your administrator or our support team for assistance.'),
            _section('6. Contact Us',
                'If you have any questions about this Privacy Policy, please contact us at support@attendancepro.com.'),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
