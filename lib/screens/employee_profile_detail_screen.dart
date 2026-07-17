import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class EmployeeProfileDetailScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String email;

  const EmployeeProfileDetailScreen({
    super.key,
    required this.userData,
    required this.email,
  });

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Orange
      const Color(0xFF10B981), // Green
      const Color(0xFFEF4444), // Red
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEC4899), // Pink
    ];
    int hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  Future<Map<String, int>> _fetchMonthlyMetrics() async {
    final now = DateTime.now();
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    int present = 0;
    int leaveTaken = 0;

    // Fetch attendance for this month
    final attendanceSnap = await FirestoreService.userAttendanceCol(email).get();
    for (var doc in attendanceSnap.docs) {
      if (doc.id.startsWith(monthStr)) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] == 'present' || data['status'] == 'late') {
          present++;
        }
      }
    }

    // Fetch approved leaves overlapping this month
    final leavesSnap = await FirestoreService.userLeaveRequestsCol(email)
        .where('status', isEqualTo: 'approved')
        .get();
        
    for (var doc in leavesSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final startTs = data['startDate'] as Timestamp?;
      final endTs = data['endDate'] as Timestamp?;
      if (startTs != null && endTs != null) {
        DateTime current = startTs.toDate();
        final end = endTs.toDate();
        while (current.isBefore(end.add(const Duration(days: 1)))) {
          if (current.year == now.year && current.month == now.month) {
            // Count week days only (assuming mon-fri, but let's just count all for simplicity unless specified)
            leaveTaken++;
          }
          current = current.add(const Duration(days: 1));
        }
      }
    }

    return {'present': present, 'leaveTaken': leaveTaken};
  }

  @override
  Widget build(BuildContext context) {
    final name = userData['name'] ?? 'Unknown';
    final role = userData['role'] ?? 'Employee';
    final department = userData['department'] ?? 'Unknown';
    final phone = userData['phone'] ?? 'Not provided';
    final dbStatus = (userData['status'] ?? 'active').toString().toLowerCase();

    String statusLabel = 'Active';
    if (dbStatus == 'on leave') statusLabel = 'On Leave';
    if (dbStatus == 'inactive' || dbStatus == 'pending') statusLabel = 'Inactive';

    Color statusBg;
    Color statusText;
    switch (statusLabel) {
      case 'On Leave':
        statusBg = const Color(0xFFF3E8FF).withOpacity(0.5);
        statusText = const Color(0xFF7C3AED);
        break;
      case 'Inactive':
        statusBg = const Color(0xFFF3F4F6);
        statusText = const Color(0xFF6B7280);
        break;
      case 'Active':
      default:
        statusBg = const Color(0xFFD1FAE5).withOpacity(0.5);
        statusText = const Color(0xFF059669);
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6F9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Employee Profile",
          style: TextStyle(color: Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileBanner(name, role, statusLabel, statusBg, statusText),
            const SizedBox(height: 16),
            _buildContactInfoCard(department, email, phone, statusLabel),
            const SizedBox(height: 16),
            _buildThisMonthCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileBanner(String name, String role, String statusLabel, Color statusBg, Color statusText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: _getAvatarColor(name),
            child: Text(
              _getInitials(name),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const SizedBox(height: 4),
          Text(role, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusText.withOpacity(0.2)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusText,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard(String dept, String email, String phone, String status) {
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
          const Text('CONTACT INFO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 20),
          _buildInfoRow('Department', dept),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('Email', email),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('Phone', phone),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('Status', status),
        ],
      ),
    );
  }

  Widget _buildThisMonthCard() {
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
      child: FutureBuilder<Map<String, int>>(
        future: _fetchMonthlyMetrics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ));
          }

          final present = snapshot.data?['present'] ?? 0;
          final leaveTaken = snapshot.data?['leaveTaken'] ?? 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('THIS MONTH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
              const SizedBox(height: 20),
              _buildInfoRow('Present', '$present days'),
              const Divider(height: 32, color: Color(0xFFF3F4F6)),
              _buildInfoRow('Leave Taken', '$leaveTaken days'),
            ],
          );
        }
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
      ],
    );
  }
}
