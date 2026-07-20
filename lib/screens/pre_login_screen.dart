import 'package:flutter/material.dart';
import 'package:attendance_app/screens/login_screen.dart';
import 'package:attendance_app/screens/register_screen.dart';
import 'package:attendance_app/theme/app_theme.dart';

class PreLoginScreen extends StatelessWidget {
  const PreLoginScreen({super.key});

  void _openLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _openOrganizationSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _openLogin(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5C5CFF),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE7E7EC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TODAY'S OVERVIEW",
                      style: AppTheme.label.copyWith(
                        fontSize: 10,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        Expanded(
                          child: _OverviewStatCard(
                            value: '124',
                            label: 'Present',
                            valueColor: Color(0xFF22C55E),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _OverviewStatCard(
                            value: '12',
                            label: 'On Leave',
                            valueColor: Color(0xFFF59E0B),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _OverviewStatCard(
                            value: '4',
                            label: 'Absent',
                            valueColor: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(
                    child: _FeatureTile(
                      iconPath: 'assets/attendance.png',
                      label: 'Attendance',
                      iconColor: Color(0xFF5C5CFF),
                      backgroundColor: Color(0xFFEEEDFF),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _FeatureTile(
                      iconPath: 'assets/leave.png',
                      label: 'Leave',
                      iconColor: Color(0xFF009EE6),
                      backgroundColor: Color(0xFFE5F5FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: _FeatureTile(
                      iconPath: 'assets/teams.png',
                      label: 'Teams',
                      iconColor: Color(0xFF8A5CF5),
                      backgroundColor: Color(0xFFF0EBFF),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _FeatureTile(
                      iconPath: 'assets/organization.png',
                      label: 'Organization',
                      iconColor: Color(0xFF15B27A),
                      backgroundColor: Color(0xFFDCFCE7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const Text(
                'Manage your workforce\nin one place',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Track attendance, manage leave, stay connected with\nyour team.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF6B7280),
                ),
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 327,
                  height: 51,
                  child: ElevatedButton(
                    onPressed: () => _openOrganizationSetup(context),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF5C5CFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: SizedBox(
                  width: 327,
                  height: 51,
                  child: OutlinedButton(
                    onPressed: () => _openLogin(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1F2937),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _OverviewStatCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String iconPath;
  final String label;
  final Color iconColor;
  final Color backgroundColor;

  const _FeatureTile({
    required this.iconPath,
    required this.label,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              iconPath,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
