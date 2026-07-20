import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class EmployeeAnnouncementTab extends StatefulWidget {
  const EmployeeAnnouncementTab({super.key});

  @override
  State<EmployeeAnnouncementTab> createState() =>
      _EmployeeAnnouncementTabState();
}

class _EmployeeAnnouncementTabState extends State<EmployeeAnnouncementTab> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'HR', 'Policy', 'Events', 'Reminders'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        _buildAnnouncementsList(),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              margin: EdgeInsets.only(
                  right: 12,
                  left: index == 0
                      ? 0
                      : 0), // Adjusting margin to align with home tab padding
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF5C5CFF) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF5C5CFF)
                      : const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    Query query = FirestoreService.announcementsCol
        .where('audience', isEqualTo: 'all')
        .where('status', isEqualTo: 'published')
        .orderBy('timestamp', descending: true);
        
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots() as Stream<QuerySnapshot<Object?>>,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        
        List<DocumentSnapshot> filteredDocs = docs;
        if (_selectedFilter != 'All') {
          filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final tag = (data['category'] ?? '').toString().toLowerCase();
            return tag == _selectedFilter.toLowerCase();
          }).toList();
        }

        if (filteredDocs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No announcements available',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            return _buildAnnouncementCard(filteredDocs[index]);
          },
        );
      },
    );
  }

  void _toggleLike(DocumentReference ref) {
    // In a real app, track the user's ID to prevent multiple likes. 
    // Here we just increment for simplicity since employees are read-only.
    FirestoreService.announcementsCol.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>?;
      final currentLikes = data?['likes'] ?? 0;
      transaction.update(ref, {'likes': currentLikes + 1});
    }).catchError((error) => debugPrint("Failed to update likes: $error"));
  }

  Widget _buildAnnouncementCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final tag = (data['category'] ?? 'General').toString();
    final lowerTag = tag.toLowerCase();
    
    DateTime timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    String timeStr = _formatTimestamp(timestamp);
    Color tagColor;
    Color tagBgColor;

    if (lowerTag == 'hr') {
      tagColor = const Color(0xFF2563EB); // Blue
      tagBgColor = const Color(0xFFEFF6FF);
    } else if (lowerTag == 'policy') {
      tagColor = const Color(0xFF8B5CF6); // Purple/Indigo
      tagBgColor = const Color(0xFFF5F3FF);
    } else if (lowerTag == 'events') {
      tagColor = const Color(0xFF8B5CF6); // Purple/Indigo
      tagBgColor = const Color(0xFFF5F3FF);
    } else if (lowerTag == 'reminders') {
      tagColor = const Color(0xFFD97706); // Orange/Amber
      tagBgColor = const Color(0xFFFFFBEB);
    } else if (lowerTag == 'manager update') {
      tagColor = const Color(0xFF10B981); 
      tagBgColor = const Color(0xFFECFDF5);
    } else {
      tagColor = const Color(0xFF5C5CFF);
      tagBgColor = const Color(0xFFEEEEFF);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: tagBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 11,
                    color: tagColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            data['title'] ?? 'No Title',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['message'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleLike(doc.reference),
                    child: _statIcon(Icons.thumb_up_alt_outlined, '${data['likes'] ?? 0}'),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(
                    '${data['commentsCount'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
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

  Widget _statIcon(IconData icon, String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 4),
          Text(
            count,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
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
}
