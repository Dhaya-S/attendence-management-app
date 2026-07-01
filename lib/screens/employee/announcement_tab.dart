import 'package:flutter/material.dart';
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
    List<Map<String, dynamic>> anns = [
      {
        'tag': 'Policy',
        'ago': '2 days ago',
        'title': 'Updated Leave Policy FY 2025–26',
        'desc':
            'Effective July 1st, 2025: All employees must submit leave requests at least one week in advance. Any exceptions must be approved directly by the HR manager.',
        'likes': '12',
        'hearts': '4',
        'stars': '6',
        'comments': '3',
      },
      {
        'tag': 'HR',
        'ago': 'Yesterday',
        'title': 'Work From Office Reminder',
        'desc':
            'All employees must report Mon–Thu. WFH on Fridays only with manager approval. Failure to comply will result in a leave deduction for the day.',
        'likes': '8',
        'hearts': '2',
        'stars': '1',
        'comments': '1',
      },
      {
        'tag': 'Events',
        'ago': '3 days ago',
        'title': 'Team Building Day – 2 Aug',
        'desc':
            'Join us for team building at Lotus Valley Resort on August 2nd. Buses leave at 8 AM. Ensure you carry your ID card and casual wear.',
        'likes': '20',
        'hearts': '15',
        'stars': '22',
        'comments': '7',
      },
      {
        'tag': 'Reminders',
        'ago': '4 days ago',
        'title': 'Appraisal Submission Deadline',
        'desc':
            'Submit self-appraisal forms by July 31st on the HR portal. Late submissions will not be entertained for this review cycle.',
        'likes': '5',
        'hearts': '1',
        'stars': '0',
        'comments': '2',
      },
    ];

    if (_selectedFilter != 'All') {
      anns = anns
          .where((a) =>
              a['tag'].toString().toLowerCase() ==
              _selectedFilter.toLowerCase())
          .toList();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: anns.length,
      itemBuilder: (context, index) {
        final a = anns[index];
        return _buildAnnouncementCard(a);
      },
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> data) {
    Color tagColor;
    Color tagBgColor;
    final tag = data['tag'].toString().toLowerCase();

    if (tag == 'hr') {
      tagColor = const Color(0xFF2563EB); // Blue
      tagBgColor = const Color(0xFFEFF6FF);
    } else if (tag == 'policy') {
      tagColor = const Color(0xFF8B5CF6); // Purple/Indigo
      tagBgColor = const Color(0xFFF5F3FF);
    } else if (tag == 'events') {
      tagColor = const Color(0xFF8B5CF6); // Purple/Indigo
      tagBgColor = const Color(0xFFF5F3FF);
    } else if (tag == 'reminders') {
      tagColor = const Color(0xFFD97706); // Orange/Amber
      tagBgColor = const Color(0xFFFFFBEB);
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
                  data['tag'],
                  style: TextStyle(
                    fontSize: 11,
                    color: tagColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                data['ago'],
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
            data['title'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['desc'],
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
                  _statIcon(Icons.thumb_up_alt_outlined, data['likes']),
                  const SizedBox(width: 12),
                  _statIcon(Icons.favorite_border_rounded, data['hearts']),
                  const SizedBox(width: 12),
                  _statIcon(Icons.star_border_rounded, data['stars']),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(
                    data['comments'],
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
}
