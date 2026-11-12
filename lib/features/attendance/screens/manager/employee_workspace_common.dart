import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';

/// Shared helpers for the Employee Workspace screens. Everything shown there comes from the
/// employee's real profile (the fields saved by the web "Add Employee" form) — empty fields
/// are simply not shown, nothing is invented.

String wsStr(dynamic v) => (v ?? '').toString().trim();

String wsFirst(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = wsStr(m[k]);
    if (v.isNotEmpty) return v;
  }
  return '';
}

String wsEmail(Map<String, dynamic> m) =>
    wsFirst(m, ['email', 'workEmail', 'userEmail']).toLowerCase();

String wsName(Map<String, dynamic> m) {
  final n = wsFirst(m, ['name']);
  if (n.isNotEmpty) return n;
  final full = '${wsStr(m['firstName'])} ${wsStr(m['lastName'])}'.trim();
  return full.isNotEmpty ? full : wsEmail(m);
}

String wsDept(Map<String, dynamic> m) => wsFirst(m, ['dept', 'department']);

/// "HR Admin" / "Manager" / "Employee" (web roleLabel, else mapped from the stored role).
String wsRole(Map<String, dynamic> m) {
  final label = wsStr(m['roleLabel']);
  if (label.isNotEmpty) return label;
  switch (wsStr(m['role']).toLowerCase().replaceAll(' ', '_')) {
    case 'hr_admin':
    case 'super_admin':
    case 'admin':
      return 'HR Admin';
    case 'manager':
      return 'Manager';
    case 'employee':
      return 'Employee';
  }
  return wsStr(m['role']);
}

String wsDate(dynamic v, {String pattern = 'dd MMM yyyy'}) {
  final d = FirestoreService.parseAnyDate(v);
  return d == null ? wsStr(v) : DateFormat(pattern).format(d);
}

String wsInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

Color wsAvatarColor(String name) {
  const colors = [
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
  ];
  return colors[name.hashCode.abs() % colors.length];
}

/// Today's status of one person from live attendance + approved leave.
/// Returns one of: Present, Late, WFH, On Leave, Not Checked In, Inactive.
String wsStatusToday(
  Map<String, dynamic> user,
  Map<String, dynamic>? todayAttendance,
  bool onLeaveToday,
) {
  if (!FirestoreService.isActiveUserDoc(user)) return 'Inactive';
  if (onLeaveToday) return 'On Leave';
  final a = todayAttendance;
  if (a == null) return 'Not Checked In';
  final status = wsStr(a['status'] ?? a['attendanceStatus']).toLowerCase();
  final mode = wsStr(a['workMode']).toLowerCase();
  final hasIn = a['checkIn'] != null || a['checkInTime'] != null || a['lastCheckIn'] != null;
  if (!hasIn && !status.contains('present')) return 'Not Checked In';
  if (mode == 'wfh' || mode == 'work_from_home') return 'WFH';
  if (status.contains('late') || a['isLate'] == true) return 'Late';
  return 'Present';
}

/// Does [leave] cover today and is it approved, for this email?
bool wsOnLeaveToday(Iterable<Map<String, dynamic>> leaves, String email) {
  final t = DateTime.now();
  final today = DateTime(t.year, t.month, t.day);
  for (final d in leaves) {
    if (FirestoreService.requesterEmail(d) != email) continue;
    if (!FirestoreService.statusIs(d['status'], 'approved')) continue;
    final from = FirestoreService.parseAnyDate(d['fromDate'] ?? d['from']);
    final to = FirestoreService.parseAnyDate(d['toDate'] ?? d['to']) ?? from;
    if (from == null || to == null) continue;
    final f = DateTime(from.year, from.month, from.day);
    final e = DateTime(to.year, to.month, to.day);
    if (!today.isBefore(f) && !today.isAfter(e)) return true;
  }
  return false;
}

/// Row list entry; rows whose value is empty are skipped.
class WsRow {
  final String label;
  final String value;
  const WsRow(this.label, this.value);
}

Widget wsSectionCard(String title, List<WsRow> rows, {String emptyText = 'No details added yet'}) {
  final shown = rows.where((r) => r.value.trim().isNotEmpty).toList();
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF3F4F6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Text(emptyText, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 20, endIndent: 20),
          wsInfoRow(shown[i].label, shown[i].value),
        ],
        const SizedBox(height: 8),
      ],
    ),
  );
}

Widget wsInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
        ),
        Expanded(
          flex: 3,
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937), fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

Widget wsStatusChip(String status, {bool small = false}) {
  Color bg, fg, border;
  switch (status.toLowerCase()) {
    case 'present':
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
      border = const Color(0xFFA7F3D0);
      break;
    case 'wfh':
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF2563EB);
      border = const Color(0xFFBFDBFE);
      break;
    case 'late':
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
      border = const Color(0xFFFDE68A);
      break;
    case 'on leave':
      bg = const Color(0xFFF5F3FF);
      fg = const Color(0xFF7C3AED);
      border = const Color(0xFFDDD6FE);
      break;
    default:
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF6B7280);
      border = const Color(0xFFE5E7EB);
  }
  return Container(
    padding: EdgeInsets.symmetric(horizontal: small ? 10 : 12, vertical: small ? 4 : 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: Text(status, style: TextStyle(color: fg, fontSize: small ? 10 : 12, fontWeight: FontWeight.w700)),
  );
}

/// Oval chip row used for the workspace tabs.
Widget wsChips(List<String> labels, int selected, ValueChanged<int> onTap) {
  return SizedBox(
    height: 56,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: labels.length,
      itemBuilder: (context, i) {
        final active = i == selected;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF5C5CFF) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(labels[i],
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : const Color(0xFF6B7280))),
          ),
        );
      },
    ),
  );
}

Widget wsEmpty(String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
      ),
    );

/// Live merge of the opened profile with its latest Firestore document.
Stream<Map<String, dynamic>> wsLiveUser(Map<String, dynamic> initial) {
  final email = wsEmail(initial);
  if (email.isEmpty) return Stream.value(initial);
  return FirestoreService.employeeDoc(email).snapshots().map((d) {
    final data = d.data();
    return data == null ? initial : {...initial, ...data};
  });
}

QuerySnapshot? wsNone() => null;
