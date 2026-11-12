import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/widgets/user_avatar.dart';
import 'package:attendance_app/features/attendance/screens/manager/employee_workspace_screen.dart';

class OrgEmployeesScreen extends StatefulWidget {
  const OrgEmployeesScreen({super.key});

  @override
  State<OrgEmployeesScreen> createState() => _OrgEmployeesScreenState();
}

class _OrgEmployeesScreenState extends State<OrgEmployeesScreen> {
  String _searchQuery = '';
  String _selectedDept = 'All';

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF5C5CFF),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF06B6D4),
      const Color(0xFFEC4899),
    ];
    int hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1F2937), size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Employees',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              'Organization Members',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.employeesCol.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = (snapshot.data?.docs ?? [])
              .where((d) =>
                  FirestoreService.isDocInCurrentCompany(d) &&
                  FirestoreService.isActiveUserDoc(d.data() as Map<String, dynamic>))
              .toList();

          // Extract departments for filter chips
          final Set<String> depts = {'All'};
          for (final doc in docs) {
            depts.add(FirestoreService.deptOf(doc.data() as Map<String, dynamic>));
          }

          // Filter by search & selected department
          final filtered = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ??
                    data['userName'] ??
                    '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
                .toString()
                .trim()
                .toLowerCase();
            final email = (data['email'] ?? doc.id).toString().toLowerCase();
            final dept = FirestoreService.deptOf(data);
            final role = (data['designation'] ?? data['roleLabel'] ?? data['role'] ?? '').toString();

            final matchesSearch = _searchQuery.isEmpty ||
                name.contains(_searchQuery.toLowerCase()) ||
                email.contains(_searchQuery.toLowerCase()) ||
                dept.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                role.toLowerCase().contains(_searchQuery.toLowerCase());

            final matchesDept = _selectedDept == 'All' ||
                dept.toLowerCase() == _selectedDept.toLowerCase();

            return matchesSearch && matchesDept;
          }).toList();

          return Column(
            children: [
              // Search & Filter header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.trim()),
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1F2937)),
                        decoration: InputDecoration(
                          hintText: 'Search by employee name, email, role...',
                          hintStyle: const TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF)),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: Color(0xFF9CA3AF), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      color: Color(0xFF9CA3AF), size: 18),
                                  onPressed: () =>
                                      setState(() => _searchQuery = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (depts.length > 2) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: depts.map((dept) {
                            final isSelected = _selectedDept.toLowerCase() ==
                                dept.toLowerCase();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(dept),
                                selected: isSelected,
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedDept = dept);
                                },
                                selectedColor: const Color(0xFF5C5CFF),
                                backgroundColor: const Color(0xFFF1F5F9),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF4B5563),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFF5C5CFF)
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Total count info bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SHOWING ${filtered.length} OF ${docs.length} EMPLOYEES',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Employees List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.people_outline_rounded,
                                  size: 48,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No employees found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No results matching "$_searchQuery"'
                                    : 'No employees in this organization yet',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final email = (data['email'] ?? doc.id).toString();

                          // Get human readable display name
                          String displayName =
                              (data['name'] ?? data['userName'] ?? '')
                                  .toString()
                                  .trim();
                          if (displayName.isEmpty) {
                            final fn =
                                (data['firstName'] ?? '').toString().trim();
                            final ln =
                                (data['lastName'] ?? '').toString().trim();
                            displayName = '$fn $ln'.trim();
                          }
                          if (displayName.isEmpty) {
                            displayName = email.split('@').first;
                          }

                          final department = FirestoreService.deptOf(data);
                          final designation = (data['designation'] ??
                                  data['jobTitle'] ??
                                  data['roleLabel'] ??
                                  data['role'] ??
                                  'Employee')
                              .toString();
                          final phone = (data['phone'] ??
                                  data['mobile'] ??
                                  data['contactNumber'] ??
                                  '')
                              .toString();
                          final avatarColor = _getAvatarColor(displayName);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x05000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EmployeeWorkspaceScreen(
                                        employeeData: {
                                          ...data,
                                          'name': displayName,
                                          'email': email,
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      UserAvatar(
                                        name: displayName,
                                        imageData: (data['profileImageUrl'] ?? '').toString(),
                                        radius: 24,
                                        color: avatarColor,
                                      ),
                                      const SizedBox(width: 14),

                                      // Employee Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF1E293B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFEEF2FF),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    designation.toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF4F46E5),
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    '•  $department',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              phone.isNotEmpty
                                                  ? '$email  •  $phone'
                                                  : email,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF94A3B8),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Chevron Right Action
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
