import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class TeamMembersView extends StatefulWidget {
  const TeamMembersView({super.key});

  @override
  State<TeamMembersView> createState() => _TeamMembersViewState();
}

class _TeamMembersViewState extends State<TeamMembersView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isFiltersExpanded = false;
  String _searchQuery = '';
  
  String _selectedDepartment = 'All';
  String _selectedStatus = 'All';

  final List<String> _departments = ['All', 'Engineering', 'Design', 'Marketing', 'Sales', 'HR', 'Finance', 'Operations'];
  final List<String> _statuses = ['All', 'Active', 'On Leave', 'Inactive'];

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
      color: const Color(0xFFF4F6F9), // App background color
      child: Column(
        children: [
          _buildSearchAndFilterBar(),
          if (_isFiltersExpanded) _buildExpandedFilters(),
          Expanded(child: _buildMembersList()),
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
                  hintText: 'Search members..',
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
              child: Icon(
                Icons.filter_alt_outlined,
                color: const Color(0xFF5C5CFF),
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
          const Text('Department', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _departments.map((dept) => _buildFilterChip(dept, _selectedDepartment == dept, (val) {
              setState(() => _selectedDepartment = dept);
            })).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statuses.map((status) => _buildFilterChip(status, _selectedStatus == status, (val) {
              setState(() => _selectedStatus = status);
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

  Widget _buildMembersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.employeesCol.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final department = data['department'] ?? 'Unknown';
          final status = (data['status'] ?? 'Active').toString();
          
          bool matchesSearch = name.contains(_searchQuery.toLowerCase());
          bool matchesDept = _selectedDepartment == 'All' || department == _selectedDepartment;
          
          String uiStatus = 'Active';
          if (status.toLowerCase() == 'on leave') uiStatus = 'On Leave';
          if (status.toLowerCase() == 'inactive' || status.toLowerCase() == 'pending') uiStatus = 'Inactive';
          
          bool matchesStatus = _selectedStatus == 'All' || uiStatus == _selectedStatus;
          
          return matchesSearch && matchesDept && matchesStatus;
        }).toList();

        if (filteredDocs.isEmpty) {
          return const Center(child: Text('No members found.', style: TextStyle(color: Color(0xFF6B7280))));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final name = data['name'] ?? 'Unknown';
            final role = data['role'] ?? 'Employee';
            final department = data['department'] ?? 'Engineering';
            final dbStatus = (data['status'] ?? 'active').toString().toLowerCase();
            
            String statusLabel = 'Active';
            if (dbStatus == 'on leave') statusLabel = 'On Leave';
            if (dbStatus == 'inactive' || dbStatus == 'pending') statusLabel = 'Inactive';

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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _getAvatarColor(name),
                    child: Text(
                      _getInitials(name),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                        const SizedBox(height: 4),
                        Text('$role Â· $department', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  _buildStatusChip(statusLabel),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Active':
        bgColor = const Color(0xFFD1FAE5).withOpacity(0.5);
        textColor = const Color(0xFF059669);
        break;
      case 'On Leave':
        bgColor = const Color(0xFFF3E8FF).withOpacity(0.5);
        textColor = const Color(0xFF7C3AED);
        break;
      case 'Inactive':
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF6B7280);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
