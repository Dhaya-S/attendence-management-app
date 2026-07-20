import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/screens/employee_profile_detail_screen.dart';

class DepartmentDetailScreen extends StatefulWidget {
  final String departmentName;
  final List<Map<String, dynamic>> members;

  const DepartmentDetailScreen({
    super.key,
    required this.departmentName,
    required this.members,
  });

  @override
  State<DepartmentDetailScreen> createState() => _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<DepartmentDetailScreen> {
  int _leaveUsedTotal = 0;
  int _pendingApprovals = 0;
  double _avgLeave = 0.0;
  
  int _taskAssigned = 0;
  int _taskInProgress = 0;
  int _taskCompleted = 0;
  int _taskOverdue = 0;

  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    int lUsed = 0;
    int lPending = 0;

    int tAssigned = 0;
    int tActive = 0;
    int tDone = 0;
    int tOverdue = 0;

    final emails = widget.members.map((m) => m['email'] as String).toList();

    // Fetch Tasks for the company and filter by members
    try {
      final tasksSnap = await FirestoreService.tasksCol.get();
      for (var doc in tasksSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final assignedTo = data['assignedTo'] as String?;
        if (assignedTo != null && emails.contains(assignedTo)) {
          final status = (data['status'] ?? '').toString().toLowerCase();
          if (status == 'assigned') tAssigned++;
          else if (status == 'in progress') tActive++;
          else if (status == 'completed') tDone++;
          else if (status == 'overdue') tOverdue++;
        }
      }
    } catch (e) {
      debugPrint("Error fetching tasks for department: $e");
    }

    // Fetch Leaves per member
    try {
      for (String email in emails) {
        final leavesSnap = await FirestoreService.userLeaveRequestsCol(email).get();
        for (var doc in leavesSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          
          if (status == 'pending') {
            lPending++;
          } else if (status == 'approved') {
            final startTs = data['startDate'] as Timestamp?;
            final endTs = data['endDate'] as Timestamp?;
            if (startTs != null && endTs != null) {
              DateTime current = startTs.toDate();
              final end = endTs.toDate();
              int days = 0;
              while (current.isBefore(end.add(const Duration(days: 1)))) {
                days++;
                current = current.add(const Duration(days: 1));
              }
              lUsed += days;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching leaves for department: $e");
    }

    if (mounted) {
      setState(() {
        _leaveUsedTotal = lUsed;
        _pendingApprovals = lPending;
        _avgLeave = emails.isEmpty ? 0 : lUsed / emails.length;

        _taskAssigned = tAssigned;
        _taskInProgress = tActive;
        _taskCompleted = tDone;
        _taskOverdue = tOverdue;
        
        _isLoadingStats = false;
      });
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
    ];
    int hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    int activeCount = 0;
    int leaveCount = 0;

    for (var m in widget.members) {
      final status = (m['status'] ?? 'active').toString().toLowerCase();
      if (status == 'on leave') {
        leaveCount++;
      } else if (status == 'active') {
        activeCount++;
      }
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
        title: Text(
          widget.departmentName,
          style: const TextStyle(color: Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricRow(widget.members.length, leaveCount, activeCount),
            const SizedBox(height: 24),
            const Text('Team Members', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            ...widget.members.map((m) => _buildMemberCard(context, m)).toList(),
            const SizedBox(height: 24),
            _buildLeaveStatusCard(),
            const SizedBox(height: 24),
            _buildTaskStatusCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(int total, int onLeave, int active) {
    return Row(
      children: [
        _buildMetricBox(total.toString(), 'Members', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF)),
        const SizedBox(width: 8),
        _buildMetricBox(onLeave.toString(), 'On Leave', const Color(0xFFF3E8FF).withOpacity(0.5), const Color(0xFF7C3AED)),
        const SizedBox(width: 8),
        _buildMetricBox(active.toString(), 'Active', const Color(0xFFECFDF5), const Color(0xFF10B981)),
      ],
    );
  }

  Widget _buildMetricBox(String count, String label, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, Map<String, dynamic> m) {
    final name = m['name'] ?? 'Unknown';
    final role = m['role'] ?? 'Employee';
    final dbStatus = (m['status'] ?? 'active').toString().toLowerCase();
    final email = m['email'] ?? '';
    
    String statusLabel = 'Active';
    if (dbStatus == 'on leave') statusLabel = 'On Leave';
    if (dbStatus == 'inactive' || dbStatus == 'pending') statusLabel = 'Inactive';

    Color bgColor = const Color(0xFFD1FAE5).withOpacity(0.5);
    Color textColor = const Color(0xFF059669);
    
    if (statusLabel == 'On Leave') {
      bgColor = const Color(0xFFF3E8FF).withOpacity(0.5);
      textColor = const Color(0xFF7C3AED);
    } else if (statusLabel == 'Inactive') {
      bgColor = const Color(0xFFF3F4F6);
      textColor = const Color(0xFF6B7280);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeProfileDetailScreen(
              userData: m,
              email: email,
            ),
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
            CircleAvatar(
              radius: 20,
              backgroundColor: _getAvatarColor(name),
              child: Text(
                _getInitials(name),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  Text(role, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: textColor.withOpacity(0.2)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveStatusCard() {
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
          const Text('LEAVE STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 20),
          _buildInfoRow('Annual Leave Used', '$_leaveUsedTotal days total', isLoading: _isLoadingStats),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('Pending Approvals', '$_pendingApprovals', isLoading: _isLoadingStats),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('Avg per Person', '${_avgLeave.toStringAsFixed(1)} days', isLoading: _isLoadingStats),
        ],
      ),
    );
  }

  Widget _buildTaskStatusCard() {
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
          const Text('TASK STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 20),
          _buildInfoRow('Assigned', '$_taskAssigned', isLoading: _isLoadingStats),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('In Progress', '$_taskInProgress', isLoading: _isLoadingStats),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('Completed', '$_taskCompleted', isLoading: _isLoadingStats),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('Overdue', '$_taskOverdue', isLoading: _isLoadingStats),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLoading = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        if (isLoading)
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
        else
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
      ],
    );
  }
}
