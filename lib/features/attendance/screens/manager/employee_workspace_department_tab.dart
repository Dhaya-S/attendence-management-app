import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/widgets/user_avatar.dart';
import 'employee_workspace_common.dart';

/// Department tab — the employee's department details and the real, active people in it
/// with their live status today.
class EmployeeWorkspaceDepartmentTab extends StatefulWidget {
  final Map<String, dynamic> employeeData;

  const EmployeeWorkspaceDepartmentTab({super.key, required this.employeeData});

  @override
  State<EmployeeWorkspaceDepartmentTab> createState() => _EmployeeWorkspaceDepartmentTabState();
}

class _EmployeeWorkspaceDepartmentTabState extends State<EmployeeWorkspaceDepartmentTab> {
  late final Stream<QuerySnapshot> _people = FirestoreService.employeesCol.snapshots();
  late final Stream<QuerySnapshot> _attendance = FirestoreService.allAttendanceRecordsCol.snapshots();
  late final Stream<QuerySnapshot> _leaves = FirestoreService.leaveRequestsCol.snapshots();

  bool _isToday(QueryDocumentSnapshot doc) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final d = doc.data() as Map<String, dynamic>;
    if (doc.id == today || doc.id.endsWith('_$today')) return true;
    if (d['recordDate'] == today || d['date'] == today) return true;
    final dt = FirestoreService.parseAnyDate(d['date']);
    return dt != null && DateFormat('yyyy-MM-dd').format(dt) == today;
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.employeeData;
    final dept = wsDept(me);

    if (dept.isEmpty) {
      return wsEmpty('No department has been assigned to this employee.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _people,
      builder: (context, peopleSnap) => StreamBuilder<QuerySnapshot>(
        stream: _attendance,
        builder: (context, attSnap) => StreamBuilder<QuerySnapshot>(
          stream: _leaves,
          builder: (context, leaveSnap) {
            if (!peopleSnap.hasData) return const Center(child: CircularProgressIndicator());

            final members = <Map<String, dynamic>>[];
            for (final doc in peopleSnap.data!.docs) {
              if (!FirestoreService.isDocInCurrentCompany(doc)) continue;
              final m = Map<String, dynamic>.from(doc.data() as Map);
              if (!FirestoreService.isActiveUserDoc(m)) continue;
              if (wsDept(m) != dept) continue;
              m['email'] = wsEmail(m).isEmpty ? doc.id.toLowerCase() : wsEmail(m);
              members.add(m);
            }
            members.sort((a, b) => wsName(a).compareTo(wsName(b)));

            final todayAtt = <String, Map<String, dynamic>>{};
            for (final doc in attSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
              if (!_isToday(doc)) continue;
              final d = doc.data() as Map<String, dynamic>;
              final email = FirestoreService.requesterEmail(d).isNotEmpty
                  ? FirestoreService.requesterEmail(d)
                  : doc.id.split('_').first.toLowerCase();
              todayAtt[email] = d;
            }
            final leaves = (leaveSnap.data?.docs ?? const <QueryDocumentSnapshot>[])
                .map((d) => d.data() as Map<String, dynamic>)
                .toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  wsSectionCard('DEPARTMENT', [
                    WsRow('Department Name', dept),
                    WsRow('Reporting Manager', wsFirst(me, ['manager', 'managerName'])),
                    WsRow('Business Unit', wsStr(me['businessUnit'])),
                    WsRow('Team', wsStr(me['team'])),
                    WsRow('Branch', wsStr(me['branch'])),
                    WsRow('Team Size', '${members.length} member${members.length == 1 ? '' : 's'}'),
                  ]),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('TEAM MEMBERS',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
                  ),
                  if (members.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('No active members in this department.', style: TextStyle(color: Color(0xFF9CA3AF))),
                    ),
                  for (final m in members) _memberCard(m, todayAtt[m['email']], wsOnLeaveToday(leaves, m['email'])),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _memberCard(Map<String, dynamic> m, Map<String, dynamic>? att, bool onLeave) {
    final name = wsName(m);
    final status = wsStatusToday(m, att, onLeave);
    final title = wsFirst(m, ['designation']).isNotEmpty ? wsStr(m['designation']) : wsRole(m);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              UserAvatar(
                name: name,
                imageData: wsStr(m['profileImageUrl']),
                radius: 20,
                color: wsAvatarColor(name),
              ),
              if (status == 'Present' || status == 'Late' || status == 'WFH')
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
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
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          wsStatusChip(status, small: true),
        ],
      ),
    );
  }
}
