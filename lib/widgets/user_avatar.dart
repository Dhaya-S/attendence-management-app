import 'dart:convert';
import 'package:flutter/material.dart';

/// A person's avatar: their profile photo when they uploaded one (stored on their profile as
/// `profileImageUrl` — an https URL or a small base64 image), otherwise their initials.
/// Everyone in the same organization sees the same photo because it lives on the profile.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? imageData;
  final double radius;
  final Color? color;

  const UserAvatar({
    super.key,
    required this.name,
    this.imageData,
    this.radius = 22,
    this.color,
  });

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static Color colorFor(String name) {
    const colors = [
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFFEF4444),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  ImageProvider? _provider() {
    final v = (imageData ?? '').trim();
    if (v.isEmpty) return null;
    try {
      if (v.startsWith('http')) return NetworkImage(v);
      return MemoryImage(base64Decode(v.contains(',') ? v.split(',').last : v));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ?? colorFor(name);
    final img = _provider();
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: img,
      onBackgroundImageError: img == null ? null : (_, __) {},
      child: img == null
          ? Text(initialsOf(name),
              style: TextStyle(color: Colors.white, fontSize: radius * 0.62, fontWeight: FontWeight.bold))
          : null,
    );
  }
}
