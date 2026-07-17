import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:intl/intl.dart';

class EmployeeTasksDetailScreen extends StatefulWidget {
  final String employeeEmail;
  final String employeeName;
  final String employeeRole;
  final String employeeDepartment;

  const EmployeeTasksDetailScreen({
    super.key,
    required this.employeeEmail,
    required this.employeeName,
    required this.employeeRole,
    required this.employeeDepartment,
  });

  @override
  State<EmployeeTasksDetailScreen> createState() => _EmployeeTasksDetailScreenState();
}

class _EmployeeTasksDetailScreenState extends State<EmployeeTasksDetailScreen> {
  String _selectedStatus = 'All';
  final List<String> _statuses = ['All', 'Assigned', 'In Progress', 'Completed', 'Overdue'];

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Orange
      const Color(0xFF10B981), // Green
      const Color(0xFFEF4444), // Red
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEC4899), // Pink
    ];
    int hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6F9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${widget.employeeName.split(' ')[0]}'s Tasks",
          style: const TextStyle(color: Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: const Color(0xFFF4F6F9),
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: _statuses.map((status) {
            final isSelected = _selectedStatus == status;
            return GestureDetector(
              onTap: () => setState(() => _selectedStatus = status),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF5C5CFF) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF4B5563),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.tasksCol.where('assignedTo', isEqualTo: widget.employeeEmail).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          
          String uiStatus = 'Assigned';
          if (status == 'in progress') uiStatus = 'In Progress';
          if (status == 'completed') uiStatus = 'Completed';
          if (status == 'overdue') uiStatus = 'Overdue';

          return _selectedStatus == 'All' || uiStatus == _selectedStatus;
        }).toList();

        // Sort: Overdue first, In Progress, Assigned, Completed last
        filteredDocs.sort((a, b) {
          final ad = a.data() as Map<String, dynamic>;
          final bd = b.data() as Map<String, dynamic>;
          
          int _getRank(String st) {
            if (st == 'overdue') return 0;
            if (st == 'in progress') return 1;
            if (st == 'assigned') return 2;
            return 3;
          }
          
          int ra = _getRank((ad['status'] ?? '').toString().toLowerCase());
          int rb = _getRank((bd['status'] ?? '').toString().toLowerCase());
          
          if (ra != rb) return ra.compareTo(rb);
          
          final tsA = (ad['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          final tsB = (bd['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          return tsA.compareTo(tsB);
        });

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildProfileBanner(docs.length), // Total tasks regardless of filter
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: filteredDocs.isEmpty 
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Text('No tasks found.', style: TextStyle(color: Color(0xFF6B7280))),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildTaskCard(data);
                        },
                        childCount: filteredDocs.length,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileBanner(int totalTasks) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _getAvatarColor(widget.employeeName),
            child: Text(
              _getInitials(widget.employeeName),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.employeeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Text('${widget.employeeRole} · ${widget.employeeDepartment}', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$totalTasks',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5C5CFF)),
              ),
              const Text(
                'total tasks',
                style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> data) {
    final title = data['title'] ?? 'Untitled Task';
    final ts = data['dueDate'] as Timestamp?;
    final dateStr = ts != null ? DateFormat('MMM d').format(ts.toDate()) : 'No date';
    final dbStatus = (data['status'] ?? 'assigned').toString().toLowerCase();
    
    String statusLabel = 'Assigned';
    if (dbStatus == 'in progress') statusLabel = 'In Progress';
    if (dbStatus == 'completed') statusLabel = 'Completed';
    if (dbStatus == 'overdue') statusLabel = 'Overdue';

    Color bgColor;
    Color textColor;

    switch (statusLabel) {
      case 'In Progress':
        bgColor = const Color(0xFFFFFBEB).withOpacity(0.5);
        textColor = const Color(0xFFF59E0B);
        break;
      case 'Completed':
        bgColor = const Color(0xFFECFDF5).withOpacity(0.5);
        textColor = const Color(0xFF10B981);
        break;
      case 'Overdue':
        bgColor = const Color(0xFFFEF2F2).withOpacity(0.5);
        textColor = const Color(0xFFEF4444);
        break;
      case 'Assigned':
      default:
        bgColor = const Color(0xFFEEF2FF).withOpacity(0.5);
        textColor = const Color(0xFF5C5CFF);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Due $dateStr',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
          )
        ],
      ),
    );
  }
}
