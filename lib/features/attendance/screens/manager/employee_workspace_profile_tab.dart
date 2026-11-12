import 'package:flutter/material.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'employee_workspace_common.dart';

/// Profile tab — only the details saved on the employee's profile (web "Add Employee").
class EmployeeWorkspaceProfileTab extends StatelessWidget {
  final Map<String, dynamic> employeeData;

  const EmployeeWorkspaceProfileTab({super.key, required this.employeeData});

  @override
  Widget build(BuildContext context) {
    final d = employeeData;
    final address = [wsStr(d['address']), wsStr(d['city']), wsStr(d['zipCode'])]
        .where((e) => e.isNotEmpty)
        .join(', ');
    final emergency = [wsStr(d['emergencyContact']), wsStr(d['emergencyPhone'])]
        .where((e) => e.isNotEmpty)
        .join(' · ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          wsSectionCard('BASIC INFORMATION', [
            WsRow('Employee ID', () {
              final id = wsFirst(d, ['employeeId', 'id']);
              return id.contains('@') ? '' : id;
            }()),
            WsRow('Official Email', wsEmail(d)),
            WsRow('Phone', wsStr(d['phone'])),
            WsRow('Joined', wsDate(d['joinDate'] ?? d['joiningDate'] ?? d['joinedDate'])),
          ]),
          const SizedBox(height: 16),
          wsSectionCard('WORK INFORMATION', [
            WsRow('Department', wsDept(d)),
            WsRow('Designation', wsStr(d['designation'])),
            WsRow('Role', wsRole(d)),
            WsRow('Reporting Manager', wsFirst(d, ['manager', 'managerName'])),
            WsRow('Branch', wsStr(d['branch'])),
            WsRow('Business Unit', wsStr(d['businessUnit'])),
            WsRow('Team', wsStr(d['team'])),
            WsRow('Work Mode', wsStr(d['workMode'])),
            WsRow('Employee Type', wsFirst(d, ['empType', 'employmentType'])),
          ]),
          const SizedBox(height: 16),
          // Shift: the shift actually assigned to this employee (live from the company shifts)
          FutureBuilder<String>(
            future: FirestoreService.shiftLabelForUser(Map<String, dynamic>.from(d)),
            builder: (context, snap) => wsSectionCard('SCHEDULE & POLICIES', [
              WsRow('Shift', snap.data ?? ''),
              WsRow('Weekly Off', wsStr(d['weeklyOff'])),
              WsRow('Leave Policy', wsStr(d['leavePolicy'])),
              WsRow('Holiday Calendar', wsStr(d['holidayCalendar'])),
            ]),
          ),
          const SizedBox(height: 16),
          wsSectionCard('PERSONAL INFORMATION', [
            WsRow('Date of Birth', wsDate(d['dob'])),
            WsRow('Gender', wsStr(d['gender'])),
            WsRow('Personal Email', wsStr(d['personalEmail'])),
            WsRow('Address', address),
            WsRow('Emergency Contact', emergency),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
