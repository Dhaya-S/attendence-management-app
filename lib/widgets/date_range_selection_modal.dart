import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';

class DateRangeSelectionModal extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;

  const DateRangeSelectionModal({super.key, required this.initialStart, required this.initialEnd});

  @override
  State<DateRangeSelectionModal> createState() => _DateRangeSelectionModalState();
}

class _DateRangeSelectionModalState extends State<DateRangeSelectionModal> {
  late DateTime _startDate;
  late DateTime _endDate;
  DateTime _focusedMonth = DateTime.now();
  bool _pickingStart = true;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStart;
    _endDate = widget.initialEnd;
    _focusedMonth = DateTime(_startDate.year, _startDate.month, 1);
  }

  void _onDateTapped(DateTime date) {
    setState(() {
      if (_pickingStart) {
        _startDate = date;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        _pickingStart = false;
      } else {
        if (date.isBefore(_startDate)) {
          _startDate = date;
        } else {
          _endDate = date;
          _pickingStart = true;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final diff = _endDate.difference(_startDate).inDays + 1;

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select Dates', style: AppTheme.h2),
                IconButton(icon: const Icon(Icons.close_rounded, color: AppTheme.textHint), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRangeDisplay(),
                    const SizedBox(height: 24),
                    _buildMonthHeader(),
                    const SizedBox(height: 16),
                    _buildCalendarGrid(),
                    const SizedBox(height: 24),
                    Text('QUICK SELECT', style: AppTheme.label.copyWith(fontSize: 10, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    _buildQuickSelect(),
                    const SizedBox(height: 24),
                    _buildSummary(diff),
                    const SizedBox(height: 24),
                    _buildApplyButton(diff),
                    
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 16),
          const SizedBox(width: 8),
          Text('${DateFormat('MMMM dd').format(_startDate)} â€” ${DateFormat('MMMM dd, yyyy').format(_endDate)}', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1))),
        Text(DateFormat('MMMM yyyy').format(_focusedMonth), style: AppTheme.h3),
        IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1))),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startWeekday = firstDay.weekday % 7;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((d) => Text(d, style: AppTheme.label.copyWith(fontSize: 9, color: AppTheme.textHint, fontWeight: FontWeight.w700))).toList(),
        ),
        const SizedBox(height: 16),
        ...List.generate(6, (week) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (weekday) {
              final dayIndex = week * 7 + weekday - startWeekday + 1;
              if (dayIndex < 1 || dayIndex > lastDay.day) return const SizedBox(width: 40, height: 40);

              final date = DateTime(year, month, dayIndex);
              final isStart = _isSameDay(date, _startDate);
              final isEnd = _isSameDay(date, _endDate);
              final inRange = date.isAfter(_startDate) && date.isBefore(_endDate);

              return GestureDetector(
                onTap: () => _onDateTapped(date),
                child: Container(
                  width: 40, height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (isStart || isEnd) ? AppTheme.primary : (inRange ? AppTheme.primary.withOpacity(0.05) : null),
                    borderRadius: (isStart && isEnd) ? BorderRadius.circular(14) : (isStart ? const BorderRadius.horizontal(left: Radius.circular(20)) : (isEnd ? const BorderRadius.horizontal(right: Radius.circular(20)) : null)),
                  ),
                  child: Text('$dayIndex', style: TextStyle(color: (isStart || isEnd) ? Colors.white : AppTheme.textPrimary, fontWeight: (isStart || isEnd || inRange) ? FontWeight.w900 : FontWeight.bold, fontSize: 13)),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  Widget _buildQuickSelect() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _quickChip('Today', () => setState(() { _startDate = DateTime.now(); _endDate = DateTime.now(); })),
          _quickChip('Tomorrow', () => setState(() { _startDate = DateTime.now().add(const Duration(days: 1)); _endDate = DateTime.now().add(const Duration(days: 1)); })),
          _quickChip('Next 3 Days', () => setState(() { _startDate = DateTime.now(); _endDate = DateTime.now().add(const Duration(days: 2)); })),
          _quickChip('Next Week', () => setState(() { _startDate = DateTime.now(); _endDate = DateTime.now().add(const Duration(days: 6)); })),
        ],
      ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      ),
    );
  }

  Widget _buildSummary(int days) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.timer_outlined, color: AppTheme.primary, size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$days Days Selected', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                Text('Includes weekends', style: AppTheme.label.copyWith(fontSize: 9)),
              ],
            ),
          ),
          ... [1, 2, 3].map((i) => Container(margin: const EdgeInsets.only(left: 4), width: 24, height: 24, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.4), shape: BoxShape.circle), child: Center(child: Text('${11+i}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))))),
        ],
      ),
    );
  }

  Widget _buildApplyButton(int days) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context, {'start': _startDate, 'end': _endDate}),
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Apply Dates', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              const Icon(Icons.check_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
