import 'package:flutter/material.dart';

class OrgPoliciesTab extends StatelessWidget {
  const OrgPoliciesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F6F9),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPolicyCard(
              title: 'Attendance Policies',
              icon: Icons.access_time_rounded,
              iconBgColor: const Color(0xFFEEF2FF),
              iconColor: const Color(0xFF5C5CFF),
              bullets: [
                'Standard shift: 9AM–6PM',
                'Grace period: 15 minutes',
                'Minimum hours: 8.5 hrs/day',
                'Overtime: Pre-approved only',
              ],
            ),
            const SizedBox(height: 16),
            _buildPolicyCard(
              title: 'Leave Policies',
              icon: Icons.calendar_today_rounded,
              iconBgColor: const Color(0xFFF3E8FF).withOpacity(0.5),
              iconColor: const Color(0xFFC084FC),
              bullets: [
                'Annual leave: 18 days/year',
                'Sick leave: 7 days/year',
                'Comp off: Within 30 days',
                'Encashment: Up to 10 days',
              ],
            ),
            const SizedBox(height: 16),
            _buildPolicyCard(
              title: 'Documents',
              icon: Icons.insert_drive_file_outlined,
              iconBgColor: const Color(0xFFEEF2FF),
              iconColor: const Color(0xFF60A5FA),
              bullets: [
                'Offer letter template',
                'Appointment letter format',
                'NDA template',
                'Appraisal form',
              ],
            ),
            const SizedBox(height: 16),
            _buildPolicyCard(
              title: 'Policy Assignments',
              icon: Icons.assignment_outlined,
              iconBgColor: const Color(0xFFECFDF5),
              iconColor: const Color(0xFF10B981),
              bullets: [
                'Engineering: Policy Set A',
                'Design: Policy Set A',
                'Sales: Policy Set B',
                'HR: Policy Set C',
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyCard({
    required String title,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required List<String> bullets,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                      const SizedBox(height: 2),
                      const Text('Read only', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('View Only', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...bullets.map((bullet) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF5C5CFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(bullet, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
