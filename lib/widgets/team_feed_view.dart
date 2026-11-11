import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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

    // Same document the web Feed creates: team_feed/F_<ms>_<rand>, createdAt = epoch millis
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final postId = 'F_${nowMs}_${(nowMs % 1679616).toRadixString(36)}';
    final dept = AppSession().userDepartment ?? '';
    final postMap = {
      'id': postId,
      'author': userName,
      'authorEmail': userEmail.toLowerCase(),
      'initials': _getInitials(userName),
      'color': '#5C5CFF',
      'time': DateFormat('hh:mm a').format(DateTime.now()),
      'createdAt': nowMs,
      'text': text,
      'dept': dept.isEmpty ? 'All' : dept,
      'designation': AppSession().displayRole,
      'pinned': false,
      'saved': false,
      'resolved': false,
      'reactions': [],
      'comments': [],
      'followers': [userName],
    };

    await FirestoreService.companyDoc().collection('team_feed').doc(postId).set(postMap);

    _postController.clear();
  }

  Future<void> _toggleStar(DocumentReference docRef, dynamic likedByData) async {
    final myEmail = AppSession().email ?? '';
    if (myEmail.isEmpty) return;

    final List likedBy = List.from(likedByData is List ? likedByData : []);
    final bool isLiked = likedBy.contains(myEmail);

    if (isLiked) {
      likedBy.remove(myEmail);
      await docRef.update({
        'likes': FieldValue.increment(-1),
        'likedBy': likedBy,
      });
    } else {
      likedBy.add(myEmail);
      await docRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': likedBy,
      });
    }
  }

  // ── Web-compatible reaction model ───────────────────────────────────────────
  // Web stores reactions as [{emoji: "👍", users: ["Display Name", ...]}].
  // Older mobile data used [{email, emoji}]; both are read here, web format is written.

  String get _myReactionId =>
      (AppSession().userName ?? AppSession().email ?? 'Member').toString();

  bool _isMine(dynamic id) {
    final v = id.toString().toLowerCase();
    return v == _myReactionId.toLowerCase() ||
        v == (AppSession().email ?? '').toLowerCase();
  }

  Map<String, int> _reactionCounts(List reactions) {
    final counts = <String, int>{};
    for (final rx in reactions) {
      if (rx is! Map) continue;
      final emoji = rx['emoji']?.toString() ?? '';
      if (emoji.isEmpty) continue;
      final users = rx['users'];
      final n = users is List ? users.length : 1; // legacy {email, emoji} = 1 person
      if (n > 0) counts[emoji] = (counts[emoji] ?? 0) + n;
    }
    return counts;
  }

  /// The reaction the current user has already given (or null).
  Map<String, dynamic>? _myReaction(List reactions) {
    for (final rx in reactions) {
      if (rx is! Map) continue;
      final users = rx['users'];
      final mine = users is List
          ? users.any(_isMine)
          : (rx['email'] != null && _isMine(rx['email']));
      if (mine) return {'emoji': rx['emoji']};
    }
    return null;
  }

  /// Toggles [emoji] for the current user and returns the list in web format.
  List<Map<String, dynamic>> _toggleReaction(List reactions, String emoji) {
    final out = <Map<String, dynamic>>[];
    for (final rx in reactions) {
      if (rx is! Map) continue;
      final e = rx['emoji']?.toString() ?? '';
      if (e.isEmpty) continue;
      final users = rx['users'] is List
          ? List<String>.from((rx['users'] as List).map((u) => u.toString()))
          : <String>[(rx['email'] ?? '').toString()]; // legacy entry
      out.add({'emoji': e, 'users': users});
    }
    final idx = out.indexWhere((r) => r['emoji'] == emoji);
    if (idx == -1) {
      out.add({'emoji': emoji, 'users': [_myReactionId]});
    } else {
      final users = List<String>.from(out[idx]['users'] as List);
      if (users.any(_isMine)) {
        users.removeWhere(_isMine);
      } else {
        users.add(_myReactionId);
      }
      out[idx] = {'emoji': emoji, 'users': users};
    }
    out.removeWhere((r) => (r['users'] as List).isEmpty);
    return out;
  }

  Future<void> _updatePostReaction(DocumentReference docRef, List reactionsList, String emoji) async {
    if ((AppSession().email ?? '').isEmpty) return;
    await docRef.update({'reactions': _toggleReaction(reactionsList, emoji)});
  }

  Future<void> _updateCommentReaction(DocumentReference postDocRef, List allComments, String commentId, String emoji) async {
    if ((AppSession().email ?? '').isEmpty) return;

    List updatedComments = allComments.map((comment) {
      final cMap = Map<String, dynamic>.from(comment);
      if (cMap['id'] == commentId) {
        cMap['reactions'] = _toggleReaction(
            cMap['reactions'] is List ? cMap['reactions'] as List : [], emoji);
      }
      return cMap;
    }).toList();

    await postDocRef.update({'comments': updatedComments});
  }

  void _showEmojiPicker({
    required BuildContext context,
    required Function(String emoji) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'React with Emoji',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onSelected(emoji);
                    },
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showCommentsBottomSheet(BuildContext context, DocumentReference docRef) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: docRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            final postData = snapshot.data!.data() as Map<String, dynamic>;
            final List rawComments = postData['comments'] is List ? postData['comments'] as List : [];
            
            DateTime? parseDate(dynamic d) {
              if (d == null) return null;
              if (d is Timestamp) return d.toDate();
              if (d is DateTime) return d;
              if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
              if (d is String) return DateTime.tryParse(d);
              return null;
            }

            final comments = rawComments.map((c) => Map<String, dynamic>.from(c)).toList()
              ..sort((a, b) {
                final aTime = parseDate(a['createdAt']) ?? DateTime(2000);
                final bTime = parseDate(b['createdAt']) ?? DateTime(2000);
                return aTime.compareTo(bTime);
              });

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Comments',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  Expanded(
                    child: comments.isEmpty
                        ? const Center(
                            child: Text('No comments yet. Be the first to comment!', style: TextStyle(color: Color(0xFF9CA3AF))),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final cData = comments[index];
                              final cName = cData['author'] ?? cData['userName'] ?? 'Member';
                              final cText = cData['text'] ?? cData['content'] ?? cData['message'] ?? '';
                              final tsVal = parseDate(cData['createdAt'] ?? cData['timestamp']);
                              final cTime = tsVal != null ? DateFormat('hh:mm a').format(tsVal) : 'Now';
                              
                              final reactionsList = cData['reactions'] is List ? cData['reactions'] as List : [];
                              final commentId = cData['id'] ?? '';

                              // Render comment reactions
                              final Map<String, int> rxCounts = _reactionCounts(reactionsList);
                              final myReaction = _myReaction(reactionsList);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(cName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937))),
                                        Text(cTime, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(cText, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: rxCounts.entries.map((e) {
                                            return Container(
                                              margin: const EdgeInsets.only(right: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                              ),
                                              child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 10)),
                                            );
                                          }).toList(),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            _showEmojiPicker(
                                              context: context,
                                              onSelected: (emoji) {
                                                _updateCommentReaction(docRef, rawComments, commentId, emoji);
                                              },
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: myReaction != null ? const Color(0xFFEEF2FF) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  myReaction != null ? myReaction['emoji'] : '☺',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: myReaction != null ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  myReaction != null ? 'Reacted' : 'React',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: myReaction != null ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFF5C5CFF), size: 20),
                          onPressed: () async {
                            final text = commentController.text.trim();
                            if (text.isEmpty) return;
                            commentController.clear();
                            
                            final timestamp = DateTime.now().millisecondsSinceEpoch;
                            final initials = _getInitials(AppSession().userName ?? 'Member');
                            
                            final newComment = {
                              'attachment': null,
                              'author': AppSession().userName ?? 'Member',
                              'authorEmail': AppSession().email ?? '',
                              'color': '#5C5CFF',
                              'createdAt': timestamp,
                              'id': 'FC_${timestamp}_${initials.toLowerCase()}',
                              'initials': initials,
                              'time': DateFormat('hh:mm a').format(DateTime.now()),
                              'reactions': [],
                              'replies': [],
                              'text': text,
                            };

                            await docRef.update({
                              'comments': FieldValue.arrayUnion([newComment]),
                            });
                          },
                        ),
                      ],
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
    final myDept = (AppSession().userDepartment ?? '').toString().trim().toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.companyDoc().collection('team_feed').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        DateTime postTime(QueryDocumentSnapshot d) {
          final m = d.data() as Map<String, dynamic>;
          return FirestoreService.parseAnyDate(m['createdAt'] ?? m['timestamp']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
        }

        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dept = (data['dept'] ?? data['department'] ?? '').toString().trim().toLowerCase();
          final isMine = (data['authorEmail'] ?? '').toString().toLowerCase() ==
              (AppSession().email ?? '').toLowerCase();
          if (myDept.isEmpty || AppSession().hasAdminAccess || isMine) return true;
          return dept == myDept || dept.isEmpty || dept == 'all';
        }).toList()
          ..sort((a, b) => postTime(b).compareTo(postTime(a)));

        if (docs.isEmpty) {
          return const Center(child: Text('No posts yet for your department.', style: TextStyle(color: Color(0xFF6B7280))));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final name = data['name'] ?? data['author'] ?? data['authorName'] ?? 'Unknown';
            final text = data['text'] ?? data['content'] ?? data['message'] ?? '';
            final likes = data['likes'] ?? 0;
            
            final List commentsList = data['comments'] is List ? data['comments'] as List : [];
            final commentsCount = commentsList.length;
            
            final List reactionsList = data['reactions'] is List ? data['reactions'] as List : [];

            DateTime? parseDate(dynamic d) {
              if (d == null) return null;
              if (d is Timestamp) return d.toDate();
              if (d is DateTime) return d;
              if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
              if (d is String) return DateTime.tryParse(d);
              return null;
            }
            final tsVal = parseDate(data['createdAt'] ?? data['timestamp']);
            final timeStr = tsVal != null ? _formatTimeAgo(tsVal) : 'Just now';

            // Post reactions grouping
            final Map<String, int> rxCounts = _reactionCounts(reactionsList);
            final myPostReaction = _myReaction(reactionsList);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
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
                  
                  // Post reactions display row
                  if (rxCounts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: rxCounts.entries.map((e) {
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 20,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _toggleStar(docs[index].reference, data['likedBy']),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (data['likedBy'] is List && (data['likedBy'] as List).contains(AppSession().email))
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 20,
                              color: (data['likedBy'] is List && (data['likedBy'] as List).contains(AppSession().email))
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${likes is num ? likes.toInt() : (likes is List ? likes.length : int.tryParse(likes.toString()) ?? 0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: (data['likedBy'] is List && (data['likedBy'] as List).contains(AppSession().email))
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      GestureDetector(
                        onTap: () {
                          _showEmojiPicker(
                            context: context,
                            onSelected: (emoji) {
                              _updatePostReaction(docs[index].reference, reactionsList, emoji);
                            },
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              myPostReaction != null ? Icons.add_reaction : Icons.add_reaction_outlined,
                              size: 18,
                              color: myPostReaction != null ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              myPostReaction != null ? myPostReaction['emoji'] : 'React',
                              style: TextStyle(
                                fontSize: 12,
                                color: myPostReaction != null ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      GestureDetector(
                        onTap: () => _showCommentsBottomSheet(context, docs[index].reference),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Text(
                              '$commentsCount',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
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
