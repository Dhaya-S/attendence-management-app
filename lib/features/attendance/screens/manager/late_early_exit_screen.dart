import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class LateEarlyExitScreen extends StatefulWidget {
  const LateEarlyExitScreen({super.key});

  @override
  State<LateEarlyExitScreen> createState() => _LateEarlyExitScreenState();
}

class _LateEarlyExitScreenState extends State<LateEarlyExitScreen> {
  static const Color _indigo = Color(0xFF6366F1);
  static const Color _amber = Color(0xFFFFB020);
  static const Color _rose = Color(0xFFF43F5E);
  static const Color _slate = Color(0xFF1E293B);

  DateTime _currentDate = DateTime.now();
  String _selectedFilter = 'all'; // 'all', 'late', 'early'
  bool _isAscending = false; // Sort order for date

  @override
  void initState() {
    super.initState();
  }

  String get _monthName => DateFormat('MMMM yyyy').format(_currentDate);

  void _previousMonth() => setState(
      () => _currentDate = DateTime(_currentDate.year, _currentDate.month - 1));
  void _nextMonth() => setState(
      () => _currentDate = DateTime(_currentDate.year, _currentDate.month + 1));

  @override
  Widget build(BuildContext context) {
    final startOfMonth =
        DateTime(_currentDate.year, _currentDate.month, 1);
    final endOfMonth =
        DateTime(_currentDate.year, _currentDate.month + 1, 0, 23, 59, 59);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _slate, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Late & Early Exits',
          style: TextStyle(
              color: _slate, fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.companyUsersQuery.snapshots(),
        builder: (context, usersSnap) {
          final usersDocs = usersSnap.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.allAttendanceRecordsCol
                .snapshots(),
            builder: (context, recordsSnap) {
              if (recordsSnap.connectionState == ConnectionState.waiting &&
                  !recordsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = recordsSnap.data?.docs ?? [];

              // ── Month filter ──────────────────────────────────
              final monthRecords = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final dateTs = data['date'] as Timestamp?;
                if (dateTs == null) return false;
                final date = dateTs.toDate();
                return !date.isBefore(startOfMonth) &&
                    !date.isAfter(endOfMonth);
              }).toList();


              // ── Build month log lists ─────────────────────────
              final List<Map<String, dynamic>> lateLogs = [];
              final List<Map<String, dynamic>> earlyLogs = [];

              for (final doc in monthRecords) {
                final data = doc.data() as Map<String, dynamic>;
                final uid = doc.reference.parent.parent?.id;

                String empName = 'Employee';
                String designation = '';
                if (uid != null) {
                  final match =
                      usersDocs.where((u) => u.id == uid).toList();
                  if (match.isNotEmpty) {
                    final ud =
                        match.first.data() as Map<String, dynamic>;
                    empName = ud['name'] ?? 'Employee';
                    designation = ud['designation'] ?? '';
                  }
                }

                final checkInTs = data['checkIn'] as Timestamp?;
                final checkOutTs = data['checkOut'] as Timestamp?;
                final dateTs = data['date'] as Timestamp?;
                if (dateTs == null) continue;
                final date = dateTs.toDate();

                if (checkInTs != null) {
                  final ci = checkInTs.toDate();
                  final sParts = AppSession().shiftStartTime.split(':');
                  final lateThreshold = DateTime(ci.year, ci.month, ci.day,
                      int.parse(sParts[0]), int.parse(sParts[1]))
                      .add(Duration(minutes: AppSession().gracePeriod));
                  if (ci.isAfter(lateThreshold)) {
                    lateLogs.add({
                      'name': empName,
                      'designation': designation,
                      'date': date,
                      'checkIn': ci,
                      'type': 'LATE ARRIVAL',
                    });
                  }
                }

                if (checkOutTs != null) {
                  final co = checkOutTs.toDate();
                  final eParts = AppSession().shiftEndTime.split(':');
                  final endThreshold = DateTime(co.year, co.month, co.day,
                      int.parse(eParts[0]), int.parse(eParts[1]));
                  if (co.isBefore(endThreshold)) {
                    earlyLogs.add({
                      'name': empName,
                      'designation': designation,
                      'date': date,
                      'checkOut': co,
                      'type': 'EARLY EXIT',
                    });
                  }
                }
              }

              List<Map<String, dynamic>> allLogs;
              if (_selectedFilter == 'late') {
                allLogs = lateLogs;
              } else if (_selectedFilter == 'early') {
                allLogs = earlyLogs;
              } else {
                allLogs = [...lateLogs, ...earlyLogs];
              }

              allLogs.sort((a, b) {
                final dateA = a['date'] as DateTime;
                final dateB = b['date'] as DateTime;
                return _isAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
              });

              // ── UI ────────────────────────────────────────────
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthSelector(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                              'LATE ARRIVALS',
                              '${lateLogs.length}'.padLeft(2, '0'),
                              Icons.access_time_rounded,
                              _amber,
                              isSelected: _selectedFilter == 'late',
                              onTap: () => setState(() => _selectedFilter = _selectedFilter == 'late' ? 'all' : 'late'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _statCard(
                              'EARLY EXITS',
                              '${earlyLogs.length}'.padLeft(2, '0'),
                              Icons.logout_rounded,
                              _rose,
                              isSelected: _selectedFilter == 'early',
                              onTap: () => setState(() => _selectedFilter = _selectedFilter == 'early' ? 'all' : 'early'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Detailed Logs',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _slate),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isAscending = !_isAscending),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _isAscending ? 'Oldest first' : 'Newest first',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate),
                                ),
                                const SizedBox(width: 4),
                                Icon(_isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: _slate),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (allLogs.isEmpty)
                      _buildEmpty()
                    else
                      ...allLogs.map((log) => _logCard(log)),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Month Selector ────────────────────────────────────────────────────────
  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: _indigo, size: 20),
            onPressed: _previousMonth,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Text(_monthName,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _slate)),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded,
                color: _indigo, size: 20),
            onPressed: _nextMonth,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Stat Card ─────────────────────────────────────────────────────────────
  Widget _statCard(
      String label, String value, IconData icon, Color color, {bool isSelected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color.withOpacity(0.3) : const Color(0xFFF0F1F3), width: 1.5),
        ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                                letterSpacing: 0.5)),
                      ),
                      const Spacer(),
                      Icon(icon, size: 14, color: color),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: _slate,
                          height: 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // ── Log Card ──────────────────────────────────────────────────────────────
  Widget _logCard(Map<String, dynamic> log) {
    final bool isLate = log['type'] == 'LATE ARRIVAL';
    final String name = log['name'] ?? 'Employee';
    final DateTime date = log['date'];
    final Color badgeColor = isLate ? _amber : _rose;

    final String actualTime = isLate
        ? DateFormat('hh:mm a').format(log['checkIn'] as DateTime)
        : DateFormat('hh:mm a').format(log['checkOut'] as DateTime);
    final String expectedTime = isLate
        ? _formatShiftTime(AppSession().shiftStartTime)
        : _formatShiftTime(AppSession().shiftEndTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: badgeColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + badge
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _slate),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(log['type'],
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                              letterSpacing: 0.3)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Date + day name
                Row(
                  children: [
                    Text(
                      DateFormat('MMMM dd, yyyy').format(date),
                      style: const TextStyle(
                          fontSize: 12,
                          color: _slate,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('EEEE').format(date),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Actual / Expected times
                Row(
                  children: [
                    _timeChip('ACTUAL', actualTime, _slate),
                    const SizedBox(width: 28),
                    _timeChip('EXPECTED', expectedTime,
                        Colors.grey[400]!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String label, String time, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(time,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  // ── Shift Time Formatter ──────────────────────────────────────────────────
  String _formatShiftTime(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final dt = DateTime(2000, 1, 1, hour, minute);
    return DateFormat('hh:mm a').format(dt);
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 64,
                color: Colors.green.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text('No Issues Found',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _slate)),
            const SizedBox(height: 8),
            Text(
              'No late arrivals or early exits this month.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
