import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class EmployeeDocumentsScreen extends StatefulWidget {
  const EmployeeDocumentsScreen({super.key});

  @override
  State<EmployeeDocumentsScreen> createState() => _EmployeeDocumentsScreenState();
}

class _EmployeeDocumentsScreenState extends State<EmployeeDocumentsScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Access Control ──────────────────────────────────────────────────────────
  bool _canAccessDocument(Map<String, dynamic> data) {
    final access = (data['accessLevel'] ?? 'All Employees').toString().toLowerCase();
    final isHr = AppSession().isHrAdmin;
    final isManager = AppSession().isManagerOrAbove;

    if (access.contains('hr only') || access.contains('hr_only')) {
      return isHr;
    }
    if (access.contains('admin') || access.contains('management')) {
      return isHr || isManager;
    }
    return true;
  }

  // ── Category Matching ───────────────────────────────────────────────────────
  bool _matchesCategory(Map<String, dynamic> data, String filter) {
    if (filter == 'All') return true;
    final cat = (data['category'] ?? data['type'] ?? '').toString().trim().toLowerCase();
    final f = filter.trim().toLowerCase();
    if (cat == f) return true;
    if (cat.contains(f) || f.contains(cat)) return true;
    if (f == 'company policies' && cat.contains('polic')) return true;
    if (f == 'policies' && cat.contains('polic')) return true;
    if (f == 'salary documents' && cat.contains('salar')) return true;
    if (f == 'certificates' && cat.contains('cert')) return true;
    if (f == 'letters' && cat.contains('letter')) return true;
    if (f == 'templates' && cat.contains('template')) return true;
    if (f == 'legal' && cat.contains('legal')) return true;
    return false;
  }

  // ── Section Header Formatting ───────────────────────────────────────────────
  String _formatSectionHeader(String cat) {
    final c = cat.trim().toLowerCase();
    if (c == 'policy' || c == 'company policies' || c == 'policies') return 'COMPANY POLICIES';
    if (c == 'certificate' || c == 'certificates') return 'CERTIFICATES';
    if (c == 'salary' || c == 'salary documents') return 'SALARY DOCUMENTS';
    if (c == 'letter' || c == 'letters') return 'LETTERS';
    if (c == 'template' || c == 'templates') return 'TEMPLATES & FORMS';
    if (c == 'legal' || c == 'legal / compliance') return 'LEGAL & COMPLIANCE';
    if (c == 'handbook' || c == 'employee handbook') return 'EMPLOYEE HANDBOOK';
    if (c == 'finance' || c == 'finance / tax') return 'FINANCE & TAX';
    return cat.trim().isEmpty ? 'GENERAL DOCUMENTS' : cat.toUpperCase();
  }

  // ── Extract Subtitle Info (e.g. "PDF · 2.4 MB · Jun 1, 2026") ───────────────
  String _formatSubtitle(Map<String, dynamic> data) {
    final fileName = (data['fileName'] ?? '').toString();
    final fileUrl = (data['fileUrl'] ?? '').toString();
    final size = (data['size'] ?? data['fileSize'] ?? '1.0 MB').toString();

    // Determine type
    String type = 'PDF';
    final targetStr = fileName.isNotEmpty ? fileName : fileUrl;
    if (targetStr.contains('.')) {
      final ext = targetStr.split('.').last.split('?').first.toUpperCase();
      if (ext.length <= 5) type = ext;
    }

    // Determine date
    String dateStr = 'Recent';
    final rawDate = data['updated'] ?? data['updatedAt'] ?? data['createdAt'];
    if (rawDate != null) {
      if (rawDate is Timestamp) {
        dateStr = DateFormat('MMM d, yyyy').format(rawDate.toDate());
      } else if (rawDate is String && rawDate.isNotEmpty) {
        try {
          final dt = DateTime.parse(rawDate);
          dateStr = DateFormat('MMM d, yyyy').format(dt);
        } catch (_) {
          dateStr = rawDate;
        }
      }
    }

    return '$type · $size · $dateStr';
  }

  // ── Open / Download Document ────────────────────────────────────────────────
  Future<void> _openDocument(String? urlStr, String title) async {
    if (urlStr == null || urlStr.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No file attachment URL found for "$title".'),
          backgroundColor: const Color(0xFF374151),
        ),
      );
      return;
    }

    final trimmed = urlStr.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open document: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // ── Share Document ──────────────────────────────────────────────────────────
  void _shareDocument(Map<String, dynamic> data) {
    final title = (data['name'] ?? data['title'] ?? 'Document').toString();
    final url = (data['fileUrl'] ?? '').toString();
    final info = _formatSubtitle(data);

    if (url.isNotEmpty) {
      Share.share('$title ($info)\n$url', subject: title);
    } else {
      Share.share('$title ($info)', subject: title);
    }
  }

  // ── Info Modal Sheet ────────────────────────────────────────────────────────
  void _showDocumentDetails(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final title = (data['name'] ?? data['title'] ?? data['fileName'] ?? 'Untitled Document').toString();
    final category = (data['category'] ?? 'Policy').toString();
    final accessLevel = (data['accessLevel'] ?? 'All Employees').toString();
    final size = (data['size'] ?? '1.0 MB').toString();
    final updatedBy = (data['updatedBy'] ?? 'Admin').toString();
    final status = (data['status'] ?? 'Published').toString();
    final fileUrl = (data['fileUrl'] ?? '').toString();
    final fileName = (data['fileName'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description_outlined, color: Color(0xFFDC2626), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              category,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFF3F4F6)),
              const SizedBox(height: 12),
              _buildDetailRow('Access Level', accessLevel),
              _buildDetailRow('File Size', size),
              if (fileName.isNotEmpty) _buildDetailRow('File Name', fileName),
              _buildDetailRow('Updated By', updatedBy),
              _buildDetailRow('Info', _formatSubtitle(data)),
              const SizedBox(height: 20),
              // Buttons
              Row(
                children: [
                  if (fileUrl.isNotEmpty) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openDocument(fileUrl, title);
                        },
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open Document', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Document Card Icon ──────────────────────────────────────────────────────
  Widget _buildDocIcon(Map<String, dynamic> data) {
    final fileName = (data['fileName'] ?? '').toString().toLowerCase();
    final fileUrl = (data['fileUrl'] ?? '').toString().toLowerCase();
    final target = fileName.isNotEmpty ? fileName : fileUrl;

    Color bgColor = const Color(0xFFFEF2F2);
    Color iconColor = const Color(0xFFDC2626);
    IconData iconData = Icons.description_outlined;

    if (target.contains('.doc') || target.contains('.docx')) {
      bgColor = const Color(0xFFEFF6FF);
      iconColor = const Color(0xFF2563EB);
      iconData = Icons.article_outlined;
    } else if (target.contains('.xls') || target.contains('.xlsx') || target.contains('.csv')) {
      bgColor = const Color(0xFFECFDF5);
      iconColor = const Color(0xFF059669);
      iconData = Icons.table_chart_outlined;
    } else if (target.contains('.png') || target.contains('.jpg') || target.contains('.jpeg') || target.contains('.webp')) {
      bgColor = const Color(0xFFF5F3FF);
      iconColor = const Color(0xFF7C3AED);
      iconData = Icons.image_outlined;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 22),
    );
  }

  // ── Action Buttons ──────────────────────────────────────────────────────────
  Widget _buildActionButton(IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 16),
      ),
    );
  }

  // ── Document Card Item ──────────────────────────────────────────────────────
  Widget _buildDocumentCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final title = (data['name'] ?? data['title'] ?? data['fileName'] ?? 'Untitled Document').toString();
    final info = _formatSubtitle(data);
    final fileUrl = (data['fileUrl'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x05000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (fileUrl.isNotEmpty) {
            _openDocument(fileUrl, title);
          } else {
            _showDocumentDetails(doc);
          }
        },
        child: Row(
          children: [
            _buildDocIcon(data),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions Row
            Row(
              children: [
                _buildActionButton(
                  Icons.info_outline,
                  const Color(0xFFEEF2FF),
                  const Color(0xFF6366F1),
                  () => _showDocumentDetails(doc),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  Icons.arrow_downward_rounded,
                  const Color(0xFFECFDF5),
                  const Color(0xFF10B981),
                  () => _openDocument(fileUrl, title),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  Icons.send_outlined,
                  const Color(0xFFF3F4F6),
                  const Color(0xFF6B7280),
                  () => _shareDocument(data),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cid = AppSession().companyId;

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
        title: const Text(
          'Documents',
          style: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: cid == null || cid.isEmpty
          ? const Center(
              child: Text(
                'Please sign in to view documents.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.documentsCol.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load documents:\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];
                // Filter accessible documents
                final accessibleDocs = allDocs.where((d) => _canAccessDocument(d.data())).toList();

                // Build dynamic filters
                final List<String> availableFilters = ['All'];
                for (final d in accessibleDocs) {
                  final cat = (d.data()['category'] ?? d.data()['type'] ?? '').toString().trim();
                  if (cat.isNotEmpty && !availableFilters.any((f) => f.toLowerCase() == cat.toLowerCase())) {
                    availableFilters.add(cat);
                  }
                }
                // Add standard filters if list is small so user has convenient category shortcuts
                for (final def in ['Company Policies', 'Certificates', 'Salary Documents', 'Templates', 'Legal']) {
                  if (!availableFilters.contains(def) && availableFilters.length < 7) {
                    availableFilters.add(def);
                  }
                }

                // Apply category & search filter
                final query = _searchController.text.trim().toLowerCase();
                final filteredDocs = accessibleDocs.where((d) {
                  final data = d.data();
                  if (!_matchesCategory(data, _selectedFilter)) return false;
                  if (query.isEmpty) return true;
                  final name = (data['name'] ?? data['title'] ?? data['fileName'] ?? '').toString().toLowerCase();
                  final cat = (data['category'] ?? '').toString().toLowerCase();
                  final updatedBy = (data['updatedBy'] ?? '').toString().toLowerCase();
                  return name.contains(query) || cat.contains(query) || updatedBy.contains(query);
                }).toList();

                // Group by Section Header
                final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
                for (final doc in filteredDocs) {
                  final rawCat = (doc.data()['category'] ?? doc.data()['type'] ?? 'General').toString();
                  final header = _formatSectionHeader(rawCat);
                  grouped.putIfAbsent(header, () => []).add(doc);
                }

                return Column(
                  children: [
                    // Search & Filters Header
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
                              suffixIcon: query.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: Color(0xFF9CA3AF)),
                                      onPressed: () => _searchController.clear(),
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFFF3F4F6),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: availableFilters.map((filter) {
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

                    // Document List or Empty State
                    Expanded(
                      child: accessibleDocs.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEEF2FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.folder_open_rounded, color: Color(0xFF4F46E5), size: 36),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No Documents Uploaded Yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Documents uploaded by HR Admin in the Web Application will automatically appear here.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : filteredDocs.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No documents match "$query"',
                                          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _selectedFilter = 'All');
                                          },
                                          child: const Text('Clear Filters', style: TextStyle(color: Color(0xFF4F46E5))),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : RefreshIndicator(
                                  color: const Color(0xFF4F46E5),
                                  onRefresh: () async {
                                    setState(() {});
                                  },
                                  child: ListView(
                                    padding: const EdgeInsets.all(16),
                                    children: grouped.entries.map((entry) {
                                      final sectionTitle = entry.key;
                                      final items = entry.value;

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
                                          ...items.map((doc) => _buildDocumentCard(doc)),
                                          const SizedBox(height: 8),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
