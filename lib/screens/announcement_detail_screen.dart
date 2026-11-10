import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/theme/app_theme.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final DocumentReference reference;
  final Map<String, dynamic> initialData;

  const AnnouncementDetailScreen({
    super.key,
    required this.reference,
    required this.initialData,
  });

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  bool _isPopping = false;

  bool _checkIsOurs(Map<String, dynamic> data) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    final currentUserName = AppSession().userName;

    final authorId = data['authorId'];
    final authorEmail = data['authorEmail'];
    final authorName = data['authorName'];

    if (authorId != null && currentUserId != null) {
      return authorId == currentUserId;
    } else if (authorEmail != null && currentUserEmail != null) {
      return authorEmail == currentUserEmail;
    } else if (authorName != null && currentUserName != null) {
      return authorName.toString().toLowerCase() == currentUserName.toString().toLowerCase();
    }
    return false;
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to delete this announcement? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              setState(() => _isPopping = true);
              try {
                await widget.reference.delete();
                if (mounted) {
                  Navigator.pop(context); // Close detail screen
                }
              } catch (e) {
                setState(() => _isPopping = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showEditBottomSheet(BuildContext context, Map<String, dynamic> currentData) {
    final titleController = TextEditingController(text: currentData['title']);
    final messageController = TextEditingController(text: currentData['message']);
    String selectedCategory = currentData['category'] ?? 'General';
    
    DateTime? selectedExpiry;
    final expiryVal = currentData['expiry'];
    if (expiryVal is Timestamp) {
      selectedExpiry = expiryVal.toDate();
    } else if (expiryVal is String) {
      selectedExpiry = DateTime.tryParse(expiryVal);
    }

    final categories = ['Manager Update', 'Policy', 'Events', 'Reminders', 'Birthdays', 'New Hires', 'General'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Announcement',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'Enter title...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: categories.contains(selectedCategory) ? selectedCategory : 'General',
                          isExpanded: true,
                          items: categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => selectedCategory = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter message details...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Expiry Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: sheetContext,
                          initialDate: selectedExpiry ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (date != null) {
                          setSheetState(() => selectedExpiry = date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedExpiry != null
                                  ? DateFormat('dd-MM-yyyy').format(selectedExpiry!)
                                  : 'Select Expiry Date (Optional)',
                              style: TextStyle(
                                color: selectedExpiry != null ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                              ),
                            ),
                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF4B5563))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final title = titleController.text.trim();
                              final message = messageController.text.trim();
                              if (title.isEmpty || message.isEmpty) {
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  const SnackBar(content: Text('Title and Message cannot be empty')),
                                );
                                return;
                              }

                              Navigator.pop(sheetContext); // Close bottom sheet
                              
                              try {
                                await widget.reference.update({
                                  'title': title,
                                  'message': message,
                                  'category': selectedCategory,
                                  'expiry': selectedExpiry != null ? Timestamp.fromDate(selectedExpiry!) : null,
                                });
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5C5CFF),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCommentsBottomSheet(BuildContext context) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  'Announcement Comments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: widget.reference.collection('comments').orderBy('timestamp', descending: false).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final commentsDocs = snapshot.data?.docs ?? [];
                    if (commentsDocs.isEmpty) {
                      return const Center(
                        child: Text('No comments yet. Leave a comment below!', style: TextStyle(color: Color(0xFF9CA3AF))),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: commentsDocs.length,
                      itemBuilder: (context, index) {
                        final cData = commentsDocs[index].data() as Map<String, dynamic>;
                        final cName = cData['userName'] ?? 'User';
                        final cText = cData['text'] ?? '';
                        final ts = cData['timestamp'] as Timestamp?;
                        final cTime = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : 'Now';

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
                            ],
                          ),
                        );
                      },
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
                          hintText: 'Write a comment...',
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
                        await widget.reference.collection('comments').add({
                          'userName': AppSession().userName ?? 'User',
                          'userEmail': AppSession().email ?? '',
                          'text': text,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        await widget.reference.update({
                          'comments': FieldValue.increment(1),
                          'commentsCount': FieldValue.increment(1),
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
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.reference.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && !snapshot.data!.exists) {
          if (!_isPopping) {
            _isPopping = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
          }
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.hasData && snapshot.data!.data() != null
            ? snapshot.data!.data() as Map<String, dynamic>
            : widget.initialData;

        final isOurs = _checkIsOurs(data);
        final title = data['title'] ?? 'No Title';
        final message = data['message'] ?? '';
        final category = data['category'] ?? 'General';
        final likes = data['likes'] ?? 0;
        final commentsCount = data['commentsCount'] ?? 0;
        final authorName = data['authorName'] ?? 'Admin';
        final authorRole = data['authorRole'] ?? 'admin';
        final audience = data['audience'] ?? 'all';
        final status = data['status'] ?? 'published';
        
        DateTime timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final expiryVal = data['expiry'];
        DateTime? expiryDate;
        if (expiryVal is Timestamp) {
          expiryDate = expiryVal.toDate();
        } else if (expiryVal is String) {
          expiryDate = DateTime.tryParse(expiryVal);
        }

        String timeStr = _formatTimestamp(timestamp);

        Color categoryBg;
        Color categoryColor;
        
        final lowerCat = category.toString().toLowerCase();
        if (lowerCat == 'events') {
          categoryBg = const Color(0xFFF5F3FF);
          categoryColor = const Color(0xFF8B5CF6);
        } else if (lowerCat == 'policy' || lowerCat == 'hr') {
          categoryBg = const Color(0xFFEFF6FF);
          categoryColor = const Color(0xFF3B82F6);
        } else if (lowerCat == 'manager update') {
          categoryBg = const Color(0xFFECFDF5);
          categoryColor = const Color(0xFF10B981);
        } else if (lowerCat == 'reminders' || lowerCat == 'task') {
          categoryBg = const Color(0xFFF5F3FF);
          categoryColor = const Color(0xFF7C3AED);
        } else if (lowerCat == 'birthdays') {
          categoryBg = const Color(0xFFFDF2F8);
          categoryColor = const Color(0xFFDB2777);
        } else if (lowerCat == 'new hires') {
          categoryBg = const Color(0xFFFFF7ED);
          categoryColor = const Color(0xFFEA580C);
        } else {
          categoryBg = const Color(0xFFF3F4F6);
          categoryColor = const Color(0xFF4B5563);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1F2937), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Announcement Details',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            centerTitle: false,
            actions: isOurs
                ? [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF5C5CFF)),
                      onPressed: () => _showEditBottomSheet(context, data),
                      tooltip: 'Edit Announcement',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                      onPressed: () => _confirmDelete(context),
                      tooltip: 'Delete Announcement',
                    ),
                    const SizedBox(width: 8),
                  ]
                : null,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Area Card (Premium visual style)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [categoryColor.withOpacity(0.08), categoryColor.withOpacity(0.01)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: categoryColor.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: categoryBg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: categoryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                            height: 1.3,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: categoryBg,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            authorName.isNotEmpty ? authorName[0].toUpperCase() : 'A',
                            style: TextStyle(
                              color: categoryColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: (data['authorEmail'] as String?) != null && (data['authorEmail'] as String).isNotEmpty
                                ? FirestoreService.employeeDoc(data['authorEmail']).snapshots()
                                : null,
                            builder: (context, userSnap) {
                              final userData = userSnap.data?.data() ?? {};
                              final liveRole = (userData['role'] ?? userData['designation'] ?? authorRole).toString();
                              final liveName = (userData['name'] ?? userData['userName'] ?? authorName).toString();
                              final rawRole = liveRole.toLowerCase().replaceAll('_', ' ');
                              final displayRole = (rawRole == 'super admin' ||
                                      rawRole == 'superadmin' ||
                                      rawRole == 'hr admin' ||
                                      rawRole == 'hradmin' ||
                                      rawRole == 'admin')
                                  ? 'HR Admin'
                                  : (rawRole == 'manager')
                                      ? 'Manager'
                                      : (rawRole == 'employee')
                                          ? 'Employee'
                                          : rawRole.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    liveName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Role: $displayRole',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Content',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Metadata card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Details Information',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildMetaRow('Target Audience', audience == 'all' ? 'All Employees' : audience),
                        const Divider(color: Color(0xFFF3F4F6), height: 24),
                        _buildMetaRow('Publish Status', status[0].toUpperCase() + status.substring(1)),
                        const Divider(color: Color(0xFFF3F4F6), height: 24),
                        _buildMetaRow('Expiry Date', expiryDate != null ? DateFormat('MMM d, yyyy').format(expiryDate) : 'No Expiry'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Row (Star & Comments)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final myEmail = AppSession().email ?? '';
                            if (myEmail.isEmpty) return;
                            final List likedBy = List.from(data['likedBy'] is List ? data['likedBy'] : []);
                            final isLiked = likedBy.contains(myEmail);
                            if (isLiked) {
                              likedBy.remove(myEmail);
                              await widget.reference.update({
                                'likes': FieldValue.increment(-1),
                                'likedBy': likedBy,
                              });
                            } else {
                              likedBy.add(myEmail);
                              await widget.reference.update({
                                'likes': FieldValue.increment(1),
                                'likedBy': likedBy,
                              });
                            }
                          },
                          child: Row(
                            children: [
                              Icon(
                                (data['likedBy'] is List && (data['likedBy'] as List).contains(AppSession().email))
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 22,
                                color: (data['likedBy'] is List && (data['likedBy'] as List).contains(AppSession().email))
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$likes Stars',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: (data['likedBy'] is List && (data['likedBy'] as List).contains(AppSession().email))
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 20, width: 1, color: const Color(0xFFE5E7EB)),
                        GestureDetector(
                          onTap: () => _showCommentsBottomSheet(context),
                          child: Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Color(0xFF6B7280)),
                              const SizedBox(width: 6),
                              Text(
                                '$commentsCount Comments',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
