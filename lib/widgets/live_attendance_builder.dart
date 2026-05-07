import 'dart:async';
import 'package:flutter/material.dart';
import 'package:attendance_app/utils/firestore_service.dart';

/// Efficiently fetches attendance records for all company employees for a
/// specific date by listening to each employee's attendance document directly.
///
/// Path: approved_companies/{companyId}/users/{email}/attendance/{yyyy-MM-dd}
///
/// This approach requires NO Firestore indexes and provides real-time updates.
class LiveAttendanceBuilder extends StatefulWidget {
  final List<String> userIds;
  final String? dateId; // 'yyyy-MM-dd' format
  final Widget Function(BuildContext context, List<Map<String, dynamic>> records)
      builder;

  const LiveAttendanceBuilder({
    Key? key,
    required this.userIds,
    this.dateId,
    required this.builder,
  }) : super(key: key);

  @override
  State<LiveAttendanceBuilder> createState() => _LiveAttendanceBuilderState();
}

class _LiveAttendanceBuilderState extends State<LiveAttendanceBuilder> {
  final List<StreamSubscription> _subscriptions = [];
  final Map<String, Map<String, dynamic>> _recordsByEmail = {};
  bool _initialized = false;

  DateTime get _targetDate {
    if (widget.dateId != null) {
      try {
        return DateTime.parse(widget.dateId!);
      } catch (_) {}
    }
    return DateTime.now();
  }

  String get _dateStr {
    final d = _targetDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  @override
  void didUpdateWidget(covariant LiveAttendanceBuilder old) {
    super.didUpdateWidget(old);
    if (old.dateId != widget.dateId ||
        old.userIds.join(',') != widget.userIds.join(',')) {
      _cancelSubscriptions();
      _recordsByEmail.clear();
      _initStreams();
    }
  }

  void _cancelSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _initStreams() {
    // Only listen to email-based IDs (skip UIDs — emails contain '@')
    final emails = widget.userIds
        .map((id) => id.toLowerCase())
        .where((id) => id.contains('@'))
        .toSet()
        .toList();

    if (emails.isEmpty) {
      if (mounted) setState(() => _initialized = true);
      return;
    }

    int pendingCount = emails.length;

    for (final email in emails) {
      final sub = FirestoreService.userAttendanceCol(email)
          .doc(_dateStr)
          .snapshots()
          .listen(
        (docSnap) {
          if (docSnap.exists && docSnap.data() != null) {
            final data = Map<String, dynamic>.from(docSnap.data()!);
            data['userId'] ??= email;
            _recordsByEmail[email] = data;
          } else {
            _recordsByEmail.remove(email);
          }
          if (mounted) {
            setState(() {
              _initialized = true;
            });
          }
        },
        onError: (e) {
          debugPrint('LiveAttendanceBuilder[$email] error: $e');
          if (mounted && !_initialized) {
            pendingCount--;
            if (pendingCount <= 0) setState(() => _initialized = true);
          }
        },
      );
      _subscriptions.add(sub);

      // Mark initialized after first batch resolves
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && !_initialized) {
          setState(() => _initialized = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return widget.builder(context, _recordsByEmail.values.toList());
  }
}

