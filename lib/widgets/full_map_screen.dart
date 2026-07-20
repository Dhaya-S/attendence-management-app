import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:attendance_app/widgets/location_map_card.dart';
import 'package:attendance_app/theme/app_theme.dart';

class FullMapScreen extends StatelessWidget {
  final double officeLat, officeLng, allowedRadius;
  final LatLng? userLocation;
  final String? userAddress;
  const FullMapScreen(
      {super.key,
      required this.officeLat,
      required this.officeLng,
      required this.allowedRadius,
      this.userLocation,
      this.userAddress});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
            margin: const EdgeInsets.only(left: 16, top: 12),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: Color(0xFF111827), size: 20),
                onPressed: () => Navigator.pop(context))),
      ),
      body: Stack(children: [
        LocationMapCard(
            officeLat: officeLat,
            officeLng: officeLng,
            allowedRadius: allowedRadius,
            userLocation: userLocation,
            userAddress: userAddress),
        Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: FadeInUp(
                child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.location_on,
                        color: AppTheme.primary, size: 24)),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Office Range Area',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827))),
                      const SizedBox(height: 4),
                      Text(
                          'Allowed geofence radius: ${allowedRadius.toInt()} meters.',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500)),
                    ])),
              ]),
            ))),
      ]),
    );
  }
}
