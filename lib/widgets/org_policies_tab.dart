import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class OrgPoliciesTab extends StatefulWidget {
  const OrgPoliciesTab({super.key});

  @override
  State<OrgPoliciesTab> createState() => _OrgPoliciesTabState();
}

class _OrgPoliciesTabState extends State<OrgPoliciesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Attendance',
    'Leave',
    'Documents',
    'Conduct',
    'Workplace',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // NOTE: policies are created and edited in the web app. The mobile app never seeds
  // made-up default policies into the company's real data.

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'access_time':
      case 'clock':
        return Icons.access_time_rounded;
      case 'calendar':
        return Icons.calendar_today_rounded;
      case 'file':
      case 'document':
        return Icons.insert_drive_file_outlined;
      case 'assignment':
        return Icons.assignment_outlined;
      case 'shield':
      case 'conduct':
        return Icons.shield_outlined;
      case 'workplace':
      case 'building':
        return Icons.business_rounded;
      default:
        return Icons.policy_outlined;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'attendance':
        return const Color(0xFF5C5CFF);
      case 'leave':
        return const Color(0xFFC084FC);
      case 'documents':
        return const Color(0xFF60A5FA);
      case 'conduct':
        return const Color(0xFFEF4444);
      case 'workplace':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getCategoryBgColor(String category) {
    switch (category.toLowerCase()) {
      case 'attendance':
        return const Color(0xFFEEF2FF);
      case 'leave':
        return const Color(0xFFFAF5FF);
      case 'documents':
        return const Color(0xFFEFF6FF);
      case 'conduct':
        return const Color(0xFFFEF2F2);
      case 'workplace':
        return const Color(0xFFECFDF5);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  void _showAddEditPolicyDialog([DocumentSnapshot? doc]) {
    final isEditing = doc != null;
    final data = isEditing ? (doc.data() as Map<String, dynamic>) : {};

    final titleController = TextEditingController(text: data['title'] ?? '');
    final categoryNotifier = ValueNotifier<String>(data['category'] ?? 'Attendance');
    final deptController = TextEditingController(text: data['department'] ?? 'All Departments');
    final badgeController = TextEditingController(text: data['badge'] ?? 'Standard');
    final iconNotifier = ValueNotifier<String>(data['icon'] ?? 'access_time');

    List<String> bullets = [];
    if (data['bullets'] is List) {
      bullets = List<String>.from(data['bullets']);
    }
    if (bullets.isEmpty) {
      bullets = [''];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Policy' : 'Create New Policy',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        const SizedBox(height: 8),
                        const Text('Policy Title',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Remote Work Policy',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Category',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                                  const SizedBox(height: 6),
                                  ValueListenableBuilder<String>(
                                    valueListenable: categoryNotifier,
                                    builder: (context, catValue, _) {
                                      return DropdownButtonFormField<String>(
                                        value: _categories.contains(catValue) ? catValue : 'Attendance',
                                        items: _categories
                                            .where((c) => c != 'All')
                                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null) categoryNotifier.value = v;
                                        },
                                        decoration: InputDecoration(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Badge / Tag',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: badgeController,
                                    decoration: InputDecoration(
                                      hintText: 'Mandatory / Standard',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Department Scope',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: deptController,
                          decoration: InputDecoration(
                            hintText: 'e.g. All Departments or Engineering',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Policy Rules / Bullet Points',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                            TextButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  bullets.add('');
                                });
                              },
                              icon: const Icon(Icons.add, size: 16, color: Color(0xFF5C5CFF)),
                              label: const Text('Add Rule',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5C5CFF))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(bullets.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 6, color: Color(0xFF5C5CFF)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: bullets[index],
                                    onChanged: (val) {
                                      bullets[index] = val;
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Rule description...',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                if (bullets.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      setModalState(() {
                                        bullets.removeAt(index);
                                      });
                                    },
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;

                        final cleanBullets = bullets.where((b) => b.trim().isNotEmpty).toList();
                        if (cleanBullets.isEmpty) {
                          cleanBullets.add('Standard policy guideline');
                        }

                        final policyData = {
                          'title': title,
                          'category': categoryNotifier.value,
                          'icon': iconNotifier.value,
                          'department': deptController.text.trim().isEmpty ? 'All Departments' : deptController.text.trim(),
                          'badge': badgeController.text.trim().isEmpty ? 'Standard' : badgeController.text.trim(),
                          'bullets': cleanBullets,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                        if (isEditing) {
                          await doc.reference.update(policyData);
                        } else {
                          await FirestoreService.policiesCol.add(policyData);
                        }

                        if (mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C5CFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isEditing ? 'Update Policy' : 'Save Policy',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deletePolicy(DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Policy'),
        content: const Text('Are you sure you want to delete this organization policy document?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession().hasPermission('organization')) {
      return Container(
        color: const Color(0xFFF4F6F9),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text('Permission Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
            SizedBox(height: 8),
            Text('You do not have permission to access Organization Policies.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }
    final isAdminOrManager = AppSession().isManager || AppSession().hasAdminAccess;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.policiesCol.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // Filter by category and search query
          final filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final cat = (data['category'] ?? '').toString();
            final title = (data['title'] ?? '').toString().toLowerCase();
            final dept = (data['department'] ?? '').toString().toLowerCase();

            List<String> bullets = [];
            if (data['bullets'] is List) {
              bullets = List<String>.from(data['bullets']);
            }
            final bulletsStr = bullets.join(' ').toLowerCase();

            bool matchesCategory = _selectedCategory == 'All' || cat.toLowerCase() == _selectedCategory.toLowerCase();
            bool matchesSearch = _searchQuery.isEmpty ||
                title.contains(_searchQuery.toLowerCase()) ||
                dept.contains(_searchQuery.toLowerCase()) ||
                bulletsStr.contains(_searchQuery.toLowerCase());

            return matchesCategory && matchesSearch;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header / Action Bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search organization policies...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF9CA3AF)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Color(0xFF9CA3AF)),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          },
                          selectedColor: const Color(0xFFEEF2FF),
                          backgroundColor: Colors.white,
                          checkmarkColor: const Color(0xFF5C5CFF),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFF4B5563),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFFE5E7EB),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // List of Policies
                if (filteredDocs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.policy_outlined, size: 48, color: Color(0xFFD1D5DB)),
                        const SizedBox(height: 12),
                        const Text(
                          'No policies found',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _searchQuery.isNotEmpty ? 'Try adjusting your search criteria' : 'Policies added by HR on the web will appear here',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredDocs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final title = (data['title'] ?? 'Policy Guideline').toString();
                      final category = (data['category'] ?? 'Attendance').toString();
                      final iconName = data['icon'] as String?;
                      final department = (data['department'] ?? 'All Departments').toString();
                      final badge = (data['badge'] ?? 'Standard').toString();

                      List<String> bullets = [];
                      if (data['bullets'] is List) {
                        bullets = List<String>.from(data['bullets']);
                      }

                      final iconData = _getIconData(iconName);
                      final iconColor = _getCategoryColor(category);
                      final iconBgColor = _getCategoryBgColor(category);

                      return _buildRealtimePolicyCard(
                        doc: doc,
                        title: title,
                        category: category,
                        department: department,
                        badge: badge,
                        icon: iconData,
                        iconBgColor: iconBgColor,
                        iconColor: iconColor,
                        bullets: bullets,
                        isAdmin: isAdminOrManager,
                      );
                    },
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRealtimePolicyCard({
    required DocumentSnapshot doc,
    required String title,
    required String category,
    required String department,
    required String badge,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required List<String> bullets,
    required bool isAdmin,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            department,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: iconColor),
                    ),
                  ),
                  if (isAdmin) ...[
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF9CA3AF)),
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showAddEditPolicyDialog(doc);
                        } else if (val == 'delete') {
                          _deletePolicy(doc);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...bullets.map((bullet) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(bullet, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.3)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
