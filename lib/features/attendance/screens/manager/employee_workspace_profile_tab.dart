import 'package:flutter/material.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EmployeeWorkspaceProfileTab extends StatelessWidget {
  final Map<String, dynamic> employeeData;

  const EmployeeWorkspaceProfileTab({super.key, required this.employeeData});

  @override
  Widget build(BuildContext context) {
    // Extracting data or using placeholders
    final employeeId = employeeData['employeeId'] ?? 'EMP-2042';
    final email = employeeData['email'] ?? 'employee@company.com';
    final phone = employeeData['phone'] ?? '+91 98765 00001';
    
    String joinedDate = 'Sep 2023';
    if (employeeData['joinedDate'] != null) {
      if (employeeData['joinedDate'] is Timestamp) {
        joinedDate = DateFormat('MMM yyyy').format((employeeData['joinedDate'] as Timestamp).toDate());
      } else {
        joinedDate = employeeData['joinedDate'].toString();
      }
    }

    final department = employeeData['department'] ?? 'Design';
    final role = employeeData['role'] ?? 'Product Designer';
    final manager = employeeData['managerName'] ?? 'Rahul Mehta';
    final empType = employeeData['employmentType'] ?? 'Full-Time Permanent';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'BASIC INFORMATION',
            children: [
              _buildInfoRow('Employee ID', employeeId),
              _buildDivider(),
              _buildInfoRow('Official Email', email),
              _buildDivider(),
              _buildInfoRow('Official Phone', phone),
              _buildDivider(),
              _buildInfoRow('Joined', joinedDate),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'WORK INFORMATION',
            children: [
              _buildInfoRow('Department', department),
              _buildDivider(),
              _buildInfoRow('Role', role),
              _buildDivider(),
              _buildInfoRow('Reporting Manager', manager),
              _buildDivider(),
              FutureBuilder<String>(
                future: FirestoreService.shiftLabelForUser(
                    Map<String, dynamic>.from(employeeData)),
                builder: (context, snap) =>
                    _buildInfoRow('Shift', snap.data ?? 'Loading…'),
              ),
              _buildDivider(),
              _buildInfoRow('Employee Type', empType),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'PERSONAL INFORMATION',
            children: [
               _buildInfoRow('Date of Birth', '15 Aug 1995'),
               _buildDivider(),
               _buildInfoRow('Blood Group', 'O+'),
               _buildDivider(),
               _buildInfoRow('Emergency Contact', '+91 98765 43210'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 20, endIndent: 20);
  }
}
