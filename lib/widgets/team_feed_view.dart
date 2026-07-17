import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class TeamFeedView extends StatefulWidget {
  const TeamFeedView({super.key});

  @override
  State<TeamFeedView> createState() => _TeamFeedViewState();
}

class _TeamFeedViewState extends State<TeamFeedView> {
  final TextEditingController _postController = TextEditingController();

  @override
  void dispose() {
    _postController.dispose();
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

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _submitPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;

    final userName = AppSession().userName ?? 'Admin';
    final userEmail = AppSession().email ?? 'admin@company.com';

    await FirestoreService.companyDoc().collection('feed_posts').add({
      'name': userName,
      'userEmail': userEmail,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
      'comments': 0,
    });

    _postController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserInitials = _getInitials(AppSession().userName ?? 'Admin');

    return Container(
      color: const Color(0xFFF4F6F9),
      child: Column(
        children: [
          Expanded(child: _buildFeedList()),
          _buildPostInput(currentUserInitials),
        ],
      ),
    );
  }

  Widget _buildFeedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.companyDoc().collection('feed_posts').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text('No posts yet.', style: TextStyle(color: Color(0xFF6B7280))));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // padding at bottom for input
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            
            final name = data['name'] ?? 'Unknown';
            final text = data['text'] ?? '';
            final likes = data['likes'] ?? 0;
            final comments = data['comments'] ?? 0;
            final ts = data['timestamp'] as Timestamp?;
            final timeStr = ts != null ? _formatTimeAgo(ts.toDate()) : 'Just now';

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                          const SizedBox(height: 2),
                          Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    text,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.star_border_rounded, size: 18, color: const Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Text('$likes', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                      const SizedBox(width: 16),
                      Icon(Icons.chat_bubble_outline_rounded, size: 16, color: const Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Text('$comments', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostInput(String currentUserInitials) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF5C5CFF),
              child: Text(
                currentUserInitials,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _postController,
                        decoration: const InputDecoration(
                          hintText: 'Share something with the team...',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _submitPost,
                      child: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF9CA3AF)),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
