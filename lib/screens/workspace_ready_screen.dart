import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/screens/admin_dashboard_screen.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class WorkspaceReadyScreen extends StatelessWidget {
  final String orgId;
  final String orgName;

  const WorkspaceReadyScreen({
    Key? key,
    required this.orgId,
    required this.orgName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Queries to fetch real-time counts for the metrics grid
    final membersStream = FirestoreService.orgMembersCol(orgId).snapshots();
    final deptsStream = FirestoreService.orgDepartmentsCol(orgId).snapshots();
    final shiftsStream = FirestoreService.orgShiftsCol(orgId).snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: membersStream,
          builder: (context, membersSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: deptsStream,
              builder: (context, deptsSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: shiftsStream,
                  builder: (context, shiftsSnap) {
                    final employeeCount = membersSnap.hasData
                        ? membersSnap.data!.docs
                            .where((doc) =>
                                (doc.data() as Map<String, dynamic>)['role'] !=
                                'admin')
                            .length
                        : 0;
                    final deptCount = deptsSnap.hasData ? deptsSnap.data!.docs.length : 0;
                    final shiftCount = shiftsSnap.hasData ? shiftsSnap.data!.docs.length : 0;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          // 1. Success checkmark icon at the top
                          Center(
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE0F2FE), // Soft light-blue/cyan background ring
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4F46E5).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // 2. Titles
                          Text(
                            'Your Workspace Is Ready',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'AttendanceOS has been successfully configured and is ready for daily workforce management.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // 3. 2x2 Metrics Row/Columns Grid
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricCard(
                                      icon: Icons.people_alt_rounded,
                                      iconColor: const Color(0xFF6366F1),
                                      bgColor: const Color(0xFFEEF2FF),
                                      value: '$employeeCount',
                                      label: 'Employees',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildMetricCard(
                                      icon: Icons.apartment_rounded,
                                      iconColor: const Color(0xFF0EA5E9),
                                      bgColor: const Color(0xFFF0F9FF),
                                      value: '$deptCount',
                                      label: 'Departments',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricCard(
                                      icon: Icons.access_time_filled_rounded,
                                      iconColor: const Color(0xFF8B5CF6),
                                      bgColor: const Color(0xFFF5F3FF),
                                      value: '$shiftCount',
                                      label: 'Shifts',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildMetricCard(
                                      icon: Icons.verified_user_rounded,
                                      iconColor: const Color(0xFF10B981),
                                      bgColor: const Color(0xFFECFDF5),
                                      value: 'Active',
                                      label: 'Policies',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 4. Setup Complete Milestones Card
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                            ),
                            child: Column(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Setup Complete',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        '9/9 done',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1.5),
                                _buildMilestoneItem('Organization Setup'),
                                _buildMilestoneItem('Administrator Setup'),
                                _buildMilestoneItem('Department Setup'),
                                _buildMilestoneItem('Employee Setup'),
                                _buildMilestoneItem('Holiday Setup'),
                                _buildMilestoneItem('Shift Setup'),
                                _buildMilestoneItem('Attendance Policy'),
                                _buildMilestoneItem('Leave Policy'),
                                _buildMilestoneItem('Notifications', isLast: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 5. Live Banner Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'AttendanceOS is Live',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'Employees · Managers · Admins can now sign in',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFE0E7FF),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),

                          // 6. Action buttons
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Enter AttendanceOS',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => _showSummarySheet(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: const Text(
                                'View Setup Summary',
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneItem(String title, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(color: Color(0xFFF1F5F9), height: 1, indent: 48, thickness: 1.2),
      ],
    );
  }

  // Summary sheet to show detailed breakdown of configured policies
  void _showSummarySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          height: MediaQuery.of(context).size.height * 0.75,
          child: FutureBuilder<DocumentSnapshot>(
            future: FirestoreService.orgDoc(orgId).get(),
            builder: (context, orgSnap) {
              if (orgSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final orgData = orgSnap.data?.data() as Map<String, dynamic>? ?? {};

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Setup Summary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    orgName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _summarySectionHeader(Icons.business, 'Organization Details'),
                          _summaryDetailRow('Workspace Name', orgName),
                          _summaryDetailRow('Work Location', orgData['location'] ?? 'Not Specified'),
                          _summaryDetailRow('Employee Type', orgData['employeeType'] ?? 'Full-Time / Part-Time'),
                          const SizedBox(height: 16),
                          
                          _summarySectionHeader(Icons.settings, 'Attendance Policy'),
                          FutureBuilder<DocumentSnapshot>(
                            future: FirestoreService.orgPolicyDoc(orgId, 'attendance').get(),
                            builder: (context, policySnap) {
                              if (!policySnap.hasData) return const SizedBox();
                              final data = policySnap.data!.data() as Map<String, dynamic>? ?? {};
                              final startHr = data['shiftStartHour'] ?? 9;
                              final startMin = data['shiftStartMinute'] ?? 0;
                              final time = '${startHr.toString().padLeft(2, '0')}:${startMin.toString().padLeft(2, '0')}';
                              return Column(
                                children: [
                                  _summaryDetailRow('Shift Start', time),
                                  _summaryDetailRow('Grace Period', '${data['gracePeriodMins'] ?? 15} mins'),
                                  _summaryDetailRow('WFH Access', (data['wfhEnabled'] ?? true) ? 'Enabled' : 'Disabled'),
                                  _summaryDetailRow('Overtime Tracker', (data['overtimeEnabled'] ?? true) ? 'Enabled' : 'Disabled'),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          _summarySectionHeader(Icons.calendar_month, 'Configured Leaves'),
                          FutureBuilder<QuerySnapshot>(
                            future: FirestoreService.orgPoliciesCol(orgId).get(),
                            builder: (context, policiesSnap) {
                              if (!policiesSnap.hasData) return const SizedBox();
                              final leaves = policiesSnap.data!.docs
                                  .where((doc) => doc.id.startsWith('leave_'))
                                  .toList();
                              if (leaves.isEmpty) return const Text('No leave types configured');
                              return Column(
                                children: leaves.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  return _summaryDetailRow(data['name'] ?? '', '${data['allocationDays'] ?? 0} days/yr');
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text('Close Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _summarySectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4F46E5), size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
