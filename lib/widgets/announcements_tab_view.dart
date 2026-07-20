import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnnouncementsTabView extends StatefulWidget {
  final bool isAdmin;
  final String? departmentId;

  const AnnouncementsTabView({
    super.key,
    required this.isAdmin,
    this.departmentId,
  });

  @override
  State<AnnouncementsTabView> createState() => _AnnouncementsTabViewState();
}

class _AnnouncementsTabViewState extends State<AnnouncementsTabView> {
  int _selectedCategoryTab = 0; // 0: All, 1: HR, 2: Policy, 3: Events, 4: Manager Update
  bool _isCreatingAnnouncement = false;

  // Create Announcement State
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  int _createCategoryIndex = 0; // 0: Manager Update, 1: Policy, 2: Events, 3: Reminders
  int _createAudienceIndex = 0;

  final _categories = ['All', 'HR', 'Policy', 'Events', 'Manager Update', 'Birthdays', 'New Hires'];
  final _createCategories = ['Manager Update', 'Policy', 'Events', 'Reminders', 'Birthdays', 'New Hires'];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submitAnnouncement(bool isDraft) async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final category = _createCategories[_createCategoryIndex];

    String audience = 'all';
    if (widget.isAdmin) {
      audience = _createAudienceIndex == 0 ? 'all' : 'managers';
    } else {
      audience = _createAudienceIndex == 0 ? 'team' : 'admins';
    }

    try {
      await FirestoreService.announcementsCol.add({
        'title': title,
        'message': message,
        'category': category,
        'audience': audience,
        'departmentId': widget.departmentId,
        'authorName': user?.displayName ?? 'Admin',
        'authorRole': widget.isAdmin ? 'admin' : 'manager',
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'commentsCount': 0,
        'status': isDraft ? 'draft' : 'published',
      });

      setState(() {
        _isCreatingAnnouncement = false;
        _titleController.clear();
        _messageController.clear();
        _createCategoryIndex = 0;
        _createAudienceIndex = 0;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isDraft ? 'Draft saved successfully' : 'Announcement published successfully'),
          backgroundColor: AppTheme.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  void _deleteAnnouncement(DocumentReference ref) async {
    try {
      await ref.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Announcement deleted'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  Widget _buildCategoryTabs() {
    return Container(
      color: Colors.white,
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          if (index == _categories.length) {
            return GestureDetector(
              onTap: () => setState(() => _isCreatingAnnouncement = true),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF5C5CFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            );
          }

          final isActive = _selectedCategoryTab == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryTab = index),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _categories[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'No Title';
    final message = data['message'] ?? '';
    final category = data['category'] ?? 'General';
    final likes = data['likes'] ?? 0;
    final commentsCount = data['commentsCount'] ?? 0;
    
    DateTime timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    String timeStr = _formatTimestamp(timestamp);

    Color categoryBg = const Color(0xFFEEF2FF);
    Color categoryColor = const Color(0xFF5C5CFF);
    
    if (category == 'Events') {
      categoryBg = const Color(0xFFFAF5FF);
      categoryColor = const Color(0xFFA855F7);
    } else if (category == 'Policy' || category == 'HR') {
      categoryBg = const Color(0xFFEFF6FF);
      categoryColor = const Color(0xFF3B82F6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: categoryBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  category,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: categoryColor),
                ),
              ),
              Row(
                children: [
                  Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  const SizedBox(width: 8),
                  const Icon(Icons.more_horiz, size: 16, color: Color(0xFF9CA3AF)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
          const SizedBox(height: 6),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.thumb_up_outlined, size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text('$likes', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  const SizedBox(width: 16),
                  const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text('$commentsCount', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
              if (widget.isAdmin || data['authorRole'] == 'manager')
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {}, // Edit not implemented
                      child: Row(
                        children: const [
                          Icon(Icons.edit_outlined, size: 12, color: Color(0xFF5C5CFF)),
                          SizedBox(width: 4),
                          Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5C5CFF))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _deleteAnnouncement(doc.reference),
                      child: Row(
                        children: const [
                          Icon(Icons.delete_outline, size: 12, color: Color(0xFFEF4444)),
                          SizedBox(width: 4),
                          Text('Delete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays == 0) {
      return DateFormat('hh:mm a').format(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(time);
    }
  }

  Widget _buildCreateAnnouncementView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isCreatingAnnouncement = false),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: const [
                Icon(Icons.arrow_back_ios, size: 16, color: Color(0xFF1F2937)),
                SizedBox(width: 8),
                Text('Create Announcement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Audience', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(2, (index) {
                    final isActive = _createAudienceIndex == index;
                    final text = widget.isAdmin 
                        ? (index == 0 ? 'All Staff' : 'Managers Only')
                        : (index == 0 ? 'My Team' : 'Admins Only');
                    return GestureDetector(
                      onTap: () => setState(() => _createAudienceIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? Colors.white : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_createCategories.length, (index) {
                    final isActive = _createCategoryIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _createCategoryIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _createCategories[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? Colors.white : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                const Text('Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Announcement title...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF5C5CFF)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Message', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Write your announcement...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF5C5CFF)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attachments coming soon')));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.attach_file, size: 16, color: Color(0xFF9CA3AF)),
                        SizedBox(width: 8),
                        Text('Add attachment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _submitAnnouncement(true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Save Draft', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _submitAnnouncement(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5C5CFF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Publish', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreatingAnnouncement) {
      return _buildCreateAnnouncementView();
    }

    Query<Map<String, dynamic>> query = FirestoreService.announcementsCol
        .where('status', isEqualTo: 'published')
        .orderBy('timestamp', descending: true);

    return Column(
      children: [
        _buildCategoryTabs(),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

              final allDocs = snapshot.data?.docs ?? [];
              
              List<DocumentSnapshot> filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                
                // Audience filtering locally to avoid composite index requirements initially
                if (!widget.isAdmin) {
                  final aud = data['audience'] ?? 'all';
                  // Managers can see 'all', 'managers', 'admins', or their own 'team'
                  if (aud != 'all' && aud != 'managers' && aud != 'admins' && aud != 'team') {
                     return false;
                  }
                  if (aud == 'team' && data['departmentId'] != widget.departmentId) {
                     return false;
                  }
                }

                // Category filtering
                String cat = data['category'] ?? 'General';
                if (_selectedCategoryTab == 1) return cat == 'HR';
                if (_selectedCategoryTab == 2) return cat == 'Policy';
                if (_selectedCategoryTab == 3) return cat == 'Events';
                if (_selectedCategoryTab == 4) return cat == 'Manager Update';
                if (_selectedCategoryTab == 5) return cat == 'Birthdays';
                if (_selectedCategoryTab == 6) return cat == 'New Hires';
                return true; // 0 is All
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(child: Text('No announcements found', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  return _buildAnnouncementCard(filteredDocs[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
