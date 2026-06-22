import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'dart:async';

class ManagerCalendarTab extends StatefulWidget {
  final Function(int)? onTabChange;
  const ManagerCalendarTab({super.key, this.onTabChange});

  @override
  State<ManagerCalendarTab> createState() => _ManagerCalendarTabState();
}

class _ManagerCalendarTabState extends State<ManagerCalendarTab> {
  DateTime? _focusedDay;
  DateTime? _selectedDay;
  DateTime get _safeFocusedDay => _focusedDay ?? DateTime.now();

  // Multi-selection state
  final Set<DateTime> _selectedDays = {};
  bool _isMultiSelect = false;

  List<Map<String, dynamic>> _holidays = [];
  bool _isLoading = true;
  bool _showAllHolidays = false;
  StreamSubscription? _holidaySubscription;

  static const String _apiKey = 'AIzaSyCvsRp7brHoYQdglX9YH2dtl15VSUdwS-M';
  static const String _calendarId =
      'en.indian%23holiday%40group.v.calendar.google.com';

  // ── Colours ─────────────────────────────────────────────────────────────
  static const Color _green = Color(0xFF10B981);
  static const Color _blue  = Color(0xFF3B82F6);
  static const Color _red   = Color(0xFFEF4444);
  static const Color _purple = Color(0xFF5C5CFF);

  static const Color _greenBg = Color(0xFFECFDF5);
  static const Color _blueBg  = Color(0xFFEFF6FF);
  static const Color _redBg   = Color(0xFFFEF2F2);
  static const Color _purpleBg = Color(0xFFEEF0FF);

  Color _colorOf(String type) {
    if (type == 'leave')    return _red;
    if (type == 'wfh')      return _purple;
    return _blue;
  }

  Color _bgOf(String type) {
    if (type == 'leave')    return _redBg;
    if (type == 'wfh')      return _purpleBg;
    return _blueBg;
  }

  String _labelOf(String type) {
    if (type == 'leave')    return 'Company Holiday';
    if (type == 'wfh')      return 'Work From Home';
    return 'Event';
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _listenHolidays();
  }

  @override
  void dispose() {
    _holidaySubscription?.cancel();
    super.dispose();
  }

  // Removed _fetchAttendance


  void _listenHolidays() {
    try {
      final cid = FirestoreService.companyId;
      _holidaySubscription?.cancel();
      _holidaySubscription = FirebaseFirestore.instance
          .collection('approved_companies')
          .doc(cid)
          .collection('company_calendar')
          .snapshots()
          .listen((snapshot) {
        final List<Map<String, dynamic>> parsed = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final date = (data['date'] as Timestamp).toDate();
          final type = data['type']; // 'leave' or 'wfh'
          parsed.add({
            'name': data['reason'] ?? (type == 'leave' ? 'Company Holiday' : 'WFH Day'),
            'date': date,
            'type': type,
            'isCompanyEvent': true,
          });
        }

        parsed.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

        if (mounted) {
          setState(() {
            _holidays = parsed;
            _isLoading = false;
          });
        }
      }, onError: (e) {
        debugPrint('Error listening to holidays: $e');
        if (mounted) setState(() => _isLoading = false);
      });
    } catch (e) {
      debugPrint('Error listening to holidays: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (_isMultiSelect) {
      setState(() {
        _focusedDay = focusedDay;
        bool exists = _selectedDays.any((d) => isSameDay(d, selectedDay));
        if (exists) {
          _selectedDays.removeWhere((d) => isSameDay(d, selectedDay));
        } else {
          _selectedDays.add(selectedDay);
        }
        
        if (_selectedDays.isEmpty) {
          _isMultiSelect = false;
        }
      });
    } else {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _showActionSheet(selectedDay);
    }
  }

  void _onDayLongPressed(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _isMultiSelect = true;
      _selectedDays.add(selectedDay);
      _focusedDay = focusedDay;
    });
  }

  void _showActionSheet(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CalendarActionSheet(
        dates: [date],
        onApply: (type, isFullDay, reason) => _applyAction(type, isFullDay, reason, [date]),
      ),
    );
  }

  void _showMultiSelectActionSheet() {
    if (_selectedDays.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CalendarActionSheet(
        dates: _selectedDays.toList()..sort(),
        onApply: (type, isFullDay, reason) => _applyAction(type, isFullDay, reason, _selectedDays.toList()),
      ),
    );
  }

  Future<void> _applyAction(String type, bool isFullDay, String reason, List<DateTime> dates) async {
    setState(() => _isLoading = true);
    try {
      final cid = FirestoreService.companyId;
      final batch = FirebaseFirestore.instance.batch();

      for (var date in dates) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final docRef = FirebaseFirestore.instance
            .collection('approved_companies')
            .doc(cid)
            .collection('company_calendar')
            .doc(dateStr);

        batch.set(docRef, {
          'type': type, // 'leave' or 'wfh'
          'isFullDay': isFullDay,
          'reason': reason,
          'date': Timestamp.fromDate(date),
          'appliedAt': FieldValue.serverTimestamp(),
          'appliedBy': FirebaseAuth.instance.currentUser?.email,
        });

        // Also add a notification for all employees
        final notifRef = FirebaseFirestore.instance
            .collection('approved_companies')
            .doc(cid)
            .collection('global_notifications')
            .doc();
        
        batch.set(notifRef, {
          'title': type == 'leave' ? 'Company Holiday' : 'WFH Day',
          'message': 'The manager has marked $dateStr as a ${type == 'leave' ? 'Holiday' : 'Work From Home'} day. Reason: $reason',
          'type': type,
          'date': Timestamp.fromDate(date),
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'target': 'all',
        });
      }

      await batch.commit();

      // Notify all employees in real-time about the Holiday or WFH day
      if (dates.isNotEmpty) {
        final notifTitle = type == 'leave'
            ? (dates.length == 1 ? 'Company Holiday 🏖️' : 'Company Holidays 🏖️')
            : (dates.length == 1 ? 'Work From Home 🏡' : 'Work From Home Days 🏡');

        final dateStr = dates.length == 1
            ? DateFormat('MMM dd, yyyy').format(dates.first)
            : 'from ${DateFormat('MMM dd').format(dates.first)} to ${DateFormat('MMM dd').format(dates.last)} (${dates.length} days)';

        final notifBody = type == 'leave'
            ? 'Manager declared $dateStr as a Company Holiday. Reason: "$reason"'
            : 'Manager approved Work From Home for $dateStr. Reason: "$reason"';

        await NotificationHelper.notifyAllEmployees(
          title: notifTitle,
          body: notifBody,
          type: 'company_${type}',
          extraData: {
            'dates': dates.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList(),
          },
        );
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isMultiSelect = false;
          _selectedDays.clear();
          _selectedDay = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calendar updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _eventsFor(DateTime day) {
    return _holidays.where((h) => isSameDay(h['date'] as DateTime, day)).toList();
  }

  List<Map<String, dynamic>> get _upcoming => _holidays
      .where((h) =>
          !(h['date'] as DateTime)
              .isBefore(DateTime.now().subtract(const Duration(days: 1))))
      .toList();

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 18),
          onPressed: () async {
            final didPop = await Navigator.maybePop(context);
            if (!didPop) {
              widget.onTabChange?.call(0);
            }
          },
        ),
        title: Text('Calendar', style: AppTheme.h3),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                // Subscription handles updates, but this allows manual trigger
                _listenHolidays();
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCalendarCard(),
                    _buildLegend(),
                    const SizedBox(height: 20),
                    _buildSelectedDayInfo(),
                    const SizedBox(height: 20),
                    if (_upcoming.isNotEmpty) ...[
                      _buildNextHolidayBanner(_upcoming.first),
                      const SizedBox(height: 20),
                    ],
                    _buildUpcomingSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      floatingActionButton: _isMultiSelect && _selectedDays.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showMultiSelectActionSheet,
              backgroundColor: const Color(0xFF5C5CFF),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Apply for Selected', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  // ── Calendar Card ─────────────────────────────────────────────────────────
  Widget _buildCalendarCard() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year - 1, now.month, now.day);
    final lastDay  = DateTime(now.year + 1, now.month, now.day);

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          if (_isMultiSelect)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C5CFF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedDays.length} dates selected',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _isMultiSelect = false;
                      _selectedDays.clear();
                    }),
                    child: const Text('Clear', style: TextStyle(color: Color(0xFF5C5CFF), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          TableCalendar<Map<String, dynamic>>(
        firstDay: firstDay,
        lastDay: lastDay,
        focusedDay: _safeFocusedDay,
        selectedDayPredicate: (day) {
          if (_isMultiSelect) {
            return _selectedDays.any((d) => isSameDay(d, day));
          }
          return _selectedDay != null && isSameDay(day, _selectedDay!);
        },
        onDaySelected: _onDaySelected,
        onDayLongPressed: _onDayLongPressed,
        onPageChanged: (foc) => setState(() => _focusedDay = foc),
        eventLoader: _eventsFor,
        rowHeight: 52,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: AppTheme.h3.copyWith(fontSize: 16),
          leftChevronIcon: _chevron(Icons.chevron_left_rounded),
          rightChevronIcon: _chevron(Icons.chevron_right_rounded),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 12),
          weekendStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 12),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: const BoxDecoration(
              color: Color(0xFF5C5CFF), shape: BoxShape.circle),
          todayTextStyle:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          selectedDecoration: BoxDecoration(
            color: const Color(0xFF5C5CFF),
            shape: BoxShape.circle,
          ),
          selectedTextStyle:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          defaultTextStyle: const TextStyle(
              fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
          weekendTextStyle: const TextStyle(
              fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
          outsideDaysVisible: false,
          markersMaxCount: 4,
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (ctx, date, events) {
            if (events.isEmpty) return const SizedBox();
            return Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: events.map((e) {
                   final type = (e as Map<String, dynamic>)['type'] as String? ?? 'public';
                   return Container(
                     margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
                     width: 4,
                     height: 4,
                     decoration: BoxDecoration(color: _colorOf(type), shape: BoxShape.circle),
                   );
                }).toList(),
              ),
            );
          },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chevron(IconData icon) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: Colors.black),
      );

  // ── Legend ────────────────────────────────────────────────────────────────
  Widget _buildLegend() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _legendDot(_red,   'Company Holiday'),
            _legendDot(_purple, 'WFH Day'),
          ],
        ),
      );

  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280))),
        ],
      );

  // ── Selected Day ──────────────────────────────────────────────────────────
  Widget _buildSelectedDayInfo() {
    if (_selectedDay == null) return const SizedBox();
    final evts = _eventsFor(_selectedDay!);

    if (evts.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(DateFormat('EEEE, MMM dd, yyyy').format(_selectedDay!), style: AppTheme.h3.copyWith(fontSize: 16)),
             const SizedBox(height: 12),
             ...evts.map((e) {
               final label = _labelOf(e['type'] as String? ?? 'public');
               final c = _colorOf(e['type'] as String? ?? 'public');
               final bg = _bgOf(e['type'] as String? ?? 'public');
               return Padding(
                 padding: const EdgeInsets.only(bottom: 8),
                 child: Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.all(6),
                       decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                       child: Icon(Icons.event, color: c, size: 16),
                     ),
                     const SizedBox(width: 8),
                     Text('${e['name']} - $label', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
                   ],
                 ),
               );
             }),
          ]
        )
      )
    );
  }


  // ── Next Holiday Banner ───────────────────────────────────────────────────
  Widget _buildNextHolidayBanner(Map<String, dynamic> h) {
    final date = h['date'] as DateTime;
    final type = h['type'] as String? ?? 'public';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border(left: BorderSide(color: _colorOf(type), width: 6)),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h['name'] as String, style: AppTheme.h3),
                  const SizedBox(height: 4),
                  Text(DateFormat('MMMM dd, yyyy').format(date),
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _bgOf(type),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_labelOf(type),
                        style: TextStyle(
                            color: _colorOf(type),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16)),
              child:
                  Icon(Icons.flag_outlined, color: _colorOf(type), size: 24),
            ),
          ],
        ),
      ),
    );
  }

  // ── Upcoming Holidays ─────────────────────────────────────────────────────
  Widget _buildUpcomingSection() {
    final list = _upcoming;
    if (list.isEmpty) return const SizedBox();

    final displayList = _showAllHolidays ? list : list.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Upcoming Holidays', style: AppTheme.h3),
              if (list.length > 3)
                GestureDetector(
                  onTap: () => setState(() => _showAllHolidays = !_showAllHolidays),
                  child: Text(
                    _showAllHolidays ? 'Show Less' : 'See All',
                    style: const TextStyle(
                        color: Color(0xFF5C5CFF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...displayList.map(_holidayTile),
        ],
      ),
    );
  }

  Widget _holidayTile(Map<String, dynamic> h) {
    final date = h['date'] as DateTime;
    final type = h['type'] as String? ?? 'public';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: const Color(0xFFF0F1F3), width: 1),
      ),
      child: Row(
        children: [
          // Date badge
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: _bgOf(type),
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(DateFormat('MMM').format(date).toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _colorOf(type))),
                Text(DateFormat('dd').format(date),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _colorOf(type))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h['name'] as String,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 4),
                Text(
                  '${_labelOf(type)} • ${DateFormat('EEEE').format(date)}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1)),
        ],
      ),
    );
  }
}

class _CalendarActionSheet extends StatefulWidget {
  final List<DateTime> dates;
  final Function(String type, bool isFullDay, String reason) onApply;

  const _CalendarActionSheet({required this.dates, required this.onApply});

  @override
  State<_CalendarActionSheet> createState() => _CalendarActionSheetState();
}

class _CalendarActionSheetState extends State<_CalendarActionSheet> {
  String _selectedType = 'leave'; // 'leave' or 'wfh'
  final TextEditingController _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: const Border.fromBorderSide(const BorderSide(color: Color(0xFFF0F1F3), width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              widget.dates.length == 1
                  ? 'Select Action'
                  : 'Apply for Selected Dates',
              style: AppTheme.h3,
            ),
          ),
          if (widget.dates.length == 1)
            Center(
              child: Text(
                DateFormat('EEEE, MMMM dd, yyyy').format(widget.dates.first),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '${widget.dates.length} dates selected',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            ),
          const SizedBox(height: 24),
          if (widget.dates.length > 1)
             SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.dates.map((d) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(DateFormat('MMM dd').format(d), style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 11)),
                  )).toList(),
                ),
              ),
          const SizedBox(height: 16),
          _buildActionOption(
            title: widget.dates.length == 1 ? 'Leave on this date' : 'Apply Leave',
            subtitle: widget.dates.length == 1 ? 'Apply for time off' : 'Request for all selected dates',
            icon: Icons.calendar_today_outlined,
            type: 'leave',
            color: Colors.red[400]!,
            isSelected: _selectedType == 'leave',
          ),
          const SizedBox(height: 12),
          _buildActionOption(
            title: widget.dates.length == 1 ? 'Work From Home' : 'Apply Work From Home',
            subtitle: 'Remote work approval',
            icon: Icons.home_outlined,
            type: 'wfh',
            color: Colors.green[400]!,
            isSelected: _selectedType == 'wfh',
          ),
          const SizedBox(height: 24),
          // Removed Half Day option as per user request
          const SizedBox(height: 24),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              hintText: 'Add reason (optional)',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply(_selectedType, true, _reasonController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C5CFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                widget.dates.length == 1 ? 'Confirm' : 'Apply',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String type,
    required Color color,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF0FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF5C5CFF) : Colors.grey[200]!,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.h3.copyWith(fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF5C5CFF), size: 24)
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

}
