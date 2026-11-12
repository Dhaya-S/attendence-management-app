import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/screens/profile_screen.dart';
import 'package:attendance_app/screens/auth_wrapper.dart';
import 'package:attendance_app/screens/employee/apply_leave_screen.dart';
import 'package:attendance_app/widgets/notification_action.dart';

class AdminLeaveScreen extends StatefulWidget {
  const AdminLeaveScreen({super.key});

  @override
  State<AdminLeaveScreen> createState() => _AdminLeaveScreenState();
}

class _AdminLeaveScreenState extends State<AdminLeaveScreen> {
  // 0 = My Space, 1 = Team
  int _selectedTab = 0;

  bool _isApplyingLeave = false;
  String _selectedLeaveType = 'Annual Leave';
  DateTime _fromDate = DateTime.now().add(const Duration(days: 1));
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _leaveTypes = [
    'Annual Leave',
    'Sick Leave',
    'Casual Leave',
    'Comp Off',
  ];

  final user = FirebaseAuth.instance.currentUser;
  late final Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = FirestoreService.userStreamByEmail(user?.email ?? '');
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'RA';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _selectedTab == 0
                  ? _MySpaceLeaveTab(
                      userEmail: user?.email ?? '',
                      onApplyLeave: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ApplyLeaveScreen()),
                        );
                      },
                    )
                  : const _TeamLeaveTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting row with avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() as Map<String, dynamic>?;
                    String rawName = AppSession().userName ?? 'Admin';
                    if (data?['name'] != null &&
                        data!['name'].toString().trim().isNotEmpty) {
                      rawName = data['name'].toString();
                    }
                    final firstName = rawName.split(' ').first;
                    return const Text(
                      'Leave Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  const NotificationAction(isManager: false),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) async {
                      if (value == 'logout') {
                        await FirebaseAuth.instance.signOut();
                        AppSession().clear();
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const AuthWrapper()),
                          (route) => false,
                        );
                      } else if (value == 'profile') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, size: 20),
                            SizedBox(width: 8),
                            Text('Profile'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Logout', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: _userStream,
                      builder: (context, snapshot) {
                        String? imageUrl;
                        String name = AppSession().userName ?? 'Admin';
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          imageUrl = data['profileImageUrl'];
                          if (data['name'] != null) name = data['name'];
                        }
                        return Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF5C5CFF),
                          ),
                          child: ClipOval(
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? (imageUrl.startsWith('http')
                                    ? Image.network(imageUrl, fit: BoxFit.cover)
                                    : Image.memory(base64Decode(imageUrl), fit: BoxFit.cover))
                                : Center(child: Text(_getInitials(name), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTabSwitcher(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabPill('My Space', 0),
          const SizedBox(width: 12),
          _tabPill('Team', 1),
        ],
      ),
    );
  }

  Widget _tabPill(String label, int index) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(24),
          border: isActive
              ? null
              : Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: isActive
              ? [
                  const BoxShadow(
                    color: Color(0x305C5CFF),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
  Widget _buildApplyLeaveScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Leave Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _leaveTypes.map((type) {
                    final isActive = _selectedLeaveType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedLeaveType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primary : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(20),
                          border: isActive ? null : Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.white : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildNewDateField('From', _fromDate, true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNewDateField('To', _toDate, false)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: TextField(
                    controller: _reasonController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Brief reason...',
                      hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _isApplyingLeave = false),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitLeave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Submit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewDateField(String label, DateTime date, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() {
                if (isStart) {
                  _fromDate = picked;
                  if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
                } else {
                  _toDate = picked;
                }
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              DateFormat('dd MMM yyyy').format(date),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitLeave() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a reason')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      int calculateWorkingDays(DateTime from, DateTime to) {
        final start = DateTime(from.year, from.month, from.day);
        final end = DateTime(to.year, to.month, to.day);
        int count = 0;
        DateTime current = start;
        while (!current.isAfter(end)) {
          if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
            count++;
          }
          current = current.add(const Duration(days: 1));
        }
        return count;
      }

      final email = user?.email ?? '';
      final durationInDays = calculateWorkingDays(_fromDate, _toDate);
      final data = {
        'companyId': FirestoreService.companyId,
        'userId': AppSession().uid,
        'email': email,
        'userName': AppSession().userName ?? 'Admin',
        'department': '',
        'leaveType': _selectedLeaveType,
        'duration': 'Full Day',
        'durationInDays': durationInDays,
        'fromDate': Timestamp.fromDate(_fromDate),
        'toDate': Timestamp.fromDate(_toDate),
        'reason': _reasonController.text.trim(),
        'requestDate': Timestamp.now(),
        'status': 'Pending',
        'senderRole': 'hr_admin',
        'targetRoles': ['hr_admin'],
        'approver': 'HR Admin',
        'requiresAdminApproval': true,
        'requiresManagerApproval': false,
        'approverRemarks': '',
      };

      await FirestoreService.userLeaveRequestsCol(email).add(data);

      final dateRangeStr = durationInDays == 1
          ? 'on ${DateFormat('MMM dd, yyyy').format(_fromDate)}'
          : 'from ${DateFormat('MMM dd').format(_fromDate)} to ${DateFormat('MMM dd').format(_toDate)}';
      await NotificationHelper.notifyAdmin(
        title: 'New Leave Request',
        body: '${AppSession().userName ?? 'Admin'} applied for $_selectedLeaveType $dateRangeStr.',
        type: 'new_leave_request',
        extraData: {'employeeEmail': email},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Leave request submitted!'),
            backgroundColor: Color(0xFF10B981)));
        setState(() {
          _isApplyingLeave = false;
          _reasonController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

// ============================================================
//  MY SPACE TAB
// ============================================================

class _MySpaceLeaveTab extends StatefulWidget {
  final String userEmail;
  final VoidCallback onApplyLeave;
  const _MySpaceLeaveTab({required this.userEmail, required this.onApplyLeave});

  @override
  State<_MySpaceLeaveTab> createState() => _MySpaceLeaveTabState();
}

class _MySpaceLeaveTabState extends State<_MySpaceLeaveTab> {
  // 0=All, 1=Annual Leave, 2=Sick Leave, 3=Casual Leave
  int _historyFilter = 0;

  late Stream<QuerySnapshot> _leaveStream;
  late Stream<QuerySnapshot> _typesStream; // organization leave types – live
  late Stream<DocumentSnapshot> _orgStream; // organization leave policy – live

  @override
  void initState() {
    super.initState();
    _leaveStream = FirestoreService.leaveRequestsCol.snapshots();
    _typesStream = FirestoreService.companyDoc().collection('leave_types').snapshots();
    _orgStream = FirestoreService.companyDoc().snapshots();
    _joinSub = FirestoreService.userStreamByEmail(
            FirebaseAuth.instance.currentUser?.email ?? widget.userEmail)
        .listen((d) {
      final u = d.data();
      final j = FirestoreService.parseAnyDate(
          u?['joinDate'] ?? u?['joiningDate'] ?? u?['createdAt'] ?? u?['joinedAt']);
      if (mounted && j != _joinDate) setState(() => _joinDate = j);
    }, onError: (_) {});
  }

  DateTime? _joinDate;
  StreamSubscription? _joinSub;

  @override
  void dispose() {
    _joinSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = widget.userEmail.toLowerCase();
    return StreamBuilder<QuerySnapshot>(
      stream: _leaveStream,
      builder: (context, snapshot) {
        final currentCompanyId = AppSession().companyId;
        final allDocs = snapshot.data?.docs ?? [];
        // Filter by email client-side to handle all field name variants
        final docs = allDocs.where((doc) {
          if (!FirestoreService.isDocInCurrentCompany(doc)) {
            return false;
          }
          final d = doc.data() as Map<String, dynamic>;
          final e1 = (d['applicantEmail'] ?? '').toString().toLowerCase();
          final e2 = (d['employeeEmail'] ?? '').toString().toLowerCase();
          final e3 = (d['email'] ?? '').toString().toLowerCase();
          return e1 == userEmail || e2 == userEmail || e3 == userEmail;
        }).toList();
        // Sort by requestDate desc
        DateTime made(QueryDocumentSnapshot d) {
          final m = d.data() as Map;
          return FirestoreService.parseAnyDate(m['createdAt'] ?? m['requestDate']) ??
              FirestoreService.parseAnyDate(m['fromDate'] ?? m['from']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
        }

        final sorted = List.of(docs)..sort((a, b) => made(b).compareTo(made(a)));

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    _buildOverviewAndApplySection(sorted),
                    const SizedBox(height: 24),
                    _buildHistoryHeader(),
                    const SizedBox(height: 12),
                    _buildHistoryFilterTabs(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildHistoryList(sorted),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  // ── Overview & Apply Section ─────────────────────────────
  Widget _buildOverviewAndApplySection(List<QueryDocumentSnapshot> docs) {
    // Same numbers as the Overview of the employee Leave tab: approved + pending days,
    // against the organization's live leave policy.

    return StreamBuilder<QuerySnapshot>(
      stream: _typesStream,
      builder: (context, typesSnap) => StreamBuilder<DocumentSnapshot>(
        stream: _orgStream,
        builder: (context, orgSnap) {
          final bal = FirestoreService.leaveBalance(
              typesSnap.data,
              orgSnap.data?.data() as Map<String, dynamic>?,
              docs.map((d) => d.data() as Map<String, dynamic>),
              _joinDate);
          final usage = bal.used;
          final usedTotal = bal.usedAll;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LEAVE OVERVIEW — FY ${DateTime.now().year}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Text(
                        '$usedTotal used',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5C5CFF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Balance chips row
                Row(
                  children: [
                    _leaveBalanceTile('Annual', usage[0], bal.total(0), const Color(0xFF5C5CFF), const Color(0xFFEEF2FF), carried: bal.carried[0]),
                    const SizedBox(width: 8),
                    _leaveBalanceTile('Sick', usage[1], bal.total(1), const Color(0xFF1F2937), const Color(0xFFF3F4F6), carried: bal.carried[1]),
                    const SizedBox(width: 8),
                    _leaveBalanceTile('Casual', usage[2], bal.total(2), const Color(0xFFD946EF), const Color(0xFFFDF4FF), carried: bal.carried[2]),
                  ],
                ),
                const SizedBox(height: 16),
                _buildApplyButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _leaveBalanceTile(
      String label, int used, int total, Color color, Color bgColor, {int carried = 0}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              used.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              carried > 0 ? 'of $total (+$carried c/f)' : 'of $total',
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: total > 0 ? used / total : 0,
              backgroundColor: const Color(0xFFE5E7EB),
              color: color,
              borderRadius: BorderRadius.circular(4),
              minHeight: 4,
            ),
            const SizedBox(height: 6),
            Text(
              '${(total - used).clamp(0, total)} left',
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ── Apply Button ─────────────────────────────────────────
  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: widget.onApplyLeave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          '+ Apply for Leave',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── History Header ────────────────────────────────────────
  Widget _buildHistoryHeader() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'LEAVE HISTORY',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF9CA3AF),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── History Filter Tabs ───────────────────────────────────
  Widget _buildHistoryFilterTabs() {
    final filters = [
      'All',
      'Annual Leave',
      'Sick Leave',
      'Casual Leave'
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.asMap().entries.map((e) {
          final i = e.key;
          final label = e.value;
          final isActive = _historyFilter == i;
          return GestureDetector(
            onTap: () => setState(() => _historyFilter = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isActive
                        ? AppTheme.primary
                        : const Color(0xFFE5E7EB)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      isActive ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }



  // ── History List ─────────────────────────────────────────
  Widget _buildHistoryList(List<QueryDocumentSnapshot> allDocs) {
    final filterTypes = [
      null,
      'Annual Leave',
      'Sick Leave',
      'Casual Leave'
    ];
    final filterType = filterTypes[_historyFilter];

    final filtered = filterType == null
        ? allDocs
        : allDocs
            .where((d) {
              final data = d.data() as Map<String, dynamic>;
              final target = filterType.toLowerCase().replaceAll(' leave', '').trim();
              final type = (data['leaveType'] ?? data['type'] ?? data['category'] ?? '').toString().toLowerCase();
              if (type.contains(target)) return true;
              if ((type.isEmpty || type == 'leave') && target == 'annual') return true;
              return false;
            })
            .toList();

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: const [
                Icon(Icons.event_busy_outlined,
                    size: 40, color: Color(0xFFD1D5DB)),
                SizedBox(height: 12),
                Text('No leave history found.',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final data = filtered[index].data() as Map;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16,
                index == filtered.length - 1 ? 0 : 10),
            child: FadeInUp(
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: index * 40),
              child: _buildHistoryCard(data),
            ),
          );
        },
        childCount: filtered.length,
      ),
    );
  }

  Widget _buildHistoryCard(Map data) {
    final status =
        (data['status'] as String? ?? 'pending').toLowerCase();
    String leaveType = (data['leaveType'] ?? data['type'] ?? data['category'] ?? '').toString();
    if (leaveType.isEmpty || leaveType.toLowerCase() == 'leave') {
      final r = (data['reason'] ?? '').toString();
      if (r.isNotEmpty && r.length < 25) {
        leaveType = '${r[0].toUpperCase()}${r.substring(1)} Leave';
      } else {
        leaveType = 'Casual Leave';
      }
    }

    final reason = (data['reason'] ?? '').toString();
    final applicant = (data['applicantName'] ?? data['employee'] ?? data['userName'] ?? '').toString();

    DateTime? parseDate(dynamic d) {
      if (d is Timestamp) return d.toDate();
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }
    
    final fromDate = parseDate(data['fromDate'] ?? data['from']);
    final toDate = parseDate(data['toDate'] ?? data['to']);
    final days = ((data['durationInDays'] ?? data['days']) as num?)?.toInt() ?? 1;

    Color statusColor;
    Color statusBg;
    String statusLabel;

    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusBg = const Color(0xFFECFDF5);
        statusLabel = 'Approved';
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusBg = const Color(0xFFFEF2F2);
        statusLabel = 'Rejected';
        break;
      case 'cancelled':
        statusColor = const Color(0xFF6B7280);
        statusBg = const Color(0xFFF3F4F6);
        statusLabel = 'Cancelled';
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusBg = const Color(0xFFFFFBEB);
        statusLabel = 'Pending';
    }

    String dateRange = 'Unknown';
    if (fromDate != null) {
      final fromStr = DateFormat('MMM d, yyyy').format(fromDate);
      if (toDate != null) {
        if (fromDate.year == toDate.year && fromDate.month == toDate.month && fromDate.day == toDate.day) {
          dateRange = '$fromStr · $days day${days > 1 ? 's' : ''}';
        } else {
          final toStr = DateFormat('MMM d, yyyy').format(toDate);
          dateRange = '$fromStr — $toStr · $days days';
        }
      } else {
        dateRange = '$fromStr · $days day${days > 1 ? 's' : ''}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leaveType,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Text(dateRange,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
                if (applicant.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Applicant: $applicant',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Reason: "$reason"',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563), fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  TEAM TAB — Company-wide leave status (admin view)
// ============================================================

class _TeamLeaveTab extends StatefulWidget {
  const _TeamLeaveTab();

  @override
  State<_TeamLeaveTab> createState() => _TeamLeaveTabState();
}

class _TeamLeaveTabState extends State<_TeamLeaveTab> {
  final TextEditingController _searchController =
      TextEditingController();
  String _searchQuery = '';
  String? _selectedDeptFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.allLeaveRequestsQuery.snapshots(),
      builder: (context, leaveSnap) {
        final leaveDocs = leaveSnap.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.employeesCol.snapshots(),
          builder: (context, empSnap) {
            final empDocs = empSnap.data?.docs ?? [];

            final today = DateTime.now();
            final todayDate =
                DateTime(today.year, today.month, today.day);
            final thisMonthStart =
                DateTime(today.year, today.month, 1);
            final thisMonthEnd =
                DateTime(today.year, today.month + 1, 0);

            // Compute stats + per-employee leave state
            int onLeaveToday = 0;
            int pendingApprovals = 0;
            int totalThisMonth = 0;
            final Map<String, String> empLeaveStatus = {};
            final Map<String, int> empPendingCount = {};

            for (final doc in leaveDocs) {
              final data = doc.data() as Map<String, dynamic>;
              // For subcollection docs the email is in the parent path
              final pathEmail = doc.reference.parent.parent?.id ?? '';
              final email = (
                data['applicantEmail'] ??
                data['employeeEmail'] ??
                data['email'] ??
                (pathEmail.contains('@') ? pathEmail : null) ??
                ''
              ).toString().toLowerCase().trim();
              final status = (data['status'] as String? ?? '').toLowerCase();

              // Parse date with multiple field variants
              Timestamp? parseTs(dynamic val) {
                if (val is Timestamp) return val;
                if (val is DateTime) return Timestamp.fromDate(val);
                if (val is String) {
                  final dt = DateTime.tryParse(val);
                  if (dt != null) return Timestamp.fromDate(dt);
                }
                return null;
              }

              final fromTs = parseTs(data['fromDate'] ?? data['from'] ?? data['startDate']);
              final toTs = parseTs(data['toDate'] ?? data['to'] ?? data['endDate']);

              if (status == 'pending') {
                pendingApprovals++;
                if (email.isNotEmpty) {
                  empPendingCount[email] = (empPendingCount[email] ?? 0) + 1;
                }
              }

              if (fromTs != null && toTs != null) {
                final from = fromTs.toDate();
                final to = toTs.toDate();
                final fromDate = DateTime(from.year, from.month, from.day);
                final toDate = DateTime(to.year, to.month, to.day);

                if (status == 'approved' &&
                    !todayDate.isBefore(fromDate) &&
                    !todayDate.isAfter(toDate)) {
                  onLeaveToday++;
                  if (email.isNotEmpty) empLeaveStatus[email] = 'onLeave';
                }

                if (status == 'approved' &&
                    !toDate.isBefore(thisMonthStart) &&
                    !fromDate.isAfter(thisMonthEnd)) {
                  totalThisMonth +=
                      (data['durationInDays'] as num? ?? 1).toInt();
                }
              }
            }

            // Collect unique departments and stats (pending count per dept)
            final deptStats = <String, Map<String, int>>{};
            for (final emp in empDocs) {
              final data = emp.data() as Map;
              final dept = (data['department'] ?? data['dept'] ?? '').toString().trim();
              final email = (data['email'] ?? data['userEmail'] ?? emp.id).toString().toLowerCase().trim();
              final pending = empPendingCount[email] ?? 0;

              if (dept.isNotEmpty) {
                if (!deptStats.containsKey(dept)) {
                  deptStats[dept] = {'total': 0, 'pending': 0};
                }
                deptStats[dept]!['total'] = (deptStats[dept]!['total'] ?? 0) + 1;
                if (pending > 0) {
                  deptStats[dept]!['pending'] = (deptStats[dept]!['pending'] ?? 0) + pending;
                }
              }
            }

            // Filter employees
            List<QueryDocumentSnapshot> filtered =
                empDocs.where((e) {
              final data = e.data() as Map;
              final name =
                  (data['name'] ?? '').toString().toLowerCase();
              final email =
                  (data['email'] ?? '').toString().toLowerCase();
              final dept =
                  (data['department'] ?? '').toString();
              final q = _searchQuery.toLowerCase();
              final matchSearch = q.isEmpty ||
                  name.contains(q) ||
                  email.contains(q);
              final matchDept = _selectedDeptFilter == null ||
                  dept == _selectedDeptFilter;
              return matchSearch && matchDept;
            }).toList();

            // Sort: on leave > pending > rest
            filtered.sort((a, b) {
              final ae =
                  (a.data() as Map)['email'] as String? ?? a.id;
              final be =
                  (b.data() as Map)['email'] as String? ?? b.id;
              final aOnLeave =
                  empLeaveStatus[ae] == 'onLeave' ? 0 : 1;
              final bOnLeave =
                  empLeaveStatus[be] == 'onLeave' ? 0 : 1;
              final aPending =
                  (empPendingCount[ae] ?? 0) > 0 ? 0 : 1;
              final bPending =
                  (empPendingCount[be] ?? 0) > 0 ? 0 : 1;
              if (aOnLeave != bOnLeave) return aOnLeave - bOnLeave;
              return aPending - bPending;
            });

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCompanyStatsCard(onLeaveToday, pendingApprovals, totalThisMonth),
                            if (deptStats.isNotEmpty) _buildDeptChips(deptStats),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: _buildSearchBar(),
                      ),
                    ],
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final emp = filtered[index];
                      final data = emp.data() as Map;
                      final email =
                          (data['email'] ?? data['userEmail'] ?? emp.id).toString().toLowerCase().trim();
                      final name =
                          (data['name'] ?? data['firstName'] ?? email).toString();
                      final dept =
                          (data['department'] ?? data['dept'] ?? '').toString();
                      final pending =
                          empPendingCount[email] ?? 0;
                      final isOnLeave =
                          empLeaveStatus[email] == 'onLeave';

                      final taken = leaveDocs
                          .where((d) {
                            final dd = d.data() as Map;
                            final pathE = d.reference.parent.parent?.id ?? '';
                            final de = (dd['applicantEmail'] ?? dd['employeeEmail'] ?? dd['email'] ?? (pathE.contains('@') ? pathE : null) ?? '').toString().toLowerCase().trim();
                            final ds = (dd['status'] as String? ?? '').toLowerCase();
                            if (de != email || ds != 'approved') return false;
                            final from0 = FirestoreService.parseAnyDate(dd['fromDate'] ?? dd['from']);
                            final to0 = FirestoreService.parseAnyDate(dd['toDate'] ?? dd['to']) ?? from0;
                            if (from0 == null || to0 == null) return false;
                            final from = from0;
                            final to = to0;
                            final fromDate = DateTime(
                                from.year, from.month, from.day);
                            final toDate = DateTime(
                                to.year, to.month, to.day);
                            return !toDate.isBefore(
                                    thisMonthStart) &&
                                !fromDate.isAfter(thisMonthEnd);
                          })
                          .fold<int>(0, (sum, d) {
                            final dd = d.data() as Map;
                            final fromTs = FirestoreService.parseAnyDate(dd['fromDate'] ?? dd['from']);
                            final toTs = FirestoreService.parseAnyDate(dd['toDate'] ?? dd['to']) ?? fromTs;
                            int days = 1;
                            if (fromTs != null && toTs != null) {
                              final start = fromTs;
                              final end = toTs;
                              int count = 0;
                              DateTime current = DateTime(start.year, start.month, start.day);
                              final limitEnd = DateTime(end.year, end.month, end.day);
                              while (!current.isAfter(limitEnd)) {
                                if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
                                  count++;
                                }
                                current = current.add(const Duration(days: 1));
                              }
                              days = count;
                            } else {
                              days = (dd['durationInDays'] as num? ?? 1).toInt();
                            }
                            return sum + days;
                          });

                      return FadeInUp(
                        duration: const Duration(milliseconds: 300),
                        delay: Duration(milliseconds: index * 40),
                        child: _buildEmployeeLeaveRow(
                          name: name,
                          email: email,
                          department: dept,
                          daysTaken: taken,
                          pendingCount: pending,
                          isOnLeave: isOnLeave,
                          leaveDocs: leaveDocs,
                          thisMonthStart: thisMonthStart,
                          thisMonthEnd: thisMonthEnd,
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: 100)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCompanyStatsCard(
      int onLeaveToday, int pendingApprovals, int totalThisMonth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COMPANY LEAVE STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF374151),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  DateFormat('MMM yyyy').format(DateTime.now()).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statCard(
                onLeaveToday.toString(),
                'On Leave',
                Icons.flight_takeoff_rounded,
                const Color(0xFFA855F7), // Purple
                const Color(0xFFFAF5FF),
                const Color(0xFFF3E8FF),
              ),
              const SizedBox(width: 10),
              _statCard(
                pendingApprovals.toString(),
                'Pending',
                Icons.pending_actions_rounded,
                const Color(0xFFD97706), // Amber
                const Color(0xFFFEFCE8),
                const Color(0xFFFEF3C7),
              ),
              const SizedBox(width: 10),
              _statCard(
                totalThisMonth.toString(),
                'This Month',
                Icons.calendar_month_rounded,
                const Color(0xFF3B82F6), // Blue
                const Color(0xFFEFF6FF),
                const Color(0xFFDBEAFE),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String value, String label, IconData icon, Color color, Color bgColor, Color borderColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4B5563),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeptChips(Map<String, Map<String, int>> deptStats) {
    final colors = [
      const Color(0xFF5C5CFF), // Indigo
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEF4444), // Red
      const Color(0xFFA855F7), // Purple
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFF43F5E), // Rose
    ];
    int colorIndex = 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: deptStats.entries.map((e) {
            final dept = e.key;
            final total = e.value['total'] ?? 0;
            final pending = e.value['pending'] ?? 0;
            final color = colors[colorIndex % colors.length];
            colorIndex++;
            return _deptChip(dept, total, pending, color);
          }).toList(),
        ),
      ),
    );
  }

  Widget _deptChip(String dept, int total, int pending, Color color) {
    final isActive = _selectedDeptFilter == dept;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDeptFilter = isActive ? null : dept;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : color.withOpacity(0.3),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dept,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                if (pending > 0)
                  Text(
                    '$pending pending',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white.withOpacity(0.9) : const Color(0xFFC2410C),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withOpacity(0.25) : color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                total.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search employee...',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w500),
                prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Icon(Icons.tune_rounded, color: Color(0xFF6B7280), size: 20),
        ),
      ],
    );
  }

  Widget _buildEmployeeLeaveRow({
    required String name,
    required String email,
    required String department,
    required int daysTaken,
    required int pendingCount,
    required bool isOnLeave,
    required List<QueryDocumentSnapshot> leaveDocs,
    required DateTime thisMonthStart,
    required DateTime thisMonthEnd,
  }) {
    final initials = _getInitials(name);
    final colors = [
      const Color(0xFF5C5CFF),
      const Color(0xFFAB40FF),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF3B82F6),
    ];
    final colorIndex =
        name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length;
    final avatarColor = colors[colorIndex];

    return GestureDetector(
      onTap: () => _showEmployeeLeaveDetail(
          context, name, email, department, leaveDocs),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$department · $daysTaken days taken',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            if (isOnLeave)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          const Color(0xFFA855F7).withOpacity(0.3)),
                ),
                child: const Text('On Leave',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFA855F7))),
              )
            else if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEFCE8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          const Color(0xFFD97706).withOpacity(0.3)),
                ),
                child: Text('$pendingCount pending',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706))),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFD1D5DB), size: 18),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0]
          .substring(0, parts[0].length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  void _showEmployeeLeaveDetail(
    BuildContext context,
    String name,
    String email,
    String department,
    List<QueryDocumentSnapshot> allLeaveDocs,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmployeeLeaveDetailModal(
        name: name,
        email: email,
        department: department,
        allLeaveDocs: allLeaveDocs,
      ),
    );
  }
}

class _EmployeeLeaveDetailModal extends StatefulWidget {
  final String name;
  final String email;
  final String department;
  final List<QueryDocumentSnapshot> allLeaveDocs;

  const _EmployeeLeaveDetailModal({
    required this.name,
    required this.email,
    required this.department,
    required this.allLeaveDocs,
  });

  @override
  State<_EmployeeLeaveDetailModal> createState() => _EmployeeLeaveDetailModalState();
}

class _EmployeeLeaveDetailModalState extends State<_EmployeeLeaveDetailModal> {
  String _selectedType = 'All';
  String? _selectedMonth;
  String? _selectedYear;

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final targetEmail = widget.email.toLowerCase().trim();

    Timestamp? parseTs(dynamic val) {
      if (val is Timestamp) return val;
      if (val is DateTime) return Timestamp.fromDate(val);
      if (val is String) {
        final dt = DateTime.tryParse(val);
        if (dt != null) return Timestamp.fromDate(dt);
      }
      return null;
    }

    final empLeaves = widget.allLeaveDocs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final pathEmail = d.reference.parent.parent?.id ?? '';
      final e1 = (data['applicantEmail'] ?? '').toString().toLowerCase().trim();
      final e2 = (data['employeeEmail'] ?? '').toString().toLowerCase().trim();
      final e3 = (data['email'] ?? '').toString().toLowerCase().trim();
      final e4 = pathEmail.contains('@') ? pathEmail : '';
      return e1 == targetEmail || e2 == targetEmail || e3 == targetEmail || e4 == targetEmail;
    }).toList();

    int daysTaken = 0;
    for (final doc in empLeaves) {
      final d = doc.data() as Map<String, dynamic>;
      final st = (d['status'] ?? '').toString().toLowerCase();
      if (st == 'approved') {
        final fromTs = parseTs(d['fromDate'] ?? d['from'] ?? d['startDate']);
        final toTs = parseTs(d['toDate'] ?? d['to'] ?? d['endDate']);
        if (fromTs != null && toTs != null) {
          final start = fromTs.toDate();
          final end = toTs.toDate();
          int count = 0;
          DateTime cur = DateTime(start.year, start.month, start.day);
          final limitEnd = DateTime(end.year, end.month, end.day);
          while (!cur.isAfter(limitEnd)) {
            if (cur.weekday != DateTime.saturday && cur.weekday != DateTime.sunday) count++;
            cur = cur.add(const Duration(days: 1));
          }
          daysTaken += count;
        } else {
          daysTaken += ((d['durationInDays'] ?? d['days']) as num?)?.toInt() ?? 1;
        }
      }
    }

    final filteredLeaves = empLeaves.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final type = (d['leaveType'] ?? d['type'] ?? 'Leave').toString();
      if (_selectedType != 'All' && !type.toLowerCase().contains(_selectedType.toLowerCase().replaceAll(' leave', ''))) {
        return false;
      }
      final fromTs = parseTs(d['fromDate'] ?? d['from'] ?? d['startDate']);
      if (fromTs != null) {
        final date = fromTs.toDate();
        if (_selectedMonth != null && DateFormat('MMM').format(date) != _selectedMonth) return false;
        if (_selectedYear != null && date.year.toString() != _selectedYear) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final aTs = parseTs((a.data() as Map)['fromDate'] ?? (a.data() as Map)['from']);
        final bTs = parseTs((b.data() as Map)['fromDate'] ?? (b.data() as Map)['from']);
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return bTs.compareTo(aTs);
      });

    final initials = _getInitials(widget.name);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF4B5563)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "${widget.name}'s Leave",
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFF5C5CFF),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.department.isNotEmpty ? widget.department : 'Team Member',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$daysTaken',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF5C5CFF)),
                            ),
                            const Text(
                              'days taken',
                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Annual Leave', 'Sick Leave', 'Casual Leave'].map((type) {
                        final isActive = _selectedType == type;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedType = type),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF5C5CFF) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isActive ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedMonth,
                              isExpanded: true,
                              hint: const Text('All Months', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('All Months', style: TextStyle(fontSize: 12))),
                                ...['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
                                    .map((m) => DropdownMenuItem<String?>(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))),
                              ],
                              onChanged: (val) => setState(() => _selectedMonth = val),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedYear,
                              isExpanded: true,
                              hint: const Text('All Years', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('All Years', style: TextStyle(fontSize: 12))),
                                ...['2024', '2025', '2026', '2027']
                                    .map((y) => DropdownMenuItem<String?>(value: y, child: Text(y, style: const TextStyle(fontSize: 12)))),
                              ],
                              onChanged: (val) => setState(() => _selectedYear = val),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (filteredLeaves.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: const Text('No leave records found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    )
                  else
                    ...filteredLeaves.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final type = (data['leaveType'] ?? data['type'] ?? 'Leave').toString();
                      final status = (data['status'] ?? 'pending').toString().toLowerCase();
                      final fromTs = parseTs(data['fromDate'] ?? data['from'] ?? data['startDate']);
                      final toTs = parseTs(data['toDate'] ?? data['to'] ?? data['endDate']);

                      // Calculate actual working days
                      int days = ((data['durationInDays'] ?? data['days']) as num?)?.toInt() ?? 1;
                      if (fromTs != null && toTs != null) {
                        final start = fromTs.toDate();
                        final end = toTs.toDate();
                        int count = 0;
                        DateTime cur = DateTime(start.year, start.month, start.day);
                        final limitEnd = DateTime(end.year, end.month, end.day);
                        while (!cur.isAfter(limitEnd)) {
                          if (cur.weekday != DateTime.saturday && cur.weekday != DateTime.sunday) count++;
                          cur = cur.add(const Duration(days: 1));
                        }
                        if (count > 0) days = count;
                      }

                      String dateRangeStr = '';
                      if (fromTs != null && toTs != null) {
                        final from = fromTs.toDate();
                        final to = toTs.toDate();
                        if (from.day == to.day && from.month == to.month) {
                          dateRangeStr = '${DateFormat('MMM d').format(from)} · $days day${days > 1 ? 's' : ''}';
                        } else {
                          dateRangeStr = '${DateFormat('MMM d').format(from)} → ${DateFormat('MMM d').format(to)} · $days days';
                        }
                      } else if (fromTs != null) {
                        dateRangeStr = '${DateFormat('MMM d').format(fromTs.toDate())} · $days day';
                      }

                      Color statusColor;
                      Color statusBg;
                      String statusLabel;
                      switch (status) {
                        case 'approved':
                          statusColor = const Color(0xFF16A34A);
                          statusBg = const Color(0xFFDCFCE7);
                          statusLabel = 'Approved';
                          break;
                        case 'rejected':
                          statusColor = const Color(0xFFDC2626);
                          statusBg = const Color(0xFFFEE2E2);
                          statusLabel = 'Rejected';
                          break;
                        default:
                          statusColor = const Color(0xFFD97706);
                          statusBg = const Color(0xFFFEFCE8);
                          statusLabel = 'Pending';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateRangeStr,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
