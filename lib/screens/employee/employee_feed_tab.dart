import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class EmployeeFeedTab extends StatefulWidget {
  const EmployeeFeedTab({super.key});

  @override
  State<EmployeeFeedTab> createState() => _EmployeeFeedTabState();
}

class _EmployeeFeedTabState extends State<EmployeeFeedTab> {
  final TextEditingController _messageController = TextEditingController();

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF5C5CFF),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
    ];
    int hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userName = AppSession().userName ?? 'Employee';
    final userEmail = AppSession().email ?? '';

    _messageController.clear();

    final postMap = {
      'companyId': FirestoreService.companyId,
      'author': userName,
      'authorEmail': userEmail,
      'color': '#5C5CFF',
      'comments': [],
      'reactions': [],
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'name': userName,
      'userEmail': userEmail,
      'department': AppSession().userDepartment ?? '',
      'text': text,
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
    };

    await FirestoreService.teamFeedCol.add(postMap);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myDept = (AppSession().userDepartment ?? '').toString().trim().toLowerCase();
    final myEmail = (AppSession().email ?? '').toString().trim().toLowerCase();

    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
        Expanded(
          child: Container(
            color: const Color(0xFFF9FAFB),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.teamFeedCol.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rawDocs = snapshot.data?.docs ?? [];
                final filteredDocs = rawDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dept = (data['department'] ?? '').toString().trim().toLowerCase();
                  if (AppSession().hasAdminAccess) return true;
                  if (myDept.isEmpty) return false;
                  return dept == myDept;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE5E7EB))),
                          child: Text(
                            DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Center(
                        child: Text(
                          'No messages in team feed yet. Start the conversation!',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                        ),
                      ),
                    ],
                  );
                }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final data = filteredDocs[index].data() as Map<String, dynamic>;
                        final senderEmail = (data['authorEmail'] ?? data['userEmail'] ?? '').toString().trim().toLowerCase();
                        final isMe = (senderEmail == myEmail);
                        final senderName = data['author'] ?? data['name'] ?? (isMe ? 'Me' : 'Colleague');
                        final text = data['content'] ?? data['text'] ?? '';
                        DateTime? parseDate(dynamic d) {
                          if (d == null) return null;
                          if (d is Timestamp) return d.toDate();
                          if (d is DateTime) return d;
                          if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
                          if (d is String) return DateTime.tryParse(d);
                          return null;
                        }
                        final tsVal = parseDate(data['timestamp'] ?? data['createdAt']);
                        final time = tsVal != null
                            ? DateFormat('hh:mm a').format(tsVal)
                            : 'Now';

                        final initials = _getInitials(senderName);
                        final color = _getAvatarColor(senderName);

                        return _buildMessageBubble({
                          'sender': senderName,
                          'initials': initials,
                          'color': color,
                          'time': time,
                          'text': text,
                          'isMe': isMe,
                          'read': true,
                        });
                      },
                );
              },
            ),
          ),
        ),
        _buildBottomInput(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              color: Color(0xFF5C5CFF),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppSession().userDepartment ?? 'Team'} Feed',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: const [
                  Text(
                    '5 members Â· ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '4 online',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
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

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg['isMe'] as bool;

    if (isMe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 60),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF5C5CFF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                msg['text'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg['read'] == true)
                  const Icon(Icons.done_all,
                      size: 14, color: Color(0xFF5C5CFF)),
                if (msg['read'] == true) const SizedBox(width: 4),
                Text(
                  msg['time'],
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: msg['color'],
            child: Text(
              msg['initials'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg['sender'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: msg['color'],
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    msg['text'],
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  msg['time'],
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                            fontWeight: FontWeight.w400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded,
                        color: Color(0xFF9CA3AF), size: 20),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded,
                  color: Color(0xFF5C5CFF), size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
