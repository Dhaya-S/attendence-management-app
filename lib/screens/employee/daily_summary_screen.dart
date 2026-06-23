import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/app_session.dart';

// ─── Brand colours (mirrored from home_tab) ───────────────────────────────
const _kPrimary    = Color(0xFF5C5CFF);
const _kBg         = Color(0xFFF6F7FB);
const _kCard       = Colors.white;
const _kText       = Color(0xFF111827);
const _kSubText    = Color(0xFF6B7280);
const _kBorder     = Color(0xFFEEEFF3);
const _kGreen      = Color(0xFF10B981);
const _kDark       = Color(0xFF1E1E2E);

class DailySummaryScreen extends StatefulWidget {
  final Timestamp? checkIn;
  final Timestamp? checkOut;

  const DailySummaryScreen({
    super.key,
    required this.checkIn,
    required this.checkOut,
  });

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Keep ticking if still checked in (no checkout yet)
    if (widget.checkOut == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  String _fmt12(Timestamp? ts) {
    if (ts == null) return '--:-- --';
    return DateFormat('hh:mm a').format(ts.toDate());
  }

  Duration _workedDuration() {
    if (widget.checkIn == null) return Duration.zero;
    final end = widget.checkOut?.toDate() ?? DateTime.now();
    return end.difference(widget.checkIn!.toDate());
  }

  Duration _shiftDuration() {
    try {
      final sParts = AppSession().shiftStartTime.split(':');
      final eParts = AppSession().shiftEndTime.split(':');
      return Duration(
              hours: int.parse(eParts[0]), minutes: int.parse(eParts[1])) -
          Duration(
              hours: int.parse(sParts[0]), minutes: int.parse(sParts[1]));
    } catch (_) {
      return const Duration(hours: 9);
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  bool _isLate() {
    if (widget.checkIn == null) return false;
    try {
      final sParts = AppSession().shiftStartTime.split(':');
      final ci = widget.checkIn!.toDate();
      final shiftStartDT =
          DateTime(ci.year, ci.month, ci.day, int.parse(sParts[0]), int.parse(sParts[1]));
      final graceLimit =
          shiftStartDT.add(Duration(minutes: AppSession().gracePeriod));
      return ci.isAfter(graceLimit);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final worked   = _workedDuration();
    final shift    = _shiftDuration();
    final overtime = worked > shift ? worked - shift : Duration.zero;
    final late     = _isLate();

    final now         = widget.checkIn?.toDate() ?? DateTime.now();
    final dateLabel   = DateFormat('EEEE, MMM d').format(now);
    final workedStr   = _formatDuration(worked);
    final overtimeStr = overtime > Duration.zero
        ? _formatDuration(overtime)
        : 'None';
    final punctuality = late ? 'Late' : 'On Time';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.only(left: 16),
            alignment: Alignment.center,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder, width: 1),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: _kText),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // ── Dark Header Card ───────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _kDark,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date label
                          Text(
                            'Daily Summary · $dateLabel',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Big worked time
                          Text(
                            workedStr,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1.5,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Total time worked today',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Overtime + Punctuality pills
                          Row(
                            children: [
                              Expanded(
                                child: _darkPill(
                                  value: overtimeStr,
                                  label: 'Overtime',
                                  valueColor: _kPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _darkPill(
                                  value: punctuality,
                                  label: 'Punctuality',
                                  valueColor: late
                                      ? const Color(0xFFF97316)
                                      : _kGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Work Breakdown Card ────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kBorder, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Work Breakdown',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _kText,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _breakdownRow(
                            label: 'Check in',
                            value: _fmt12(widget.checkIn),
                          ),
                          const SizedBox(height: 16),
                          _breakdownRow(
                            label: 'Check out',
                            value: widget.checkOut != null
                                ? _fmt12(widget.checkOut)
                                : 'In progress...',
                            valueColor: widget.checkOut != null
                                ? _kPrimary
                                : _kSubText,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Bottom Buttons ─────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // TODO: navigate to attendance history tab
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 54),
                              backgroundColor: const Color(0xFFF4F5FB),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              side: BorderSide.none,
                            ),
                            child: const Text(
                              'View History',
                              style: TextStyle(
                                color: _kPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kPrimary,
                              minimumSize: const Size(0, 54),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Return Home',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dark pill widget (inside the dark header) ────────────────────────────
  Widget _darkPill({
    required String value,
    required String label,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Single breakdown row ─────────────────────────────────────────────────
  Widget _breakdownRow({
    required String label,
    required String value,
    Color valueColor = _kPrimary,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFEEEEFF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _kPrimary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: _kText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
