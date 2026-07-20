import 'dart:math';
import 'package:flutter/material.dart';
import 'package:attendance_app/theme/app_theme.dart';

class AnimatedMeshGradient extends StatefulWidget {
  final Widget? child;
  const AnimatedMeshGradient({super.key, this.child});

  @override
  State<AnimatedMeshGradient> createState() => _AnimatedMeshGradientState();
}

class _AnimatedMeshGradientState extends State<AnimatedMeshGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Orb configurations (x, y, radius, color)
  final List<_Orb> _orbs = [
    _Orb(AppTheme.primary, 0.2, 0.3, 150), // Orange
    _Orb(const Color(0xFFFF5722), 0.8, 0.7, 180), // Deep Orange
    _Orb(const Color(0xFFFFCC80), 0.5, 0.5, 120), // Light Orange
    _Orb(const Color(0xFFFFAB91), 0.9, 0.2, 100), // Light Coral
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Background Fill
        Container(color: AppTheme.surfaceVariant),

        // 2. Animated Orbs
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _MeshGradientPainter(
                progress: _controller.value,
                orbs: _orbs,
              ),
              size: Size.infinite,
            );
          },
        ),

        // 3. Blur Overlay (Glass Effect)
        // BackdropFilter(
        //   filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        //   child: Container(color: Colors.white.withOpacity(0.3)),
        // ),
        // Using a simpler heavy blur approach for better performance
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.5),
              ],
            ),
          ),
        ),

        // 4. Content
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _Orb {
  final Color color;
  final double initialX;
  final double initialY;
  final double radius;

  _Orb(this.color, this.initialX, this.initialY, this.radius);
}

class _MeshGradientPainter extends CustomPainter {
  final double progress;
  final List<_Orb> orbs;

  _MeshGradientPainter({required this.progress, required this.orbs});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    for (var i = 0; i < orbs.length; i++) {
      final orb = orbs[i];
      paint.color = orb.color.withOpacity(0.6);

      // Complex movement calculation using sine/cosine for organic drift
      final moveX = sin(progress * 2 * pi + i) * 50;
      final moveY = cos(progress * 2 * pi + i * 2) * 50;

      final x = (orb.initialX * size.width) + moveX;
      final y = (orb.initialY * size.height) + moveY;

      canvas.drawCircle(Offset(x, y), orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) => true;
}
