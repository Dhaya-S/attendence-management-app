import 'package:flutter/material.dart';

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
    'Birthdays',
    'New Hires',
    'Manager',
    'Events'
  ];

  final List<Map<String, dynamic>> _announcements = [
    {
      'tag': 'Task',
      'tagColor': const Color(0xFF6366F1), // Indigo/Purple
      'tagBg': const Color(0xFFEEF2FF),
      'time': '09:00 AM',
      'title': 'Wireframe Review — EOD Today',
      'subtitle': 'Due: Today, 6:00 PM',
      'subtitleColor': const Color(0xFF5C5CFF),
      'body':
          'Complete the wireframe review and send updated Figma files to the team...',
    },
    {
      'tag': 'Meeting',
      'tagColor': const Color(0xFF3B82F6), // Blue
      'tagBg': const Color(0xFFEFF6FF),
      'time': 'Yesterday',
      'title': 'Sprint Planning — Thursday 3 PM',
      'subtitle': 'Conference Room A · Thu 3:00 PM',
      'subtitleColor': const Color(0xFF5C5CFF),
      'body':
          'Weekly sprint planning has been moved to Thursday at 3:00 PM in Confer...',
    },
    {
      'tag': 'Policy',
      'tagColor': const Color(0xFF6366F1), // Indigo/Purple
      'tagBg': const Color(0xFFEEF2FF),
      'time': '2 days ago',
      'title': 'WFO Policy Update',
      'subtitle': 'Effective: Aug 1, 2026',
      'subtitleColor': const Color(0xFF5C5CFF),
      'body':
          'Work From Office policy updated effective August 1, 2026. All team mem...',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Container(
          color: const Color(0xFFF9FAFB),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _announcements.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildAnnouncementCard(_announcements[index]);
            },
          ),
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

  Widget _buildAnnouncementCard(Map<String, dynamic> data) {
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
                  color: data['tagBg'],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  data['tag'],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: data['tagColor'],
                  ),
                ),
              ),
              Text(
                data['time'],
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
            data['title'],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data['subtitle'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: data['subtitleColor'],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['body'],
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
            children: const [
              Text(
                'View Details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5C5CFF),
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Color(0xFF5C5CFF),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
