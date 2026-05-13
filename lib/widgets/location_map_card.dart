import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:attendance_app/theme/app_theme.dart';

class LocationMapCard extends StatefulWidget {
  const LocationMapCard({
    super.key,
    required this.officeLat,
    required this.officeLng,
    required this.allowedRadius,
    this.userLocation,
    this.userAddress,
    this.height,
  });

  final double officeLat;
  final double officeLng;
  final double allowedRadius;
  final LatLng? userLocation;
  final String? userAddress;
  final double? height;

  @override
  State<LocationMapCard> createState() => _LocationMapCardState();
}

class _LocationMapCardState extends State<LocationMapCard> {
  GoogleMapController? _mapController;

  // Cache markers and circles to prevent rebuilds
  Set<Marker>? _cachedMarkers;
  Set<Circle>? _cachedCircles;
  LatLng? _lastUserLocation;
  String? _lastUserAddress;

  @override
  void dispose() {
    try {
      _mapController?.dispose();
    } catch (e) {
      // Ignore web-specific disposal error: "Maps cannot be retrieved before calling buildView!"
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(LocationMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Invalidate cache if user location or address changed
    if (widget.userLocation != _lastUserLocation ||
        widget.userAddress != _lastUserAddress) {
      _cachedMarkers = null;
      _lastUserLocation = widget.userLocation;
      _lastUserAddress = widget.userAddress;
    }

    // Animate to user location when it updates
    if (widget.userLocation != null &&
        widget.userLocation != oldWidget.userLocation &&
        _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(widget.userLocation!, 15.0),
      );
    }
  }

  Set<Marker> _getMarkers() {
    // Return cached markers if available
    if (_cachedMarkers != null) return _cachedMarkers!;

    final markers = <Marker>{};

    // Office marker
    markers.add(
      Marker(
        markerId: const MarkerId('office'),
        position: LatLng(widget.officeLat, widget.officeLng),
        infoWindow: const InfoWindow(title: 'Office'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // User location marker
    if (widget.userLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: widget.userLocation!,
          infoWindow: InfoWindow(
            title: 'You',
            snippet: widget.userAddress ?? 'Your Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    _cachedMarkers = markers;
    return markers;
  }

  Set<Circle> _getCircles() {
    // Cache circles (they never change)
    _cachedCircles ??= {
      Circle(
        circleId: const CircleId('office_radius'),
        center: LatLng(widget.officeLat, widget.officeLng),
        radius: widget.allowedRadius,
        fillColor: AppTheme.primary.withOpacity(0.2),
        strokeColor: AppTheme.primary,
        strokeWidth: 2,
      ),
    };
    return _cachedCircles!;
  }

  @override
  Widget build(BuildContext context) {
    final officeLocation = LatLng(widget.officeLat, widget.officeLng);

    return Container(
      height: widget.height ?? double.infinity,
      width: double.infinity,
      decoration: widget.height == null ? null : BoxDecoration(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.height == null ? 0 : 20),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: officeLocation,
            zoom: 15.0,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
          },
          markers: _getMarkers(),
          circles: _getCircles(),

          // Enable smooth gestures for user interaction
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,

          // Native-like features
          buildingsEnabled: true, // Show 3D buildings
          indoorViewEnabled: true,
          trafficEnabled: false,

          // Zoom preferences
          minMaxZoomPreference: const MinMaxZoomPreference(10.0, 20.0),

          // Disable unnecessary controls
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false, // Disable on-screen zoom buttons
          mapToolbarEnabled: false,
          compassEnabled: true, // Show compass for orientation
        ),
      ),
    );
  }
}
