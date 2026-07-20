import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class EmployeeTeamAnnouncementsTab extends StatefulWidget {
  const EmployeeTeamAnnouncementsTab({super.key});

  @override
  State<EmployeeTeamAnnouncementsTab> createState() =>
      _EmployeeTeamAnnouncementsTabState();
}

class _EmployeeTeamAnnouncementsTabState
    extends State<EmployeeTeamAnnouncementsTab> {
  int _selectedFilter = 0;
  final List<String> _filters = [
    'All',
    'Task',
    'Meeting',
    'Policy',
    'Events'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Container(
          color: const Color(0xFFF9FAFB),
          child: _buildAnnouncementsList(),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: List.generate(_filters.length, (i) {
          final sel = _selectedFilter == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = i),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.only(bottom: 11, top: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: sel ? const Color(0xFF5C5CFF) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _filters[i],
                    style: TextStyle(
                      color: sel
                          ? const Color(0xFF5C5CFF)
                          : const Color(0xFF6B7280),
                      fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    // If we can't get departmentId easily from AppSession, we will just query for 'team' audience.
    // In a full implementation, you'd add departmentId to AppSession and filter by it.
    Query query = FirestoreService.announcementsCol
        .where('audience', isEqualTo: 'team')
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
        if (_selectedFilter != 0) { // 0 is 'All'
          final filterText = _filters[_selectedFilter].toLowerCase();
          filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final tag = (data['category'] ?? '').toString().toLowerCase();
            return tag == filterText;
          }).toList();
        }

        if (filteredDocs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No team announcements available',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredDocs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _buildAnnouncementCard(filteredDocs[index]);
          },
        );
      },
    );
  }

  void _toggleLike(DocumentReference ref) {
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

    Color tagColor = const Color(0xFF5C5CFF);
    Color tagBgColor = const Color(0xFFEEF2FF);

    if (lowerTag == 'hr' || lowerTag == 'policy' || lowerTag == 'manager update') {
      tagColor = const Color(0xFF6366F1); // Indigo
      tagBgColor = const Color(0xFFEEF2FF);
    } else if (lowerTag == 'events') {
      tagColor = const Color(0xFF3B82F6); // Blue
      tagBgColor = const Color(0xFFEFF6FF);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tagColor,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data['title'] ?? 'No Title',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Likes: ${data['likes'] ?? 0}  Â·  Comments: ${data['commentsCount'] ?? 0}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF5C5CFF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['message'] ?? '',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _toggleLike(doc.reference),
                child: Row(
                  children: const [
                    Icon(Icons.thumb_up_alt_outlined, size: 16, color: Color(0xFF5C5CFF)),
                    SizedBox(width: 4),
                    Text(
                      'Like',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5C5CFF),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: const [
                  Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Color(0xFF6B7280),
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
}
