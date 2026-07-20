import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/screens/department_detail_screen.dart';

class TeamDepartmentsView extends StatelessWidget {
  const TeamDepartmentsView({super.key});

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

  Color _getDeptColor(String dept) {
    final colors = [
      const Color(0xFF5C5CFF), // Indigo
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Orange
      const Color(0xFF10B981), // Green
      const Color(0xFFEF4444), // Red
      const Color(0xFFEC4899), // Pink
    ];
    int hash = dept.hashCode.abs();
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F6F9),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.employeesCol.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          
          if (docs.isEmpty) {
            return const Center(child: Text('No departments found.', style: TextStyle(color: Color(0xFF6B7280))));
          }

          final Map<String, List<Map<String, dynamic>>> deptMap = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            data['email'] = doc.id; // inject email
            final dept = data['department'] ?? 'Unknown';
            if (!deptMap.containsKey(dept)) {
              deptMap[dept] = [];
            }
            deptMap[dept]!.add(data);
          }

          final deptList = deptMap.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: deptList.length,
            itemBuilder: (context, index) {
              final dept = deptList[index];
              final members = deptMap[dept]!;
              final deptColor = _getDeptColor(dept);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DepartmentDetailScreen(
                        departmentName: dept,
                        members: members,
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
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: deptColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.business_rounded, color: deptColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dept, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                          const SizedBox(height: 4),
                          Text('${members.length} member${members.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    _buildMiniAvatars(members),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
                  ],
                ),
              ),
            );
          },
          );
        },
      ),
    );
  }

  Widget _buildMiniAvatars(List<Map<String, dynamic>> members) {
    const double size = 24;
    const double overlap = 8;
    
    final displayCount = members.length > 3 ? 3 : members.length;
    
    return SizedBox(
      width: (displayCount * size) - ((displayCount - 1) * overlap),
      height: size,
      child: Stack(
        children: List.generate(displayCount, (index) {
          final member = members[index];
          final name = member['name'] ?? 'Unknown';
          
          return Positioned(
            left: index * (size - overlap),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: CircleAvatar(
                radius: (size - 4) / 2, // Account for border
                backgroundColor: _getAvatarColor(name),
                child: Text(
                  _getInitials(name),
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
