import 'package:flutter/material.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class EmployeeWorkspaceRelatedDataTab extends StatefulWidget {
  final Map<String, dynamic> employeeData;

  const EmployeeWorkspaceRelatedDataTab({super.key, required this.employeeData});

  @override
  State<EmployeeWorkspaceRelatedDataTab> createState() => _EmployeeWorkspaceRelatedDataTabState();
}

class _EmployeeWorkspaceRelatedDataTabState extends State<EmployeeWorkspaceRelatedDataTab> {
  int _selectedSubTab = 0; // 0: Attendance, 1: Leave, 2: Tasks
  String _selectedFilter = 'Daily'; // Daily, Weekly, Monthly

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tabs
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildSubTab('Attendance', 0),
              _buildSubTab('Leave', 1),
              _buildSubTab('Tasks', 2),
            ],
          ),
        ),
        const SizedBox(height: 1),
        
        // Content
        Expanded(
          child: Container(
            color: const Color(0xFFF4F6F9),
            child: _selectedSubTab == 0
                ? _buildAttendanceView()
                : _selectedSubTab == 1
                    ? const Center(child: Text('Leave Data'))
                    : const Center(child: Text('Tasks Data')),
          ),
        ),
      ],
    );
  }

  Widget _buildSubTab(String label, int index) {
    final isSelected = _selectedSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF5C5CFF) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterButton('Daily'),
                _buildFilterButton('Weekly'),
                _buildFilterButton('Monthly'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Daily Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TODAY · JUL 28',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9CA3AF),
                          letterSpacing: 0.5,
                        ),
                      ),
                      _buildStatusChip('Present'),
                    ],
                  ),
                ),
                _buildDivider(),
                _buildInfoRow('Check-In', '09:07 AM'),
                _buildDivider(),
                _buildInfoRow('Check-Out', '—'),
                _buildDivider(),
                _buildInfoRow('Working Hours', '6h 23m'),
                _buildDivider(),
                _buildInfoRow('Overtime', '7 min'),
                _buildDivider(),
                FutureBuilder<String>(
                  future: FirestoreService.shiftLabelForUser(
                      Map<String, dynamic>.from(widget.employeeData)),
                  builder: (context, snap) =>
                      _buildInfoRow('Assigned Shift', snap.data ?? 'Loading…'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5C5CFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16);
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Color(0xFF059669),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
