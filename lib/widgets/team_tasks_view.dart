import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/screens/employee_tasks_detail_screen.dart';

class TeamTasksView extends StatefulWidget {
  const TeamTasksView({super.key});

  @override
  State<TeamTasksView> createState() => _TeamTasksViewState();
}

class _TeamTasksViewState extends State<TeamTasksView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isFiltersExpanded = false;
  String _searchQuery = '';
  
  String _selectedDepartment = 'All';
  String _selectedStatus = 'All';

  final List<String> _departments = ['All', 'Engineering', 'Design', 'Marketing', 'Sales', 'HR', 'Finance', 'Operations'];
  final List<String> _statuses = ['All', 'Assigned', 'In Progress', 'Completed', 'Overdue'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
    return Container(
      color: const Color(0xFFF4F6F9),
      child: Column(
        children: [
          _buildSearchAndFilterBar(),
          if (_isFiltersExpanded) _buildExpandedFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      color: const Color(0xFFF4F6F9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB).withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Search employee name or dept...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() => _isFiltersExpanded = !_isFiltersExpanded),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isFiltersExpanded ? const Color(0xFFEEF2FF) : Colors.white,
                border: Border.all(color: _isFiltersExpanded ? const Color(0xFF5C5CFF) : const Color(0xFF5C5CFF).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.filter_alt_outlined,
                color: Color(0xFF5C5CFF),
                size: 20,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildExpandedFilters() {
    return Container(
      color: const Color(0xFFF4F6F9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statuses.map((status) => _buildFilterChip(status, _selectedStatus == status, (val) {
              setState(() => _selectedStatus = status);
            })).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Department', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _departments.map((dept) => _buildFilterChip(dept, _selectedDepartment == dept, (val) {
              setState(() => _selectedDepartment = dept);
            })).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, Function(bool) onSelected) {
    return GestureDetector(
      onTap: () => onSelected(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5C5CFF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.tasksCol.snapshots(),
      builder: (context, tasksSnapshot) {
        if (tasksSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final allTasks = tasksSnapshot.data?.docs ?? [];
        
        int totalAssigned = 0;
        int totalInProgress = 0;
        int totalCompleted = 0;
        int totalOverdue = 0;

        for (var doc in allTasks) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          if (status == 'assigned') totalAssigned++;
          else if (status == 'in progress') totalInProgress++;
          else if (status == 'completed') totalCompleted++;
          else if (status == 'overdue') totalOverdue++;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.employeesCol.snapshots(),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allUsers = usersSnapshot.data?.docs ?? [];

            final filteredUsers = allUsers.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final department = data['department'] ?? 'Unknown';
              
              bool matchesSearch = name.contains(_searchQuery.toLowerCase()) || 
                                   department.toString().toLowerCase().contains(_searchQuery.toLowerCase());
              bool matchesDept = _selectedDepartment == 'All' || department == _selectedDepartment;
              
              return matchesSearch && matchesDept;
            }).toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildMetricsRow(totalAssigned, totalInProgress, totalCompleted, totalOverdue),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final userDoc = filteredUsers[index];
                        final userData = userDoc.data() as Map<String, dynamic>;
                        final email = userDoc.id;
                        
                        // Calculate task counts for this user
                        int assigned = 0;
                        int active = 0;
                        int done = 0;
                        int overdue = 0;
                        
                        for (var taskDoc in allTasks) {
                          final td = taskDoc.data() as Map<String, dynamic>;
                          if (td['assignedTo'] == email) {
                            final st = (td['status'] ?? '').toString().toLowerCase();
                            if (st == 'assigned') assigned++;
                            else if (st == 'in progress') active++;
                            else if (st == 'completed') done++;
                            else if (st == 'overdue') overdue++;
                          }
                        }
                        
                        final totalTasks = assigned + active + done + overdue;

                        // Filter out users if _selectedStatus is applied and they don't match
                        if (_selectedStatus != 'All') {
                          if (_selectedStatus == 'Assigned' && assigned == 0) return const SizedBox();
                          if (_selectedStatus == 'In Progress' && active == 0) return const SizedBox();
                          if (_selectedStatus == 'Completed' && done == 0) return const SizedBox();
                          if (_selectedStatus == 'Overdue' && overdue == 0) return const SizedBox();
                        }

                        return _buildUserTaskCard(context, userData, email, totalTasks, assigned, active, done, overdue);
                      },
                      childCount: filteredUsers.length,
                    ),
                  ),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildMetricsRow(int assigned, int inProgress, int completed, int overdue) {
    return Row(
      children: [
        _buildMetricBox(assigned.toString(), 'Assigned', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF)),
        const SizedBox(width: 8),
        _buildMetricBox(inProgress.toString(), 'In Progress', const Color(0xFFFFFBEB), const Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        _buildMetricBox(completed.toString(), 'Completed', const Color(0xFFECFDF5), const Color(0xFF10B981)),
        const SizedBox(width: 8),
        _buildMetricBox(overdue.toString(), 'Overdue', const Color(0xFFFEF2F2), const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildMetricBox(String count, String label, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTaskCard(
    BuildContext context, 
    Map<String, dynamic> userData, 
    String email, 
    int totalTasks, 
    int assigned, 
    int active, 
    int done, 
    int overdue
  ) {
    final name = userData['name'] ?? 'Unknown';
    final role = userData['role'] ?? 'Employee';
    final department = userData['department'] ?? 'Engineering';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeTasksDetailScreen(
              employeeEmail: email,
              employeeName: name,
              employeeRole: role,
              employeeDepartment: department,
            ),
          ),
        );
      },
      child: Container(
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
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _getAvatarColor(name),
                  child: Text(
                    _getInitials(name),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                      const SizedBox(height: 4),
                      Text(department, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$totalTasks tasks',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5C5CFF)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (assigned > 0) _buildTaskTag('$assigned Assigned', const Color(0xFFEEF2FF), const Color(0xFF5C5CFF)),
                if (active > 0) _buildTaskTag('$active Active', const Color(0xFFFFFBEB), const Color(0xFFF59E0B)),
                if (done > 0) _buildTaskTag('$done Done', const Color(0xFFECFDF5), const Color(0xFF10B981)),
                if (overdue > 0) _buildTaskTag('$overdue Overdue', const Color(0xFFFEF2F2), const Color(0xFFEF4444)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTag(String label, Color bgColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
