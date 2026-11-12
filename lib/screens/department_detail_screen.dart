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
    this.members = const [],
  });

  @override
  State<DepartmentDetailScreen> createState() => _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<DepartmentDetailScreen> {
  // Everything below is computed live from Firestore (people, tasks, leave requests)
  late final Stream<QuerySnapshot> _peopleStream = FirestoreService.employeesCol.snapshots();
  late final Stream<QuerySnapshot> _tasksStream = FirestoreService.tasksCol.snapshots();
  late final Stream<QuerySnapshot> _leaveStream = FirestoreService.leaveRequestsCol.snapshots();

  int _taskAssigned = 0;
  int _taskInProgress = 0;
  int _taskCompleted = 0;
  int _taskOverdue = 0;
  int _leaveUsedTotal = 0;
  int _pendingApprovals = 0;
  double _avgLeave = 0.0;
  Set<String> _onLeaveToday = {};

  List<Map<String, dynamic>> _membersFrom(QuerySnapshot? snap) {
    final out = <Map<String, dynamic>>[];
    for (final doc in snap?.docs ?? const <QueryDocumentSnapshot>[]) {
      if (!FirestoreService.isDocInCurrentCompany(doc)) continue;
      final data = Map<String, dynamic>.from(doc.data() as Map);
      if (!FirestoreService.isActiveUserDoc(data)) continue;
      if (FirestoreService.deptOf(data) != widget.departmentName) continue;
      data['email'] = doc.id;
      out.add(data);
    }
    out.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return out;
  }

  void _computeStats(List<Map<String, dynamic>> members, QuerySnapshot? tasks, QuerySnapshot? leaves) {
    final emails = members.map((m) => (m['email'] ?? '').toString().toLowerCase()).toSet();
    int tA = 0, tP = 0, tD = 0, tO = 0;
    for (final doc in tasks?.docs ?? const <QueryDocumentSnapshot>[]) {
      if (!FirestoreService.isDocInCurrentCompany(doc)) continue;
      final d = doc.data() as Map<String, dynamic>;
      final mine = members.any((m) => FirestoreService.taskAssignedTo(d, (m['email'] ?? '').toString(),
          name: (m['name'] ?? '').toString(), uid: (m['uid'] ?? '').toString()));
      if (!mine) continue;
      switch (FirestoreService.taskBucket(d)) {
        case 'Assigned':
          tA++;
          break;
        case 'In Progress':
          tP++;
          break;
        case 'Completed':
          tD++;
          break;
        case 'Overdue':
          tO++;
          break;
      }
    }

    int used = 0, pending = 0;
    final onLeave = <String>{};
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    for (final doc in leaves?.docs ?? const <QueryDocumentSnapshot>[]) {
      final d = doc.data() as Map<String, dynamic>;
      final who = FirestoreService.requesterEmail(d);
      if (!emails.contains(who)) continue;
      final from = FirestoreService.parseAnyDate(d['fromDate'] ?? d['from']);
      final to = FirestoreService.parseAnyDate(d['toDate'] ?? d['to']) ?? from;
      if (FirestoreService.statusIs(d['status'], 'pending')) {
        pending++;
      } else if (FirestoreService.statusIs(d['status'], 'approved')) {
        if (from != null && from.year == today.year) {
          final raw = d['days'] ?? d['durationInDays'];
          final n = raw is num
              ? raw.toInt()
              : int.tryParse((raw ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '')) ??
                  ((to ?? from).difference(from).inDays + 1);
          used += n;
        }
        if (from != null && to != null) {
          final f0 = DateTime(from.year, from.month, from.day);
          final e0 = DateTime(to.year, to.month, to.day);
          if (!t0.isBefore(f0) && !t0.isAfter(e0)) onLeave.add(who);
        }
      }
    }

    _taskAssigned = tA;
    _taskInProgress = tP;
    _taskCompleted = tD;
    _taskOverdue = tO;
    _leaveUsedTotal = used;
    _pendingApprovals = pending;
    _avgLeave = emails.isEmpty ? 0 : used / emails.length;
    _onLeaveToday = onLeave;
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _peopleStream,
        builder: (context, peopleSnap) => StreamBuilder<QuerySnapshot>(
          stream: _tasksStream,
          builder: (context, taskSnap) => StreamBuilder<QuerySnapshot>(
            stream: _leaveStream,
            builder: (context, leaveSnap) {
              if (!peopleSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final members = _membersFrom(peopleSnap.data);
              _computeStats(members, taskSnap.data, leaveSnap.data);
              final leaveCount =
                  members.where((m) => _onLeaveToday.contains((m['email'] ?? '').toString().toLowerCase())).length;
              final activeCount = members.length - leaveCount;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricRow(members.length, leaveCount, activeCount),
                    const SizedBox(height: 24),
                    const Text('Team Members', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    const SizedBox(height: 12),
                    if (members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No active members in this department.', style: TextStyle(color: Color(0xFF6B7280))),
                      ),
                    ...members.map((m) => _buildMemberCard(context, m)),
                    const SizedBox(height: 24),
                    _buildLeaveStatusCard(),
                    const SizedBox(height: 24),
                    _buildTaskStatusCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
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
    final role = (m['designation'] ?? m['role'] ?? 'Employee').toString();
    final email = m['email'] ?? '';
    final dbStatus = _onLeaveToday.contains(email.toString().toLowerCase()) ? 'on leave' : 'active';
    
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
          _buildInfoRow('Leave Used This Year', '$_leaveUsedTotal days total'),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('Pending Approvals', '$_pendingApprovals'),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('Avg per Person', '${_avgLeave.toStringAsFixed(1)} days'),
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
          _buildInfoRow('Assigned', '$_taskAssigned'),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('In Progress', '$_taskInProgress'),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('Completed', '$_taskCompleted'),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          _buildInfoRow('Overdue', '$_taskOverdue'),
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
