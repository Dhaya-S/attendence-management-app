import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'employee_workspace_common.dart';

/// Related Data — this employee's real attendance, leave requests and tasks (live).
class EmployeeWorkspaceRelatedDataTab extends StatefulWidget {
  final Map<String, dynamic> employeeData;

  const EmployeeWorkspaceRelatedDataTab({super.key, required this.employeeData});

  @override
  State<EmployeeWorkspaceRelatedDataTab> createState() => _EmployeeWorkspaceRelatedDataTabState();
}

class _EmployeeWorkspaceRelatedDataTabState extends State<EmployeeWorkspaceRelatedDataTab> {
  int _selectedSubTab = 0; // 0: Attendance, 1: Leave, 2: Tasks
  String _selectedFilter = 'Daily'; // Daily, Weekly, Monthly

  late final String _email = wsEmail(widget.employeeData);
  late final Stream<QuerySnapshot>? _attStream =
      _email.isEmpty ? null : FirestoreService.userAttendanceCol(_email).snapshots();
  late final Stream<QuerySnapshot> _leaveStream = FirestoreService.leaveRequestsCol.snapshots();
  late final Stream<QuerySnapshot> _taskStream = FirestoreService.tasksCol.snapshots();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: wsChips(const ['Attendance', 'Leave', 'Tasks'], _selectedSubTab,
              (i) => setState(() => _selectedSubTab = i)),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: Container(
            color: const Color(0xFFF4F6F9),
            child: _selectedSubTab == 0
                ? _attendanceView()
                : _selectedSubTab == 1
                    ? _leaveView()
                    : _tasksView(),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Attendance ─────────────────────────
  String _dayStatus(Map<String, dynamic> a) {
    final status = wsStr(a['status'] ?? a['attendanceStatus']).toLowerCase();
    final mode = wsStr(a['workMode']).toLowerCase();
    if (status.contains('leave')) return 'On Leave';
    if (mode == 'wfh' || mode == 'work_from_home') return 'WFH';
    if (status.contains('late') || a['isLate'] == true) return 'Late';
    if (a['checkIn'] != null || a['checkInTime'] != null || a['lastCheckIn'] != null || status.contains('present')) {
      return 'Present';
    }
    return 'Absent';
  }

  DateTime? _in(Map<String, dynamic> a, DateTime day) =>
      FirestoreService.parseTimeOnDay(a['checkIn'] ?? a['checkInTime'] ?? a['lastCheckIn'], day);
  DateTime? _out(Map<String, dynamic> a, DateTime day) =>
      FirestoreService.parseTimeOnDay(a['checkOut'] ?? a['checkOutTime'] ?? a['lastCheckout'], day);

  String _hours(DateTime? i, DateTime? o, {bool ongoing = false}) {
    if (i == null) return '—';
    final end = o ?? (ongoing ? DateTime.now() : null);
    if (end == null) return '—';
    final mins = end.difference(i).inMinutes.abs();
    return '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';
  }

  Widget _attendanceView() {
    if (_attStream == null) return wsEmpty('No attendance found for this employee.');
    return StreamBuilder<QuerySnapshot>(
      stream: _attStream,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final byDay = <String, Map<String, dynamic>>{
          for (final d in snap.data!.docs) d.id: d.data() as Map<String, dynamic>,
        };
        final now = DateTime.now();
        final fmtKey = DateFormat('yyyy-MM-dd');

        List<DateTime> days;
        if (_selectedFilter == 'Daily') {
          days = [now];
        } else if (_selectedFilter == 'Weekly') {
          days = [for (var i = 0; i < 7; i++) DateTime(now.year, now.month, now.day).subtract(Duration(days: i))];
        } else {
          days = [for (var d = now.day; d >= 1; d--) DateTime(now.year, now.month, d)];
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _filterBar(),
              const SizedBox(height: 16),
              if (_selectedFilter == 'Daily')
                _dailyCard(byDay[fmtKey.format(now)], now)
              else ...[
                _summaryRow(days, byDay),
                const SizedBox(height: 12),
                for (final d in days) _dayRow(d, byDay[fmtKey.format(d)]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final f in const ['Daily', 'Weekly', 'Monthly']) _filterButton(f)],
      ),
    );
  }

  Widget _filterButton(String label) {
    final selected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5C5CFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF6B7280))),
      ),
    );
  }

  Widget _dailyCard(Map<String, dynamic>? a, DateTime day) {
    final status = a == null ? 'Not Checked In' : _dayStatus(a);
    final i = a == null ? null : _in(a, day);
    final o = a == null ? null : _out(a, day);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TODAY · ${DateFormat('MMM d').format(day).toUpperCase()}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
                wsStatusChip(status, small: true),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
          wsInfoRow('Check-In', i == null ? '—' : DateFormat('hh:mm a').format(i)),
          const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
          wsInfoRow('Check-Out', o == null ? '—' : DateFormat('hh:mm a').format(o)),
          const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
          wsInfoRow('Working Hours', _hours(i, o, ongoing: true)),
          if (a != null && wsStr(a['workMode']).isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
            wsInfoRow('Work Mode', wsStr(a['workMode']).toUpperCase() == 'WFH' ? 'Work From Home' : wsStr(a['workMode'])),
          ],
          const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
          FutureBuilder<String>(
            future: FirestoreService.shiftLabelForUser(Map<String, dynamic>.from(widget.employeeData)),
            builder: (context, snap) => wsInfoRow('Assigned Shift', snap.data ?? '—'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _summaryRow(List<DateTime> days, Map<String, Map<String, dynamic>> byDay) {
    int present = 0, late = 0, wfh = 0, leave = 0;
    final fmt = DateFormat('yyyy-MM-dd');
    for (final d in days) {
      final a = byDay[fmt.format(d)];
      if (a == null) continue;
      switch (_dayStatus(a)) {
        case 'Present':
          present++;
          break;
        case 'Late':
          late++;
          break;
        case 'WFH':
          wfh++;
          break;
        case 'On Leave':
          leave++;
          break;
      }
    }
    Widget box(String n, String l, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Text(n, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
              const SizedBox(height: 2),
              Text(l, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    return Row(children: [
      box('$present', 'Present', const Color(0xFF10B981)),
      const SizedBox(width: 8),
      box('$late', 'Late', const Color(0xFFF59E0B)),
      const SizedBox(width: 8),
      box('$wfh', 'WFH', const Color(0xFF3B82F6)),
      const SizedBox(width: 8),
      box('$leave', 'Leave', const Color(0xFF7C3AED)),
    ]);
  }

  Widget _dayRow(DateTime day, Map<String, dynamic>? a) {
    final status = a == null ? '—' : _dayStatus(a);
    final i = a == null ? null : _in(a, day);
    final o = a == null ? null : _out(a, day);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(children: [
              Text(DateFormat('E').format(day), style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              Text('${day.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              i == null
                  ? 'No check-in'
                  : '${DateFormat('hh:mm a').format(i)} – ${o == null ? '—' : DateFormat('hh:mm a').format(o)}   ·   ${_hours(i, o)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
            ),
          ),
          if (a != null) wsStatusChip(status, small: true),
        ],
      ),
    );
  }

  // ───────────────────────── Leave ─────────────────────────
  Widget _leaveView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _leaveStream,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .where((d) => FirestoreService.requesterEmail(d) == _email)
            .toList()
          ..sort((a, b) {
            final x = FirestoreService.parseAnyDate(a['fromDate'] ?? a['from']) ?? DateTime(2000);
            final y = FirestoreService.parseAnyDate(b['fromDate'] ?? b['from']) ?? DateTime(2000);
            return y.compareTo(x);
          });
        if (list.isEmpty) return wsEmpty('No leave requests from this employee.');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final d = list[i];
            final status = wsStr(d['status']).isEmpty ? 'Pending' : wsStr(d['status']);
            final color = FirestoreService.statusIs(status, 'approved')
                ? const Color(0xFF10B981)
                : FirestoreService.statusIs(status, 'rejected')
                    ? const Color(0xFFEF4444)
                    : FirestoreService.statusIs(status, 'cancelled')
                        ? const Color(0xFF6B7280)
                        : const Color(0xFFF59E0B);
            final days = wsStr(d['days'] ?? d['durationInDays']);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(wsFirst(d, ['leaveType', 'type']).isEmpty ? 'Leave' : wsFirst(d, ['leaveType', 'type']),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                        const SizedBox(height: 4),
                        Text(
                            '${wsDate(d['fromDate'] ?? d['from'])} – ${wsDate(d['toDate'] ?? d['to'])}'
                            '${days.isEmpty ? '' : '  ·  $days day${days == '1' ? '' : 's'}'}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ───────────────────────── Tasks ─────────────────────────
  Widget _tasksView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _taskStream,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!.docs
            .where((d) => FirestoreService.isDocInCurrentCompany(d))
            .map((d) => d.data() as Map<String, dynamic>)
            .where((d) =>
                FirestoreService.taskAssignedTo(d, _email,
                    name: wsName(widget.employeeData), uid: wsStr(widget.employeeData['uid'])) &&
                FirestoreService.taskBucket(d) != 'Archived')
            .toList();
        if (list.isEmpty) return wsEmpty('No tasks assigned to this employee.');
        const order = {'Overdue': 0, 'In Progress': 1, 'Assigned': 2, 'Completed': 3};
        list.sort((a, b) =>
            (order[FirestoreService.taskBucket(a)] ?? 9).compareTo(order[FirestoreService.taskBucket(b)] ?? 9));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final d = list[i];
            final b = FirestoreService.taskBucket(d);
            final color = b == 'Completed'
                ? const Color(0xFF10B981)
                : b == 'Overdue'
                    ? const Color(0xFFEF4444)
                    : b == 'In Progress'
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF5C5CFF);
            final due = FirestoreService.parseAnyDate(d['dueDate'] ?? d['due']);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(wsStr(d['title']).isEmpty ? 'Untitled Task' : wsStr(d['title']),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                        if (due != null) ...[
                          const SizedBox(height: 4),
                          Text('Due ${DateFormat('MMM d, yyyy').format(due)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(b, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
