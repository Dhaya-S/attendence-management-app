import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
    // Everything on this screen is live: people, their shifts, today's attendance and approved leave.
    return Container(
      color: const Color(0xFFF4F6F9), // App background color
      child: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.employeesCol.snapshots(),
        builder: (context, usersSnap) => StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.shiftsCol.snapshots(),
          builder: (context, shiftsSnap) => StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.attendanceCol.snapshots(),
            builder: (context, attSnap) => StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.leaveRequestsCol.snapshots(),
              builder: (context, leaveSnap) {
                if (usersSnap.hasError) {
                  return Center(child: Text('Error: ${usersSnap.error}'));
                }
                if (!usersSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final members = _buildMembers(
                    usersSnap.data!, shiftsSnap.data, attSnap.data, leaveSnap.data);
                return Column(
                  children: [
                    _buildSummaryCards(members),
                    Expanded(child: _buildMembersList(members)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _buildMembers(
    QuerySnapshot users,
    QuerySnapshot? shiftsSnap,
    QuerySnapshot? attSnap,
    QuerySnapshot? leaveSnap,
  ) {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final todayDate = DateTime(today.year, today.month, today.day);

    final shifts = (shiftsSnap?.docs ?? [])
        .map((d) {
          final m = Map<String, dynamic>.from(d.data() as Map);
          m['id'] = m['id'] ?? d.id;
          return m;
        })
        .toList();

    // today's attendance by employee email
    final Map<String, Map<String, dynamic>> attByEmail = {};
    for (final d in attSnap?.docs ?? const <QueryDocumentSnapshot>[]) {
      final m = d.data() as Map<String, dynamic>;
      final isToday = d.id.endsWith('_$todayKey') || (m['date'] ?? '').toString() == todayKey;
      if (!isToday) continue;
      final email = (m['email'] ?? m['userEmail'] ?? d.id.split('_').first).toString().toLowerCase();
      attByEmail[email] = m;
    }

    // employees on approved leave today
    final Set<String> onLeave = {};
    for (final d in leaveSnap?.docs ?? const <QueryDocumentSnapshot>[]) {
      final m = d.data() as Map<String, dynamic>;
      if (!FirestoreService.statusIs(m['status'], 'approved')) continue;
      final from = FirestoreService.parseAnyDate(m['fromDate'] ?? m['from']);
      final to = FirestoreService.parseAnyDate(m['toDate'] ?? m['to']) ?? from;
      if (from == null || to == null) continue;
      final f = DateTime(from.year, from.month, from.day);
      final t = DateTime(to.year, to.month, to.day);
      if (todayDate.isBefore(f) || todayDate.isAfter(t)) continue;
      final email = FirestoreService.requesterEmail(m);
      if (email.isNotEmpty) onLeave.add(email);
    }

    // team scope: everyone for admins, otherwise my department
    final docs = users.docs
        .where((d) =>
            FirestoreService.isDocInCurrentCompany(d) &&
            FirestoreService.isActiveUserDoc(d.data() as Map<String, dynamic>))
        .toList();
    final currentUserEmail = (AppSession().email ?? '').toLowerCase();
    String myDept = (AppSession().userDepartment ?? '').toString().trim().toLowerCase();
    if (myDept.isEmpty) {
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        if ((data['email'] ?? doc.id).toString().toLowerCase() == currentUserEmail) {
          myDept = (data['department'] ?? data['dept'] ?? '').toString().trim().toLowerCase();
          break;
        }
      }
    }

    final members = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      final dept = (data['department'] ?? data['dept'] ?? '').toString().trim().toLowerCase();
      if (!(myDept.isEmpty || AppSession().hasAdminAccess || dept == myDept)) continue;

      final email = (data['email'] ?? data['workEmail'] ?? doc.id).toString().toLowerCase();
      final rec = attByEmail[email];

      String todayStatus;
      String todayLine;
      if (rec != null) {
        final st = (rec['status'] ?? rec['attendanceStatus'] ?? '').toString().toLowerCase();
        final isWfh = rec['workMode'] == 'wfh' || st == 'wfh';
        todayStatus = isWfh ? 'WFH' : (st == 'late' ? 'Late' : 'Present');
        String inT = FirestoreService.formatTime12(rec['checkInTime']);
        if (inT.isEmpty) {
          final ci = FirestoreService.parseAnyDate(rec['checkIn']);
          if (ci != null) inT = DateFormat('hh:mm a').format(ci);
        }
        String outT = FirestoreService.formatTime12(rec['checkOutTime']);
        if (outT.isEmpty) {
          final co = FirestoreService.parseAnyDate(rec['checkOut']);
          if (co != null) outT = DateFormat('hh:mm a').format(co);
        }
        todayLine = inT.isEmpty ? 'Checked in' : 'In: $inT${outT.isNotEmpty ? ' · Out: $outT' : ''}';
      } else if (onLeave.contains(email)) {
        todayStatus = 'On Leave';
        todayLine = 'On leave today';
      } else {
        todayStatus = 'Absent';
        todayLine = 'Not checked in';
      }

      final rawRole = (data['role'] ?? '').toString().toLowerCase();
      final roleText = (data['designation'] ?? '').toString().trim().isNotEmpty
          ? data['designation'].toString()
          : (rawRole == 'hr_admin' || rawRole == 'admin' || rawRole == 'super_admin'
              ? 'HR Admin'
              : rawRole == 'manager'
                  ? 'Manager'
                  : 'Employee');

      members.add({
        'name': data['name'] ?? data['userName'] ?? data['fullName'] ?? 'Team Member',
        'department': data['department'] ?? data['dept'] ?? 'General',
        ...data,
        // computed (live) values — never overwritten by profile fields
        'roleText': roleText,
        'shiftLine': FirestoreService.shiftLabel(FirestoreService.pickShiftFor(data, shifts)),
        'todayStatus': todayStatus,
        'todayLine': todayLine,
      });
    }
    return members;
  }

  Widget _buildSummaryCards(List<Map<String, dynamic>> members) {
    int count(String s) => members.where((m) => m['todayStatus'] == s).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryCard('${count('Present')}', 'Present', const Color(0xFF059669), const Color(0xFFECFDF5)),
          _buildSummaryCard('${count('WFH')}', 'WFH', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
          _buildSummaryCard('${count('Late')}', 'Late', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
          _buildSummaryCard('${count('On Leave')}', 'Leave', const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
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

  Widget _buildMembersList(List<Map<String, dynamic>> members) {
    if (members.isEmpty) {
      return const Center(
        child: Text('No team members found', style: TextStyle(color: Color(0xFF9CA3AF))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final data = members[index];
        final name = data['name'].toString();
        final roleText = data['roleText'].toString();
        final statusLabel = data['todayStatus'].toString();
        final shiftLine = data['shiftLine'].toString();
        final todayLine = data['todayLine'].toString();
        final checkedIn = statusLabel == 'Present' || statusLabel == 'Late' || statusLabel == 'WFH';

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
                    if (checkedIn)
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
                      Text(roleText, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(shiftLine, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(todayLine, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
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
