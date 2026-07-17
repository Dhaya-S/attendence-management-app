import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class CalendarEvent {
  final String title;
  final String type;
  final DateTime date;

  CalendarEvent(this.title, this.type, this.date);
}

class CalendarTabView extends StatefulWidget {
  const CalendarTabView({super.key});

  @override
  State<CalendarTabView> createState() => _CalendarTabViewState();
}

class _CalendarTabViewState extends State<CalendarTabView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isFiltersExpanded = false;

  final Set<String> _activeFilters = {
    'my_leave',
    'team_leave',
    'holidays',
    'birthdays',
    'anniversaries',
    'events',
    'shift_schedule',
    'training',
  };

  final Map<String, Color> _filterColors = {
    'my_leave': const Color(0xFF5C5CFF), // Blue
    'team_leave': const Color(0xFFA855F7), // Purple
    'holidays': const Color(0xFFEF4444), // Red
    'birthdays': const Color(0xFFEAB308), // Yellow
    'anniversaries': const Color(0xFFEC4899), // Pink
    'events': const Color(0xFF22C55E), // Green
    'shift_schedule': const Color(0xFF1E3A8A), // Dark blue
    'training': const Color(0xFF14B8A6), // Teal
  };

  final Map<String, String> _filterLabels = {
    'my_leave': 'My Leave',
    'team_leave': 'Team Leave',
    'holidays': 'Holidays',
    'birthdays': 'Birthdays',
    'anniversaries': 'Anniversaries',
    'events': 'Events',
    'shift_schedule': 'Shift Schedule',
    'training': 'Training',
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  Map<DateTime, List<CalendarEvent>> _buildEventMap(
      List<QueryDocumentSnapshot> leaves, List<QueryDocumentSnapshot> calendarEvents) {
    Map<DateTime, List<CalendarEvent>> events = {};
    final currentUserUid = AppSession().uid;

    void addEvent(DateTime date, CalendarEvent event) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (events[normalizedDate] == null) {
        events[normalizedDate] = [];
      }
      events[normalizedDate]!.add(event);
    }

    for (var doc in leaves) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'approved') {
        final userId = data['userId'] ?? '';
        final isMine = userId == currentUserUid;
        final type = isMine ? 'my_leave' : 'team_leave';
        
        if (_activeFilters.contains(type)) {
          final startDate = (data['startDate'] as Timestamp?)?.toDate();
          final endDate = (data['endDate'] as Timestamp?)?.toDate();
          if (startDate != null) {
            DateTime current = startDate;
            final end = endDate ?? startDate;
            while (current.isBefore(end.add(const Duration(days: 1)))) {
              addEvent(current, CalendarEvent('Leave', type, current));
              current = current.add(const Duration(days: 1));
            }
          }
        }
      }
    }

    for (var doc in calendarEvents) {
      final data = doc.data() as Map<String, dynamic>;
      final type = (data['type'] as String?)?.toLowerCase() ?? 'events';
      
      // Match types to our filters
      String filterType = 'events';
      if (type.contains('holiday')) filterType = 'holidays';
      else if (type.contains('birthday')) filterType = 'birthdays';
      else if (type.contains('anniversary')) filterType = 'anniversaries';
      else if (type.contains('training')) filterType = 'training';
      else if (type.contains('shift')) filterType = 'shift_schedule';

      if (_activeFilters.contains(filterType)) {
        final date = (data['date'] as Timestamp?)?.toDate();
        final title = data['title'] ?? data['name'] ?? 'Event';
        if (date != null) {
          addEvent(date, CalendarEvent(title, filterType, date));
        }
      }
    }

    return events;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.allLeaveRequestsQuery.snapshots(),
      builder: (context, leaveSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.companyCalendarCol.snapshots(),
          builder: (context, calendarSnap) {
            final leaves = leaveSnap.data?.docs ?? [];
            final events = calendarSnap.data?.docs ?? [];
            final eventMap = _buildEventMap(leaves, events);

            return Container(
              color: const Color(0xFFF9FAFB),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTopControls(),
                    if (_isFiltersExpanded) _buildFiltersPanel(),
                    _buildCalendar(eventMap),
                    _buildLegend(),
                    if (_calendarFormat == CalendarFormat.week) _buildDayEventsList(eventMap),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildToggleButton('Month', CalendarFormat.month),
              const SizedBox(width: 8),
              _buildToggleButton('Week', CalendarFormat.week),
            ],
          ),
          GestureDetector(
            onTap: () => setState(() => _isFiltersExpanded = !_isFiltersExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isFiltersExpanded ? const Color(0xFFEEF2FF) : Colors.white,
                border: Border.all(color: _isFiltersExpanded ? const Color(0xFF5C5CFF) : const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: _isFiltersExpanded ? const Color(0xFF5C5CFF) : const Color(0xFF6B7280)),
                  const SizedBox(width: 4),
                  Text('Filters', style: TextStyle(
                    color: _isFiltersExpanded ? const Color(0xFF5C5CFF) : const Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, CalendarFormat format) {
    final isActive = _calendarFormat == format;
    return GestureDetector(
      onTap: () => setState(() => _calendarFormat = format),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF5C5CFF) : Colors.white,
          border: Border.all(color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF4B5563),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SHOW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: _filterLabels.keys.map((key) => _buildFilterChip(key)).toList(),
          ),
          const SizedBox(height: 20),
          const Text('ADDITIONAL FILTERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key) {
    final isActive = _activeFilters.contains(key);
    final color = _filterColors[key]!;
    final label = _filterLabels[key]!;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isActive) {
            _activeFilters.remove(key);
          } else {
            _activeFilters.add(key);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(color: isActive ? color : const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : const Color(0xFF4B5563),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(Map<DateTime, List<CalendarEvent>> eventMap) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF4B5563), size: 24),
          rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF4B5563), size: 24),
          titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
          headerMargin: EdgeInsets.only(bottom: 8),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w600),
          weekendStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w600),
        ),
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w700, fontSize: 13),
          weekendTextStyle: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w700, fontSize: 13),
          todayDecoration: BoxDecoration(),
          todayTextStyle: TextStyle(color: Color(0xFF5C5CFF), fontWeight: FontWeight.w800, fontSize: 13),
          selectedDecoration: BoxDecoration(
            color: Color(0xFF5C5CFF),
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
        ),
        eventLoader: (day) {
          final normalizedDay = DateTime(day.year, day.month, day.day);
          return eventMap[normalizedDay] ?? [];
        },
        calendarBuilders: CalendarBuilders(
          selectedBuilder: (context, date, events) {
            final isWeek = _calendarFormat == CalendarFormat.week;
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: isWeek ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF5C5CFF), width: 3)),
              ) : null,
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(color: Color(0xFF5C5CFF), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('${date.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            );
          },
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return const SizedBox();
            
            // Deduplicate event colors for markers
            final uniqueColors = events
                .map((e) => _filterColors[(e as CalendarEvent).type])
                .where((c) => c != null)
                .toSet()
                .toList();

            return Positioned(
              bottom: _calendarFormat == CalendarFormat.week ? 10 : 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: uniqueColors.take(3).map((color) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                )).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final activeFiltersList = _activeFilters.toList();
    if (activeFiltersList.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LEGEND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: activeFiltersList.map((key) {
              final color = _filterColors[key]!;
              final label = _filterLabels[key]!;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                ],
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildDayEventsList(Map<DateTime, List<CalendarEvent>> eventMap) {
    if (_selectedDay == null) return const SizedBox();
    
    final normalizedDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final events = eventMap[normalizedDate] ?? [];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('E, MMM d').format(_selectedDay!),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (events.isEmpty)
            const Text('No events for this day.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13))
          else
            ...events.map((e) {
              final color = _filterColors[e.type] ?? Colors.grey;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(e.title, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
