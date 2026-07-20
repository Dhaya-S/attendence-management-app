import 'package:flutter/material.dart';

class EmployeeDocumentsScreen extends StatefulWidget {
  const EmployeeDocumentsScreen({super.key});

  @override
  State<EmployeeDocumentsScreen> createState() => _EmployeeDocumentsScreenState();
}

class _EmployeeDocumentsScreenState extends State<EmployeeDocumentsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Company Policies', 'Certificates', 'Salary Documents', 'Letters'];
  final TextEditingController _searchController = TextEditingController();

  final Map<String, List<Map<String, String>>> _documents = {
    'COMPANY POLICIES': [
      {'title': 'Employee Handbook 2026', 'info': 'PDF · 2.4 MB · Jun 1, 2026'},
      {'title': 'Leave Policy FY 2025–26', 'info': 'PDF · 420 KB · Jul 1, 2026'},
      {'title': 'Code of Conduct', 'info': 'PDF · 880 KB · Jan 15, 2026'},
    ],
    'CERTIFICATES': [
      {'title': 'Experience Certificate', 'info': 'PDF · 156 KB · Mar 10, 2026'},
      {'title': 'Relieving Letter', 'info': 'PDF · 128 KB · Mar 10, 2026'},
    ],
    'SALARY DOCUMENTS': [
      {'title': 'Salary Slip — June 2026', 'info': 'PDF · 96 KB · Jul 5, 2026'},
      {'title': 'Salary Slip — May 2026', 'info': 'PDF · 94 KB · Jun 5, 2026'},
    ],
    'OFFER LETTER': [
      {'title': 'Offer Letter', 'info': 'PDF · 210 KB · Sep 1, 2023'},
    ],
    'APPOINTMENT LETTER': [
      {'title': 'Appointment Letter', 'info': 'PDF · 190 KB · Sep 15, 2023'},
    ],
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Documents', style: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search documents...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFF9CA3AF), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = filter == _selectedFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFilter = filter),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _documents.entries.map((entry) {
                  final sectionTitle = entry.key;
                  final items = entry.value;

                  // Basic filter logic
                  if (_selectedFilter != 'All') {
                    if (_selectedFilter == 'Company Policies' && sectionTitle != 'COMPANY POLICIES') return const SizedBox.shrink();
                    if (_selectedFilter == 'Certificates' && sectionTitle != 'CERTIFICATES') return const SizedBox.shrink();
                    if (_selectedFilter == 'Salary Documents' && sectionTitle != 'SALARY DOCUMENTS') return const SizedBox.shrink();
                    if (_selectedFilter == 'Letters' && !sectionTitle.contains('LETTER')) return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, top: 8),
                        child: Text(
                          sectionTitle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      ...items.map((doc) => _buildDocumentCard(doc)).toList(),
                      const SizedBox(height: 8),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, String> doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.description_outlined, color: Color(0xFFDC2626), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc['title']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  doc['info']!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          Row(
            children: [
              _buildActionButton(Icons.info_outline, const Color(0xFFEEF2FF), const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              _buildActionButton(Icons.arrow_downward_rounded, const Color(0xFFECFDF5), const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildActionButton(Icons.send_outlined, const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color bgColor, Color iconColor) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: 16),
    );
  }
}
