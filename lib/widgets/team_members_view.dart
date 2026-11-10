import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/features/attendance/screens/manager/employee_workspace_screen.dart';

class TeamMembersView extends StatefulWidget {
  const TeamMembersView({super.key});

  @override
  State<TeamMembersView> createState() => _TeamMembersViewState();
}

class _TeamMembersViewState extends State<TeamMembersView> {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F6F9), // App background color
      child: Column(
        children: [
          _buildSummaryCards(),
          Expanded(child: _buildMembersList()),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryCard('3', 'Present', const Color(0xFF059669), const Color(0xFFECFDF5)),
          _buildSummaryCard('1', 'WFH', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
          _buildSummaryCard('1', 'Late', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
          _buildSummaryCard('1', 'Leave', const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String count, String label, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.employeesCol.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = (snapshot.data?.docs ?? [])
            .where((d) => FirestoreService.isDocInCurrentCompany(d))
            .toList();
        final currentUserEmail = (AppSession().email ?? '').toLowerCase();
        String myDept = (AppSession().userDepartment ?? '').toString().trim().toLowerCase();
        if (myDept.isEmpty) {
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final email = (data['email'] ?? doc.id).toString().toLowerCase();
            if (email == currentUserEmail) {
              myDept = (data['department'] ?? '').toString().trim().toLowerCase();
              break;
            }
          }
        }

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dept = (data['department'] ?? '').toString().trim().toLowerCase();
          if (myDept.isEmpty || AppSession().hasAdminAccess) return true;
          return dept == myDept;
        }).toList();

        final mockMembers = filteredDocs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return {
            'name': data['name'] ?? data['userName'] ?? 'Team Member',
            'role': data['designation'] ?? data['role'] ?? 'Member',
            'department': data['department'] ?? 'General',
            'status': 'Present',
            'time': 'In: 09:00 AM',
            ...data,
          };
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: mockMembers.length,
          itemBuilder: (context, index) {
            final data = mockMembers[index];
            final name = data['name'] as String;
            final role = data['role'] as String;
            final statusLabel = data['status'] as String;
            final timeStr = data['time'] as String;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmployeeWorkspaceScreen(employeeData: Map<String, dynamic>.from(data)),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
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
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _getAvatarColor(name),
                          child: Text(
                            _getInitials(name),
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (statusLabel == 'Present')
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                          const SizedBox(height: 4),
                          Text(role, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    ),
                    _buildStatusChip(statusLabel),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (status) {
      case 'Present':
        bgColor = const Color(0xFFECFDF5);
        textColor = const Color(0xFF059669);
        borderColor = const Color(0xFFA7F3D0);
        break;
      case 'WFH':
        bgColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF2563EB);
        borderColor = const Color(0xFFBFDBFE);
        break;
      case 'Late':
        bgColor = const Color(0xFFFFFBEB);
        textColor = const Color(0xFFD97706);
        borderColor = const Color(0xFFFDE68A);
        break;
      case 'On Leave':
        bgColor = const Color(0xFFF5F3FF);
        textColor = const Color(0xFF7C3AED);
        borderColor = const Color(0xFFDDD6FE);
        break;
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF6B7280);
        borderColor = const Color(0xFFE5E7EB);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
