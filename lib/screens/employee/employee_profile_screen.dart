import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EmployeeProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final String statusBadge;
  final Color statusColor;

  const EmployeeProfileScreen({
    super.key,
    required this.user,
    required this.statusBadge,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final isLead = user['role'].toString().toLowerCase().contains('lead');
    final f = user['firstName'].toString().isNotEmpty ? user['firstName'].toString()[0] : '';
    final l = user['lastName'].toString().isNotEmpty ? user['lastName'].toString()[0] : '';
    final initials = '$f$l'.toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: const Text(
          'Employee Profile',
          style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded,
                color: Color(0xFF5C5CFF)),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF3F4F6), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: Color(0xFF5C5CFF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                if (isLead)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.star_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '${user['firstName']} ${user['lastName']}',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 6),
            Text(
              user['role'],
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLead)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.star_rounded,
                            color: Color(0xFFD97706), size: 14),
                        SizedBox(width: 4),
                        Text('Team Lead',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706))),
                      ],
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(statusBadge,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 48),
            _buildDetailRow('Department', user['department'] ?? 'Design'),
            const Divider(height: 32, color: Color(0xFFF3F4F6), thickness: 1),
            _buildDetailRow('Reporting Manager',
                user['reportingManager'] ?? 'Sarah Mitchell'),
            const Divider(height: 32, color: Color(0xFFF3F4F6), thickness: 1),
            _buildDetailRow(
                'Check-in',
                statusBadge == 'Present' ||
                        statusBadge == 'Late' ||
                        statusBadge == 'WFH'
                    ? '08:50 AM'
                    : '--:--'),
            const Divider(height: 32, color: Color(0xFFF3F4F6), thickness: 1),
            _buildDetailRow('Current Status', statusBadge),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280)),
        ),
        Text(
          value,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827)),
        ),
      ],
    );
  }
}
