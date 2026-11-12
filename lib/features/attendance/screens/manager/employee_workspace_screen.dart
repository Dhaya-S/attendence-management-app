import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/widgets/user_avatar.dart';
import 'employee_workspace_common.dart';
import 'employee_workspace_profile_tab.dart';
import 'employee_workspace_department_tab.dart';
import 'employee_workspace_related_data_tab.dart';

class EmployeeWorkspaceScreen extends StatefulWidget {
  final Map<String, dynamic> employeeData;

  const EmployeeWorkspaceScreen({
    super.key,
    required this.employeeData,
  });

  @override
  State<EmployeeWorkspaceScreen> createState() => _EmployeeWorkspaceScreenState();
}

class _EmployeeWorkspaceScreenState extends State<EmployeeWorkspaceScreen> {
  int _selectedTab = 0; // 0: Profile, 1: Department, 2: Related Data
  late final Stream<Map<String, dynamic>> _userStream = wsLiveUser(widget.employeeData);
  late final Stream<QuerySnapshot> _leaveStream = FirestoreService.leaveRequestsCol.snapshots();
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _todayStream;

  @override
  void initState() {
    super.initState();
    final email = wsEmail(widget.employeeData);
    if (email.isNotEmpty) {
      final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _todayStream = FirestoreService.userAttendanceCol(email).doc(key).snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _userStream,
      initialData: widget.employeeData,
      builder: (context, userSnap) {
        final data = userSnap.data ?? widget.employeeData;
        final name = wsName(data);
        final role = wsRole(data);
        final dept = wsDept(data);
        final designation = wsStr(data['designation']);
        final subtitle = [if (designation.isNotEmpty) designation else role, if (dept.isNotEmpty) dept].join(' · ');
        final email = wsEmail(data);

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1F2937), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Employee Workspace',
                style: TextStyle(color: Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.bold)),
            centerTitle: false,
          ),
          body: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    UserAvatar(
                      name: name,
                      imageData: wsStr(data['profileImageUrl']),
                      radius: 28,
                      color: wsAvatarColor(name),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // live status: today's attendance + approved leave
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _todayStream,
                      builder: (context, attSnap) => StreamBuilder<QuerySnapshot>(
                        stream: _leaveStream,
                        builder: (context, leaveSnap) {
                          final onLeave = wsOnLeaveToday(
                              (leaveSnap.data?.docs ?? const <QueryDocumentSnapshot>[])
                                  .map((d) => d.data() as Map<String, dynamic>),
                              email);
                          return wsStatusChip(wsStatusToday(data, attSnap.data?.data(), onLeave));
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                child: wsChips(const ['Profile', 'Department', 'Related Data'], _selectedTab,
                    (i) => setState(() => _selectedTab = i)),
              ),
              const SizedBox(height: 1),
              Expanded(
                child: _selectedTab == 0
                    ? EmployeeWorkspaceProfileTab(employeeData: data)
                    : _selectedTab == 1
                        ? EmployeeWorkspaceDepartmentTab(employeeData: data)
                        : EmployeeWorkspaceRelatedDataTab(employeeData: data),
              ),
            ],
          ),
        );
      },
    );
  }
}
