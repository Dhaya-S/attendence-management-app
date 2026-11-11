import 'dart:convert';
import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'app_session.dart';
import 'firestore_service.dart';

enum ReportFormat { csv, excel, pdf }

/// One table of a report.
class ReportSection {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  const ReportSection(this.title, this.columns, this.rows);
}

/// Everything that goes into an exported report.
class ReportData {
  final String title; // e.g. "Attendance Report"
  final String period; // e.g. "November 2026"
  final List<MapEntry<String, String>> summary;
  final List<ReportSection> sections;
  const ReportData(this.title, this.period, this.summary, this.sections);
}

/// Builds the organization reports from LIVE Firestore data (read from the server at the moment
/// the user taps Export) and delivers them as CSV, Excel (.xlsx) or PDF through the share sheet.
class ReportExporter {
  ReportExporter._();

  // ── Public entry point ──────────────────────────────────────────────────────

  static Future<void> run(BuildContext context, String reportType, ReportFormat format) async {
    final messenger = ScaffoldMessenger.of(context);
    Rect? origin;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Text('Preparing $reportType report…'),
        ]),
        duration: const Duration(seconds: 60),
      ));

    try {
      final data = await build(reportType);
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final org = (AppSession().companyName ?? 'Organization').replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final base = '${org}_${reportType}_Report_$stamp';

      late final Uint8List bytes;
      late final String fileName;
      late final String mime;
      switch (format) {
        case ReportFormat.csv:
          bytes = Uint8List.fromList(utf8.encode(toCsv(data)));
          fileName = '$base.csv';
          mime = 'text/csv';
          break;
        case ReportFormat.excel:
          bytes = toXlsx(data);
          fileName = '$base.xlsx';
          mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          break;
        case ReportFormat.pdf:
          bytes = await toPdf(data);
          fileName = '$base.pdf';
          mime = 'application/pdf';
          break;
      }

      await _deliver(bytes, fileName, mime, data.title, origin);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${data.title} ready · ${data.sections.fold<int>(0, (s, e) => s + e.rows.length)} rows'),
          backgroundColor: const Color(0xFF10B981),
        ));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Could not export the report: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
    }
  }

  static Future<ReportData> build(String reportType) {
    switch (reportType) {
      case 'Employee':
        return _employeeReport();
      case 'Department':
        return _departmentReport();
      case 'Attendance':
        return _attendanceReport();
      case 'Leave':
        return _leaveReport();
      case 'Announcement':
        return _announcementReport();
      default:
        throw 'This report cannot be exported yet';
    }
  }

  // ── Delivery ────────────────────────────────────────────────────────────────

  static Future<void> _deliver(
      Uint8List bytes, String fileName, String mime, String subject, Rect? origin) async {
    XFile file;
    if (kIsWeb) {
      file = XFile.fromData(bytes, mimeType: mime, name: fileName);
    } else {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName';
      await File(path).writeAsBytes(bytes, flush: true);
      file = XFile(path, mimeType: mime, name: fileName);
    }
    await Share.shareXFiles(
      [file],
      subject: subject,
      text: '$subject — ${AppSession().companyName ?? ''}',
      fileNameOverrides: [fileName],
      sharePositionOrigin: origin,
    );
  }

  // ── Fresh reads (server first, cache as a fallback when offline) ─────────────

  static Future<QuerySnapshot<Map<String, dynamic>>> _fresh(Query<Map<String, dynamic>> q) async {
    try {
      return await q.get(const GetOptions(source: Source.server));
    } catch (_) {
      return q.get();
    }
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> _freshDoc(DocumentReference<Map<String, dynamic>> d) async {
    try {
      return await d.get(const GetOptions(source: Source.server));
    } catch (_) {
      return d.get();
    }
  }

  // ── Small value helpers ─────────────────────────────────────────────────────

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static DateTime? _dt(dynamic v) {
    final d = FirestoreService.parseAnyDate(v);
    if (d != null) return d;
    final t = _s(v);
    for (final f in ['MMM d, yyyy', 'MMMM d, yyyy', 'd MMM yyyy', 'dd/MM/yyyy', 'dd-MM-yyyy']) {
      try {
        return DateFormat(f).parseStrict(t);
      } catch (_) {}
    }
    return null;
  }

  static String _date(dynamic v) {
    final d = _dt(v);
    return d == null ? '' : DateFormat('yyyy-MM-dd').format(d);
  }

  static String _time(dynamic v) {
    if (v == null) return '';
    final t = FirestoreService.formatTime12(v);
    if (t.isNotEmpty) return t;
    final d = FirestoreService.parseAnyDate(v);
    return d == null ? _s(v) : DateFormat('hh:mm a').format(d);
  }

  static String _dept(Map<String, dynamic> m) => _s(m['dept'] ?? m['department']);

  static String _name(Map<String, dynamic> m, [String fallback = '']) {
    final n = _s(m['name'] ?? m['fullName'] ?? m['userName'] ?? m['employee'] ?? m['applicantName']);
    if (n.isNotEmpty) return n;
    final composed = '${_s(m['firstName'])} ${_s(m['lastName'])}'.trim();
    return composed.isNotEmpty ? composed : fallback;
  }

  static String _email(Map<String, dynamic> m, [String fallback = '']) {
    final e = _s(m['email'] ?? m['workEmail'] ?? fallback).toLowerCase();
    return e;
  }

  static String _roleLabel(Map<String, dynamic> m) {
    final r = _s(m['role']).toLowerCase();
    if (r == 'hr_admin' || r == 'admin' || r == 'super_admin' || r == 'superadmin') return 'HR Admin';
    if (r == 'manager') return 'Manager';
    if (r == 'employee') return 'Employee';
    final l = _s(m['roleLabel']);
    return l.isNotEmpty ? l : (r.isEmpty ? 'Employee' : r);
  }

  static String _meta() => DateFormat('MMM d, yyyy · hh:mm a').format(DateTime.now());

  static Set<int> _workingWeekdays(dynamic v) {
    const names = {'mon': 1, 'tue': 2, 'wed': 3, 'thu': 4, 'fri': 5, 'sat': 6, 'sun': 7};
    int? day(String s) {
      final k = s.trim().toLowerCase();
      return k.length >= 3 ? names[k.substring(0, 3)] : null;
    }

    if (v is List) {
      final out = v.map((e) => day(e.toString())).whereType<int>().toSet();
      if (out.isNotEmpty) return out;
    } else if (v is String && v.trim().isNotEmpty) {
      final m = RegExp(r'^\s*([A-Za-z]{3,})\s*[–—-]\s*([A-Za-z]{3,})\s*$').firstMatch(v);
      if (m != null) {
        final a = day(m.group(1)!), b = day(m.group(2)!);
        if (a != null && b != null) {
          final out = <int>{};
          var d = a;
          for (var i = 0; i < 7; i++) {
            out.add(d);
            if (d == b) break;
            d = d % 7 + 1;
          }
          return out;
        }
      }
      final out = v.split(RegExp(r'[,/ ]+')).map(day).whereType<int>().toSet();
      if (out.isNotEmpty) return out;
    }
    return {1, 2, 3, 4, 5};
  }

  static DateTime? _holidayDate(Map<String, dynamic> m) {
    final d = _dt(m['rawDate'] ?? m['date']);
    if (d != null) return d;
    final y = int.tryParse(_s(m['year']));
    final mo = int.tryParse(_s(m['month']));
    final dd = int.tryParse(_s(m['day']));
    return (y != null && mo != null && dd != null) ? DateTime(y, mo, dd) : null;
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _people() async {
    final snap = await _fresh(FirestoreService.employeesCol);
    final docs = snap.docs.where((d) => FirestoreService.isDocInCurrentCompany(d)).toList();
    docs.sort((a, b) => _name(a.data(), a.id).toLowerCase().compareTo(_name(b.data(), b.id).toLowerCase()));
    return docs;
  }

  // ── 1. Employee report ──────────────────────────────────────────────────────

  static Future<ReportData> _employeeReport() async {
    final people = await _people();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    int active = 0, inactive = 0, joiners = 0;
    final depts = <String>{};
    final rows = <List<String>>[];
    for (final d in people) {
      final m = d.data();
      final isActive = FirestoreService.isActiveUserDoc(m);
      isActive ? active++ : inactive++;
      final dept = _dept(m);
      if (isActive && dept.isNotEmpty) depts.add(dept);
      final joined = _dt(m['joinDate'] ?? m['joiningDate'] ?? m['dateOfJoining']);
      if (isActive && joined != null && !joined.isBefore(monthStart)) joiners++;
      rows.add([
        _s(m['id'] ?? m['employeeId']),
        _name(m, d.id),
        _email(m, d.id),
        dept,
        _s(m['designation']),
        _roleLabel(m),
        _s(m['branch'] ?? m['location']),
        _s(m['manager'] ?? m['managerName']),
        _s(m['empType'] ?? m['employmentType']),
        joined == null ? '' : DateFormat('yyyy-MM-dd').format(joined),
        isActive ? 'Active' : 'Inactive',
        _s(m['phone'] ?? m['mobile']),
      ]);
    }

    return ReportData(
      'Employee Report',
      'As on ${DateFormat('MMM d, yyyy').format(now)}',
      [
        MapEntry('Total employees (active)', '$active'),
        MapEntry('Inactive', '$inactive'),
        MapEntry('Departments', '${depts.length}'),
        MapEntry('Joiners this month', '$joiners'),
      ],
      [
        ReportSection('Employees', [
          'Employee ID', 'Name', 'Email', 'Department', 'Designation', 'Role', 'Branch',
          'Reporting Manager', 'Employment Type', 'Join Date', 'Status', 'Phone'
        ], rows),
      ],
    );
  }

  // ── Today's attendance + leave lookups shared by several reports ─────────────

  static Future<Map<String, Map<String, dynamic>>> _todayAttendance() async {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snap = await _fresh(FirestoreService.attendanceCol);
    final out = <String, Map<String, dynamic>>{};
    for (final d in snap.docs) {
      final m = d.data();
      final isToday = d.id.endsWith('_$todayKey') || _s(m['date']) == todayKey;
      if (!isToday) continue;
      out[_s(m['email'] ?? d.id.split('_').first).toLowerCase()] = m;
    }
    return out;
  }

  // ── 2. Department report ────────────────────────────────────────────────────

  static Future<ReportData> _departmentReport() async {
    final people = await _people();
    final attToday = await _todayAttendance();
    final leaveSnap = await _fresh(FirestoreService.leaveRequestsCol);
    final deptSnap = await _fresh(FirestoreService.companyDoc().collection('departments'));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final heads = <String, String>{};
    for (final d in deptSnap.docs) {
      final m = d.data();
      final n = _s(m['name']).toLowerCase();
      if (n.isNotEmpty) heads[n] = _s(m['head']).isNotEmpty ? _s(m['head']) : _s(m['headEmail']);
    }

    final onLeave = <String>{};
    final pendingByEmail = <String, int>{};
    for (final d in leaveSnap.docs) {
      if (!FirestoreService.isDocInCurrentCompany(d)) continue;
      final m = d.data();
      final email = FirestoreService.requesterEmail(m);
      if (FirestoreService.statusIs(m['status'], 'pending')) {
        pendingByEmail[email] = (pendingByEmail[email] ?? 0) + 1;
      }
      if (!FirestoreService.statusIs(m['status'], 'approved')) continue;
      final from = _dt(m['fromDate'] ?? m['from']);
      final to = _dt(m['toDate'] ?? m['to']) ?? from;
      if (from == null || to == null) continue;
      if (todayDate.isBefore(DateTime(from.year, from.month, from.day)) ||
          todayDate.isAfter(DateTime(to.year, to.month, to.day))) {
        continue;
      }
      onLeave.add(email);
    }

    // department → counters
    final stats = <String, List<int>>{}; // [employees, present, late, wfh, leave, notMarked, pending]
    for (final d in people) {
      final m = d.data();
      if (!FirestoreService.isActiveUserDoc(m)) continue;
      final dept = _dept(m).isEmpty ? 'Unassigned' : _dept(m);
      final email = _email(m, d.id);
      final s = stats.putIfAbsent(dept, () => List.filled(7, 0));
      s[0]++;
      final rec = attToday[email];
      if (rec != null) {
        final st = _s(rec['status'] ?? rec['attendanceStatus']).toLowerCase();
        final isWfh = rec['workMode'] == 'wfh' || st == 'wfh';
        if (isWfh) {
          s[3]++;
        } else {
          s[1]++;
          if (rec['isLate'] == true || st == 'late') s[2]++;
        }
      } else if (onLeave.contains(email)) {
        s[4]++;
      } else {
        s[5]++;
      }
      s[6] += pendingByEmail[email] ?? 0;
    }

    final names = stats.keys.toList()..sort();
    final rows = <List<String>>[];
    final total = List.filled(7, 0);
    for (final n in names) {
      final s = stats[n]!;
      for (var i = 0; i < 7; i++) {
        total[i] += s[i];
      }
      rows.add([n, heads[n.toLowerCase()] ?? '', ...s.map((e) => '$e')]);
    }
    rows.add(['TOTAL', '', ...total.map((e) => '$e')]);

    return ReportData(
      'Department Report',
      'Today, ${DateFormat('MMM d, yyyy').format(today)}',
      [
        MapEntry('Departments', '${names.length}'),
        MapEntry('Active employees', '${total[0]}'),
        MapEntry('Present today', '${total[1]}'),
        MapEntry('WFH today', '${total[3]}'),
        MapEntry('On leave today', '${total[4]}'),
      ],
      [
        ReportSection('Departments', [
          'Department', 'Head', 'Employees', 'Present Today', 'of which Late', 'WFH Today',
          'On Leave Today', 'Not Marked Today', 'Pending Leave Requests'
        ], rows),
      ],
    );
  }

  // ── 3. Attendance report (current month, every employee, every working day) ──

  static Future<ReportData> _attendanceReport() async {
    final people = await _people();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final startKey = DateFormat('yyyy-MM-dd').format(monthStart);
    final todayKey = DateFormat('yyyy-MM-dd').format(today);

    final attSnap = await _fresh(FirestoreService.attendanceCol);
    final leaveSnap = await _fresh(FirestoreService.leaveRequestsCol);
    final holSnap = await _fresh(FirestoreService.companyDoc().collection('holidays'));
    final shiftSnap = await _fresh(FirestoreService.shiftsCol);

    final shifts = shiftSnap.docs.map((d) {
      final m = Map<String, dynamic>.from(d.data());
      m['id'] = m['id'] ?? d.id;
      return m;
    }).toList();

    final holidays = <String>{};
    for (final d in holSnap.docs) {
      final dt = _holidayDate(d.data());
      if (dt != null) holidays.add(DateFormat('yyyy-MM-dd').format(dt));
    }

    // approved leave days per person
    final leaveDays = <String, Set<String>>{};
    for (final d in leaveSnap.docs) {
      if (!FirestoreService.isDocInCurrentCompany(d)) continue;
      final m = d.data();
      if (!FirestoreService.statusIs(m['status'], 'approved')) continue;
      final email = FirestoreService.requesterEmail(m);
      final from = _dt(m['fromDate'] ?? m['from']);
      final to = _dt(m['toDate'] ?? m['to']) ?? from;
      if (from == null || to == null) continue;
      var c = DateTime(from.year, from.month, from.day);
      final end = DateTime(to.year, to.month, to.day);
      while (!c.isAfter(end)) {
        leaveDays.putIfAbsent(email, () => {}).add(DateFormat('yyyy-MM-dd').format(c));
        c = c.add(const Duration(days: 1));
      }
    }

    // records of this month by (email, date)
    final records = <String, Map<String, dynamic>>{};
    for (final d in attSnap.docs) {
      if (!FirestoreService.isDocInCurrentCompany(d)) continue;
      final m = d.data();
      var date = _s(m['date']);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
        final idx = d.id.lastIndexOf('_');
        date = idx > 0 ? d.id.substring(idx + 1) : _date(m['date'] ?? m['dateTimestamp']);
      }
      if (date.compareTo(startKey) < 0 || date.compareTo(todayKey) > 0) continue;
      final email = _s(m['email'] ?? (d.id.contains('_') ? d.id.substring(0, d.id.lastIndexOf('_')) : d.id)).toLowerCase();
      records['$email|$date'] = m;
    }

    int present = 0, late = 0, wfh = 0, leave = 0, absent = 0, notMarked = 0, workingDayTotal = 0;
    final rows = <List<String>>[];

    for (final p in people) {
      final m = p.data();
      if (!FirestoreService.isActiveUserDoc(m)) continue;
      final email = _email(m, p.id);
      final shift = FirestoreService.pickShiftFor(m, shifts);
      final workDays = _workingWeekdays(shift?['days'] ?? shift?['workingDays'] ?? shift?['weeklyOff']);
      final shiftName = shift == null ? '' : FirestoreService.shiftLabel(shift);

      var day = monthStart;
      while (!day.isAfter(today)) {
        final key = DateFormat('yyyy-MM-dd').format(day);
        final rec = records['$email|$key'];
        final isWorkDay = workDays.contains(day.weekday) && !holidays.contains(key);
        if (isWorkDay) workingDayTotal++;

        String status = '';
        String mode = '';
        String cin = '', cout = '', hours = '', isLate = '', place = '';
        if (rec != null) {
          final st = _s(rec['status'] ?? rec['attendanceStatus']).toLowerCase();
          final wfhDay = rec['workMode'] == 'wfh' || st == 'wfh';
          final lateDay = rec['isLate'] == true || st == 'late';
          status = wfhDay ? 'WFH' : (lateDay ? 'Late' : (st == 'half day' ? 'Half Day' : 'Present'));
          mode = wfhDay ? 'WFH' : 'Office';
          cin = _time(rec['checkInTime'] ?? rec['checkIn']);
          cout = _time(rec['checkOutTime'] ?? rec['checkOut']);
          hours = _s(rec['hoursWorked']);
          isLate = lateDay ? 'Yes' : 'No';
          place = _s(rec['location']);
          if (wfhDay) {
            wfh++;
          } else if (lateDay) {
            late++;
          } else {
            present++;
          }
        } else if (leaveDays[email]?.contains(key) == true) {
          status = 'On Leave';
          leave++;
        } else if (!isWorkDay) {
          day = day.add(const Duration(days: 1));
          continue; // weekend / holiday with no record: not a row
        } else if (day == today) {
          status = 'Not Marked';
          notMarked++;
        } else {
          status = 'Absent';
          absent++;
        }

        rows.add([
          key,
          DateFormat('EEE').format(day),
          _s(m['id'] ?? m['employeeId']),
          _name(m, p.id),
          email,
          _dept(m),
          status,
          mode,
          cin,
          cout,
          hours,
          shiftName,
          isLate,
          place,
        ]);
        day = day.add(const Duration(days: 1));
      }
    }

    final worked = present + late + wfh;
    final denominator = worked + absent;
    final rate = denominator == 0 ? '—' : '${(worked / denominator * 100).toStringAsFixed(1)}%';

    return ReportData(
      'Attendance Report',
      '${DateFormat('MMMM yyyy').format(now)} (1 – ${DateFormat('d MMM').format(today)})',
      [
        MapEntry('Employees', '${people.where((d) => FirestoreService.isActiveUserDoc(d.data())).length}'),
        MapEntry('Working days (employee-days)', '$workingDayTotal'),
        MapEntry('Present', '$present'),
        MapEntry('Late', '$late'),
        MapEntry('WFH', '$wfh'),
        MapEntry('On leave', '$leave'),
        MapEntry('Absent', '$absent'),
        MapEntry('Not marked today', '$notMarked'),
        MapEntry('Attendance rate', rate),
      ],
      [
        ReportSection('Daily attendance', [
          'Date', 'Day', 'Employee ID', 'Employee', 'Email', 'Department', 'Status', 'Work Mode',
          'Check In', 'Check Out', 'Hours Worked', 'Shift', 'Late', 'Location'
        ], rows),
      ],
    );
  }

  // ── 4. Leave report (requests + balances) ───────────────────────────────────

  static Future<ReportData> _leaveReport() async {
    final people = await _people();
    final leaveSnap = await _fresh(FirestoreService.leaveRequestsCol);
    final typesSnap = await _fresh(FirestoreService.companyDoc().collection('leave_types'));
    final orgSnap = await _freshDoc(FirestoreService.companyDoc());
    final now = DateTime.now();

    final byEmail = <String, Map<String, dynamic>>{};
    for (final p in people) {
      byEmail[_email(p.data(), p.id)] = p.data();
    }

    final leaves = leaveSnap.docs.where((d) => FirestoreService.isDocInCurrentCompany(d)).toList();
    leaves.sort((a, b) {
      final ad = _dt(a.data()['createdAt'] ?? a.data()['requestDate'] ?? a.data()['from']) ?? DateTime(2000);
      final bd = _dt(b.data()['createdAt'] ?? b.data()['requestDate'] ?? b.data()['from']) ?? DateTime(2000);
      return bd.compareTo(ad);
    });

    int pending = 0, approved = 0, rejected = 0, cancelled = 0, approvedDays = 0;
    final rows = <List<String>>[];
    final perEmailThisYear = <String, List<Map<String, dynamic>>>{};

    for (final d in leaves) {
      final m = d.data();
      final email = FirestoreService.requesterEmail(m);
      final person = byEmail[email];
      final status = _s(m['status']).toLowerCase();
      final days = (m['days'] ?? m['durationInDays']) is num
          ? ((m['days'] ?? m['durationInDays']) as num).toInt()
          : int.tryParse(_s(m['days'] ?? m['durationInDays'])) ?? 1;
      if (status == 'pending') {
        pending++;
      } else if (status == 'approved') {
        approved++;
        approvedDays += days;
      } else if (status == 'rejected') {
        rejected++;
      } else if (status == 'cancelled') {
        cancelled++;
      }

      final from = _dt(m['fromDate'] ?? m['from']);
      if (from != null && from.year == now.year) {
        perEmailThisYear.putIfAbsent(email, () => []).add(m);
      }

      rows.add([
        _s(m['id'] ?? d.id),
        _name(m, _name(person ?? {}, email)),
        email,
        _s(m['dept']).isNotEmpty ? _s(m['dept']) : _dept(person ?? {}),
        _s(m['leaveType'] ?? m['type']),
        _date(m['fromDate'] ?? m['from']),
        _date(m['toDate'] ?? m['to']),
        '$days',
        status.isEmpty ? 'Pending' : '${status[0].toUpperCase()}${status.substring(1)}',
        _date(m['createdAt'] ?? m['requestDate']),
        _s(m['approvedBy'] ?? m['rejectedBy']),
        _date(m['approvedAt'] ?? m['rejectedAt'] ?? m['cancelledAt']),
        _s(m['reason']),
        _s(m['rejectReason'] ?? m['rejectNote']),
      ]);
    }

    // balances for the current year (same numbers as the app / web Leave screens)
    final limits = FirestoreService.leaveLimits(typesSnap, orgSnap.data());
    final balanceRows = <List<String>>[];
    for (final p in people) {
      final m = p.data();
      if (!FirestoreService.isActiveUserDoc(m)) continue;
      final email = _email(m, p.id);
      final u = FirestoreService.leaveUsage(perEmailThisYear[email] ?? const []);
      final usedTotal = u[0] + u[1] + u[2];
      final maxTotal = limits[0] + limits[1] + limits[2];
      final left = maxTotal - usedTotal;
      balanceRows.add([
        _name(m, p.id),
        email,
        _dept(m),
        '${u[0]} / ${limits[0]}',
        '${u[1]} / ${limits[1]}',
        '${u[2]} / ${limits[2]}',
        '$usedTotal',
        '${left < 0 ? 0 : left}',
      ]);
    }

    return ReportData(
      'Leave Report',
      'All requests · balances for ${now.year}',
      [
        MapEntry('Total requests', '${leaves.length}'),
        MapEntry('Pending', '$pending'),
        MapEntry('Approved', '$approved'),
        MapEntry('Rejected', '$rejected'),
        MapEntry('Cancelled', '$cancelled'),
        MapEntry('Approved leave days', '$approvedDays'),
        MapEntry('Yearly entitlement', 'Annual ${limits[0]} · Sick ${limits[1]} · Casual ${limits[2]}'),
      ],
      [
        ReportSection('Leave requests', [
          'Request ID', 'Employee', 'Email', 'Department', 'Leave Type', 'From', 'To', 'Days', 'Status',
          'Applied On', 'Decided By', 'Decided On', 'Reason', 'Reason Given'
        ], rows),
        ReportSection('Leave balance ${now.year} (used / entitlement)', [
          'Employee', 'Email', 'Department', 'Annual', 'Sick', 'Casual', 'Total Used', 'Total Remaining'
        ], balanceRows),
      ],
    );
  }

  // ── 5. Announcement report ──────────────────────────────────────────────────

  static Future<ReportData> _announcementReport() async {
    final orgSnap = await _fresh(FirestoreService.announcementsCol);
    final teamSnap = await _fresh(FirestoreService.teamAnnouncementsCol);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final items = <MapEntry<String, QueryDocumentSnapshot<Map<String, dynamic>>>>[
      ...orgSnap.docs.map((d) => MapEntry('Organization', d)),
      ...teamSnap.docs.map((d) => MapEntry('Team', d)),
    ];
    DateTime when(Map<String, dynamic> m) =>
        _dt(m['createdAt'] ?? m['timestamp'] ?? m['publishedAt'] ?? m['date']) ?? DateTime(2000);
    items.sort((a, b) => when(b.value.data()).compareTo(when(a.value.data())));

    int published = 0, drafts = 0, thisMonth = 0;
    final rows = <List<String>>[];
    for (final e in items) {
      final m = e.value.data();
      final status = _s(m['status']).isEmpty ? 'Published' : _s(m['status']);
      final isDraft = status.toLowerCase() == 'draft' || m['isDraft'] == true;
      isDraft ? drafts++ : published++;
      final dt = when(m);
      if (dt.year > 2000 && !dt.isBefore(monthStart)) thisMonth++;
      final attachments = m['attachments'] is List ? (m['attachments'] as List).length : 0;
      final comments = m['commentsCount'] is num ? (m['commentsCount'] as num).toInt() : 0;
      final likes = m['likes'] is num ? (m['likes'] as num).toInt() : 0;
      rows.add([
        _s(m['title']),
        e.key,
        _s(m['category']),
        _s(m['priority']),
        _s(m['audience']).isNotEmpty ? _s(m['audience']) : _s(m['audienceType'] ?? m['dept']),
        _s(m['author'] ?? m['authorName']),
        dt.year > 2000 ? DateFormat('yyyy-MM-dd HH:mm').format(dt) : '',
        isDraft ? 'Draft' : 'Published',
        '$likes',
        '$comments',
        '$attachments',
        _date(m['expiry']),
      ]);
    }

    return ReportData(
      'Announcement Report',
      'All announcements',
      [
        MapEntry('Total announcements', '${items.length}'),
        MapEntry('Published', '$published'),
        MapEntry('Drafts', '$drafts'),
        MapEntry('Published this month', '$thisMonth'),
      ],
      [
        ReportSection('Announcements', [
          'Title', 'Type', 'Category', 'Priority', 'Audience', 'Author', 'Published On', 'Status',
          'Likes', 'Comments', 'Attachments', 'Expires'
        ], rows),
      ],
    );
  }

  // ── Writers ─────────────────────────────────────────────────────────────────

  static String _csvCell(String v) {
    var s = v;
    // keep spreadsheet apps from running cell text as a formula
    if (s.isNotEmpty && '=+-@'.contains(s[0]) && !RegExp(r'^-?\d+([.,]\d+)?%?$').hasMatch(s)) {
      s = "'$s";
    }
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String toCsv(ReportData d) {
    final b = StringBuffer('﻿'); // UTF-8 BOM so Excel shows every character correctly
    void line(List<String> cells) => b.writeln(cells.map(_csvCell).join(','));

    line([d.title]);
    line(['Organization', AppSession().companyName ?? '']);
    line(['Period', d.period]);
    line(['Generated', _meta()]);
    b.writeln();
    for (final s in d.summary) {
      line([s.key, s.value]);
    }
    for (final section in d.sections) {
      b.writeln();
      if (d.sections.length > 1) line([section.title]);
      line(section.columns);
      for (final r in section.rows) {
        line(r);
      }
    }
    return b.toString();
  }

  static Uint8List toXlsx(ReportData d) {
    final book = xl.Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();

    String sheetName(String s) {
      final cleaned = s.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ').trim();
      return cleaned.length > 31 ? cleaned.substring(0, 31) : (cleaned.isEmpty ? 'Sheet' : cleaned);
    }

    xl.CellStyle header() => xl.CellStyle(
          bold: true,
          backgroundColorHex: xl.ExcelColor.fromHexString('#EEF2FF'),
          fontColorHex: xl.ExcelColor.fromHexString('#3730A3'),
        );

    // Summary sheet
    final summary = book[sheetName('Summary')];
    summary.appendRow([xl.TextCellValue(d.title)]);
    summary.appendRow([xl.TextCellValue('Organization'), xl.TextCellValue(AppSession().companyName ?? '')]);
    summary.appendRow([xl.TextCellValue('Period'), xl.TextCellValue(d.period)]);
    summary.appendRow([xl.TextCellValue('Generated'), xl.TextCellValue(_meta())]);
    summary.appendRow([xl.TextCellValue('')]);
    for (final s in d.summary) {
      summary.appendRow([xl.TextCellValue(s.key), xl.TextCellValue(s.value)]);
    }
    summary.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle =
        xl.CellStyle(bold: true, fontSize: 14);
    summary.setColumnWidth(0, 34);
    summary.setColumnWidth(1, 40);

    // One sheet per table
    final used = <String>{'Summary'};
    for (final section in d.sections) {
      var name = sheetName(section.title);
      var n = 2;
      while (used.contains(name)) {
        name = sheetName('${section.title} $n');
        n++;
      }
      used.add(name);
      final sheet = book[name];
      sheet.appendRow(section.columns.map((c) => xl.TextCellValue(c)).toList());
      for (var i = 0; i < section.columns.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = header();
        sheet.setColumnWidth(i, 18);
      }
      for (final r in section.rows) {
        sheet.appendRow(r.map((c) => xl.TextCellValue(c)).toList());
      }
    }

    if (defaultSheet != null && !used.contains(defaultSheet)) {
      book.delete(defaultSheet);
    }
    book.setDefaultSheet('Summary');
    final out = book.encode();
    if (out == null) throw 'Could not create the Excel file';
    return Uint8List.fromList(out);
  }

  static String _pdfSafe(String s) {
    const map = {
      '–': '-', '—': '-', '‘': "'", '’': "'", '“': '"', '”': '"', '•': '-', '…': '...', '·': '-', '₹': 'Rs ',
    };
    final b = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      if (map.containsKey(ch)) {
        b.write(map[ch]);
      } else if (r < 256) {
        b.write(ch);
      } else {
        b.write('?');
      }
    }
    return b.toString();
  }

  static Future<Uint8List> toPdf(ReportData d) async {
    final doc = pw.Document(title: d.title, author: AppSession().companyName ?? 'Workzi');
    const accent = PdfColor.fromInt(0xFF5C5CFF);

    pw.Widget table(ReportSection s) {
      final wide = s.columns.length > 9;
      return pw.TableHelper.fromTextArray(
        headers: s.columns.map(_pdfSafe).toList(),
        data: s.rows.map((r) => r.map(_pdfSafe).toList()).toList(),
        headerStyle: pw.TextStyle(fontSize: wide ? 6.5 : 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: accent),
        cellStyle: pw.TextStyle(fontSize: wide ? 6.5 : 8),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4))),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
        border: null,
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(_pdfSafe('${AppSession().companyName ?? ''}  ·  ${d.title}'),
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ]),
        ),
        build: (ctx) => [
          pw.Text(_pdfSafe(d.title), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: accent)),
          pw.SizedBox(height: 2),
          pw.Text(_pdfSafe('${d.period}   ·   Generated ${_meta()}'), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 10),
          pw.Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in d.summary)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFEEF2FF), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(_pdfSafe(s.value), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_pdfSafe(s.key), style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                ]),
              ),
          ]),
          for (final section in d.sections) ...[
            pw.SizedBox(height: 14),
            if (d.sections.length > 1)
              pw.Text(_pdfSafe(section.title), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            if (d.sections.length > 1) pw.SizedBox(height: 4),
            if (section.rows.isEmpty)
              pw.Text('No records.', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))
            else
              table(section),
          ],
        ],
      ),
    );
    return Uint8List.fromList(await doc.save());
  }
}
